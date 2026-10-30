--!strict
--!native
local Factory = require(game:GetService("ReplicatedStorage").Benchmarks.Factory)
export type Result = { Name: string, MedianMicroseconds: number, P90Microseconds: number }
export type Report = { Results: { Result }, FasterThanAll: boolean, Count: number, Rigid: boolean }

-- Setup/teardown are outside timing. A losing result remains a failure, not a skipped case.
return function(count: number?, rigid: boolean?, requireWin: boolean?): Report
	local population = count or 1000
	local model = rigid or false
	local bench = Factory(population, model)
	local keys: { string } = {}
	for name in bench.Functions do
		table.insert(keys, name)
	end
	table.sort(keys)
	local samples: { [string]: { number } } = {}
	for _, name in keys do
		samples[name] = {}
	end
	local profiler = { Begin = function(_name: string) end, End = function() end }
	local ok, failure = pcall(function()
		bench.BeforeAll()
		for iteration = 1, 120 do
			for offset = 1, #keys do
				local name = keys[(iteration + offset) % #keys + 1]
				local start = os.clock()
				bench.Functions[name](profiler)
				local elapsed = os.clock() - start
				if iteration > 20 then
					table.insert(samples[name], elapsed * 1e6 / bench.UpdatesPerSample)
				end
			end
			task.wait()
		end
	end)
	bench.Cleanup()
	assert(ok, tostring(failure))
	local results: { Result } = {}
	local quickMedian = math.huge
	for _, name in keys do
		local values = samples[name]
		table.sort(values)
		local result = { Name = name, MedianMicroseconds = values[50], P90Microseconds = values[90] }
		table.insert(results, result)
		if name:find("QuickPart", 1, true) then
			quickMedian = result.MedianMicroseconds
		end
		print(
			`{name}: median {string.format("%.2f", result.MedianMicroseconds)} µs, p90 {string.format(
				"%.2f",
				result.P90Microseconds
			)} µs per update`
		)
	end
	local wins = true
	for _, result in results do
		if not result.Name:find("QuickPart", 1, true) then
			wins = wins and quickMedian < result.MedianMicroseconds
			print(`QuickPart vs {result.Name}: {string.format("%.2f", result.MedianMicroseconds / quickMedian)}x`)
		end
	end
	if requireWin then
		assert(wins, "QuickPart did not beat every baseline on this machine/workload")
	end
	return { Results = results, FasterThanAll = wins, Count = population, Rigid = model }
end
