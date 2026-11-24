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
	SEALED = "The island has sealed this Relic. Too many are already held here.",
	LEDGER_LOCKED = "Your Ledger is locked while a claim is made against you.",
	VAULTED = "{name} is now in your Vault.",
	UNVAULTED = "{name} left your Vault.",
	VAULT_FULL = "Your Vault is full.",
	NOT_HELD = "You do not hold that Relic.",
	CROWN_NO_VAULT = "Crown Relics cannot be Vaulted.",
	ALREADY_VAULTED = "That Relic is already in your Vault.",
	NOT_VAULTED = "That Relic is not in your Vault.",
	NOT_IN_SAFE_ZONE = "You can change your Vault only in Tallyport.",
	SHIELD_SELF = "You are shielded. Drop your shield to fight.",
	TARGET_SHIELDED = "That player is shielded.",
	SAFE_ZONE = "No fighting in Tallyport.",
	SHIELD_ENDED = "Your new-player shield has ended. Other players can now attack you.",
	MARKED = "You started a fight. You are Marked for 5 minutes.",
	DEFEATED_BY = "{player} defeated you and is making a claim on your Ledger.",
	CLAIM_STARTED = "You defeated {player}. Make your claim.",
	CLAIM_COOLDOWN = "You defeated {player}, but you already claimed from them in the last hour.",
	CLAIM_TAKEN = "You took {name}!",
	CLAIM_MISS = "Nothing there.",
	CLAIM_LOST = "{player} took from you: {names}.",
	CLAIM_SAFE = "{player} took nothing from you.",
	CLAIM_OVER = "The claim is over.",
	ALREADY_PICKED = "You already picked that slot.",
	TIER_LIMIT = "You cannot take any more Relics of that rarity.",
	BAD_SLOT = "That did not work.",
	CALLING_CHOSEN = "{path} is now your Calling.",
	CALLING_CHANGED = "{path} is now your Calling.",
	CALLING_ALREADY_SET = "You already have a Calling.",
	CALLING_SAME = "That is already your Calling.",
	CALLING_COOLDOWN = "You can change your Calling again in {days} days.",
	NOT_ENOUGH_COIN = "You need {cost} Coin.",
	NO_CALLING = "Choose a Calling first.",
	LEVEL_UP = "{path} reached level {level}.",
	ABILITY_UNLOCKED = "You learned {name}!",
	LOADOUT_CHANGED = "Abilities updated.",
	LOADOUT_SAFE_ZONE = "You can change abilities only in Tallyport.",
	NOT_UNLOCKED = "You have not learned that ability yet.",
	NO_ABILITY = "Nothing is equipped in that slot.",
	ON_COOLDOWN = "That ability is not ready yet.",
	ROOTED = "You are rooted and cannot dash.",
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
