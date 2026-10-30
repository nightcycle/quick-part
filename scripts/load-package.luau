--!strict
-- Lune adapter for loading the production modules without a Studio DataModel.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

type ModuleRef = string | { ModulePath: string }

return function(overrides: { [string]: any }?, moduleOverrides: { [string]: any }?): (ModuleRef) -> any
	local cache: { [string]: any } = if moduleOverrides then table.clone(moduleOverrides) else {}
	local environment: { [string]: any } = table.clone(roblox :: any)
	environment._G = {}
	if overrides then
		for key, value in overrides do
			environment[key] = value
		end
	end
	local function loadModule(reference: ModuleRef): any
		local name = if typeof(reference) == "string" then reference else reference.ModulePath
		if cache[name] ~= nil then
			return cache[name]
		end
		local file = name .. ".luau"
		if not fs.isFile(file) then
			file = name .. "/init.luau"
		end
		local source = fs.readFile(file)
		-- Resolve the same ModuleScript ancestry that Rojo builds in Studio.
		source = source:gsub("require%((script[%w%.]*)%)", function(expression: string): string
			local path = string.split(name, "/")
			local members = string.split(expression, ".")
			for index = 2, #members do
				if members[index] == "Parent" then
					table.remove(path)
				else
					table.insert(path, members[index])
				end
			end
			return string.format("require(%q)", table.concat(path, "/"))
		end)
		local scope = table.clone(environment)
		scope.require = loadModule
		local result = luau.load(source, { debugName = file, environment = scope, injectGlobals = true })()
		cache[name] = result
		return result
	end
	return loadModule
end
