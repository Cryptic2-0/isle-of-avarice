--!strict
local T = require("./harness")
local Messages = require("../src/shared/Catalog/Messages")

local codes = {
	"GOT_CARD",
	"CLAIMED",
	"UNCLAIMED",
	"DISCARDED",
	"FREE_FULL",
	"CACHE_EMPTY",
	"TOO_FAR",
	"ALREADY_CLAIMED",
	"NOT_CLAIMED",
	"BAD_REQUEST",
	"BAD_INDEX",
	"UNKNOWN_CARD",
	"SLOW_DOWN",
	"DATA_NOT_LOADED",
	"LEDGER_COMPLETE",
	"SEALED",
	"LEDGER_LOCKED",
	"VAULTED",
	"UNVAULTED",
	"VAULT_FULL",
	"NOT_HELD",
	"CROWN_NO_VAULT",
	"ALREADY_VAULTED",
	"NOT_VAULTED",
	"NOT_IN_SAFE_ZONE",
	"SHIELD_SELF",
	"TARGET_SHIELDED",
	"SAFE_ZONE",
	"SHIELD_ENDED",
	"MARKED",
	"DEFEATED_BY",
	"CLAIM_STARTED",
	"CLAIM_COOLDOWN",
	"CLAIM_TAKEN",
	"CLAIM_MISS",
	"CLAIM_LOST",
	"CLAIM_SAFE",
	"CLAIM_OVER",
	"ALREADY_PICKED",
	"TIER_LIMIT",
	"BAD_SLOT",
	"CALLING_CHOSEN",
	"CALLING_CHANGED",
	"CALLING_ALREADY_SET",
	"CALLING_SAME",
	"CALLING_COOLDOWN",
	"NOT_ENOUGH_COIN",
	"NO_CALLING",
	"LEVEL_UP",
	"ABILITY_UNLOCKED",
	"LOADOUT_CHANGED",
	"LOADOUT_SAFE_ZONE",
	"NOT_UNLOCKED",
	"NO_ABILITY",
	"ON_COOLDOWN",
	"ROOTED",
}

T.test("every message code has text", function()
	for _, code in codes do
		T.truthy(Messages.format(code) ~= code, code)
	end
end)

T.test("format fills in placeholders", function()
	T.eq(
		Messages.format("CLAIM_LOST", { player = "Ann", names = "Barnacle Key, Bottled Squall" }),
		"Ann took from you: Barnacle Key, Bottled Squall."
	)
end)

T.test("format fills in path and level", function()
	T.eq(Messages.format("LEVEL_UP", { path = "Gale", level = "10" }), "Gale reached level 10.")
end)
