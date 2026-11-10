--!strict

-- Token bucket. `allow` mutates its bucket (the one deliberate exception to
-- the no-mutation rule for rules modules).
export type Bucket = { tokens: number, last: number }

local RateLimiter = {}

function RateLimiter.new(capacity: number, now: number): Bucket
	return { tokens = capacity, last = now }
end

function RateLimiter.allow(bucket: Bucket, now: number, capacity: number, refillPerSecond: number): boolean
	local elapsed = math.max(0, now - bucket.last)
	bucket.tokens = math.min(capacity, bucket.tokens + elapsed * refillPerSecond)
	bucket.last = math.max(bucket.last, now)
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

return RateLimiter
