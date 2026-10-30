--!strict
local QuickPart = require(game:GetService("ReplicatedStorage").Packages.QuickPart)
return function()
	local renderer = QuickPart.new()
	local ok, reason = pcall(function()
		local handle, failure =
			renderer.Create({ Size = Vector3.new(2, 4, 6), CFrame = CFrame.new(12, 8, -3), Transparency = 0.25 })
		assert(handle, failure)
		local geometry = renderer.GetGeometry(handle)
		assert(#geometry.VertexIds == 8 and #geometry.TriangleIds == 12)
		-- The engine quantizes face alpha to 8 bits (0.75 reads back as 192/255).
		assert(math.abs(assert(geometry.EditableMesh:GetColorAlpha(geometry.ColorId)) - 0.75) <= 1 / 255)
		handle.CFrame = CFrame.new(-10, 5, 6) * CFrame.Angles(0, 1, 0)
		handle.Size = Vector3.new(4, 2, 8)
		handle.Transparency = 0.5
		renderer.Update(handle)
		local expected = handle.CFrame * (Vector3.new(-0.5, -0.5, -0.5) * handle.Size)
		assert((geometry.EditableMesh:GetPosition(geometry.VertexIds[1]) - expected).Magnitude < 0.0001)
		assert(math.abs(assert(geometry.EditableMesh:GetColorAlpha(geometry.ColorId)) - 0.5) <= 1 / 255)
		renderer.Remove(handle)
		assert(renderer.GetStats().Meshes == 0)
	end)
	renderer.Destroy()
	assert(ok, tostring(reason))
	print("QuickPart Studio checks passed")
end
