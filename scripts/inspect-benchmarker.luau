--!strict
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local roots = roblox.deserializeModel(fs.readFile("C:/Users/nightcycle/Downloads/Benchmarker (1).rbxm"))
fs.writeDir(".tools/benchmarker")
for _, root in roots do
	for _, item in root:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			local object = item :: any
			local name = object:GetFullName():gsub("[^%w_.-]", "_")
			fs.writeFile(`.tools/benchmarker/{name}.luau`, object.Source)
			print(name)
		end
	end
end
