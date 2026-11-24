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
	"CREATURE_DEFEATED",
	"REWARD_SEALED",
	"REWARD_LOST",
	"REWARD_LOCKED",
	"TRIAL_STARTED",
	"TRIAL_PASSED",
	"TRIAL_FAILED_TIME",
	"TRIAL_FAILED_DEFEAT",
	"TRIAL_BUSY",
	"TRIAL_COOLDOWN",
	"MARKER_REACHED",
	"HUNT_PROGRESS",
	"QUEST_STEP",
	"QUEST_COMPLETE",
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

T.test("format fills in trial and creature messages", function()
	T.eq(
		Messages.format("TRIAL_PASSED", { name = "Tidewalk", coin = "30" }),
		"You passed Tidewalk! +30 Coin."
	)
	T.eq(
		Messages.format("CREATURE_DEFEATED", { creature = "Brinehound", coin = "4" }),
		"Brinehound defeated! +4 Coin."
	)
	T.eq(
		Messages.format("TRIAL_COOLDOWN", { name = "Tidewalk", seconds = "12" }),
		"You can try Tidewalk again in 12 seconds."
	)
	T.eq(Messages.format("MARKER_REACHED", { n = "2", total = "6" }), "Marker 2 of 6.")
	T.eq(Messages.format("QUEST_STEP", { n = "2" }), "The Unpaid Debt: step 2 of 4 done.")
	T.eq(Messages.format("QUEST_COMPLETE", { coin = "150" }), "The Unpaid Debt is paid! +150 Coin.")
	T.eq(
		Messages.format("REWARD_SEALED", { name = "Bog Pearl" }),
		"Bog Pearl is sealed on this server, so you did not get it."
	)
end)
