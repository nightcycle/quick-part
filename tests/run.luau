--!strict
local Sandbox = require("./Sandbox")
local sandbox = Sandbox()
local r, state = sandbox.Roblox, sandbox.State
local QuickPart = sandbox.Load("src")
local V, CF, Color = r.Vector3, r.CFrame, r.Color3
local passed = 0
local function test(name: string, callback: () -> ())
	callback()
	passed += 1
	print(`PASS {name}`)
end
local function near(a: any, b: any)
	assert((a - b).Magnitude < 0.0001, `{a} ~= {b}`)
end
local function create(options: any?): any
	local handle, reason = QuickPart:Create(options or { Size = V.one })
	assert(handle, reason)
	return handle
end
test("package entry exposes shared modules and independent colon-method renderers", function()
	for _, name in { "Renderer", "CONSTANTS", "Geometry", "Mesh", "Import", "PartSource", "Types" } do
		assert(QuickPart[name] == sandbox.Load("src/" .. name), `Missing or copied module: {name}`)
	end
	local first, second = QuickPart.Renderer.new(), QuickPart.new()
	local original = sandbox.New("Part")
	original.Size = V.new(2, 3, 4)
	local options = assert(QuickPart.PartSource.options(original))
	options.Geometry = QuickPart.Geometry.primitive("Block", 24)
	local a = assert(first:Create(options))
	local b = assert(second:FromPart(original))
	first:PivotTo(a, CF.new(5, 6, 7))
	near(first:GetPivot(a).Position, V.new(5, 6, 7))
	near(b.CFrame.Position, original.CFrame.Position)
	assert(not pcall(first.Update, first, b), "Handles must remain bound to their renderer")
	first:Destroy()
	assert(first.RenderingPart.Destroyed and second:GetStats().Parts == 1)
	second:Remove(b)
	second:Destroy()
	original:Destroy()
end)
test("box topology, winding, triangle colour and alpha", function()
	local handle =
		create({ Size = V.new(2, 4, 6), CFrame = CF.new(8, 10, 12), Transparency = 0.4, Color = Color.new(1, 0, 0) })
	local info = QuickPart:GetGeometry(handle)
	assert(#info.VertexIds == 8 and #info.TriangleIds == 12)
	assert(math.abs(info.EditableMesh:GetColorAlpha(info.ColorId) - 0.6) < 1e-6)
	for _, face in info.EditableMesh.Faces do
		local a, b, c = unpack(face.Vertices)
		local pa, pb, pc = info.EditableMesh.Vertices[a], info.EditableMesh.Vertices[b], info.EditableMesh.Vertices[c]
		assert((pb - pa):Cross(pc - pa):Dot((pa + pb + pc) / 3 - handle.CFrame.Position) > 0)
		assert(face.Colors[1] == info.ColorId and face.Colors[2] == info.ColorId and face.Colors[3] == info.ColorId)
	end
	QuickPart:Remove(handle)
	assert(info.EditableMesh.Destroyed and QuickPart:GetStats().Meshes == 0)
end)
test("batched transform, resize, pivot semantics and no-op dirty tracking", function()
	local handles = assert(QuickPart:CreateMany({ { Size = V.one }, { Size = V.one } }))
	local oldCalls = state.BatchCalls
	for index, handle in handles do
		handle.CFrame = CF.new(index * 10, 3, 5) * CF.Angles(0.3, 0.8, 0.1)
		handle.Size = V.new(index, 3, 5)
	end
	QuickPart:UpdateMany(handles)
	assert(state.BatchCalls == oldCalls + 1)
	for _, handle in handles do
		local info = QuickPart:GetGeometry(handle)
		near(info.EditableMesh:GetPosition(info.VertexIds[1]), handle.CFrame * (V.new(-0.5, -0.5, -0.5) * handle.Size))
	end
	local writes = state.Writes
	QuickPart:UpdateMany(handles)
	assert(state.Writes == writes)
	local handle = handles[1]
	handle.PivotOffset = CF.new(2, 0, 0) * CF.Angles(0, 0.5, 0)
	QuickPart:Update(handle)
	assert(state.Writes == writes)
	local desired = CF.new(15, 4, 9) * CF.Angles(0, 1, 0)
	QuickPart:PivotTo(handle, desired)
	near(QuickPart:GetPivot(handle).Position, desired.Position)
	handle.Transparency = 0.9
	handle.Color = Color.new(0, 1, 0)
	writes = state.Writes
	QuickPart:Update(handle)
	assert(state.Writes == writes)
	QuickPart:RemoveMany(handles)
end)
test("style groups, mutable render root, sparse IDs survive removal", function()
	local a, b = create(), create()
	local c = create({ Size = V.one, CastShadow = false })
	assert(QuickPart:GetStats().Meshes == 2)
	local before = QuickPart:GetGeometry(b)
	QuickPart:Remove(a)
	b.CFrame = CF.new(0, 7, 0)
	QuickPart:Update(b)
	assert(QuickPart:GetGeometry(b).VertexIds[1] == before.VertexIds[1])
	QuickPart.RenderingPart.CFrame = CF.new(10, 0, 0)
	near(before.RenderingPart.CFrame.Position, V.new(10, 0, 0))
	QuickPart.RenderingPart.CFrame = CF.identity
	QuickPart:RemoveMany({ b, b, c })
	assert(QuickPart:GetStats().Meshes == 0)
	assert(not pcall(QuickPart.Update, QuickPart, b))
end)
test("soft budget and capacity split", function()
	local constants = QuickPart.CONSTANTS
	local budget, percent, capacity =
		constants.TRIANGLE_BUDGET, constants.TRIANGLE_BUDGET_PERCENT, constants.MAX_TRIANGLES_PER_MESH
	constants.TRIANGLE_BUDGET = 48
	constants.TRIANGLE_BUDGET_PERCENT = 50
	constants.MAX_TRIANGLES_PER_MESH = 12
	local a, b = create(), create()
	assert(QuickPart:GetStats().Meshes == 2 and not QuickPart:Create({ Size = V.one }))
	QuickPart:Remove(a)
	local c = create()
	QuickPart:RemoveMany({ b, c })
	constants.TRIANGLE_BUDGET, constants.TRIANGLE_BUDGET_PERCENT, constants.MAX_TRIANGLES_PER_MESH =
		budget, percent, capacity
end)
test("memory nil, partial topology failure, attachment failure and transactional rollback", function()
	state.FailCreate = true
	assert(not QuickPart:Create({ Size = V.one }))
	state.FailCreate = false
	local existing = create()
	state.FailAfter = 30
	assert(not QuickPart:CreateMany({ { Size = V.one }, { Size = V.one } }))
	state.FailAfter = nil
	assert(QuickPart:GetStats().Parts == 1 and QuickPart:GetStats().Triangles == 12)
	local mesh = QuickPart:GetGeometry(existing).EditableMesh
	local count = 0
	for _ in mesh.Vertices do
		count += 1
	end
	assert(count == 8)
	state.FailAttach = true
	assert(not QuickPart:CreateMany({ { Size = V.one }, { Size = V.one, CastShadow = false } }))
	state.FailAttach = false
	assert(QuickPart:GetStats().Parts == 1 and QuickPart:GetStats().Meshes == 1)
	QuickPart:Remove(existing)
	for _, editable in state.Meshes do
		assert(editable.Destroyed)
	end
end)
test("creation yield lock and whole-batch validation", function()
	state.OnAttach = function()
		assert(not pcall(QuickPart.Create, QuickPart, { Size = V.one }))
	end
	local a, b = create(), create()
	state.OnAttach = nil
	a.CFrame = CF.new(1, 2, 3)
	b.Size = V.new(-1, 1, 1)
	local writes = state.Writes
	assert(not pcall(QuickPart.UpdateMany, QuickPart, { a, b }))
	assert(state.Writes == writes)
	b.Size = V.one
	QuickPart:UpdateMany({ a, b })
	QuickPart:RemoveMany({ a, b })
end)
test("all primitive faces are nondegenerate and face outwards", function()
	for _, shape in { "Block", "Wedge", "CornerWedge", "Cylinder", "Ball" } do
		local geometry = QuickPart.Geometry.primitive(shape, 24)
		local count = 0
		local interior = V.zero
		for _, vertex in geometry.Vertices do
			interior += vertex
		end
		interior /= #geometry.Vertices
		for _, face in geometry.Faces do
			for index = 2, #face.Vertices - 1 do
				local a, b, c =
					geometry.Vertices[face.Vertices[1]],
					geometry.Vertices[face.Vertices[index]],
					geometry.Vertices[face.Vertices[index + 1]]
				assert((b - a):Cross(c - a).Magnitude > 1e-7, shape)
				assert((b - a):Cross(c - a):Dot((a + b + c) / 3 - interior) > 0, shape)
				count += 1
			end
		end
		assert(count == geometry.TriangleCount)
	end
end)
test("rigid models preserve pivot and absolute scale without rewriting vertices", function()
	local source = sandbox.New("Model")
	source.WorldPivot = CF.new(30, 0, 0) * CF.Angles(0, 0.4, 0)
	source.ScaleValue = 2
	for index = 1, 4 do
		local part = sandbox.New("Part")
		part.CFrame = source.WorldPivot * CF.new(index * 3, 2, 0)
		part.Parent = source
	end
	local handle = assert(QuickPart:FromModel(source))
	assert(handle.Scale == 2 and QuickPart:GetStats().Parts == 4)
	local writes = state.Writes
	handle.WorldPivot = CF.new(-10, 12, 4) * CF.Angles(0, 1, 0)
	handle.Scale = 4
	QuickPart:UpdateModel(handle)
	assert(state.Writes == writes)
	local render = QuickPart.RenderingPart:GetChildren()[1]
	near(render.CFrame.Position, handle.WorldPivot.Position)
	near(render.Size, render.Mesh:GetSize() * 2)
	assert(#source:GetChildren() == 4)
	QuickPart:RemoveModel(handle)
	assert(QuickPart:GetStats().Meshes == 0)
	local unsupported = sandbox.New("MeshPart")
	unsupported.Parent = source
	local failed, reason = QuickPart:FromModel(source)
	assert(not failed and reason and QuickPart:GetStats().Parts == 0)
	source:Destroy()
end)
test("imported mesh geometry, colours, alpha, normals and source cleanup", function()
	local mesh = sandbox.NewMesh()
	local a, b, c = mesh:AddVertex(V.new(-1, 0, 0)), mesh:AddVertex(V.new(1, 0, 0)), mesh:AddVertex(V.new(0, 2, 0))
	local face = mesh:AddTriangle(a, b, c)
	local normal = mesh:AddNormal(V.zAxis)
	local color = mesh:AddColor(Color.new(0.5, 0.8, 1), 0.6)
	local uv = mesh:AddUV(r.Vector2.zero)
	mesh:SetFaceColors(face, { color, color, color })
	mesh:SetFaceNormals(face, { normal, normal, normal })
	mesh:SetFaceUVs(face, { uv, uv, uv })
	state.SourceMesh = mesh
	local source = sandbox.New("MeshPart")
	source.MeshSize = V.new(2, 2, 0)
	source.Size = V.new(4, 6, 1)
	source.Color = Color.new(0.5, 1, 1)
	source.Transparency = 0.5
	source.TextureID = "rbxassetid://123"
	source.DoubleSided = true
	local handle, reason = QuickPart:FromPart(source)
	assert(handle, reason)
	assert(mesh.Destroyed)
	local info = QuickPart:GetGeometry(handle)
	near(info.EditableMesh:GetPosition(info.VertexIds[1]), V.new(-2, 0, 0))
	assert(math.abs(info.EditableMesh:GetColorAlpha(info.ColorId) - 0.3) < 1e-6)
	assert(info.EditableMesh:GetColor(info.ColorId).R == 0.25)
	assert(info.RenderingPart.TextureID == source.TextureID and info.RenderingPart.DoubleSided)
	handle.CFrame = CF.Angles(0, math.pi / 2, 0)
	handle.Size = V.new(2, 3, 1)
	handle.Transparency = 0
	QuickPart:Update(handle)
	assert(math.abs(info.EditableMesh:GetColorAlpha(info.ColorId) - 0.6) < 1e-6)
	for _, n in info.EditableMesh.Normals do
		near(n, V.xAxis)
	end
	QuickPart:Remove(handle)
	state.SourceMesh = sandbox.NewMesh()
	state.Skinned = true
	assert(not QuickPart:FromPart(source) and state.SourceMesh.Destroyed)
	state.Skinned = false
	state.SourceMesh = nil
end)
test("1000-part independent and rigid plugin preflight excludes slow fixture setup", function()
	local isolated = Sandbox()
	local factory = isolated.Load("benchmarks/Factory")
	-- Simulate slow mesh attachment and scheduler waits without benchmarking mocks.
	-- The old ParameterGenerator setup exceeds the real plugin's 40 ms guard.
	local elapsed = 0
	isolated.State.OnAttach = function()
		elapsed += 1
	end
	isolated.State.OnWait = function()
		elapsed += 0.1
	end
	for _, rigid in { false, true } do
		local beforeSetup = elapsed
		local bench = factory(1000, rigid)
		assert(bench.UpdatesPerSample == 1)
		assert(elapsed - beforeSetup > 0.04, "Fixtures must be created before plugin preflight")
		local meshCount, objectCount, waitCount =
			#isolated.State.Meshes, #isolated.State.Objects, isolated.State.WaitCalls
		for name, callback in bench.Functions do
			-- Match Runner's order: timer -> ParameterGenerator -> YieldCheck -> timer.
			local startCheck = elapsed
			local frameWrites, vertexWrites, bulkCalls =
				isolated.State.CFrameWrites, isolated.State.Writes, isolated.State.BulkCalls
			local parameters = table.pack(bench.ParameterGenerator())
			local thread = coroutine.create(callback)
			local ok, reason = coroutine.resume(thread, {}, table.unpack(parameters, 1, parameters.n))
			assert(ok, tostring(reason))
			assert(coroutine.status(thread) == "dead", "Timed benchmark must not yield")
			assert(elapsed - startCheck <= 0.04, "Setup leaked into the plugin timeout check")
			assert(#isolated.State.Meshes == meshCount and #isolated.State.Objects == objectCount)
			assert(isolated.State.WaitCalls == waitCount)
			if name == "BasePart CFrame" or name:find("BulkMoveTo", 1, true) then
				assert(
					isolated.State.CFrameWrites - frameWrites == 1000,
					"Each baseline must submit one full population update"
				)
			elseif rigid then
				assert(isolated.State.CFrameWrites - frameWrites == 1 and isolated.State.Writes == vertexWrites)
			else
				assert(isolated.State.Writes - vertexWrites == 8000, "QuickPart must submit one full population update")
			end
			if name:find("BulkMoveTo", 1, true) then
				assert(isolated.State.BulkCalls - bulkCalls == 1)
			end
		end
		bench.BeforeAll()
		for _ = 1, 3 do
			for _, callback in bench.Functions do
				bench.ParameterGenerator()
				callback({})
			end
		end
		bench.AfterAll()
		for _, mesh in isolated.State.Meshes do
			assert(mesh.Destroyed)
		end
	end
	isolated.Load("src"):Destroy()
end)
test("legacy SetPosition fallback and renderer ownership", function()
	local legacy = Sandbox(false)
	local package = legacy.Load("src")
	local handle = assert(package:Create({ Size = V.one }))
	assert(package:GetStats().BatchMeshes == 0)
	handle.CFrame = CF.new(1, 2, 3)
	package:Update(handle)
	assert(legacy.State.Writes == 8)
	assert(not pcall(QuickPart.Update, QuickPart, handle))
	package:Destroy()
	package:Destroy()
	assert(not pcall(package.Update, package, handle))
end)
QuickPart:Destroy()
print(`{passed} Lune sandbox checks passed (not engine timing benchmarks).`)
