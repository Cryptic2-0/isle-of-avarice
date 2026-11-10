--!strict
local T = require("./harness")
local Net = require("../src/shared/Net")

T.test("remote names are fixed", function()
	T.eq(Net.FOLDER, "Remotes")
	T.eq(Net.LedgerSync, "LedgerSync")
	T.eq(Net.LedgerAction, "LedgerAction")
	T.eq(Net.LedgerRequest, "LedgerRequest")
	T.eq(Net.Notify, "Notify")
end)
