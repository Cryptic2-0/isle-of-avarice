--!strict
export type CardId = string
export type Tier = "Copper" | "Silver" | "Gold" | "Platinum" | "Crown"
export type Relic = { id: CardId, slot: number, name: string, tier: Tier, description: string }
export type Ledger = { claimed: { [CardId]: boolean }, free: { CardId } }
export type Vec3 = { x: number, y: number, z: number }
export type Cache = { id: string, relicId: CardId, position: Vec3, hold: number? }
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
export type RegionId =
	"Tallyport"
	| "CountingFields"
	| "Thornwood"
	| "SquallSteps"
	| "CinderFlats"
	| "DrownedFen"
	| "ReckoningRock"
	| "HushGardens"
	| "BastionReach"
export type Region = {
	id: RegionId,
	name: string,
	hint: string,
	bearing: number?, -- wild regions only
	ground: string, -- a look name
	fog: { r: number, g: number, b: number, start: number, finish: number },
}
-- Every field is always present; unused ones are 0 or "".
export type Shape = {
	kind: "circle" | "rect" | "region",
	x: number,
	z: number, -- centre; 0 for "region"
	radius: number, -- circle radius; for "region" the least distance from the island centre
	bearing: number,
	halfAlong: number,
	halfAcross: number, -- rect only
	region: string, -- "region" only
}
export type Cycle = { period: number, warn: number, active: number, offset: number }
export type Hazard = {
	id: string,
	region: RegionId,
	name: string,
	look: string,
	shape: Shape,
	holes: { Shape }?,
	cycle: Cycle?,
	dps: number?,
	damage: number?,
	heal: number?,
	slow: number?, -- speed multiplier, 0.5 = half speed
	push: { x: number, z: number }?, -- world velocity, studs per second
	markerY: number?, -- height of the visual marker; ground when nil
}
-- x, y, z is the centre. sx is the extent across the yaw bearing, sy the height, sz the
-- extent along it. A cylinder stands upright: sx = sz = diameter.
export type Feature = {
	look: string,
	shape: "block" | "cylinder",
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	yaw: number,
	solid: boolean,
	text: string?,
}
export type SiteCache = { relicId: CardId, x: number, y: number, z: number, hold: number? }
export type Site = {
	region: RegionId,
	hazards: { Hazard },
	features: { Feature },
	prize: SiteCache?,
	keepOut: { Shape },
}

return {}
