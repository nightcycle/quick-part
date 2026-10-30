--!strict
local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local function run(command: string, arguments: { string })
	local result = process.exec(command, arguments)
	assert(result.ok, result.stdout .. result.stderr)
	if result.stdout ~= "" then
		print(result.stdout)
	end
end
run("lune", { "run", "tests/run" })
run("lune", { "run", "tests/check-demo" })
run("stylua", { "--check", "src", "demo", "benchmarks", "tests", "scripts" })
run("rojo", { "sourcemap", "demo.project.json", "--output", "sourcemap.json" })
local definitions = process.args[1] or ".tools/globalTypes.d.luau"
if not fs.isFile(definitions) then
	assert(not process.args[1], `Missing definitions: {definitions}`)
	fs.writeDir(".tools")
	local response =
		net.request("https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/master/scripts/globalTypes.d.luau")
	assert(
		response.ok,
		"Could not download Roblox type definitions; pass a local definitions path as the first argument"
	)
	fs.writeFile(definitions, response.body)
end
run("luau-lsp", {
	"analyze",
	"--platform",
	"roblox",
	"--sourcemap",
	"sourcemap.json",
	"--definitions",
	definitions,
	"src",
	"demo",
	"benchmarks",
	"tests/StudioChecks.luau",
})
print("Lune checks, formatting and strict Roblox type analysis passed.")
