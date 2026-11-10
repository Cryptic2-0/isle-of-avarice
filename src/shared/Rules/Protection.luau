--!strict
local World = require("../Catalog/World")
local Combat = require("./Combat")
local Types = require("../Types")

type Vec3 = Types.Vec3
type Ledger = Types.Ledger

export type Status = {
	inSafeZone: boolean,
	newShield: boolean,
	respawnShieldUntil: number,
	markedUntil: number,
}
-- key: killerId .. ":" .. victimId -> time of last claim
export type ClaimHistory = { [string]: number }

local Protection = {}

Protection.SHIELD_RELICS = 3
Protection.RESPAWN_SHIELD_SECONDS = 60
Protection.MARKED_SECONDS = 300
Protection.RETALIATE_SECONDS = 30
Protection.CLAIM_COOLDOWN_SECONDS = 3600

local function claimKey(killerId: number, victimId: number): string
	return tostring(killerId) .. ":" .. tostring(victimId)
end

function Protection.inSafeZone(position: Vec3): boolean
	return math.sqrt(position.x * position.x + position.z * position.z) <= World.townRadius
end

-- Claimed Relics plus spare ones.
function Protection.shouldEndShield(ledger: Ledger): boolean
	local count = #ledger.free
	for _ in ledger.claimed do
		count += 1
	end
	return count >= Protection.SHIELD_RELICS
end

function Protection.isMarked(status: Status, now: number): boolean
	return now < status.markedUntil
end

function Protection.isShielded(status: Status, now: number): boolean
	return status.newShield or now < status.respawnShieldUntil
end

function Protection.canDamage(attacker: Status, victim: Status, now: number): (boolean, string?)
	if attacker.newShield then
		return false, "SHIELD_SELF"
	end
	if Protection.isShielded(victim, now) then
		return false, "TARGET_SHIELDED"
	end
	local victimMarked = Protection.isMarked(victim, now)
	if victim.inSafeZone and not victimMarked then
		return false, "SAFE_ZONE"
	end
	if attacker.inSafeZone and not victimMarked then
		return false, "SAFE_ZONE"
	end
	return true, nil
end

-- True when this hit starts a fight: the victim is not Marked and did not hit the attacker recently.
function Protection.isAggressor(
	log: Combat.HitLog,
	attackerId: number,
	victimId: number,
	victimMarked: boolean,
	now: number
): boolean
	if victimMarked then
		return false
	end
	local entry = log[tostring(attackerId)]
	if
		entry ~= nil
		and entry.attackerId == victimId
		and now - entry.at <= Protection.RETALIATE_SECONDS
	then
		return false
	end
	return true
end

function Protection.canClaim(
	history: ClaimHistory,
	killerId: number,
	victimId: number,
	now: number
): boolean
	local last = history[claimKey(killerId, victimId)]
	return last == nil or now - last >= Protection.CLAIM_COOLDOWN_SECONDS
end

function Protection.recordClaim(
	history: ClaimHistory,
	killerId: number,
	victimId: number,
	now: number
): ClaimHistory
	local newHistory = table.clone(history)
	newHistory[claimKey(killerId, victimId)] = now
	return newHistory
end

return Protection
