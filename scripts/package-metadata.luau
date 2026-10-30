--!strict
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Release = require("./release-utils")
return function(): { Version: string, Archive: string }
	local manifest = serde.decode("toml", fs.readFile("wally.toml"))
	local version = Release.version(manifest.package.version)
	return { Version = version, Archive = `build/quick-part-{version}.zip` }
end
