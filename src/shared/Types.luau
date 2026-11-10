--!strict
export type CardId = string
export type Tier = "Copper" | "Silver" | "Gold" | "Platinum" | "Crown"
export type Relic = { id: CardId, slot: number, name: string, tier: Tier, description: string }
export type Ledger = { claimed: { [CardId]: boolean }, free: { CardId } }
export type Vec3 = { x: number, y: number, z: number }
export type Cache = { id: string, relicId: CardId, position: Vec3 }
export type PlayerData = { schemaVersion: number, ledger: Ledger, coin: number }

return {}
