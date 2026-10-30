--!strict
local Release = require("../scripts/release-utils")
local metadata = require("../scripts/package-metadata")()
assert(metadata.Archive == `build/quick-part-{metadata.Version}.zip`)
Release.validateTag("v0.2.3", "0.2.3")
for _, tag in { "0.2.3", "v0.2.4", "main", "v0.2.3;echo bad", "v0.2.3-rc.1" } do
	assert(not pcall(Release.validateTag, tag, "0.2.3"), `Accepted invalid release tag {tag}`)
end
for _, version in { "01.2.3", "1.02.3", "1.2.03", "1.2", "1.2.3-rc.1", "1.2.3\n" } do
	assert(not pcall(Release.version, version), `Accepted invalid version {version}`)
end
assert(Release.published(true, "Package published successfully!\n"))
assert(not Release.published(true, "Error: 401 Unauthorized"))
assert(not Release.published(true, "Error: 409 Conflict"))
assert(not Release.published(true, ""))
assert(not Release.published(false, "Package published successfully!"))
print("Release checks passed: versioned archives, tag validation and registry rejection detection.")
