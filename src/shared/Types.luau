--!strict
export type CardId = string
export type Tier = "Copper" | "Silver" | "Gold" | "Platinum" | "Crown"
export type Relic = { id: CardId, slot: number, name: string, tier: Tier, description: string }
export type Ledger = { claimed: { [CardId]: boolean }, free: { CardId } }
export type Vec3 = { x: number, y: number, z: number }
export type Cache = { id: string, relicId: CardId, position: Vec3 }
export type Vault = { [CardId]: boolean }
export type PathId = "Fang" | "Gale" | "Ember" | "Mire" | "Mend" | "Bulwark"
export type PathProgress = {
	calling: string, -- a PathId, or "" before the first choice
	xp: { [string]: number }, -- one entry per PathId
	loadout: { string }, -- exactly 4 entries; "" = empty slot
	callingChanges: number,
	callingChangedAt: number, -- os.time() of the last change, 0 if never
}
export type Ability = {
	id: string,
	name: string,
	path: PathId,
	unlockLevel: number,
	cooldown: number,
	description: string,
	kind: "melee" | "shot" | "dash" | "zone" | "self" | "burst",
	range: number?,
	damage: number?,
	hits: number?,
	interval: number?,
	shots: number?,
	spread: number?, -- shot fan: count, total angle in degrees
	distance: number?, -- dash length
	executeBelow: number?,
	executeDamage: number?,
	burn: { dps: number, duration: number }?,
	root: number?,
	slow: { factor: number, duration: number }?, -- factor = speed multiplier (0.7 = 30% slower)
	pull: number?,
	knockback: number?,
	taunt: number?,
	zone: { radius: number, duration: number, dps: number, slow: number?, ahead: number }?,
	radius: number?, -- burst radius
	heal: number?,
	healOnHit: boolean?,
	cleanse: boolean?,
	shield: { amount: number, duration: number }?,
	immune: number?,
	empower: { bonus: number, duration: number }?,
	reduction: { factor: number, duration: number }?, -- factor = damage multiplier (0.6 = 40% less)
	reflect: { factor: number, duration: number }?,
	allyRadius: number?,
}
export type PlayerData = {
	schemaVersion: number,
	ledger: Ledger,
	coin: number,
	vault: Vault,
	shieldEnded: boolean,
	paths: PathProgress,
}

return {}
