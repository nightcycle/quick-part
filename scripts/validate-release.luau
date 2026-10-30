--!strict
local process = require("@lune/process")
local metadata = require("./package-metadata")()
local Release = require("./release-utils")
local tag = process.env.RELEASE_TAG or process.args[1]
assert(tag, "Provide RELEASE_TAG or a version tag argument")
Release.validateTag(tag, metadata.Version)
local target = process.exec("git", { "rev-parse", "--verify", `refs/tags/{tag}^\{commit\}` })
local head = process.exec("git", { "rev-parse", "HEAD" })
assert(target.ok and head.ok and target.stdout == head.stdout, "Release must build the exact existing tag commit")
print(`Validated {tag} and wally.toml version {metadata.Version}`)
