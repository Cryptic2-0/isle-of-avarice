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
	"CROWNED_YOU",
	"RENOUNCE_NOT_READY",
	"RENOUNCE_NOT_IN_TOWN",
	"RENOUNCE_CLAIMING",
	"RENOUNCE_TRADING",
	"RENOUNCE_WORD",
	"RENOUNCE_EXPIRED",
	"RENOUNCE_NO_OFFER",
	"RENOUNCE_CANCELLED",
	"RENOUNCE_DONE",
	"RENOUNCED",
	"HOLD_TOO_SHORT",
	"ROUND_STEP",
	"ROUND_COMPLETE",
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

T.test("M5 messages", function()
	local m5 = {
		"NOT_A_RELIC",
		"EDICT_NO_TARGET",
		"EDICT_MARKED",
		"EDICT_IN_COMBAT",
		"EDICT_IN_TRIAL",
		"EDICT_NOT_MET",
		"EDICT_NOT_NOW",
		"EDICT_VEILED",
		"EDICT_VEIL_ON",
		"AUDITED",
		"EDICTS_LOST",
		"PASSAGE_DONE",
		"HOMECOMING_DONE",
		"SHOP_NO_ROOM",
		"SHOP_PACK",
		"SHOP_BOUGHT",
		"SHOP_SOLD",
		"NOT_FOR_SALE",
		"TRADE_SENT",
		"TRADE_DECLINED",
		"TRADE_BUSY",
		"TRADE_EXPIRED",
		"TRADE_CANCELLED",
		"TRADE_DONE",
		"TRADE_TOO_SOON",
		"TRADE_NO_ROOM",
		"TRADE_BAD_OFFER",
		"TRADE_NOT_OPEN",
	}
	for _, code in m5 do
		T.truthy(Messages.format(code) ~= code, code)
	end
	T.eq(
		Messages.format("SHOP_SOLD", { name = "Bottled Squall", coin = "15" }),
		"You sold Bottled Squall for 15 Coin."
	)
	T.eq(
		Messages.format("EDICTS_LOST", { names = "Veil, Audit" }),
		"Your defeat cost you: Veil, Audit."
	)
	T.eq(Messages.format("SHOP_NO_ROOM", { count = "3" }), "You need 3 free slots.")
end)

T.test("M6 messages", function()
	for _, code in
		{
			"PARTY_INVITE_SENT",
			"PARTY_DECLINED",
			"PARTY_EXPIRED",
			"PARTY_BUSY",
			"PARTY_NO_INVITE",
			"PARTY_JOINED",
			"PARTY_MEMBER_JOINED",
			"PARTY_LEFT",
			"PARTY_MEMBER_LEFT",
			"PARTY_KICKED",
			"PARTY_MEMBER_KICKED",
			"PARTY_NEW_LEADER",
			"PARTY_DISBANDED",
			"PARTY_FULL",
			"PARTY_NOT_LEADER",
			"PARTY_TARGET_IN_PARTY",
			"PARTY_NOT_IN",
			"PARTY_JOIN_FAILED",
		}
	do
		T.truthy(Messages.format(code) ~= code, code)
	end
	T.eq(Messages.format("PARTY_JOINED", { player = "Ann" }), "You joined Ann's party.")
	T.eq(Messages.format("PARTY_KICKED", { player = "Ann" }), "Ann removed you from the party.")
	T.eq(Messages.format("PARTY_DISBANDED"), "Your party broke up.")
end)

T.test("M7 messages", function()
	T.eq(
		Messages.format("LEDGER_COMPLETE", { player = "Ann" }),
		"Ann has claimed every Relic and is Crowned!"
	)
	T.eq(
		Messages.format("CROWNED_YOU", { title = "Crowned twice ★1" }),
		"You are Crowned twice ★1! Your name goes on the Tally Stone in Tallyport."
	)
	T.eq(
		Messages.format("ROUND_STEP", { name = "The Warden's Round", n = "3", total = "9" }),
		"The Warden's Round: 3 of 9 done."
	)
	T.eq(
		Messages.format("ROUND_COMPLETE", { name = "The Beast Tally", coin = "250" }),
		"The Beast Tally complete! +250 Coin."
	)
	T.eq(
		Messages.format("RENOUNCED", { player = "Ann" }),
		"Ann has Renounced the Ledger and starts again."
	)
end)
