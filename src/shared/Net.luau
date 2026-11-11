--!strict
-- Names of the remotes the server creates under ReplicatedStorage.
return {
	FOLDER = "Remotes",
	-- server -> one client: (ledger: Ledger, vault: Vault)
	LedgerSync = "LedgerSync",
	-- client -> server: (request: table)
	LedgerAction = "LedgerAction",
	-- client -> server: () ask for the current Ledger (the first sync may have been missed)
	LedgerRequest = "LedgerRequest",
	-- server -> client(s): (code: string, args: { [string]: string }?)
	Notify = "Notify",
	-- client -> server: (request: table)
	VaultAction = "VaultAction",
	-- server -> one client: (status: { newShield: boolean, respawnShieldSeconds: number, markedSeconds: number })
	StatusSync = "StatusSync",
	-- client -> server: ()
	ShieldDrop = "ShieldDrop",
	-- client -> server: ()
	Strike = "Strike",
	-- server -> all clients: (victimUserId: number)
	HitFx = "HitFx",
	-- server -> one client: (payload: { victimName: string, claim: Claim, secondsLeft: number }?), nil closes the screen
	ClaimUpdate = "ClaimUpdate",
	-- client -> server: (slot: number)
	ClaimPick = "ClaimPick",
	-- server -> one client: (progress: PathProgress, coin: number, now: number) now = server os.time()
	PathSync = "PathSync",
	-- client -> server: (pathId: string)
	PickCalling = "PickCalling",
	-- client -> server: (pathId: string)
	ChangeCalling = "ChangeCalling",
	-- client -> server: (request: { slot: number, abilityId: string })
	LoadoutAction = "LoadoutAction",
	-- client -> server: (slot: number)
	CastAbility = "CastAbility",
	-- server -> one client: (slot: number, seconds: number)
	AbilityCooldown = "AbilityCooldown",
}
