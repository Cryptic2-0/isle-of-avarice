--!strict
local T = require("./harness")
local Vault = require("../src/shared/Rules/Vault")

local held: any = { claimed = { R001 = true }, free = { "R007", "R007" } }

local function add(cardId: any): any
	return { kind = "add", cardId = cardId }
end

T.test("add vaults a held card", function()
	T.eq(
		{ Vault.apply({}, held, add("R007"), true, false) },
		{ { R007 = true }, "VAULTED", "R007" }
	)
end)

T.test("remove unvaults a card", function()
	T.eq(
		{ Vault.apply({ R007 = true }, held, { kind = "remove", cardId = "R007" }, true, false) },
		{ {}, "UNVAULTED", "R007" }
	)
end)

T.test("outside the safe zone is refused", function()
	T.eq({ Vault.apply({}, held, add("R007"), false, false) }, { nil, "NOT_IN_SAFE_ZONE" })
end)

T.test("locked ledger is refused", function()
	T.eq({ Vault.apply({}, held, add("R007"), true, true) }, { nil, "LEDGER_LOCKED" })
end)

T.test("a card not held is refused", function()
	T.eq({ Vault.apply({}, held, add("R002"), true, false) }, { nil, "NOT_HELD" })
end)

T.test("an already vaulted card is refused", function()
	T.eq(
		{ Vault.apply({ R007 = true }, held, add("R007"), true, false) },
		{ nil, "ALREADY_VAULTED" }
	)
end)

T.test("removing a card that is not vaulted is refused", function()
	T.eq(
		{ Vault.apply({}, held, { kind = "remove", cardId = "R007" }, true, false) },
		{ nil, "NOT_VAULTED" }
	)
end)

T.test("unloaded data is DATA_NOT_LOADED", function()
	T.eq({ Vault.apply(nil, held, add("R007"), true, false) }, { nil, "DATA_NOT_LOADED" })
	T.eq({ Vault.apply({}, nil, add("R007"), true, false) }, { nil, "DATA_NOT_LOADED" })
end)

T.test("a full vault refuses a fourth card", function()
	local big: any = { claimed = {}, free = { "R001", "R002", "R003", "R004" } }
	local full = { R001 = true, R002 = true, R003 = true }
	T.eq(Vault.size(full), 3)
	T.eq({ Vault.apply(full, big, add("R004"), true, false) }, { nil, "VAULT_FULL" })
end)

T.test("hostile payloads are BAD_REQUEST", function()
	local bad: { any } = {
		5,
		"add",
		{},
		{ kind = "steal" },
		{ kind = "add" },
		{ kind = "add", cardId = 7 },
		{ kind = "add", cardId = string.rep("R", 17) },
		{ kind = "remove", cardId = {} },
	}
	for _, raw in bad do
		T.eq({ Vault.apply({}, held, raw, true, false) }, { nil, "BAD_REQUEST" })
	end
end)

T.test("an unknown card is UNKNOWN_CARD", function()
	T.eq({ Vault.apply({}, held, add("R999"), true, false) }, { nil, "UNKNOWN_CARD" })
end)

T.test("check order: locked before bad request before safe zone", function()
	T.eq({ Vault.apply({}, held, 5, false, true) }, { nil, "LEDGER_LOCKED" })
	T.eq({ Vault.apply({}, held, 5, false, false) }, { nil, "BAD_REQUEST" })
	T.eq({ Vault.apply({}, held, add("R999"), false, false) }, { nil, "NOT_IN_SAFE_ZONE" })
end)

T.test("apply does not mutate its inputs", function()
	local vault: any = { R001 = true }
	Vault.apply(vault, held, add("R007"), true, false)
	Vault.apply(vault, held, { kind = "remove", cardId = "R001" }, true, false)
	T.eq(vault, { R001 = true })
	T.eq(held, { claimed = { R001 = true }, free = { "R007", "R007" } })
end)

T.test("prune drops ids the ledger no longer holds", function()
	T.eq(
		Vault.prune({ R001 = true, R007 = true }, { claimed = { R001 = true }, free = {} }),
		{ R001 = true }
	)
end)

T.test("sanitize never errors and keeps only valid entries", function()
	T.eq(Vault.sanitize("junk", held), {})
	T.eq(Vault.sanitize(nil, held), {})
	T.eq(
		Vault.sanitize({ R001 = true, R002 = true, R999 = true, R007 = "yes" }, held),
		{ R001 = true }
	)
end)

T.test("sanitize keeps at most 3, lowest slot numbers first", function()
	local big: any = { claimed = {}, free = { "R001", "R002", "R003", "R004", "R005" } }
	T.eq(
		Vault.sanitize({ R005 = true, R004 = true, R003 = true, R002 = true, R001 = true }, big),
		{ R001 = true, R002 = true, R003 = true }
	)
end)
