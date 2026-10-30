--!strict
--!native
local Renderer = require(script.Renderer)
local Types = require(script.Types)
export type PartHandle = Types.PartHandle
export type ModelHandle = Types.ModelHandle
export type PartOptions = Types.PartOptions
export type Geometry = Types.Geometry
export type Shape = Types.Shape
export type Face = Types.Face
export type Style = Types.Style
export type BatchWriter = Types.BatchWriter
export type Bucket = Types.Bucket
export type Record = Types.Record
export type GeometryInfo = Types.GeometryInfo
export type Stats = Types.Stats
export type Renderer = Renderer.Renderer
local QuickPart = Renderer.new()
-- Wally consumers only require the package entry point. Share the actual module
-- tables so CONSTANTS and cached geometry stay consistent with the renderer.
return setmetatable(QuickPart, {
	__index = {
		new = Renderer.new,
		Renderer = Renderer,
		Types = Types,
		Mesh = require(script.Mesh),
		Import = require(script.Import),
		PartSource = require(script.PartSource),
	},
})
