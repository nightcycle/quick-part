--!strict
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Sandbox = require("./Sandbox")
local r = roblox :: any
local assets = roblox.deserializeModel(fs.readFile("demo/assets/LibrarySamples.rbxm"))[1] :: any
assert(#assets:GetChildren() == 7)
local parts, appearances = 0, 0
for _, sample in assets:GetChildren() do
	assert(sample:IsA("Model"))
	local minimumY = math.huge
	for _, object in sample:GetDescendants() do
		assert(not object:IsA("LuaSourceContainer"), "Asset subset must contain no executable code")
		if object:IsA("MeshPart") then
			parts += 1
			assert(tostring(object.MeshContent):find("rbxassetid://"))
			assert(object.Size.X > 0 and object.Size.Y > 0 and object.Size.Z > 0)
			assert(object.Anchored and not object.CanCollide)
			assert(
				tostring(object.TextureContent):find("rbxassetid://")
					or object:FindFirstChildWhichIsA("SurfaceAppearance")
			)
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						minimumY = math.min(minimumY, (object.CFrame * (object.Size * r.Vector3.new(x, y, z) * 0.5)).Y)
					end
				end
			end
		elseif object:IsA("SurfaceAppearance") then
			appearances += 1
		end
	end
	assert(math.abs(minimumY) < 0.001, "Sample must be grounded at its pivot")
end
assert(parts == 8 and appearances == 1, "Retain the eight meshes and the birch leaf-card SurfaceAppearance")
local leaves = assets.Birch
	:FindFirstChild("Meshes/Birch_Tree_Birch_Small_01")
	:FindFirstChild("Meshes/Tree_Birch_Small_01_leaf_card")
assert(leaves.DoubleSided and leaves.SurfaceAppearance.AlphaMode == r.Enum.AlphaMode.Transparency)
assert(tostring(leaves.SurfaceAppearance.ColorMapContent):find("6811821682"))

-- Network-independent rejection path: a denied library mesh must leave the renderer reusable.
local sandbox = Sandbox()
local package = sandbox.Load("src")
local source = sandbox.New("Model")
local trunk = sandbox.New("Part")
trunk.Parent = source
local leaves = sandbox.New("MeshPart")
leaves.MeshContent, leaves.MeshSize = "denied-leaf-mesh", r.Vector3.one
leaves.Parent = source
local handle, reason = package.FromModel(source)
assert(not handle and reason)
assert(package.GetStats().Parts == 0 and package.GetStats().Triangles == 0 and package.GetStats().Meshes == 0)
assert(not trunk.Destroyed and not leaves.Destroyed)
local recovery = assert(package.Create({ Size = r.Vector3.one }))
package.Remove(recovery)
package.Destroy()
print(
	`Library checks passed: {parts} original meshes, {appearances} SurfaceAppearances, grounded pivots and failed-import recovery.`
)
