--!strict
--!native
local Types = require(script.Parent.Types)
local Import = require(script.Parent.Import)
local PartSource = {}

function PartSource.options(part: BasePart): (Types.PartOptions?, string?)
	local shape: Types.Shape? = nil
	local geometry: Types.Geometry? = nil
	local texture = ""
	local doubleSided = false
	if part:IsA("Part") then
		if part.Shape == Enum.PartType.Block then
			shape = "Block"
		elseif part.Shape == Enum.PartType.Ball then
			shape = "Ball"
		elseif part.Shape == Enum.PartType.Cylinder then
			shape = "Cylinder"
		end
	elseif part:IsA("WedgePart") then
		shape = "Wedge"
	elseif part:IsA("CornerWedgePart") then
		shape = "CornerWedge"
	elseif part:IsA("MeshPart") then
		local reason: string? = nil
		geometry, reason = Import.meshPart(part)
		if not geometry then
			return nil, reason
		end
		texture, doubleSided = part.TextureID, part.DoubleSided
	end
	if not shape and not geometry then
		return nil, `Unsupported BasePart {part.ClassName}: {part:GetFullName()}`
	end
	for _, child in part:GetChildren() do
		if child:IsA("DataModelMesh") or child:IsA("Decal") then
			return nil, `Unsupported visual child {child.ClassName}: {child:GetFullName()}`
		end
	end
	return {
		Size = part.Size,
		CFrame = part.CFrame,
		PivotOffset = part.PivotOffset,
		Color = part.Color,
		Transparency = part.Transparency,
		Material = part.Material,
		MaterialVariant = part.MaterialVariant,
		Reflectance = part.Reflectance,
		CastShadow = part.CastShadow,
		SurfaceAppearance = part:FindFirstChildWhichIsA("SurfaceAppearance"),
		Shape = shape,
		Geometry = geometry,
		TextureID = texture,
		DoubleSided = doubleSided,
	},
		nil
end
return PartSource
