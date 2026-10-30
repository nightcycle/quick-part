--!strict
--!native
local Types = require(script.Parent.Types)
type Geometry = Types.Geometry
type Face = Types.Face
local GeometryUtil = {}
local cache: { [string]: Geometry } = {}

function GeometryUtil.validate(geometry: Geometry)
	assert(#geometry.Vertices > 0 and #geometry.Faces > 0, "Geometry must contain vertices and faces")
	local triangles = 0
	for _, face in geometry.Faces do
		local count = #face.Vertices
		assert(count == 3 or count == 4, "Geometry faces must be triangles or quads")
		assert(#face.UVs >= count, "Every face corner needs a UV")
		assert(not face.Normals or #face.Normals == count, "Invalid face normals")
		assert(not face.Colors or #face.Colors == count, "Invalid face colours")
		assert(not face.Alphas or #face.Alphas == count, "Invalid face alpha")
		for _, index in face.Vertices do
			assert(index % 1 == 0 and index >= 1 and index <= #geometry.Vertices, "Invalid geometry vertex index")
		end
		triangles += count - 2
	end
	assert(
		geometry.TriangleCount == triangles,
		"TriangleCount must match the geometry; budget cannot be under-reported"
	)
end

local function polygon(vertices: { Vector3 }, indices: { number }): Face
	-- The vertex centroid is interior even when the origin lies on a wedge face.
	local a, b, c = vertices[indices[1]], vertices[indices[2]], vertices[indices[3]]
	local normal = (b - a):Cross(c - a)
	local center = Vector3.zero
	for _, index in indices do
		center += vertices[index]
	end
	local interior = Vector3.zero
	for _, point in vertices do
		interior += point
	end
	interior /= #vertices
	if normal:Dot(center / #indices - interior) < 0 then
		local reverse = {}
		for index = #indices, 1, -1 do
			table.insert(reverse, indices[index])
		end
		indices = reverse
	end
	local uvs = { Vector2.new(0, 1), Vector2.new(1, 1), Vector2.new(1, 0), Vector2.new(0, 0) }
	return { Vertices = indices, UVs = uvs }
end

function GeometryUtil.primitive(shape: string, segments: number): Geometry
	local key = `{shape}:{segments}`
	local cached = cache[key]
	if cached then
		return cached
	end
	local vertices: { Vector3 } = {}
	local faces: { Face } = {}
	local function vertex(x: number, y: number, z: number): number
		table.insert(vertices, Vector3.new(x, y, z) * 0.5)
		return #vertices
	end
	local function face(indices: { number })
		table.insert(faces, polygon(vertices, indices))
	end
	if shape == "Block" then
		for _, p in
			{
				{ -1, -1, -1 },
				{ 1, -1, -1 },
				{ 1, 1, -1 },
				{ -1, 1, -1 },
				{ -1, -1, 1 },
				{ 1, -1, 1 },
				{ 1, 1, 1 },
				{
					-1,
					1,
					1,
				},
			}
		do
			vertex(p[1], p[2], p[3])
		end
		for _, f in { { 1, 2, 3, 4 }, { 5, 8, 7, 6 }, { 1, 5, 6, 2 }, { 4, 3, 7, 8 }, { 1, 4, 8, 5 }, { 2, 6, 7, 3 } } do
			face(f)
		end
	elseif shape == "Wedge" then
		for _, p in { { -1, -1, -1 }, { 1, -1, -1 }, { -1, -1, 1 }, { 1, -1, 1 }, { -1, 1, 1 }, { 1, 1, 1 } } do
			vertex(p[1], p[2], p[3])
		end
		for _, f in { { 1, 2, 4, 3 }, { 3, 4, 6, 5 }, { 1, 3, 5 }, { 2, 6, 4 }, { 1, 5, 6, 2 } } do
			face(f)
		end
	elseif shape == "CornerWedge" then
		for _, p in { { -1, -1, -1 }, { 1, -1, -1 }, { -1, -1, 1 }, { 1, -1, 1 }, { 1, 1, 1 } } do
			vertex(p[1], p[2], p[3])
		end
		for _, f in { { 1, 2, 4, 3 }, { 2, 5, 4 }, { 3, 4, 5 }, { 1, 5, 2 }, { 1, 3, 5 } } do
			face(f)
		end
	elseif shape == "Cylinder" then
		local left, right = vertex(-1, 0, 0), vertex(1, 0, 0)
		for index = 0, segments - 1 do
			local angle = index * math.pi * 2 / segments
			vertex(-1, math.cos(angle), math.sin(angle))
			vertex(1, math.cos(angle), math.sin(angle))
		end
		for index = 0, segments - 1 do
			local a, b = 3 + index * 2, 3 + ((index + 1) % segments) * 2
			face({ left, a, b })
			face({ right, b + 1, a + 1 })
			face({ a, a + 1, b + 1, b })
		end
	elseif shape == "Ball" then
		local top = vertex(0, 1, 0)
		local rings = math.floor(segments / 2)
		for row = 1, rings - 1 do
			local latitude = row * math.pi / rings
			for column = 0, segments - 1 do
				local longitude = column * math.pi * 2 / segments
				vertex(
					math.sin(latitude) * math.cos(longitude),
					math.cos(latitude),
					math.sin(latitude) * math.sin(longitude)
				)
			end
		end
		local bottom = vertex(0, -1, 0)
		for column = 0, segments - 1 do
			local nextColumn = (column + 1) % segments
			face({ top, 2 + column, 2 + nextColumn })
			for row = 0, rings - 3 do
				local a, b = 2 + row * segments + column, 2 + row * segments + nextColumn
				face({ a, b, b + segments, a + segments })
			end
			face({ bottom, 2 + (rings - 2) * segments + nextColumn, 2 + (rings - 2) * segments + column })
		end
	else
		error(`Unsupported shape: {shape}`)
	end
	local triangleCount = 0
	for _, f in faces do
		if shape == "Ball" or (shape == "Cylinder" and #f.Vertices == 4) then
			local normals: { Vector3 } = {}
			for _, index in f.Vertices do
				local p = vertices[index]
				table.insert(normals, if shape == "Ball" then p.Unit else Vector3.new(0, p.Y, p.Z).Unit)
			end
			f.Normals = normals
		end
		triangleCount += #f.Vertices - 2
	end
	local result = { Vertices = vertices, Faces = faces, TriangleCount = triangleCount }
	cache[key] = result
	return result
end

-- Reusable hot loop: writes into caller-owned arrays without temporary CFrames.
function GeometryUtil.transform(vertices: { Vector3 }, size: Vector3, cf: CFrame, output: { Vector3 }, offset: number)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local sx, sy, sz = size.X, size.Y, size.Z
	for index, point in vertices do
		local px, py, pz = point.X * sx, point.Y * sy, point.Z * sz
		output[offset + index] = Vector3.new(
			x + r00 * px + r01 * py + r02 * pz,
			y + r10 * px + r11 * py + r12 * pz,
			z + r20 * px + r21 * py + r22 * pz
		)
	end
end
return GeometryUtil
