--!strict
local passed = 0
local failed = 0
local failures: { string } = {}

local function describe(value: any, seen: { [any]: boolean }?): string
	if type(value) ~= "table" then
		return if type(value) == "string" then string.format("%q", value) else tostring(value)
	end
	-- A table that holds itself would never finish printing.
	local path = seen or {}
	if path[value] then
		return "<cycle>"
	end
	path[value] = true
	local keys = {}
	for key in value do
		table.insert(keys, key)
	end
	table.sort(keys, function(a: any, b: any)
		return tostring(a) < tostring(b)
	end)
	local parts = {}
	for _, key in keys do
		table.insert(parts, `[{describe(key, path)}] = {describe(value[key], path)}`)
	end
	path[value] = nil
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local function deepEqual(a: any, b: any, seen: { [any]: { [any]: boolean } }?): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		-- NaN is the only value not equal to itself; treat NaN as equal to NaN
		return a ~= a and b ~= b
	end
	-- A pair already being compared further up is assumed equal, so cycles end.
	local pairs_ = seen or {}
	local mine = pairs_[a]
	if mine == nil then
		mine = {}
		pairs_[a] = mine
	end
	if mine[b] then
		return true
	end
	mine[b] = true
	for key, value in a do
		if not deepEqual(value, b[key], pairs_) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function fail(label: string?, message: string)
	error((if label then label .. ": " else "") .. message, 0)
end

local T = {}

function T.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		table.insert(failures, `{name}: {tostring(err)}`)
	end
end

function T.eq(actual: any, expected: any, label: string?)
	if not deepEqual(actual, expected) then
		fail(label, `expected {describe(expected)}, got {describe(actual)}`)
	end
end

function T.truthy(value: any, label: string?)
	if not value then
		fail(label, `expected a truthy value, got {describe(value)}`)
	end
end

function T.falsy(value: any, label: string?)
	if value then
		fail(label, `expected a falsy value, got {describe(value)}`)
	end
end

function T.results(): { passed: number, failed: number, failures: { string } }
	return { passed = passed, failed = failed, failures = failures }
end

return T
