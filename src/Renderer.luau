--!strict
--!native
local Types = require(script.Parent.Types)
local CONSTANTS = require(script.Parent.CONSTANTS)
local Geometry = require(script.Parent.Geometry)
local Mesh = require(script.Parent.Mesh)
local PartSource = require(script.Parent.PartSource)
type PartHandle = Types.PartHandle
type ModelHandle = Types.ModelHandle
type Record = Types.Record
type Bucket = Types.Bucket
type ModelRecord = { Handle: ModelHandle, Parts: { PartHandle }, Buckets: { Bucket }, InitialScale: number }
export type Renderer = {
	RenderingPart: Part,
	CONSTANTS: typeof(CONSTANTS),
	Geometry: typeof(Geometry),
	Create: (self: Renderer, options: Types.PartOptions) -> (PartHandle?, string?),
	CreateMany: (self: Renderer, options: { Types.PartOptions }) -> ({ PartHandle }?, string?),
	FromPart: (self: Renderer, part: BasePart) -> (PartHandle?, string?),
	Update: (self: Renderer, handle: PartHandle) -> (),
	UpdateMany: (self: Renderer, handles: { PartHandle }) -> (),
	PivotTo: (self: Renderer, handle: PartHandle, pivot: CFrame) -> (),
	GetPivot: (self: Renderer, handle: PartHandle) -> CFrame,
	Remove: (self: Renderer, handle: PartHandle) -> (),
	RemoveMany: (self: Renderer, handles: { PartHandle }) -> (),
	GetGeometry: (self: Renderer, handle: PartHandle) -> Types.GeometryInfo,
	FromModel: (self: Renderer, model: Model) -> (ModelHandle?, string?),
	UpdateModel: (self: Renderer, handle: ModelHandle) -> (),
	RemoveModel: (self: Renderer, handle: ModelHandle) -> (),
	GetStats: (self: Renderer) -> Types.Stats,
	Destroy: (self: Renderer) -> (),
}

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end
local function validate(handle: PartHandle)
	local size = handle.Size
	assert(
		finite(size.X) and finite(size.Y) and finite(size.Z) and size.X > 0 and size.Y > 0 and size.Z > 0,
		"Size must be finite and positive"
	)
	assert(
		finite(handle.Transparency) and handle.Transparency >= 0 and handle.Transparency <= 1,
		"Transparency must be in [0, 1]"
	)
end
local function sameStyle(a: Types.Style, b: Types.Style): boolean
	return a.Material == b.Material
		and a.MaterialVariant == b.MaterialVariant
		and a.Reflectance == b.Reflectance
		and a.CastShadow == b.CastShadow
		and a.SurfaceAppearance == b.SurfaceAppearance
		and a.TextureID == b.TextureID
		and a.DoubleSided == b.DoubleSided
end

local function new(): Renderer
	local root = Instance.new("Part")
	root.Name = "QuickPart"
	root.Size = Vector3.one
	root.CFrame = CFrame.identity
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide, root.CanTouch, root.CanQuery = false, false, false
	root.CastShadow = false
	root.Parent = workspace
	local records: { [number]: Record } = {}
	local models: { [number]: ModelRecord } = {}
	local buckets: { Bucket } = {}
	local nextId, triangles, partCount = 0, 0, 0
	local busy, destroyed = false, false
	local function ready()
		assert(not destroyed, "Renderer is destroyed")
		assert(not busy, "Renderer is creating meshes; wait for the creation call to finish")
	end
	local function limit(): number
		assert(
			finite(CONSTANTS.TRIANGLE_BUDGET_PERCENT)
				and CONSTANTS.TRIANGLE_BUDGET_PERCENT >= 0
				and CONSTANTS.TRIANGLE_BUDGET_PERCENT <= 100,
			"TRIANGLE_BUDGET_PERCENT must be in [0, 100]"
		)
		assert(
			finite(CONSTANTS.TRIANGLE_BUDGET) and CONSTANTS.TRIANGLE_BUDGET >= 0,
			"TRIANGLE_BUDGET must be nonnegative"
		)
		return math.floor(CONSTANTS.TRIANGLE_BUDGET * CONSTANTS.TRIANGLE_BUDGET_PERCENT / 100)
	end
	local function get(handle: PartHandle): Record
		local record = records[handle.Id]
		assert(record and record.Handle == handle, "Unknown, removed, or foreign part handle (Id is read-only)")
		return record
	end
	local function clean()
		for index = #buckets, 1, -1 do
			local bucket = buckets[index]
			if bucket.Count == 0 then
				Mesh.destroy(bucket)
				table.remove(buckets, index)
			end
		end
	end
	local function remove(handle: PartHandle)
		local record = get(handle)
		Mesh.remove(record)
		triangles -= record.Geometry.TriangleCount
		partCount -= 1
		records[handle.Id] = nil
	end
	local connection = root:GetPropertyChangedSignal("CFrame"):Connect(function()
		for _, bucket in buckets do
			Mesh.sync(bucket, root)
		end
	end)

	local function createMany(options: { Types.PartOptions }, group: number, origin: CFrame): ({ PartHandle }?, string?)
		ready()
		busy = true
		local created: { PartHandle } = {}
		local touched: { [Bucket]: boolean } = {}
		local ok, reason = pcall(function()
			for _, option in options do
				nextId += 1
				local handle: PartHandle = {
					Id = nextId,
					Size = option.Size,
					CFrame = option.CFrame or CFrame.identity,
					PivotOffset = option.PivotOffset or CFrame.identity,
					Color = option.Color or Color3.new(1, 1, 1),
					Transparency = option.Transparency or 0,
				}
				validate(handle)
				assert(
					CONSTANTS.CURVE_SEGMENTS >= 8
						and CONSTANTS.CURVE_SEGMENTS <= 128
						and CONSTANTS.CURVE_SEGMENTS % 2 == 0,
					"CURVE_SEGMENTS must be an even integer in [8, 128]"
				)
				local geometry = option.Geometry
					or Geometry.primitive(option.Shape or "Block", CONSTANTS.CURVE_SEGMENTS)
				if option.Geometry then
					Geometry.validate(geometry)
				end
				assert(triangles + geometry.TriangleCount <= limit(), "Triangle budget exhausted")
				local style: Types.Style = {
					Material = option.Material or Enum.Material.Plastic,
					MaterialVariant = option.MaterialVariant or "",
					Reflectance = option.Reflectance or 0,
					CastShadow = if option.CastShadow == nil then true else option.CastShadow,
					SurfaceAppearance = option.SurfaceAppearance,
					TextureID = option.TextureID or "",
					DoubleSided = option.DoubleSided or false,
				}
				assert(
					finite(style.Reflectance) and style.Reflectance >= 0 and style.Reflectance <= 1,
					"Reflectance must be in [0, 1]"
				)
				local triangleLimit = math.min(CONSTANTS.MAX_TRIANGLES_PER_MESH, 20000)
				local vertexLimit = math.min(CONSTANTS.MAX_VERTICES_PER_MESH, 60000)
				assert(
					geometry.TriangleCount <= triangleLimit and #geometry.Vertices <= vertexLimit,
					"Shape exceeds per-mesh capacity"
				)
				local selected: Bucket? = nil
				for _, bucket in buckets do
					if
						bucket.Group == group
						and sameStyle(style, bucket.Style)
						and bucket.Triangles + geometry.TriangleCount <= triangleLimit
						and bucket.Vertices + #geometry.Vertices <= vertexLimit
					then
						selected = bucket
						break
					end
				end
				if not selected then
					selected = Mesh.new(style, group, origin)
					assert(selected, "EditableMesh memory exhausted")
					table.insert(buckets, selected)
				end
				local bucket = selected :: Bucket
				touched[bucket] = true
				records[handle.Id] = Mesh.add(bucket, handle, geometry)
				table.insert(created, handle)
				triangles += geometry.TriangleCount
				partCount += 1
			end
			-- Only yields after all topology has been prepared; busy prevents races.
			for bucket in touched do
				Mesh.attach(bucket, root)
			end
		end)
		if not ok then
			for _, handle in created do
				remove(handle)
			end
			for bucket in touched do
				if bucket.Count > 0 then
					bucket.Mesh:RemoveUnused()
				end
			end
			clean()
			busy = false
			return nil, tostring(reason)
		end
		busy = false
		return created, nil
	end

	local api = { RenderingPart = root, CONSTANTS = CONSTANTS, Geometry = Geometry } :: Renderer
	function api:CreateMany(options: { Types.PartOptions }): ({ PartHandle }?, string?)
		return createMany(options, 0, CFrame.identity)
	end
	function api:Create(options: Types.PartOptions): (PartHandle?, string?)
		local result, reason = api:CreateMany({ options })
		return if result then result[1] else nil, reason
	end
	function api:FromPart(part: BasePart): (PartHandle?, string?)
		local options, reason = PartSource.options(part)
		if not options then
			return nil, reason
		end
		return api:Create(options)
	end
	function api:UpdateMany(handles: { PartHandle })
		ready()
		-- Validate the complete batch before writing anything; duplicate handles are harmless.
		for _, handle in handles do
			get(handle)
			validate(handle)
		end
		local touched: { [Bucket]: boolean } = {}
		for _, handle in handles do
			local record = get(handle)
			if Mesh.queue(record) then
				touched[record.Bucket] = true
			end
		end
		for bucket in touched do
			Mesh.flush(bucket)
		end
	end
	function api:Update(handle: PartHandle)
		ready()
		local record = get(handle)
		validate(handle)
		Mesh.queue(record)
		Mesh.flush(record.Bucket)
	end
	function api:PivotTo(handle: PartHandle, pivot: CFrame)
		ready()
		get(handle)
		handle.CFrame = pivot * handle.PivotOffset:Inverse()
		api:Update(handle)
	end
	function api:GetPivot(handle: PartHandle): CFrame
		ready()
		get(handle)
		return handle.CFrame * handle.PivotOffset
	end
	function api:RemoveMany(handles: { PartHandle })
		ready()
		for _, handle in handles do
			get(handle)
		end
		local removed: { [PartHandle]: boolean } = {}
		local touched: { [Bucket]: boolean } = {}
		for _, handle in handles do
			if not removed[handle] then
				touched[get(handle).Bucket] = true
				remove(handle)
				removed[handle] = true
			end
		end
		for bucket in touched do
			if bucket.Count > 0 then
				bucket.Mesh:RemoveUnused()
			end
		end
		clean()
	end
	function api:Remove(handle: PartHandle)
		api:RemoveMany({ handle })
	end
	function api:GetGeometry(handle: PartHandle)
		ready()
		local record = get(handle)
		return {
			EditableMesh = record.Bucket.Mesh,
			RenderingPart = record.Bucket.Part,
			VertexIds = table.clone(record.VertexIds),
			TriangleIds = table.clone(record.FaceIds),
			FaceIds = table.clone(record.FaceIds),
			ColorId = record.ColorId,
			ColorIds = table.clone(record.ColorIds),
			NormalIds = table.clone(record.NormalIds),
		}
	end
	function api:FromModel(model: Model): (ModelHandle?, string?)
		ready()
		local pivot, initialScale = model:GetPivot(), model:GetScale()
		local options: { Types.PartOptions } = {}
		for _, instance in model:GetDescendants() do
			if instance:IsA("BasePart") then
				local option, reason = PartSource.options(instance)
				if not option then
					return nil, reason
				end
				option.CFrame = pivot:ToObjectSpace(instance.CFrame)
				table.insert(options, option)
			end
		end
		if #options == 0 then
			return nil, "Model contains no BaseParts"
		end
		nextId += 1
		local handle: ModelHandle = { Id = nextId, Scale = initialScale, WorldPivot = pivot }
		local parts, reason = createMany(options, handle.Id, pivot)
		if not parts then
			return nil, reason
		end
		local modelBuckets: { Bucket } = {}
		for _, bucket in buckets do
			if bucket.Group == handle.Id then
				table.insert(modelBuckets, bucket)
			end
		end
		models[handle.Id] = { Handle = handle, Parts = parts, Buckets = modelBuckets, InitialScale = initialScale }
		return handle, nil
	end
	function api:UpdateModel(handle: ModelHandle)
		ready()
		local record = models[handle.Id]
		assert(record and record.Handle == handle, "Unknown, removed, or foreign model handle")
		assert(finite(handle.Scale) and handle.Scale > 0, "Scale must be finite and positive")
		for _, bucket in record.Buckets do
			bucket.Origin = handle.WorldPivot
			bucket.Scale = handle.Scale / record.InitialScale
			Mesh.sync(bucket, root)
		end
	end
	function api:RemoveModel(handle: ModelHandle)
		ready()
		local record = models[handle.Id]
		assert(record and record.Handle == handle, "Unknown, removed, or foreign model handle")
		api:RemoveMany(record.Parts)
		models[handle.Id] = nil
	end
	function api:GetStats()
		local modelCount, batchCount = 0, 0
		for _ in models do
			modelCount += 1
		end
		for _, bucket in buckets do
			if bucket.Write then
				batchCount += 1
			end
		end
		return {
			Parts = partCount,
			Models = modelCount,
			Meshes = #buckets,
			Triangles = triangles,
			TriangleLimit = limit(),
			BatchMeshes = batchCount,
		}
	end
	function api:Destroy()
		if destroyed then
			return
		end
		ready()
		connection:Disconnect()
		for _, bucket in buckets do
			Mesh.destroy(bucket)
		end
		table.clear(buckets)
		table.clear(records)
		table.clear(models)
		triangles, partCount = 0, 0
		root:Destroy()
		destroyed = true
	end
	return api
end
return { new = new }
