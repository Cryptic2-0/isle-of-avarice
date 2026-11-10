--!strict
local DataService = require(script.Parent.DataService)
local WorldBuilder = require(script.Parent.WorldBuilder)

WorldBuilder.build()
DataService.start()

print("[IsleOfAvarice] server started")
