--!strict
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuickPart = require(ReplicatedStorage.Packages.QuickPart)
type PartHandle = QuickPart.PartHandle
type Renderer = QuickPart.Renderer
type ModelHandle = QuickPart.ModelHandle
type Profiler = { Begin: (string) -> (), End: () -> () }

return function(count: number, rigid: boolean, template: Model?)
	assert(count >= 1 and count % 1 == 0, "Benchmark count must be a positive integer")
	local templateParts: { BasePart } = {}
	local templatePivot = CFrame.identity
	if template then
		templatePivot = template:GetPivot()
		for _, object in template:GetDescendants() do
			if object:IsA("BasePart") then
				table.insert(templateParts, object)
			end
		end
		assert(#templateParts == count, "Benchmark count must match the template's BaseParts")
	end
	local renderer: Renderer? = nil
	local folder: Folder? = nil
	local handles: { PartHandle } = {}
	local modelHandle: ModelHandle? = nil
	local groups: { { BasePart } } = { {}, {}, {} }
	local targets: { { CFrame } } = { {}, {} }
	local phases = { 1, 1, 1, 1 }
	local pivots = { CFrame.new(0, 10, 0), CFrame.new(1, 11, 0) * CFrame.Angles(0, 0.1, 0) }
	-- Bound repeated work to roughly 1000 part updates per sample. Every case
	-- uses the same repeat count, including the constant-cost rigid-model path.
	local repeats = if template then 1 else math.clamp(math.floor(1000 / count), 1, 8)
	local function cleanup()
		if renderer then
			renderer:Destroy()
			renderer = nil
		end
		if folder then
			folder:Destroy()
			folder = nil
		end
		table.clear(handles)
		modelHandle = nil
		groups = { {}, {}, {} }
		targets = { {}, {} }
	end
	local function prepare()
		if renderer then
			return
		end
		local ok, reason = pcall(function()
			local active = QuickPart.new()
			renderer = active
			active.RenderingPart.Name = `QuickPartBenchmarkMeshes_{count}`
			local container = Instance.new("Folder")
			folder = container
			container.Name = `QuickPartBenchmark_{count}`
			container.Parent = workspace
			local source = Instance.new("Model")
			source.Name = "Source"
			source.Parent = container
			local options: { QuickPart.PartOptions } = {}
			for index = 1, count do
				local original = templateParts[index]
				local localFrame = if original
					then templatePivot:ToObjectSpace(original.CFrame)
					else CFrame.new((index % 32) * 3, math.floor(index / 32) * 3, 0)
				for phase = 1, 2 do
					targets[phase][index] = pivots[phase] * localFrame
				end
				options[index] =
					{ Size = Vector3.one, CFrame = targets[1][index], Color = Color3.fromRGB(70, 170, 240) }
				for group = 1, 3 do
					local part: BasePart = if original then original:Clone() else Instance.new("Part")
					part.Anchored = true
					part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
					if not original then
						part.Size = Vector3.one
					end
					part.CFrame = targets[1][index]
					part.Parent = if group == 1 then source else container
					table.insert(groups[group], part)
				end
				if index % 256 == 0 then
					task.wait()
				end
			end
			if rigid then
				source.WorldPivot = pivots[1]
				local value, failure = active:FromModel(source)
				assert(value, failure)
				modelHandle = value
			elseif template then
				for _, part in groups[1] do
					local value, failure = active:FromPart(part)
					assert(value, `Library mesh import failed before timing: {tostring(failure)}`)
					table.insert(handles, value)
				end
			else
				local value, failure = active:CreateMany(options)
				assert(value, failure)
				handles = value
			end
			print(
				`QuickPart benchmark: {count} parts, rigid={rigid}, batches={active:GetStats().Meshes}, batch API={active:GetStats().BatchMeshes > 0}`
			)
		end)
		if not ok then
			cleanup()
			error(tostring(reason), 0)
		end
	end
	local function advance(index: number): number
		phases[index] = 3 - phases[index]
		return phases[index]
	end
	local functions: { [string]: (Profiler) -> () } = {
		["BasePart CFrame"] = function(_profiler: Profiler)
			for _ = 1, repeats do
				local frames = targets[advance(1)]
				for index, part in groups[1] do
					part.CFrame = frames[index]
				end
			end
		end,
		["BulkMoveTo FireAllEvents"] = function(_profiler: Profiler)
			for _ = 1, repeats do
				workspace:BulkMoveTo(groups[2], targets[advance(2)], Enum.BulkMoveMode.FireAllEvents)
			end
		end,
		["BulkMoveTo FireCFrameChanged"] = function(_profiler: Profiler)
			for _ = 1, repeats do
				workspace:BulkMoveTo(groups[3], targets[advance(3)], Enum.BulkMoveMode.FireCFrameChanged)
			end
		end,
	}
	functions[if rigid then "QuickPart UpdateModel" else "QuickPart UpdateMany"] = function(_profiler: Profiler)
		local active = renderer
		assert(active)
		for _ = 1, repeats do
			local phase = advance(4)
			local model = modelHandle
			if model then
				model.WorldPivot = pivots[phase]
				active:UpdateModel(model)
			else
				local frames = targets[phase]
				for index, handle in handles do
					handle.CFrame = frames[index]
				end
				active:UpdateMany(handles)
			end
		end
	end
	-- Benchmarker starts its 40 ms preflight timer BEFORE ParameterGenerator.
	-- Build fixtures while requiring the benchmark module, outside that timer.
	-- BeforeAll is too late: the plugin runs its preflight before that hook.
	prepare()
	task.wait()
	return {
		ParameterGenerator = function() end,
		BeforeAll = prepare,
		AfterAll = cleanup,
		Functions = functions,
		Cleanup = cleanup,
		UpdatesPerSample = repeats,
	}
end
