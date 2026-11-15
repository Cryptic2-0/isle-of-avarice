--!strict
-- Pays one player a reward: Coin, then Path XP, then Relics. Creature defeats, passed trials
-- and the quest all pay through here, so they cannot drift apart. SourceService.award tells
-- the player what became of each Relic (gained, sealed, lost).
local PathService = require(script.Parent.PathService)
local SourceService = require(script.Parent.SourceService)

export type Reward = {
	coin: number,
	xp: number,
	-- The Path the XP goes to; "" or nil pays no XP.
	path: string?,
	relics: { string }?,
}

local Payout = {}

function Payout.give(player: Player, reward: Reward)
	if reward.coin > 0 then
		SourceService.addCoin(player, reward.coin)
	end
	local path = reward.path
	if reward.xp > 0 and path ~= nil and path ~= "" then
		PathService.grant(player, path, reward.xp)
	end
	local relics = reward.relics
	if relics ~= nil then
		for _, relicId in relics do
			SourceService.award(player, relicId)
		end
	end
end

-- The player's Calling, or "" before they have one or before their data has loaded.
function Payout.calling(player: Player): string
	local progress = PathService.get(player)
	return if progress ~= nil then progress.calling else ""
end

return Payout
