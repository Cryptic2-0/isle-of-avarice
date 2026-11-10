--!strict
local templates: { [string]: string } = {
	GOT_CARD = "You found {name}!",
	CLAIMED = "{name} claimed.",
	UNCLAIMED = "{name} moved to your free slots.",
	DISCARDED = "{name} discarded.",
	FREE_FULL = "Your free slots are full.",
	CACHE_EMPTY = "This cache is empty. It will refill soon.",
	TOO_FAR = "You are too far away.",
	ALREADY_CLAIMED = "You have already claimed that Relic.",
	NOT_CLAIMED = "You have not claimed that Relic.",
	BAD_REQUEST = "That did not work.",
	BAD_INDEX = "That did not work.",
	UNKNOWN_CARD = "That did not work.",
	SLOW_DOWN = "Slow down.",
	DATA_NOT_LOADED = "Your Ledger is still loading.",
	LEDGER_COMPLETE = "{player} has completed the Ledger!",
}

local function format(code: string, args: { [string]: string }?): string
	local template = templates[code]
	if template == nil then
		return code
	end
	local values = args
	if values == nil then
		return template
	end
	local text = string.gsub(template, "{(%w+)}", function(key: string): string?
		return values[key]
	end)
	return text
end

return {
	format = format,
}
