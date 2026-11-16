--!strict
-- The rules of the five Edicts (spec 3.13): checking a "use" request, who a Summons lists,
-- who an Audit looks at and what it shows, the Veil, where a Passage arrives, when travel is
-- refused, and what a defeat destroys. Pure: the server gathers the facts and applies results.
local Cards = require("../Catalog/Cards")
local Edicts = require("../Catalog/Edicts")
local Ledger = require("./Ledger")
local Relics = require("../Catalog/Relics")
local Types = require("../Types")

type Ledger = Types.Ledger
type Vec3 = Types.Vec3

export type Use = {
	freeIndex: number,
	cardId: string,
	key: string,
	relicId: string?,
	targetId: number?,
}
export type TravelState = { marked: boolean, inTrial: boolean, lastFightAt: number? }
export type Person = { userId: number, name: string, ledger: Ledger, veiled: boolean }
export type Body = { userId: number, position: Vec3 }
-- What the result window shows.
export type Result = { title: string, lines: { string } }

local MAX_CARD_ID_LENGTH = 16
local RING_SPOTS = 8

local EdictRules = {}

EdictRules.VEIL_SECONDS = 600
EdictRules.AUDIT_RANGE = 20
EdictRules.MEET_RANGE = 30
EdictRules.PASSAGE_DISTANCE = 8
EdictRules.COMBAT_SECONDS = 30

local function isWhole(n: any): boolean
	return type(n) == "number" and n > -math.huge and n < math.huge and n == math.floor(n)
end

-- Checks a raw client request to use the Edict on one free-slot row. The request carries
-- the card the player saw there; if the row has shifted (a double click) it is BAD_INDEX.
-- Summons must name a Relic and Passage a player; anything an Edict does not need is dropped.
-- Success: the request, "OK". Never errors on hostile input.
function EdictRules.parseUse(ledger: Ledger?, raw: any): (Use?, string)
	if ledger == nil then
		return nil, "DATA_NOT_LOADED"
	end
	if type(raw) ~= "table" then
		return nil, "BAD_REQUEST"
	end
	local freeIndex, cardId = raw.freeIndex, raw.cardId
	if type(freeIndex) ~= "number" then
		return nil, "BAD_REQUEST"
	end
	if type(cardId) ~= "string" or #cardId > MAX_CARD_ID_LENGTH then
		return nil, "BAD_REQUEST"
	end
	if not isWhole(freeIndex) or ledger.free[freeIndex] ~= cardId then
		return nil, "BAD_INDEX"
	end
	local edict = Edicts.byId[cardId]
	if edict == nil then
		return nil, "BAD_REQUEST"
	end
	local use: Use = { freeIndex = freeIndex, cardId = cardId, key = edict.key }
	if edict.needs == "relic" then
		if not Cards.isRelic(raw.relicId) then
			return nil, "BAD_REQUEST"
		end
		use.relicId = raw.relicId
	elseif edict.needs == "player" then
		if not isWhole(raw.targetId) then
			return nil, "BAD_REQUEST"
		end
		use.targetId = raw.targetId
	end
	return use, "OK"
end

-- Passage and Homecoming: refused while Marked, within 30 seconds of dealing or taking
-- player damage, and during a trial. A clock that is not a number counts as "in combat".
function EdictRules.canTravel(state: TravelState, now: number): (boolean, string?)
	if state.marked then
		return false, "EDICT_MARKED"
	end
	local lastFightAt = state.lastFightAt
	if lastFightAt ~= nil and not (now - lastFightAt >= EdictRules.COMBAT_SECONDS) then
		return false, "EDICT_IN_COMBAT"
	end
	if state.inTrial then
		return false, "EDICT_IN_TRIAL"
	end
	return true, nil
end

-- Names of the other players who hold the Relic, claimed or spare, in name order. Veiled
-- players are left out.
function EdictRules.holders(people: { Person }, relicId: string, askerId: number): { string }
	local names: { string } = {}
	for _, person in people do
		if
			person.userId ~= askerId
			and not person.veiled
			and Ledger.count(person.ledger, relicId) > 0
		then
			table.insert(names, person.name)
		end
	end
	table.sort(names)
	return names
end

function EdictRules.summonsResult(relicId: string, names: { string }): Result
	local lines: { string } = {}
	if #names == 0 then
		-- Says nothing about whether anyone is veiled.
		table.insert(lines, "Nobody else here holds it, or they are veiled.")
	else
		table.insert(lines, "Held on this server by:")
		for _, name in names do
			table.insert(lines, name)
		end
	end
	return { title = "Summons: " .. Cards.name(relicId), lines = lines }
end

local function distance(a: Vec3, b: Vec3): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

-- True when the two points are within `range` of each other. A NaN position is not near.
function EdictRules.near(a: Vec3, b: Vec3, range: number): boolean
	return distance(a, b) <= range
end

-- The nearest other player within the Audit's range, or nil. Ties go to the lower id.
function EdictRules.auditTarget(asker: Body, others: { Body }): number?
	local bestId: number? = nil
	local best = math.huge
	for _, other in others do
		if other.userId == asker.userId then
			continue
		end
		local gap = distance(asker.position, other.position)
		if not (gap <= EdictRules.AUDIT_RANGE) then
			continue
		end
		if gap < best or (gap == best and bestId ~= nil and other.userId < bestId) then
			best = gap
			bestId = other.userId
		end
	end
	return bestId
end

-- What an Audit shows: claimed Relics in slot order (and which are Vaulted), then the
-- free-slot cards in the order first held, with a count when there are several.
function EdictRules.auditResult(name: string, ledger: Ledger, vault: Types.Vault): Result
	local lines: { string } = {}
	table.insert(lines, `Claimed: {Ledger.claimedCount(ledger)} of {Relics.count}`)
	for _, relic in Relics.list do
		if ledger.claimed[relic.id] then
			local line = string.format("%03d %s (%s)", relic.slot, relic.name, relic.tier)
			if vault[relic.id] then
				line ..= ", Vaulted"
			end
			table.insert(lines, line)
		end
	end
	table.insert(lines, `Free slots: {#ledger.free} of {Ledger.FREE_SLOTS}`)
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, id in ledger.free do
		if counts[id] == nil then
			table.insert(order, id)
		end
		counts[id] = (counts[id] or 0) + 1
	end
	for _, id in order do
		local cardName = Cards.name(id)
		table.insert(lines, if counts[id] > 1 then `{cardName} x{counts[id]}` else cardName)
	end
	return { title = "Audit: " .. name, lines = lines }
end

function EdictRules.veiledResult(name: string): Result
	return { title = "Audit: " .. name, lines = { "Their Ledger is veiled." } }
end

-- Written so a NaN time or a NaN end both read as "not veiled".
function EdictRules.isVeiled(veilUntil: number?, now: number): boolean
	return veilUntil ~= nil and now < veilUntil
end

-- Seconds of Veil left, 0 when none.
function EdictRules.veilSeconds(veilUntil: number?, now: number): number
	if veilUntil == nil or not (now < veilUntil) then
		return 0
	end
	return veilUntil - now
end

-- Where a Passage sets the traveller down: the first of eight spots on a ring around the
-- target (starting at +x) for which `isClear(x, z)` is true, at the target's height. With no
-- clear spot, the target's own position.
function EdictRules.arrival(target: Vec3, isClear: (x: number, z: number) -> boolean): Vec3
	for i = 0, RING_SPOTS - 1 do
		local angle = i / RING_SPOTS * 2 * math.pi
		local x = target.x + math.cos(angle) * EdictRules.PASSAGE_DISTANCE
		local z = target.z + math.sin(angle) * EdictRules.PASSAGE_DISTANCE
		if isClear(x, z) then
			return { x = x, y = target.y, z = z }
		end
	end
	return target
end

-- A defeat destroys one third of the Edicts held, rounded down, picked at random (one roll
-- per card lost). Relics are never touched. Returns the new Ledger and the lost cards.
function EdictRules.defeatLoss(ledger: Ledger, rng: () -> number): (Ledger, { string })
	local free = table.clone(ledger.free)
	local lost: { string } = {}
	for _ = 1, Ledger.edictCount(ledger) // 3 do
		local positions: { number } = {}
		for index, id in free do
			if Cards.isEdict(id) then
				table.insert(positions, index)
			end
		end
		if #positions == 0 then
			break
		end
		local roll = rng()
		-- A roll outside 0..1, or one that is not a number, still picks a card.
		if not (roll >= 0) then
			roll = 0
		end
		local pick = math.clamp(math.floor(roll * #positions) + 1, 1, #positions)
		table.insert(lost, table.remove(free, positions[pick]) :: string)
	end
	return { claimed = table.clone(ledger.claimed), free = free }, lost
end

return EdictRules
