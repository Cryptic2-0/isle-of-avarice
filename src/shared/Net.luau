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
	-- server -> all clients: (victimId: number) any fighter id (a player user id or a creature id)
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
	-- server -> one client: (offer: TrialView.OfferView)
	TrialOffer = "TrialOffer",
	-- client -> server: (trialId: string)
	TrialAccept = "TrialAccept",
	-- server -> one client: (state: TrialView.HudState?, questStep: number, rounds: RoundsRecord)
	TrialSync = "TrialSync",
	-- server -> one client: (coin: number)
	CoinSync = "CoinSync",
	-- client -> server: (request: { freeIndex: number, cardId: string, relicId: string?, targetId: number? })
	EdictUse = "EdictUse",
	-- server -> one client: (result: { title: string, lines: { string } }) what a Summons or an Audit found
	EdictResult = "EdictResult",
	-- server -> one client: (veilSeconds: number, met: { { userId: number, name: string } })
	EdictSync = "EdictSync",
	-- server -> one client: (view: Shop.View)
	ShopOpen = "ShopOpen",
	-- client -> server: (request: { kind: "pack" } | { kind: "relic", relicId: string } | { kind: "sell", freeIndex: number, cardId: string })
	ShopAction = "ShopAction",
	-- client -> server: () ask the nearest player to trade
	TradeRequest = "TradeRequest",
	-- server -> one client: (invite: { from: string, seconds: number }?) nil withdraws it
	TradeInvite = "TradeInvite",
	-- client -> server: (accept: boolean)
	TradeReply = "TradeReply",
	-- client -> server: (request: { kind: "offer", cards: { string }, coin: number } | { kind: "confirm" } | { kind: "cancel" })
	TradeAction = "TradeAction",
	-- server -> one client: (view: Trade.View?) nil closes the window
	TradeSync = "TradeSync",
	-- client -> server: () invite the nearest player
	PartyRequest = "PartyRequest",
	-- server -> one client: (invite: { from: string, seconds: number }?) nil withdraws it
	PartyInvite = "PartyInvite",
	-- client -> server: (accept: boolean)
	PartyReply = "PartyReply",
	-- client -> server: (request: { kind: "leave" } | { kind: "kick", userId: number } | { kind: "promote", userId: number })
	PartyAction = "PartyAction",
	-- server -> one client: (sync: PartyView.Sync?) nil = not in a party
	PartySync = "PartySync",
	-- server -> all clients: (ceremony: { userId: number, name: string, crowns: number })
	Ceremony = "Ceremony",
	-- server -> one client: (offer: { lines: { string }, seconds: number }?) nil closes the window
	RenounceOffer = "RenounceOffer",
	-- client -> server: (request: { kind: "confirm", word: string } | { kind: "cancel" })
	RenounceAction = "RenounceAction",
}
