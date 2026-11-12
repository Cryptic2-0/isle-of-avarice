local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local T = require("./harness")

T.test("built place sets the fall-destroy height", function()
	local game = roblox.deserializePlace(fs.readFile("build/IsleOfAvarice.rbxlx"))
	T.eq(game:GetService("Workspace").FallenPartsDestroyHeight, -60)
end)

T.test("built place contains the expected scripts", function()
	local game = roblox.deserializePlace(fs.readFile("build/IsleOfAvarice.rbxlx"))
	T.eq(game:GetService("ServerScriptService").Server.Main.ClassName, "Script")
	T.eq(game:GetService("ReplicatedStorage").Shared.Types.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.WorldBuilder.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.LookPainter.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.TerrainBuilder.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.SiteBuilder.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.DataService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.LedgerService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.SourceService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.VaultService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.ProtectionService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.CombatService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.ClaimService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.PathService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.StatusService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.AbilityService.ClassName, "ModuleScript")
	T.eq(game:GetService("ServerScriptService").Server.HazardService.ClassName, "ModuleScript")
	T.eq(game:GetService("ReplicatedStorage").Shared.Rules.Geography.ClassName, "ModuleScript")
	T.eq(game:GetService("ReplicatedStorage").Shared.Rules.Hazards.ClassName, "ModuleScript")
	T.eq(game:GetService("ReplicatedStorage").Shared.Rules.PlaceView.ClassName, "ModuleScript")
	T.eq(game:GetService("ReplicatedStorage").Shared.Catalog.Regions.ClassName, "ModuleScript")
	T.eq(game:GetService("ReplicatedStorage").Shared.Catalog.Looks.ClassName, "ModuleScript")
	T.eq(game:GetService("ReplicatedStorage").Shared.Catalog.Sites.ClassName, "ModuleScript")
	T.eq(
		game:GetService("ReplicatedStorage").Shared.Catalog.SiteData.Thornwood.ClassName,
		"ModuleScript"
	)
	T.eq(game:GetService("ReplicatedStorage").Shared.Net.ClassName, "ModuleScript")
	T.eq(
		game:GetService("ServerScriptService").Server.Vendor.ProfileStore.ClassName,
		"ModuleScript"
	)
	T.eq(game:GetService("ReplicatedStorage").Shared.Catalog.World.ClassName, "ModuleScript")
	T.eq(game:GetService("ReplicatedStorage").Shared.Rules.LedgerView.ClassName, "ModuleScript")
	T.eq(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.LedgerUI.ClassName,
		"ModuleScript"
	)
	T.eq(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.Toast.ClassName,
		"ModuleScript"
	)
	T.eq(game:GetService("ReplicatedStorage").Shared.Rules.StatusView.ClassName, "ModuleScript")
	T.eq(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.StatusHUD.ClassName,
		"ModuleScript"
	)
	T.eq(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.CombatController.ClassName,
		"ModuleScript"
	)
	T.eq(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.ClaimUI.ClassName,
		"ModuleScript"
	)
	T.eq(game:GetService("ReplicatedStorage").Shared.Rules.PathView.ClassName, "ModuleScript")
	T.eq(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.PathUI.ClassName,
		"ModuleScript"
	)
	T.eq(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.AbilityBar.ClassName,
		"ModuleScript"
	)
	T.eq(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.HazardController.ClassName,
		"ModuleScript"
	)
	T.eq(
		game:GetService("StarterPlayer").StarterPlayerScripts.Client.Atmosphere.ClassName,
		"ModuleScript"
	)
	T.eq(game:GetService("StarterPlayer").StarterPlayerScripts.Client.Main.ClassName, "LocalScript")
end)
