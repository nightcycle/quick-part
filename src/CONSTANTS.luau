--!strict
--!native
return {
	-- Roblox does not expose the device's remaining editable-memory budget.
	-- This is an application triangle allowance, NOT a percentage of device RAM.
	TRIANGLE_BUDGET = 20000,
	TRIANGLE_BUDGET_PERCENT = 80,
	MAX_TRIANGLES_PER_MESH = 20000,
	MAX_VERTICES_PER_MESH = 60000,
	USE_BATCH_API = true,
	CURVE_SEGMENTS = 24,
}
