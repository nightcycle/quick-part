--!strict
local process = require("@lune/process")
local Release = require("./release-utils")
local token = process.env.WALLY_AUTH_TOKEN
assert(token and token ~= "", "Configure the WALLY_AUTH_TOKEN repository secret before publishing")
local login = process.exec("wally", { "login", "--token", token })
assert(login.ok, "Wally authentication failed")
local result = process.exec("wally", { "publish" })
-- Never print the credential, including if an upstream command echoes it.
print(table.concat(string.split(result.stdout .. result.stderr, token), "[REDACTED]"))
assert(Release.published(result.ok, result.stdout), "Wally did not confirm publication; inspect the registry response")
