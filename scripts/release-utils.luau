--!strict
local Release = {}
function Release.version(value: unknown): string
	assert(typeof(value) == "string", "Package version must be a string")
	local major, minor, patch = value:match("^(%d+)%.(%d+)%.(%d+)$")
	assert(major and minor and patch, "Release automation requires a stable X.Y.Z package version")
	for _, component in { major, minor, patch } do
		assert(#component == 1 or component:sub(1, 1) ~= "0", "Version components cannot have leading zeros")
	end
	return value
end
function Release.validateTag(tag: string, version: string)
	assert(tag == "v" .. Release.version(version), "Release tag must be v" .. version .. " to match wally.toml")
end
function Release.published(ok: boolean, stdout: string): boolean
	-- Wally 0.3.2 can exit successfully even when the registry rejects publication.
	return ok and stdout:find("Package published successfully!", 1, true) ~= nil
end
return Release
