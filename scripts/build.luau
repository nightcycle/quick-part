--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local Vector3 = (roblox :: any).Vector3
fs.writeDir("build")
local function run(command: string, arguments: { string })
	local result = process.exec(command, arguments)
	assert(result.ok, result.stdout .. result.stderr)
	print(result.stdout)
end
run("lune", { "run", "scripts/build-gallery" })
run("rojo", { "build", "default.project.json", "--output", "build/quick-part.rbxm" })
run("rojo", { "build", "demo.project.json", "--output", "build/quick-part-demo.rbxl" })
run("wally", { "package", "--output", "build/quick-part-0.1.0.tar.gz" })
local root = roblox.deserializeModel(fs.readFile("build/quick-part.rbxm"))[1] :: any
assert(root:IsA("ModuleScript") and root.Name == "QuickPart")
local model = roblox.deserializePlace(fs.readFile("build/quick-part-demo.rbxl")) :: any
model.Workspace.CurrentCamera = model.Workspace.Camera
fs.writeFile("build/quick-part-demo.rbxl", roblox.serializePlace(model))
local gallery = model.Workspace.ComparisonGallery
assert(gallery.Spawn:IsA("SpawnLocation") and gallery.Spawn.Neutral and gallery.Spawn.Anchored)
local layout = require("./load-package")()("demo/Layout")
for _, example in layout.Examples do
	local row = gallery:FindFirstChild(example.Name)
	assert(row and row.Reference:IsA("Model") and row.Preview:IsA("Model"))
	assert(#row.Reference:GetChildren() == #example.Parts and #row.Preview:GetChildren() == #example.Parts)
	for _, spec in example.Parts do
		local real, preview = row.Reference:FindFirstChild(spec.Name), row.Preview:FindFirstChild(spec.Name)
		assert(real.Size == preview.Size and real.Color == preview.Color and real.Material == preview.Material)
		assert(
			(preview.CFrame.Position - real.CFrame.Position - Vector3.new(layout.RightX - layout.LeftX, 0, 0)).Magnitude
				< 0.001
		)
	end
end
local package = model.ReplicatedStorage.Packages.QuickPart
assert(package.Source == root.Source)
local modules = 0
local references = 0
for _, instance in model:GetDescendants() do
	if instance:IsA("LuaSourceContainer") then
		local object = instance :: any
		assert(object.Source:find("^%-%-!strict"), object.Name .. " is not strict")
		luau.compile(object.Source)
		-- Resolve against real Instances, not the sandbox's path substitution.
		-- Property names (for example ModuleScript.Source) take precedence over children.
		for expression in object.Source:gmatch("require%((script[%w%.]*)%)") do
			local target = object
			local members = string.split(expression, ".")
			for index = 2, #members do
				assert(typeof(target) == "Instance", `{object:GetFullName()}: {expression} resolves through a property`)
				target = target[members[index]]
			end
			assert(
				typeof(target) == "Instance" and target:IsA("ModuleScript"),
				`{object:GetFullName()}: {expression} must resolve to a ModuleScript, not an Instance property`
			)
			references += 1
		end
		modules += 1
	end
end
assert(model.StarterPlayer.StarterPlayerScripts.QuickPartDemo:IsA("LocalScript"))
assert(model.ReplicatedStorage.Benchmarks:FindFirstChild("Independent1000.bench"))
print(
	`Build verified: {modules} compiled scripts, {references} resolved module references, standalone package, demo and Wally archive.`
)
