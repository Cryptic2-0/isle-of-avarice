--!strict
local AbilityService = require(script.Parent.AbilityService)
local ClaimService = require(script.Parent.ClaimService)
local CombatService = require(script.Parent.CombatService)
local CreatureService = require(script.Parent.CreatureService)
local DataService = require(script.Parent.DataService)
local EdictService = require(script.Parent.EdictService)
local Fighters = require(script.Parent.Fighters)
local HazardService = require(script.Parent.HazardService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local LedgerService = require(script.Parent.LedgerService)
local PartyService = require(script.Parent.PartyService)
local PathService = require(script.Parent.PathService)
local ProtectionService = require(script.Parent.ProtectionService)
local ShopService = require(script.Parent.ShopService)
local SourceService = require(script.Parent.SourceService)
local StatusService = require(script.Parent.StatusService)
local TradeService = require(script.Parent.TradeService)
local TrialService = require(script.Parent.TrialService)
local VaultService = require(script.Parent.VaultService)
local WorldBuilder = require(script.Parent.WorldBuilder)

-- A failing step is reported but does not stop the steps after it.
local function runStep(name: string, step: () -> ())
	local ok, trace = xpcall(step, debug.traceback)
	if not ok then
		warn(`[IsleOfAvarice] {name} failed: {trace}`)
	end
end

runStep("WorldBuilder.build", WorldBuilder.build)
-- The fighter registry first: every service below looks players and posts up by id.
runStep("Fighters.start", Fighters.start)
runStep("LedgerService.start", LedgerService.start)
runStep("SourceService.start", SourceService.start)
runStep("VaultService.start", VaultService.start)
runStep("ProtectionService.start", ProtectionService.start)
-- StatusService never requires CombatService, and CombatService never requires PathService
-- (PathService -> ClaimService -> CombatService): the functions are passed in here instead.
runStep("StatusService.start", function()
	StatusService.start(CombatService.damage)
end)
runStep("CombatService.start", function()
	CombatService.start(PathService.get, PathService.grant)
end)
runStep("AbilityService.start", AbilityService.start)
runStep("HazardService.start", HazardService.start)
runStep("ClaimService.start", ClaimService.start)
runStep("PathService.start", PathService.start)
runStep("CreatureService.start", CreatureService.start)
runStep("TrialService.start", TrialService.start)
runStep("EdictService.start", EdictService.start)
runStep("ShopService.start", ShopService.start)
runStep("TradeService.start", TradeService.start)
-- After CombatService: a leaver's combat-log credit runs before they leave their party.
runStep("PartyService.start", PartyService.start)
runStep("LeaderboardService.start", LeaderboardService.start)
-- Data last, so no player loads before the remotes and callbacks exist.
runStep("DataService.start", DataService.start)

print("[IsleOfAvarice] server started")
