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
}
