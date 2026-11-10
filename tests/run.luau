--!strict
local fs = require("@lune/fs")
local process = require("@lune/process")

local T = require("./harness")

local specs: { string } = {}
for _, file in fs.readDir("tests") do
	if string.sub(file, -10) == ".spec.luau" then
		table.insert(specs, string.sub(file, 1, -6))
	end
end
table.sort(specs)
if #specs == 0 then
	print("No spec files found in tests/ (expected tests/*.spec.luau)")
	process.exit(1)
end

for _, name in specs do
	require("./" .. name)
end

local results = T.results()
for _, failure in results.failures do
	print("FAIL " .. failure)
end
print(`{results.passed} passed, {results.failed} failed`)
if results.failed > 0 then
	process.exit(1)
end
