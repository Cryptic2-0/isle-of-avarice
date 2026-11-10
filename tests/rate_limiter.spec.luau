--!strict
local T = require("./harness")
local RateLimiter = require("../src/shared/Rules/RateLimiter")

local function drain(bucket: RateLimiter.Bucket, now: number): number
	local allowed = 0
	for _ = 1, 100 do
		if RateLimiter.allow(bucket, now, 10, 5) then
			allowed += 1
		end
	end
	return allowed
end

T.test("a new bucket allows exactly capacity calls", function()
	local bucket = RateLimiter.new(10, 0)
	T.eq(drain(bucket, 0), 10)
	T.falsy(RateLimiter.allow(bucket, 0, 10, 5))
end)

T.test("tokens refill over time", function()
	local bucket = RateLimiter.new(10, 0)
	drain(bucket, 0)
	T.eq(drain(bucket, 1), 5)
end)

T.test("long idle never exceeds capacity", function()
	local bucket = RateLimiter.new(10, 0)
	drain(bucket, 0)
	T.eq(drain(bucket, 1000), 10)
end)
