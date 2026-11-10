--!strict
local DataService = require(script.Parent.DataService)
local LedgerService = require(script.Parent.LedgerService)
local SourceService = require(script.Parent.SourceService)
local WorldBuilder = require(script.Parent.WorldBuilder)

WorldBuilder.build()
LedgerService.start()
SourceService.start()
-- Data last, so no player loads before the remotes and callbacks exist.
DataService.start()

print("[IsleOfAvarice] server started")
