--!strict
-- Bake inspectable BasePart examples into the place; EditableMeshes are created on Play.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Layout = require("./load-package")()("demo/Layout")
local r = roblox :: any
local V, CF, Color = r.Vector3, r.CFrame, r.Color3

local gallery = roblox.Instance.new("Folder") :: any
gallery.Name = "ComparisonGallery"
local function box(parent: any, name: string, size: any, cf: any, color: any): any
	local object = roblox.Instance.new("Part") :: any
	object.Name, object.Size, object.CFrame, object.Color = name, size, cf, color
	object.Anchored = true
	object.Material = r.Enum.Material.SmoothPlastic
	object.TopSurface, object.BottomSurface = r.Enum.SurfaceType.Smooth, r.Enum.SurfaceType.Smooth
	object.Parent = parent
	return object
end
local function sign(parent: any, name: string, position: any, text: string, color: any, width: number): any
	local anchor = box(parent, name, V.one, CF.new(position), Color.new(1, 1, 1))
	anchor.Transparency, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = 1, false, false, false
	local gui = roblox.Instance.new("BillboardGui") :: any
	gui.Name, gui.Size, gui.AlwaysOnTop = "Sign", r.UDim2.new(width, 0, 3, 0), false
	gui.MaxDistance, gui.LightInfluence = 300, 0
	gui.Parent = anchor
	local label = roblox.Instance.new("TextLabel") :: any
	label.Name = "Text"
	label.Size = r.UDim2.fromScale(1, 1)
	label.BackgroundColor3, label.BackgroundTransparency = Color.fromRGB(15, 23, 34), 0.1
	label.TextColor3, label.Text, label.TextScaled = color, text, true
	label.TextWrapped = true
	label.Parent = gui
	return anchor
end

local spawn = roblox.Instance.new("SpawnLocation") :: any
spawn.Name, spawn.Size, spawn.CFrame = "Spawn", V.new(8, 1, 8), CF.new(0, 0.5, 63)
spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
spawn.Material, spawn.Color = r.Enum.Material.Neon, Color.fromRGB(83, 224, 176)
spawn.Parent = gallery
sign(
	gallery,
	"Welcome",
	V.new(0, 7, 61),
	"QUICKPART COMPARISON GALLERY\nPress Play (F5) to animate both sides",
	Color.fromRGB(233, 242, 255),
	42
)

for _, example in Layout.Examples do
	local row = roblox.Instance.new("Folder") :: any
	row.Name, row.Parent = example.Name, gallery
	for _, right in { false, true } do
		local origin = Layout.origin(example, right)
		local accent = if right then Color.fromRGB(173, 139, 255) else Color.fromRGB(77, 209, 221)
		local platform = box(
			row,
			if right then "MeshPlatform" else "RealPlatform",
			V.new(39, 1, 32),
			origin * CF.new(0, -0.5, 0),
			Color.fromRGB(29, 38, 53)
		)
		box(
			row,
			if right then "MeshStripe" else "RealStripe",
			V.new(39, 0.1, 0.3),
			origin * CF.new(0, 0.05, 15.7),
			accent
		).Material =
			r.Enum.Material.Neon
		platform.CanTouch = false
		sign(
			row,
			if right then "MeshStatus" else "RealStatus",
			origin.Position + V.new(0, 2, 17),
			if right then "QUICKPART\nBasePart preview - press Play" else "ROBLOX BASEPARTS / MODEL\nOriginal geometry",
			accent,
			37
		)
		local model = roblox.Instance.new("Model") :: any
		model.Name, model.Parent = if right then "Preview" else "Reference", row
		for _, spec in example.Parts do
			local object = roblox.Instance.new(if spec.Shape == "Wedge" then "WedgePart" else "Part") :: any
			object.Name, object.Size, object.CFrame = spec.Name, spec.Size, origin * spec.CFrame
			object.Color, object.Transparency = spec.Color, spec.Transparency
			object.Material, object.Reflectance, object.PivotOffset = spec.Material, spec.Reflectance, spec.PivotOffset
			object.Anchored, object.CanCollide, object.CanTouch, object.CanQuery = true, false, false, false
			object.TopSurface, object.BottomSurface = r.Enum.SurfaceType.Smooth, r.Enum.SurfaceType.Smooth
			if spec.Shape == "Ball" then
				object.Shape = r.Enum.PartType.Ball
			elseif spec.Shape == "Cylinder" then
				object.Shape = r.Enum.PartType.Cylinder
			end
			object.Parent = model
		end
		model.WorldPivotData, model.NeedsPivotMigration = origin, false
	end
	sign(
		row,
		"Title",
		V.new(0, 18, example.Z - 2),
		example.Title .. "\n" .. example.Description,
		Color.fromRGB(233, 242, 255),
		54
	)
end

fs.writeDir("demo/world")
fs.writeFile("demo/world/Gallery.rbxm", roblox.serializeModel({ gallery }))
local camera = roblox.Instance.new("Camera") :: any
camera.Name = "Camera"
camera.CFrame = CF.lookAt(V.new(92, 86, 116), V.new(0, 4, -12))
camera.Focus = CF.new(0, 4, -12)
camera.FieldOfView = 65
fs.writeFile("demo/world/Camera.rbxm", roblox.serializeModel({ camera }))
print("Baked spawn and three paired comparison rows into demo/world/Gallery.rbxm")
