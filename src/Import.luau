--!strict
--!native
local AssetService = game:GetService("AssetService")
local Types = require(script.Parent.Types)
local Import = {}

function Import.meshPart(part: MeshPart): (Types.Geometry?, string?)
	local editable: EditableMesh? = nil
	local result: Types.Geometry? = nil
	local ok, reason = pcall(function()
		local mesh = AssetService:CreateEditableMeshAsync(part.MeshContent)
		assert(mesh, "EditableMesh memory exhausted while importing source")
		editable = mesh
		assert(#mesh:GetBones() == 0, "Skinned MeshParts require their animation rig and are unsupported")
		local size = part.MeshSize
		-- Planar meshes may have a zero extent; their zero coordinate remains zero.
		local divisor = Vector3.new(
			if size.X == 0 then 1 else size.X,
			if size.Y == 0 then 1 else size.Y,
			if size.Z == 0 then 1 else size.Z
		)
		local vertices: { Vector3 } = {}
		local remap: { [number]: number } = {}
		for _, id in mesh:GetVertices() do
			table.insert(vertices, mesh:GetPosition(id) / divisor)
			remap[id] = #vertices
		end
		local faces: { Types.Face } = {}
		local triangles = 0
		for _, id in mesh:GetFaces() do
			local sourceVertices = mesh:GetFaceVertices(id)
			local sourceUVs, sourceNormals, sourceColors =
				mesh:GetFaceUVs(id), mesh:GetFaceNormals(id), mesh:GetFaceColors(id)
			local indices: { number } = {}
			local uvs: { Vector2 } = {}
			local normals: { Vector3 } = {}
			local colors: { Color3 } = {}
			local alphas: { number } = {}
			for corner, vertexId in sourceVertices do
				table.insert(indices, remap[vertexId])
				table.insert(uvs, mesh:GetUV(sourceUVs[corner]) or Vector2.zero)
				local normal = mesh:GetNormal(sourceNormals[corner]) or Vector3.yAxis
				table.insert(normals, (normal * divisor).Unit)
				table.insert(colors, mesh:GetColor(sourceColors[corner]) or Color3.new(1, 1, 1))
				table.insert(alphas, mesh:GetColorAlpha(sourceColors[corner]) or 1)
			end
			table.insert(faces, { Vertices = indices, UVs = uvs, Normals = normals, Colors = colors, Alphas = alphas })
			triangles += #indices - 2
		end
		assert(triangles > 0, "MeshPart has no faces")
		result = { Vertices = vertices, Faces = faces, TriangleCount = triangles }
	end)
	if editable then
		editable:Destroy()
	end
	return result, if ok then nil else tostring(reason)
end
return Import
