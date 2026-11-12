--!strict
-- Applies the island's hazards to every player four times a second. The server decides all
-- of it: damage, healing, slow and drowning. The gust push is the one client-applied effect
-- and is not handled here. Hazard cycles run on workspace:GetServerTimeNow().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effects = require(ReplicatedStorage.Shared.Rules.Effects)
local Geography = require(ReplicatedStorage.Shared.Rules.Geography)
local Hazards = require(ReplicatedStorage.Shared.Rules.Hazards)
local Sites = require(ReplicatedStorage.Shared.Catalog.Sites)
local CombatService = require(script.Parent.CombatService)
local StatusService = require(script.Parent.StatusService)

-- A long stall must not turn into one huge damage or healing step.
local MAX_ELAPSED_SECONDS = 1

local HazardService = {}

-- Real time gathered since the last tick.
local accumulated = 0
-- The last burst cycle that hit each player, by hazard id, so a burst lands once per cycle.
local lastBurst: { [Player]: { [string]: number } } = {}

-- The Humanoid and HumanoidRootPart of a living character, or nil.
local function living(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

-- One player's share of a tick: drowning, damage, bursts, healing, then slow.
local function tickPlayer(player: Player, now: number, elapsed: number)
	local humanoid, root = living(player)
	if humanoid == nil or root == nil then
		return
	end
	local position = root.Position
	if position.Y < Geography.DROWN_Y then
		CombatService.environmentDefeat(player)
		return
	end

	local sample = Hazards.sample(Sites.hazards, position.X, position.Z, now)
	if sample.dps > 0 then
		CombatService.environmentDamage(player, sample.dps * elapsed)
	end

	if #sample.bursts > 0 then
		local seen = lastBurst[player]
		if seen == nil then
			seen = {}
			lastBurst[player] = seen
		end
		for _, burst in sample.bursts do
			if seen[burst.id] ~= burst.cycle then
				seen[burst.id] = burst.cycle
				CombatService.environmentDamage(player, burst.damage, true)
			end
		end
	end

	if sample.heal > 0 and humanoid.Health > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + sample.heal * elapsed)
	end

	local slow = sample.slow
	if slow < 1 then
		StatusService.update(player, function(status, at)
			return Effects.applyAmbientSlow(status, slow, Hazards.SLOW_SECONDS, at)
		end)
	end
end

local function runTick(elapsed: number)
	local now = workspace:GetServerTimeNow()
	local failures = 0
	local firstError = ""
	for _, player in Players:GetPlayers() do
		local ok, err = pcall(tickPlayer, player, now, elapsed)
		if not ok then
			failures += 1
			if failures == 1 then
				firstError = tostring(err)
			end
		end
	end
	-- One warning per tick, however many players failed: this runs four times a second.
	if failures > 0 then
		warn(`[IsleOfAvarice] HazardService failed for {failures} player(s): {firstError}`)
	end
end

local function onHeartbeat(deltaTime: number)
	accumulated += deltaTime
	if accumulated < Hazards.TICK_SECONDS then
		return
	end
	local elapsed = math.min(accumulated, MAX_ELAPSED_SECONDS)
	accumulated = 0
	runTick(elapsed)
end

function HazardService.start()
	Players.PlayerRemoving:Connect(function(player)
		lastBurst[player] = nil
	end)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return HazardService
