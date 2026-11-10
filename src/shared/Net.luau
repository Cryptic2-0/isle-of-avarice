--!strict
-- Names of the remotes the server creates under ReplicatedStorage.
return {
	FOLDER = "Remotes",
	-- server -> one client: (ledger: Ledger)
	LedgerSync = "LedgerSync",
	-- client -> server: (request: table)
	LedgerAction = "LedgerAction",
	-- client -> server: () ask for the current Ledger (the first sync may have been missed)
	LedgerRequest = "LedgerRequest",
	-- server -> client(s): (code: string, args: { [string]: string }?)
	Notify = "Notify",
}
