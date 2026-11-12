--!strict
local AbilityService = require(script.Parent.AbilityService)
local ClaimService = require(script.Parent.ClaimService)
local CombatService = require(script.Parent.CombatService)
local DataService = require(script.Parent.DataService)
local HazardService = require(script.Parent.HazardService)
local LedgerService = require(script.Parent.LedgerService)
local PathService = require(script.Parent.PathService)
local ProtectionService = require(script.Parent.ProtectionService)
local SourceService = require(script.Parent.SourceService)
local StatusService = require(script.Parent.StatusService)
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
runStep("LedgerService.start", LedgerService.start)
runStep("SourceService.start", SourceService.start)
runStep("VaultService.start", VaultService.start)
runStep("ProtectionService.start", ProtectionService.start)
-- StatusService never requires CombatService, and CombatService never requires PathService
-- (PathService -> ClaimService -> CombatService): the functions are passed in here instead.
runStep("StatusService.start", function()
	StatusService.start(CombatService.damage, CombatService.hitPost)
end)
runStep("CombatService.start", function()
	CombatService.start(PathService.get, PathService.grant)
end)
runStep("AbilityService.start", AbilityService.start)
runStep("HazardService.start", HazardService.start)
runStep("ClaimService.start", ClaimService.start)
runStep("PathService.start", PathService.start)
-- Data last, so no player loads before the remotes and callbacks exist.
runStep("DataService.start", DataService.start)

print("[IsleOfAvarice] server started")
