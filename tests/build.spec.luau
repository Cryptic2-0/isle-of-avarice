local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local T = require("./harness")

T.test("built place contains the expected scripts", function()
	local game = roblox.deserializePlace(fs.readFile("build/IsleOfAvarice.rbxlx"))
	T.eq(game:GetService("ServerScriptService").Server.Main.ClassName, "Script")
	T.eq(game:GetService("ReplicatedStorage").Shared.Types.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.WorldBuilder.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.DataService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.LedgerService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.SourceService.ClassName, "ModuleScript")
	T.eq(game:GetService("ReplicatedStorage").Shared.Net.ClassName, "ModuleScript")
	T.eq(
		game:GetService("ServerScriptService").Server.Vendor.ProfileStore.ClassName,
		"ModuleScript"
	)
	T.eq(game:GetService("ReplicatedStorage").Shared.Catalog.World.ClassName, "ModuleScript")
	T.eq(game:GetService("ReplicatedStorage").Shared.Rules.LedgerView.ClassName, "ModuleScript")
	T.eq(game:GetService("StarterPlayer").StarterPlayerScripts.Client.LedgerUI.ClassName, "ModuleScript")
	T.eq(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Toast.ClassName, "ModuleScript")
	T.eq(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Main.ClassName, "LocalScript")
end)
