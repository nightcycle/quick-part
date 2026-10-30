--!strict
--!native
-- Live asset integration checks. Permission-denied imports are reported as blocked, never passed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuickPart = require(ReplicatedStorage.Packages.QuickPart)
export type Result = { Example: string, Status: string, Detail: string }
return function(): { Result }
	local results: { Result } = {}
	for _, name in { "BirchTrees", "Woodland" } do
		local row = workspace.ComparisonGallery:FindFirstChild(name)
		assert(row)
		local original = row:FindFirstChild("Reference")
		assert(original and original:IsA("Model"))
		local preview = row:FindFirstChild("Preview")
		assert(preview and preview:IsA("Model"))
		-- Match by relative path: GetDescendants order is not stable across clones.
		for _, part in original:GetDescendants() do
			if not part:IsA("BasePart") then
				continue
			end
			local path: { string } = {}
			local cursor: Instance = part
			while cursor ~= original do
				table.insert(path, 1, cursor.Name)
				cursor = assert(cursor.Parent)
			end
			local copy: Instance = preview
			for _, member in path do
				copy = assert(copy:FindFirstChild(member))
			end
			assert(copy:IsA("MeshPart") and part:IsA("MeshPart"))
			assert(copy.MeshContent == part.MeshContent and copy.TextureContent == part.TextureContent)
			assert(copy.DoubleSided == part.DoubleSided and copy.Size == part.Size)
			assert((copy.Position - part.Position - Vector3.new(46, 0, 0)).Magnitude < 0.001)
		end
		local source = original:Clone()
		local renderer = QuickPart.new()
		renderer.RenderingPart.Name = `QuickPartFoliageCheck_{name}`
		local ok, reason = pcall(function()
			local snapshots: { { Part: BasePart, Size: Vector3, CFrame: CFrame } } = {}
			for _, object in source:GetDescendants() do
				if object:IsA("BasePart") then
					table.insert(snapshots, { Part = object, Size = object.Size, CFrame = object.CFrame })
				end
			end
			local handle, failure = renderer:FromModel(source)
			local stats = renderer:GetStats()
			if not handle then
				assert(stats.Parts == 0 and stats.Meshes == 0 and stats.Triangles == 0, "Failed import leaked geometry")
				if string.find(string.lower(tostring(failure)), "permission", 1, true) then
					table.insert(results, { Example = name, Status = "Blocked", Detail = tostring(failure) })
					return true
				end
				error(failure or "Unknown import failure")
			end
			assert(stats.Parts == #snapshots and stats.Models == 1 and stats.Triangles > 0)
			local hosts: { { Part: MeshPart, Size: Vector3, Local: CFrame } } = {}
			local pivot, initialScale = handle.WorldPivot, handle.Scale
			for _, object in renderer.RenderingPart:GetChildren() do
				assert(object:IsA("MeshPart"))
				table.insert(hosts, { Part = object, Size = object.Size, Local = pivot:ToObjectSpace(object.CFrame) })
			end
			for _, scale in { 0.6, 1.4, 1 } do
				handle.WorldPivot = pivot * CFrame.new(4, 3, -7) * CFrame.Angles(0.1, 0.8, -0.1)
				handle.Scale = initialScale * scale
				renderer:UpdateModel(handle)
				for _, host in hosts do
					local expected = handle.WorldPivot * (host.Local.Rotation + host.Local.Position * scale)
					assert((host.Part.Position - expected.Position).Magnitude < 0.001)
					assert(host.Part.CFrame.LookVector:Dot(expected.LookVector) > 0.9999)
					assert((host.Part.Size - host.Size * scale).Magnitude < 0.001)
				end
			end
			for _, snapshot in snapshots do
				assert(
					snapshot.Part.Size == snapshot.Size and snapshot.Part.CFrame == snapshot.CFrame,
					"Import mutated source"
				)
			end
			renderer:RemoveModel(handle)
			assert(renderer:GetStats().Meshes == 0 and renderer:GetStats().Triangles == 0)
			table.insert(results, {
				Example = name,
				Status = "Passed",
				Detail = `{stats.Parts} parts / {stats.Triangles} triangles; transform, scale and cleanup`,
			})
			return true
		end)
		renderer:Destroy()
		source:Destroy()
		assert(ok, `{name}: {tostring(reason)}`)
	end
	return results
end
