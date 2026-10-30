--!strict
-- Compare rendered geometry to the real-part transform contract without a Studio session.
local Sandbox = require("./Sandbox")
local sandbox = Sandbox()
local Layout = sandbox.Load("demo/Layout")
local QuickPart = sandbox.Load("src")
local r = sandbox.Roblox
local compared = 0

for _, example in Layout.Examples do
	if example.Assets then
		continue -- Real library assets are validated by check-library and Studio FoliageChecks.
	end
	local renderer = QuickPart.new()
	if example.Kind ~= "Model" then
		local options = {}
		for _, spec in example.Parts do
			table.insert(options, {
				Size = spec.Size,
				CFrame = Layout.origin(example, true) * spec.CFrame,
				Color = spec.Color,
				Material = spec.Material,
				Shape = spec.Shape,
				PivotOffset = spec.PivotOffset,
			})
		end
		local handles, reason = renderer:CreateMany(options)
		assert(handles, reason)
		for _, time in { 0, 0.4, 1.2, 4 } do
			for index, spec in example.Parts do
				local handle = handles[index]
				local size, cf, color, transparency = Layout.sample(example, spec, index, time)
				handle.Size, handle.CFrame, handle.Color, handle.Transparency =
					size, Layout.origin(example, true) * cf, color, transparency
			end
			renderer:UpdateMany(handles)
			for index, spec in example.Parts do
				local size, cf, color, transparency = Layout.sample(example, spec, index, time)
				local geometry = renderer:GetGeometry(handles[index])
				local primitive = QuickPart.Geometry.primitive(spec.Shape, QuickPart.CONSTANTS.CURVE_SEGMENTS)
				for vertexIndex, id in geometry.VertexIds do
					local actual = geometry.EditableMesh:GetPosition(id)
					local real = Layout.origin(example, false) * cf * (primitive.Vertices[vertexIndex] * size)
					assert(
						(actual - real - r.Vector3.new(Layout.RightX - Layout.LeftX, 0, 0)).Magnitude < 0.0001,
						example.Name
					)
					compared += 1
				end
				assert(math.abs(geometry.EditableMesh:GetColorAlpha(geometry.ColorId) - (1 - transparency)) < 0.0001)
				assert(geometry.EditableMesh:GetColor(geometry.ColorId) == color)
			end
		end
	else
		local source = sandbox.New("Model")
		source.WorldPivot = Layout.origin(example, true)
		for _, spec in example.Parts do
			local part = sandbox.New("Part")
			part.Size, part.CFrame, part.Color, part.Material =
				spec.Size, source.WorldPivot * spec.CFrame, spec.Color, spec.Material
			part.Parent = source
		end
		local handle, reason = renderer:FromModel(source)
		assert(handle, reason)
		local expectedCount = 0
		local block = QuickPart.Geometry.primitive("Block", 24)
		for _, time in { 0, 0.4, 1.2, 4 } do
			local rotation, scale = Layout.sampleModel(time)
			handle.WorldPivot, handle.Scale = Layout.origin(example, true) * rotation, scale
			local writes = sandbox.State.Writes
			renderer:UpdateModel(handle)
			assert(sandbox.State.Writes == writes, "Rigid model should move hosts without rewriting vertices")
			local expected = {}
			for _, spec in example.Parts do
				for _, vertex in block.Vertices do
					table.insert(expected, handle.WorldPivot * ((spec.CFrame * (vertex * spec.Size)) * scale))
				end
			end
			expectedCount = #expected
			for _, host in renderer.RenderingPart:GetChildren() do
				for _, vertex in host.Mesh.Vertices do
					local actual = host.CFrame * (vertex * (host.Size / host.Mesh:GetSize()))
					local found: number? = nil
					for index, position in expected do
						if (actual - position).Magnitude < 0.0001 then
							found = index
							break
						end
					end
					assert(found, "Model vertex does not match the scaled and pivoted reference")
					table.remove(expected, found)
					compared += 1
				end
			end
			assert(#expected == 0)
		end
		assert(expectedCount == 26 * 8)
		source:Destroy()
	end
	renderer:Destroy()
end
QuickPart:Destroy()
print(`Demo comparison checks passed: {compared} vertex comparisons across all three animations.`)
