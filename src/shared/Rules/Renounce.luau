--!strict
-- Renounce (spec 3.15): when it is allowed, the two-step offer and confirm, and what it
-- returns and keeps. Pure: the server gathers the facts and applies the result.
local Crown = require("./Crown")
local EdictRules = require("./EdictRules")
local Relics = require("../Catalog/Relics")
local Rounds = require("./Rounds")
local Types = require("../Types")

type CrownRecord = Types.CrownRecord
type Ledger = Types.Ledger
type RoundsRecord = Types.RoundsRecord
type TrialRecord = Types.TrialRecord
type Vault = Types.Vault

export type State = {
	loaded: boolean,
	complete: boolean,
	crowns: number,
	stars: number,
	alive: boolean,
	locked: boolean,
	claiming: boolean,
	trading: boolean,
	inTrial: boolean,
	inTown: boolean,
	marked: boolean,
	lastFightAt: number?,
}
export type Offer = { expiresAt: number }
export type Request = { kind: string, word: string? }
export type Parts = {
	ledger: Ledger,
	vault: Vault,
	crown: CrownRecord,
	trials: TrialRecord,
	rounds: RoundsRecord,
}

local Renounce = {}

Renounce.OFFER_SECONDS = 60
Renounce.FIGHT_SECONDS = 30
Renounce.WORD = "RENOUNCE"
Renounce.MAX_WORD_LENGTH = 32

-- The first refusal in spec order, or true, "RENOUNCE_OFFER". The Marked and fight refusals
-- are EdictRules.canDeal (its 30 s window equals FIGHT_SECONDS).
function Renounce.check(state: State, now: number): (boolean, string)
	if not state.loaded then
		return false, "DATA_NOT_LOADED"
	end
	if not state.complete or not (state.crowns > state.stars) then
		return false, "RENOUNCE_NOT_READY"
	end
	if not state.alive then
		return false, "EDICT_NOT_NOW"
	end
	if state.locked then
		return false, "LEDGER_LOCKED"
	end
	if state.claiming then
		return false, "RENOUNCE_CLAIMING"
	end
	if state.trading then
		return false, "RENOUNCE_TRADING"
	end
	if state.inTrial then
		return false, "EDICT_IN_TRIAL"
	end
	if not state.inTown then
		return false, "RENOUNCE_NOT_IN_TOWN"
	end
	local ok, code =
		EdictRules.canDeal({ marked = state.marked, lastFightAt = state.lastFightAt }, now)
	if not ok then
		return false, code or "EDICT_IN_COMBAT"
	end
	return true, "RENOUNCE_OFFER"
end

function Renounce.offer(now: number): Offer
	return { expiresAt = now + Renounce.OFFER_SECONDS }
end

function Renounce.parse(raw: any): (Request?, string)
	if type(raw) ~= "table" then
		return nil, "BAD_REQUEST"
	end
	if raw.kind == "cancel" then
		return { kind = "cancel" }, "OK"
	end
	if raw.kind == "confirm" then
		local word = raw.word
		if type(word) ~= "string" or #word > Renounce.MAX_WORD_LENGTH then
			word = ""
		end
		return { kind = "confirm", word = word }, "OK"
	end
	return nil, "BAD_REQUEST"
end

function Renounce.wordMatches(word: any): boolean
	if type(word) ~= "string" then
		return false
	end
	-- The same cap as parse, so a long string is not scanned.
	if #word > Renounce.MAX_WORD_LENGTH then
		return false
	end
	-- Spec 3.15: any case, and spaces anywhere are ignored.
	local squeezed = string.gsub(word, "%s", "")
	return string.upper(squeezed) == Renounce.WORD
end

function Renounce.confirm(offer: Offer?, word: string, now: number): (boolean, string)
	if offer == nil then
		return false, "RENOUNCE_NO_OFFER"
	end
	if not (now < offer.expiresAt) then
		return false, "RENOUNCE_EXPIRED"
	end
	if not Renounce.wordMatches(word) then
		return false, "RENOUNCE_WORD"
	end
	return true, "OK"
end

-- Every card goes back (claimed, spare and Edicts alike), the Vault empties, a star is
-- earned. Cooldowns and the other Crown fields are kept; the Unpaid Debt and the rounds restart.
function Renounce.apply(parts: Parts): Parts
	local crown = table.clone(parts.crown)
	crown.stars += 1
	local trials = table.clone(parts.trials)
	trials.cooldowns = table.clone(parts.trials.cooldowns)
	trials.questStep = 0
	return {
		ledger = { claimed = {}, free = {} },
		vault = {},
		crown = crown,
		trials = trials,
		rounds = Rounds.new(),
	}
end

function Renounce.offerLines(record: CrownRecord): { string }
	return {
		`Every card in your Ledger goes back to the island: all {Relics.count} claimed Relics, your spare Relics and your Edicts.`,
		"Your Vault empties. The Unpaid Debt, the Warden's Round and the Beast Tally start again.",
		"You keep your Coin, your Paths and abilities, your trial cooldowns and your Crowns.",
		`You earn a star and will show as "{Crown.title(record.crowns, record.stars + 1)}".`,
		"This cannot be undone.",
	}
end

return Renounce
