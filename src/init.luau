--!strict
--!native
local Renderer = require(script.Renderer)
local Types = require(script.Types)
export type PartHandle = Types.PartHandle
export type ModelHandle = Types.ModelHandle
export type PartOptions = Types.PartOptions
export type Geometry = Types.Geometry
export type Renderer = typeof(Renderer.new())
local QuickPart = Renderer.new()
return setmetatable(QuickPart, { __index = { new = Renderer.new } })
