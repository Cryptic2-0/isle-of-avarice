--!strict
-- The two rounds (Warden's Round, Beast Tally): which steps are done this round. Each step
-- counts once; finishing the last one completes the round and empties its list. Pure.
local Trials = require("../Catalog/Trials")
local Types = require("../Types")

type RoundsRecord = Types.RoundsRecord

local Rounds = {}

function Rounds.new(): RoundsRecord
	local record: RoundsRecord = {}
	for _, round in Trials.rounds do
		record[round.id] = {}
	end
	return record
end

function Rounds.sanitize(raw: any): RoundsRecord
	local out = Rounds.new()
	if type(raw) ~= "table" then
		return out
	end
	for _, round in Trials.rounds do
		local saved = raw[round.id]
		if type(saved) == "table" then
			local isStep: { [string]: boolean } = {}
			for _, step in round.steps do
				isStep[step] = true
			end
			local seen: { [string]: boolean } = {}
			local kept: { string } = {}
			for _, entry in saved do
				if type(entry) == "string" and isStep[entry] and not seen[entry] then
					seen[entry] = true
					table.insert(kept, entry)
				end
			end
			if #kept < #round.steps then
				out[round.id] = kept
			end
		end
	end
	return out
end

-- Returns the new record and "ROUND_STEP" or "ROUND_COMPLETE"; the same record and "" when
-- nothing counts (unknown round, step not in it, step already done).
function Rounds.advance(
	record: RoundsRecord,
	roundId: string,
	stepId: string
): (RoundsRecord, string)
	local round = Trials.roundById[roundId]
	if round == nil or not table.find(round.steps, stepId) then
		return record, ""
	end
	local done = record[roundId] or {}
	if table.find(done, stepId) then
		return record, ""
	end
	local out = table.clone(record)
	local list = table.clone(done)
	table.insert(list, stepId)
	if #list >= #round.steps then
		out[roundId] = {}
		return out, "ROUND_COMPLETE"
	end
	out[roundId] = list
	return out, "ROUND_STEP"
end

function Rounds.line(raw: any): string
	local record = Rounds.sanitize(raw)
	local parts: { string } = {}
	for _, round in Trials.rounds do
		table.insert(parts, `{round.short} {#record[round.id]} / {#round.steps}`)
	end
	return table.concat(parts, ", ")
end

return Rounds
