--!strict
local DataService = require(script.Parent.DataService)
local LedgerService = require(script.Parent.LedgerService)
local SourceService = require(script.Parent.SourceService)
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
-- Data last, so no player loads before the remotes and callbacks exist.
runStep("DataService.start", DataService.start)

print("[IsleOfAvarice] server started")
