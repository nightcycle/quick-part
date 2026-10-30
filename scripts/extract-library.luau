--!strict
-- Run explicitly when refreshing the selected demo assets; normal builds use the checked-in subset.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local r = roblox :: any
local path = process.args[1] or "C:/Users/nightcycle/repos/local-package/demo/lib.rbxm"
local library = roblox.deserializeModel(fs.readFile(path))[1] :: any
local samples = roblox.Instance.new("Folder") :: any
samples.Name = "DemoAssets"
local selections = {
	{ "Birch", "vegetation/tree/full/Meshes|Birch_Tree_Birch_Small_01" },
	{ "RoundTree", "vegetation/tree/full/Meshes|PolygonNature_Tree_Round_01" },
	{ "Pine", "vegetation/tree/full/Meshes|PolygonNature_Tree_PolyPine_03" },
	{ "Fern", "vegetation/bush/Meshes|PolygonNature_Plant_Fern_01" },
	{ "Bush", "vegetation/bush/Meshes|PolygonNature_Plant_Hedge_Bush_01" },
	{ "Grass", "vegetation/grass/Meshes|PolygonNature_Plant_Grass_02" },
	{ "Boulder", "rock/boulder/Meshes|PolygonNature_Rock_Boulder_01" },
}
local provenance = {}
for _, selection in selections do
	local source = library
	for _, member in string.split(selection[2], "/") do
		source = assert(source:FindFirstChild((member:gsub("|", "/"))), selection[2])
	end
	local model = roblox.Instance.new("Model") :: any
	model.Name, model.Parent = selection[1], samples
	local copy = source:Clone()
	copy.Parent = model
	local minimum, maximum =
		r.Vector3.new(math.huge, math.huge, math.huge), r.Vector3.new(-math.huge, -math.huge, -math.huge)
	local count = 0
	for _, object in model:GetDescendants() do
		assert(not object:IsA("LuaSourceContainer"), "Demo asset must contain no scripts")
		if object:IsA("BasePart") then
			count += 1
			for x = -1, 1, 2 do
				for y = -1, 1, 2 do
					for z = -1, 1, 2 do
						local corner = object.CFrame * (object.Size * r.Vector3.new(x, y, z) * 0.5)
						minimum, maximum = minimum:Min(corner), maximum:Max(corner)
					end
				end
			end
		end
	end
	assert(count > 0)
	local center = r.Vector3.new((minimum.X + maximum.X) / 2, minimum.Y, (minimum.Z + maximum.Z) / 2)
	for _, object in model:GetDescendants() do
		if object:IsA("BasePart") then
			object.CFrame = object.CFrame - center
			object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
		end
	end
	model.WorldPivotData, model.NeedsPivotMigration = r.CFrame.identity, false
	table.insert(provenance, { Name = selection[1], Source = source:GetFullName(), Parts = count })
end
fs.writeDir("demo/assets")
fs.writeFile("demo/assets/LibrarySamples.rbxm", roblox.serializeModel({ samples }))
fs.writeFile("demo/assets/provenance.json", serde.encode("json", { Source = path, Samples = provenance }, true))
print(`Extracted {#selections} original assets, retaining mesh content, textures and SurfaceAppearance.`)
