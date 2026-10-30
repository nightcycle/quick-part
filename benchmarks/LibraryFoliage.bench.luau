--!strict
--!native
local source = workspace.ComparisonGallery.Woodland.Reference
local count = 0
for _, object in source:GetDescendants() do
	if object:IsA("BasePart") then
		count += 1
	end
end
return require(script.Parent.Factory)(count, false, source)
