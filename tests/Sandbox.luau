--!strict
-- Lune only. This models API contracts and fault injection, not engine performance.
local roblox = require("@lune/roblox")
local loadPackage = require("../scripts/load-package")
local r = roblox :: any

return function(batchAvailable: boolean?)
	local state: any = {
		Meshes = {},
		Objects = {},
		FailCreate = false,
		FailAttach = false,
		FailAfter = nil,
		Writes = 0,
		BatchCalls = 0,
		WaitCalls = 0,
		CFrameWrites = 0,
		BulkCalls = 0,
	}
	local function newObject(className: string): any
		local data: any = {
			ClassName = className,
			Name = className,
			CFrame = r.CFrame.identity,
			WorldPivot = r.CFrame.identity,
			Size = r.Vector3.one,
			PivotOffset = r.CFrame.identity,
			Color = r.Color3.new(1, 1, 1),
			Transparency = 0,
			Material = r.Enum.Material.Plastic,
			MaterialVariant = "",
			Reflectance = 0,
			CastShadow = true,
			Shape = r.Enum.PartType.Block,
			ScaleValue = 1,
			Signals = {},
			Destroyed = false,
		}
		local object: any = setmetatable({}, {
			__index = data,
			__newindex = function(_self: any, key: string, value: any)
				if key == "CFrame" then
					state.CFrameWrites += 1
				end
				data[key] = value
				for _, callback in data.Signals[key] or {} do
					callback()
				end
			end,
		})
		function data:IsA(name: string): boolean
			return name == className
				or (
					name == "BasePart"
					and table.find({ "Part", "MeshPart", "WedgePart", "CornerWedgePart" }, className) ~= nil
				)
		end
		function data:GetChildren(): { any }
			local children = {}
			for _, item in state.Objects do
				if item.Parent == object and not item.Destroyed then
					table.insert(children, item)
				end
			end
			return children
		end
		function data:GetDescendants(): { any }
			local result = {}
			local function visit(parent: any)
				for _, child in parent:GetChildren() do
					table.insert(result, child)
					visit(child)
				end
			end
			visit(object)
			return result
		end
		function data:FindFirstChildWhichIsA(name: string): any
			for _, item in object:GetChildren() do
				if item:IsA(name) then
					return item
				end
			end
			return nil
		end
		function data:GetFullName(): string
			return data.Name
		end
		function data:GetPivot(): any
			return if className == "Model" then data.WorldPivot else data.CFrame * data.PivotOffset
		end
		function data:GetScale(): number
			return data.ScaleValue
		end
		function data:Destroy()
			data.Destroyed = true
			for _, item in object:GetChildren() do
				item:Destroy()
			end
			data.Parent = nil
		end
		function data:Clone(): any
			return newObject(className)
		end
		function data:GetPropertyChangedSignal(key: string): any
			data.Signals[key] = data.Signals[key] or {}
			return {
				Connect = function(_signal: any, callback: () -> ())
					table.insert(data.Signals[key], callback)
					return {
						Disconnect = function()
							table.clear(data.Signals[key])
						end,
					}
				end,
			}
		end
		table.insert(state.Objects, object)
		return object
	end
	local function newMesh(): any
		local mesh: any =
			{ NextId = 0, Vertices = {}, Faces = {}, Colors = {}, Normals = {}, UVs = {}, Destroyed = false }
		local function allocate(values: any, value: any): number
			if state.FailAfter ~= nil then
				if state.FailAfter == 0 then
					error("Injected allocation failure")
				end
				state.FailAfter -= 1
			end
			mesh.NextId += 7 -- Deliberately sparse: IDs are NOT array offsets.
			values[mesh.NextId] = value
			return mesh.NextId
		end
		function mesh:AddVertex(position: any): number
			return allocate(self.Vertices, position)
		end
		function mesh:AddColor(color: any, alpha: number): number
			return allocate(self.Colors, { Color = color, Alpha = alpha })
		end
		function mesh:AddNormal(normal: any): number
			return allocate(self.Normals, normal or r.Vector3.yAxis)
		end
		function mesh:SetNormal(id: number, normal: any)
			assert(self.Normals[id])
			self.Normals[id] = normal
		end
		function mesh:GetNormal(id: number): any
			return self.Normals[id]
		end
		function mesh:GetUV(id: number): any
			return self.UVs[id]
		end
		function mesh:GetBones(): { number }
			return if state.Skinned then { 7 } else {}
		end
		function mesh:GetVertices(): { number }
			local result = {}
			for id in self.Vertices do
				table.insert(result, id)
			end
			table.sort(result)
			return result
		end
		function mesh:GetFaces(): { number }
			local result = {}
			for id in self.Faces do
				table.insert(result, id)
			end
			table.sort(result)
			return result
		end
		function mesh:GetFaceVertices(id: number): any
			return self.Faces[id].Vertices
		end
		function mesh:GetFaceNormals(id: number): any
			return self.Faces[id].Normals
		end
		function mesh:GetFaceUVs(id: number): any
			return self.Faces[id].UVs
		end
		function mesh:GetFaceColors(id: number): any
			return self.Faces[id].Colors
		end
		function mesh:AddUV(uv: any): number
			return allocate(self.UVs, uv)
		end
		function mesh:AddTriangle(a: number, b: number, c: number): number
			return allocate(self.Faces, { Vertices = { a, b, c } })
		end
		function mesh:SetFaceColors(id: number, ids: any)
			self.Faces[id].Colors = ids
		end
		function mesh:SetFaceNormals(id: number, ids: any)
			self.Faces[id].Normals = ids
		end
		function mesh:SetFaceUVs(id: number, ids: any)
			self.Faces[id].UVs = ids
		end
		function mesh:GetPosition(id: number): any
			return self.Vertices[id]
		end
		function mesh:SetPosition(id: number, position: any)
			assert(self.Vertices[id], "Invalid stable vertex ID")
			self.Vertices[id] = position
			state.Writes += 1
		end
		function mesh:SetColor(id: number, color: any)
			self.Colors[id].Color = color
		end
		function mesh:SetColorAlpha(id: number, alpha: number)
			self.Colors[id].Alpha = alpha
		end
		function mesh:GetColorAlpha(id: number): number
			return self.Colors[id].Alpha
		end
		function mesh:GetColor(id: number): any
			return self.Colors[id].Color
		end
		function mesh:BatchSetValues(ids: any, values: any)
			assert(batchAvailable ~= false, "Batch API unavailable")
			assert(#ids == #values)
			state.BatchCalls += 1
			for index, id in ids do
				self:SetPosition(id, values[index])
			end
		end
		function mesh:RemoveFace(id: number)
			assert(self.Faces[id])
			self.Faces[id] = nil
		end
		function mesh:RemoveUnused()
			local used: any = {}
			for _, face in self.Faces do
				for _, kind in { "Vertices", "Colors", "Normals", "UVs" } do
					for _, id in face[kind] or {} do
						used[id] = true
					end
				end
			end
			for _, kind in { "Vertices", "Colors", "Normals", "UVs" } do
				for id in self[kind] do
					if not used[id] then
						self[kind][id] = nil
					end
				end
			end
		end
		function mesh:GetSize(): any
			local minimum, maximum =
				r.Vector3.new(math.huge, math.huge, math.huge), r.Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, position in self.Vertices do
				minimum = minimum:Min(position)
				maximum = maximum:Max(position)
			end
			return maximum - minimum
		end
		function mesh:Destroy()
			self.Destroyed = true
		end
		table.insert(state.Meshes, mesh)
		return mesh
	end
	local asset: any = {}
	function asset:CreateEditableMesh(): any
		return if state.FailCreate then nil else newMesh()
	end
	function asset:CreateEditableMeshAsync(_content: any): any
		return if state.FailCreate then nil else state.SourceMesh
	end
	function asset:CreateMeshPartAsync(mesh: any): any
		if state.OnAttach then
			state.OnAttach()
		end
		assert(not state.FailAttach, "Injected CreateMeshPartAsync failure")
		local part = newObject("MeshPart")
		part.Size = mesh:GetSize()
		part.Mesh = mesh
		return part
	end
	local world = newObject("Workspace")
	local services: any = {
		AssetService = asset,
		ReplicatedStorage = { Packages = { QuickPart = "src" }, Benchmarks = { Factory = "benchmarks/Factory" } },
	}
	function world:BulkMoveTo(parts: { any }, frames: { any }, _mode: any)
		state.BulkCalls += 1
		assert(#parts == #frames)
		for index, part in parts do
			part.CFrame = frames[index]
		end
	end
	local environment = {
		game = {
			GetService = function(_self: any, name: string): any
				assert(services[name], name)
				return services[name]
			end,
		},
		workspace = world,
		Instance = { new = newObject },
		Content = {
			fromObject = function(mesh: any): any
				return mesh
			end,
		},
		task = {
			wait = function()
				state.WaitCalls += 1
				if state.OnWait then
					state.OnWait()
				end
			end,
		},
	}
	local loader = loadPackage(environment)
	return { State = state, Load = loader, New = newObject, Roblox = r, NewMesh = newMesh }
end
