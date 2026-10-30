--!strict
--!native
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Layout = require(ReplicatedStorage.DemoLayout)
local Types = require(ReplicatedStorage.Packages.QuickPart.Types)
type Package = typeof(require(ReplicatedStorage.Packages.QuickPart))
type Renderer = typeof(require(ReplicatedStorage.Packages.QuickPart).new())
type Row = {
	Example: Layout.Example,
	Reference: Model,
	Preview: Model,
	Source: Model?,
	RealParts: { BasePart },
	PreviewParts: { BasePart },
	Status: TextLabel,
	Message: string,
	Renderer: Renderer?,
	Handles: { Types.PartHandle }?,
	ModelHandle: Types.ModelHandle?,
}

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "QuickPartDemo", false
local label = Instance.new("TextLabel")
label.Size, label.Position = UDim2.new(1, -32, 0, 130), UDim2.fromOffset(16, 16)
label.BackgroundColor3, label.BackgroundTransparency = Color3.fromRGB(17, 24, 35), 0.08
label.TextColor3, label.TextSize = Color3.fromRGB(232, 240, 252), 16
label.Font, label.TextWrapped = Enum.Font.Gotham, true
label.Text = "QuickPart comparison gallery · Loading paired examples..."
label.Parent = gui
local function button(text: string, x: number): TextButton
	local control = Instance.new("TextButton")
	control.Size, control.Position = UDim2.fromOffset(170, 36), UDim2.fromOffset(x, 154)
	control.BackgroundColor3, control.TextColor3 = Color3.fromRGB(44, 59, 81), Color3.new(1, 1, 1)
	control.Font, control.TextSize, control.Text = Enum.Font.GothamBold, 14, text
	control.Parent = gui
	return control
end
local pauseButton = button("Pause animation", 16)
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local rows: { Row } = {}
local paused, alive = false, true
local time = 0
local connections: { RBXScriptConnection } = {}
local function refreshText()
	local lines = {
		"QUICKPART  /  LIVE COMPARISONS",
		"Left: real Roblox parts and models · Right: matching EditableMesh versions",
	}
	for _, row in rows do
		table.insert(lines, `{row.Example.Name}: {row.Message}`)
	end
	label.Text = table.concat(lines, "\n")
end
local function status(row: Row, message: string, failed: boolean?)
	row.Message = message
	row.Status.Text = "QUICKPART\n" .. message
	row.Status.TextColor3 = if failed then Color3.fromRGB(255, 181, 100) else Color3.fromRGB(190, 162, 255)
	refreshText()
end
local function setPreviewVisible(row: Row, visible: boolean)
	for _, part in row.PreviewParts do
		part.LocalTransparencyModifier = if visible then 0 else 1
	end
end
local function fail(row: Row, reason: string)
	if row.Renderer then
		row.Renderer.Destroy()
	end
	row.Renderer, row.Handles, row.ModelHandle = nil, nil, nil
	setPreviewVisible(row, true)
	status(row, "BasePart preview — mesh unavailable (see Output)", true)
	label.Text ..= "\nEnable Mesh / Image APIs in Game Settings > Security."
	warn(`QuickPart demo [{row.Example.Name}]: {reason}`)
end
table.insert(
	connections,
	pauseButton.Activated:Connect(function()
		paused = not paused
		pauseButton.Text = if paused then "Resume animation" else "Pause animation"
	end)
)

local gallery = workspace:WaitForChild("ComparisonGallery")
for _, example in Layout.Examples do
	local folder = gallery:WaitForChild(example.Name)
	local reference, preview = folder:WaitForChild("Reference"), folder:WaitForChild("Preview")
	assert(reference:IsA("Model") and preview:IsA("Model"))
	local statusText = folder:WaitForChild("MeshStatus"):WaitForChild("Sign"):WaitForChild("Text")
	assert(statusText:IsA("TextLabel"))
	local realParts: { BasePart }, previewParts: { BasePart } = {}, {}
	for _, spec in example.Parts do
		local real, copy = reference:WaitForChild(spec.Name), preview:WaitForChild(spec.Name)
		assert(real:IsA("BasePart") and copy:IsA("BasePart"))
		table.insert(realParts, real)
		table.insert(previewParts, copy)
	end
	local row: Row = {
		Example = example,
		Reference = reference,
		Preview = preview,
		Source = if example.Kind == "Model" then preview:Clone() else nil,
		RealParts = realParts,
		PreviewParts = previewParts,
		Status = statusText,
		Message = "Preparing EditableMesh...",
		Renderer = nil,
		Handles = nil,
		ModelHandle = nil,
	}
	table.insert(rows, row)
	status(row, row.Message)
end

local function update(row: Row, animationTime: number): boolean
	local example = row.Example
	local left, right = Layout.origin(example, false), Layout.origin(example, true)
	local renderer, model = row.Renderer, row.ModelHandle
	if example.Kind == "Model" then
		local rotation, scale = Layout.sampleModel(animationTime)
		row.Reference:ScaleTo(scale)
		row.Reference:PivotTo(left * rotation)
		if renderer and model then
			model.WorldPivot, model.Scale = right * rotation, scale
			renderer.UpdateModel(model)
		else
			row.Preview:ScaleTo(scale)
			row.Preview:PivotTo(right * rotation)
		end
		return true
	end
	local handles = row.Handles
	for index, spec in example.Parts do
		local size, cf, color, transparency = Layout.sample(example, spec, index, animationTime)
		local real = row.RealParts[index]
		real.Size, real.CFrame, real.Color, real.Transparency = size, left * cf, color, transparency
		if handles then
			local handle = handles[index]
			handle.Size, handle.CFrame, handle.Color, handle.Transparency = size, right * cf, color, transparency
		else
			local copy = row.PreviewParts[index]
			copy.Size, copy.CFrame, copy.Color, copy.Transparency = size, right * cf, color, transparency
		end
	end
	if renderer and handles then
		renderer.UpdateMany(handles)
	end
	return true
end

-- Start the reference animation BEFORE requesting EditableMesh. A rejected API
-- or slow mesh attachment must not leave the gallery looking empty or frozen.
table.insert(
	connections,
	RunService.Heartbeat:Connect(function(deltaTime: number)
		if paused then
			return
		end
		time += deltaTime
		for _, row in rows do
			local ok, reason = pcall(update, row, time)
			if not ok then
				fail(row, tostring(reason))
			end
		end
	end)
)

task.spawn(function()
	local package: Package? = nil
	local loaded, loadError = pcall(function()
		package = require(ReplicatedStorage.Packages.QuickPart)
	end)
	local quickPart = package
	if not alive then
		return
	end
	if not loaded or not quickPart then
		for _, row in rows do
			fail(row, tostring(loadError))
		end
		return
	end
	for _, row in rows do
		if not alive then
			break
		end
		local renderer = quickPart.new()
		renderer.RenderingPart.Name = `QuickPartDemo_{row.Example.Name}`
		local handles: { Types.PartHandle }? = nil
		local modelHandle: Types.ModelHandle? = nil
		local ok, reason = pcall(function()
			local source = row.Source
			if source then
				local result, failure = renderer.FromModel(source)
				assert(result, failure)
				modelHandle = result
			else
				local options: { Types.PartOptions } = {}
				for _, spec in row.Example.Parts do
					table.insert(options, {
						Size = spec.Size,
						CFrame = Layout.origin(row.Example, true) * spec.CFrame,
						Color = spec.Color,
						Transparency = spec.Transparency,
						Shape = spec.Shape,
						Material = spec.Material,
						Reflectance = spec.Reflectance,
						PivotOffset = spec.PivotOffset,
					})
				end
				local result, failure = renderer.CreateMany(options)
				assert(result, failure)
				handles = result
			end
		end)
		if row.Source then
			row.Source:Destroy()
			row.Source = nil
		end
		if not alive then
			renderer.Destroy()
			break
		end
		if ok then
			row.Renderer, row.Handles, row.ModelHandle = renderer, handles, modelHandle
			-- Align to the current shared animation time before hiding the preview.
			local synced, syncError = pcall(update, row, time)
			if synced then
				setPreviewVisible(row, false)
				local stats = renderer.GetStats()
				status(row, `Live · {stats.Parts} parts → {stats.Meshes} meshes`)
			else
				fail(row, tostring(syncError))
			end
		else
			renderer.Destroy()
			fail(row, tostring(reason))
		end
	end
end)

script.Destroying:Connect(function()
	alive = false
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, row in rows do
		if row.Renderer then
			row.Renderer.Destroy()
		end
		if row.Source then
			row.Source:Destroy()
		end
		setPreviewVisible(row, true)
	end
	gui:Destroy()
end)
