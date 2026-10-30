--!strict
--!native
local AssetService = game:GetService("AssetService")
local Types = require(script.Parent.Types)
local Geometry = require(script.Parent.Geometry)
local CONSTANTS = require(script.Parent.CONSTANTS)
type Bucket = Types.Bucket
type Record = Types.Record
local Mesh = {}
local function tint(a: Color3, b: Color3): Color3
	return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

function Mesh.new(style: Types.Style, group: number, origin: CFrame): Bucket?
	local editable = AssetService:CreateEditableMesh()
	if not editable then
		return nil
	end
	return {
		Mesh = editable,
		Part = nil,
		Style = style,
		Group = group,
		Origin = origin,
		Scale = 1,
		BaseSize = Vector3.one,
		Count = 0,
		Triangles = 0,
		Vertices = 0,
		Write = nil,
		PendingIds = {},
		PendingPositions = {},
	}
end

function Mesh.attach(bucket: Bucket, root: BasePart)
	if bucket.Part then
		return
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(bucket.Mesh), {
		CollisionFidelity = Enum.CollisionFidelity.Box,
		RenderFidelity = Enum.RenderFidelity.Precise,
	})
	bucket.Part = part -- Retain immediately so failure cleanup also destroys this instance.
	part.Name = `Batch_{bucket.Group}`
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Color = Color3.new(1, 1, 1)
	part.Transparency = 0
	part.Material = bucket.Style.Material
	part.MaterialVariant = bucket.Style.MaterialVariant
	part.Reflectance = bucket.Style.Reflectance
	part.CastShadow = bucket.Style.CastShadow
	part.TextureID = bucket.Style.TextureID
	part.DoubleSided = bucket.Style.DoubleSided
	local appearance = bucket.Style.SurfaceAppearance
	if appearance then
		local clone = appearance:Clone()
		assert(clone, "SurfaceAppearance must be Archivable")
		clone.Parent = part
	end
	-- Keep one stud in EditableMesh space equal to one stud in part space.
	bucket.BaseSize = part.Size
	part.CFrame = root.CFrame * bucket.Origin
	part.Parent = root
end

function Mesh.sync(bucket: Bucket, root: BasePart)
	local part = bucket.Part
	if part then
		part.CFrame = root.CFrame * bucket.Origin
		part.Size = bucket.BaseSize * bucket.Scale
	end
end

function Mesh.add(bucket: Bucket, handle: Types.PartHandle, geometry: Types.Geometry): Record
	local mesh = bucket.Mesh
	local vertices: { number } = {}
	local faces: { number } = {}
	local colorId = 0
	local colorIds: { number } = {}
	local baseColors: { Color3 } = {}
	local baseAlphas: { number } = {}
	local normalIds: { number } = {}
	local baseNormals: { Vector3 } = {}
	local positions: { Vector3 } = {}
	Geometry.transform(geometry.Vertices, handle.Size, handle.CFrame, positions, 0)
	local ok, reason = pcall(function()
		for _, position in positions do
			table.insert(vertices, mesh:AddVertex(position))
		end
		for _, polygon in geometry.Faces do
			-- One auto normal per polygon gives hard box edges and a planar quad.
			local colors: { number } = {}
			local normals: { number } = {}
			local normal = if polygon.Normals then nil else mesh:AddNormal()
			local uvs: { number } = {}
			for corner = 1, #polygon.Vertices do
				table.insert(uvs, mesh:AddUV(polygon.UVs[corner]))
				if polygon.Normals then
					local base = polygon.Normals[corner]
					local id = mesh:AddNormal(handle.CFrame:VectorToWorldSpace((base / handle.Size).Unit))
					table.insert(normals, id)
					table.insert(normalIds, id)
					table.insert(baseNormals, base)
				else
					table.insert(normals, normal :: number)
				end
				if polygon.Colors or polygon.Alphas then
					local color = if polygon.Colors then polygon.Colors[corner] else Color3.new(1, 1, 1)
					local alpha = if polygon.Alphas then polygon.Alphas[corner] else 1
					local id = mesh:AddColor(tint(color, handle.Color), alpha * (1 - handle.Transparency))
					table.insert(colors, id)
					table.insert(colorIds, id)
					table.insert(baseColors, color)
					table.insert(baseAlphas, alpha)
				else
					if colorId == 0 then
						colorId = mesh:AddColor(handle.Color, 1 - handle.Transparency)
						table.insert(colorIds, colorId)
						table.insert(baseColors, Color3.new(1, 1, 1))
						table.insert(baseAlphas, 1)
					end
					table.insert(colors, colorId)
				end
			end
			for index = 2, #polygon.Vertices - 1 do
				local face = mesh:AddTriangle(
					vertices[polygon.Vertices[1]],
					vertices[polygon.Vertices[index]],
					vertices[polygon.Vertices[index + 1]]
				)
				table.insert(faces, face)
				mesh:SetFaceColors(face, { colors[1], colors[index], colors[index + 1] })
				mesh:SetFaceNormals(face, { normals[1], normals[index], normals[index + 1] })
				mesh:SetFaceUVs(face, { uvs[1], uvs[index], uvs[index + 1] })
			end
		end
	end)
	if not ok then
		for _, face in faces do
			mesh:RemoveFace(face)
		end
		mesh:RemoveUnused()
		error(tostring(reason), 0)
	end
	-- Probe once with an actual attribute ID; empty arrays cannot reliably test
	-- engines that infer the attribute kind from the first element.
	if bucket.Count == 0 and CONSTANTS.USE_BATCH_API then
		local supported = pcall(function()
			mesh:BatchSetValues({ vertices[1] }, { positions[1] })
		end)
		if supported then
			bucket.Write = function(target: EditableMesh, ids: { number }, values: { Vector3 })
				target:BatchSetValues(ids, values)
			end
		end
	end
	bucket.Count += 1
	bucket.Triangles += geometry.TriangleCount
	bucket.Vertices += #vertices
	return {
		Handle = handle,
		Bucket = bucket,
		Geometry = geometry,
		VertexIds = vertices,
		FaceIds = faces,
		ColorId = if colorId == 0 then colorIds[1] else colorId,
		ColorIds = colorIds,
		BaseColors = baseColors,
		BaseAlphas = baseAlphas,
		NormalIds = normalIds,
		BaseNormals = baseNormals,
		Size = handle.Size,
		CFrame = handle.CFrame,
		Color = handle.Color,
		Transparency = handle.Transparency,
	}
end

function Mesh.queue(record: Record): boolean
	local handle, bucket = record.Handle, record.Bucket
	local changed = handle.Size ~= record.Size or handle.CFrame ~= record.CFrame
	if changed then
		local offset = #bucket.PendingIds
		Geometry.transform(record.Geometry.Vertices, handle.Size, handle.CFrame, bucket.PendingPositions, offset)
		for index, id in record.VertexIds do
			bucket.PendingIds[offset + index] = id
		end
		if handle.Size ~= record.Size or handle.CFrame.Rotation ~= record.CFrame.Rotation then
			for index, id in record.NormalIds do
				bucket.Mesh:SetNormal(
					id,
					handle.CFrame:VectorToWorldSpace((record.BaseNormals[index] / handle.Size).Unit)
				)
			end
		end
		record.Size, record.CFrame = handle.Size, handle.CFrame
	end
	if handle.Color ~= record.Color then
		for index, id in record.ColorIds do
			bucket.Mesh:SetColor(id, tint(record.BaseColors[index], handle.Color))
		end
		record.Color = handle.Color
	end
	if handle.Transparency ~= record.Transparency then
		for index, id in record.ColorIds do
			bucket.Mesh:SetColorAlpha(id, record.BaseAlphas[index] * (1 - handle.Transparency))
		end
		record.Transparency = handle.Transparency
	end
	return changed
end

function Mesh.flush(bucket: Bucket)
	if #bucket.PendingIds == 0 then
		return
	end
	local writer = bucket.Write
	if writer then
		writer(bucket.Mesh, bucket.PendingIds, bucket.PendingPositions)
	else
		for index, id in bucket.PendingIds do
			bucket.Mesh:SetPosition(id, bucket.PendingPositions[index])
		end
	end
	table.clear(bucket.PendingIds)
	table.clear(bucket.PendingPositions)
end

function Mesh.remove(record: Record)
	local bucket = record.Bucket
	for _, face in record.FaceIds do
		bucket.Mesh:RemoveFace(face)
	end
	bucket.Count -= 1
	bucket.Triangles -= record.Geometry.TriangleCount
	bucket.Vertices -= #record.VertexIds
end

function Mesh.destroy(bucket: Bucket)
	if bucket.Part then
		bucket.Part:Destroy()
	end
	bucket.Mesh:Destroy()
end
return Mesh
