--!strict
--!native
export type Shape = "Block" | "Ball" | "Cylinder" | "Wedge"
export type Spec = {
	Name: string,
	Shape: Shape,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Transparency: number,
	Material: Enum.Material,
	Reflectance: number,
	PivotOffset: CFrame,
}
export type Example = {
	Name: string,
	Title: string,
	Description: string,
	Kind: "Properties" | "Population" | "Model",
	Z: number,
	Parts: { Spec },
}

local Layout = {}
Layout.LeftX = -23
Layout.RightX = 23
Layout.Examples = {} :: { Example }

local function part(name: string, size: Vector3, cf: CFrame, color: Color3): Spec
	return {
		Name = name,
		Shape = "Block",
		Size = size,
		CFrame = cf,
		Color = color,
		Transparency = 0,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0,
		PivotOffset = CFrame.identity,
	}
end

local properties: Example = {
	Name = "Properties",
	Title = "01  /  PART PROPERTIES",
	Z = 28,
	Kind = "Properties",
	Description = "Matching position, rotation, size, color and transparency",
	Parts = {},
}
for index, shape in { "Block", "Wedge", "Ball", "Cylinder", "Block" } do
	local spec = part(
		`Part{index}`,
		Vector3.new(3, 3, 3),
		CFrame.new((index - 3) * 7, 5, 0),
		Color3.fromHSV((index - 1) / 6, 0.65, 1)
	)
	spec.Shape = shape :: Shape
	spec.Material = if index == 4
		then Enum.Material.Metal
		elseif index == 5 then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	spec.Reflectance = if index == 4 then 0.2 else 0
	spec.PivotOffset = CFrame.new(0, -1.5, 0)
	table.insert(properties.Parts, spec)
end
table.insert(Layout.Examples, properties)

local population: Example = {
	Name = "Population",
	Title = "02  /  100 MOVING CUBES",
	Z = -13,
	Kind = "Population",
	Description = "Individual BasePart CFrames vs one UpdateMany call",
	Parts = {},
}
for index = 1, 100 do
	local column, row = (index - 1) % 10, math.floor((index - 1) / 10)
	table.insert(
		population.Parts,
		part(
			`Cube{index}`,
			Vector3.new(1.5, 1.5, 1.5),
			CFrame.new((column - 4.5) * 2.8, 4, (row - 4.5) * 2.4),
			Color3.fromHSV((index - 1) / 100, 0.65, 1)
		)
	)
end
table.insert(Layout.Examples, population)

local model: Example = {
	Name = "Model",
	Title = "03  /  RIGID MODEL",
	Z = -55,
	Kind = "Model",
	Description = "Model PivotTo + ScaleTo vs UpdateModel",
	Parts = {},
}
local stone = Color3.fromRGB(225, 184, 108)
for side = -1, 1, 2 do
	for level = 0, 5 do
		table.insert(
			model.Parts,
			part(`Pillar{side}_{level}`, Vector3.new(3.5, 1.6, 4), CFrame.new(side * 7, 1 + level * 1.7, 0), stone)
		)
	end
end
for index = -4, 4 do
	table.insert(model.Parts, part(`Lintel{index}`, Vector3.new(1.9, 2, 4.5), CFrame.new(index * 2, 11.3, 0), stone))
end
for index = -2, 2 do
	local spec = part(
		`Crown{index}`,
		Vector3.new(1.5, 1.5 + math.abs(index) * 0.3, 2.2),
		CFrame.new(index * 3.5, 13.2, 0),
		Color3.fromRGB(92, 210, 255)
	)
	spec.Material = Enum.Material.Neon
	table.insert(model.Parts, spec)
end
table.insert(Layout.Examples, model)

function Layout.origin(example: Example, right: boolean): CFrame
	return CFrame.new(if right then Layout.RightX else Layout.LeftX, 1, example.Z)
end

-- Both sides sample exactly the same local transform at the same animation time.
function Layout.sample(example: Example, spec: Spec, index: number, time: number): (Vector3, CFrame, Color3, number)
	if example.Kind == "Properties" then
		local wave = math.sin(time * 1.6 + index * 0.7)
		local size = spec.Size * Vector3.new(1 + wave * 0.22, 1 - wave * 0.18, 1 + wave * 0.12)
		local pivot = spec.CFrame
			* spec.PivotOffset
			* CFrame.new(0, math.sin(time + index) * 1.4, 0)
			* CFrame.Angles(time * 0.4, time * 0.65, index * 0.1)
		local cf = pivot * spec.PivotOffset:Inverse()
		local color = spec.Color:Lerp(Color3.new(1, 1, 1), (wave + 1) * 0.18)
		local transparency = if index == 3 or index == 5 then (wave + 1) * 0.3 else 0
		return size, cf, color, transparency
	end
	local cf = spec.CFrame
		* CFrame.new(0, math.sin(time * 2 + index * 0.17) * 1.6, 0)
		* CFrame.Angles(0, time * 0.6 + index * 0.04, 0)
	return spec.Size, cf, spec.Color, spec.Transparency
end

function Layout.sampleModel(time: number): (CFrame, number)
	return CFrame.Angles(0, math.sin(time * 0.4) * 0.65, math.sin(time * 0.6) * 0.06), 1 + math.sin(time * 0.9) * 0.12
end
return Layout
