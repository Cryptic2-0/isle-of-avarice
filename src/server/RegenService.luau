--!strict
-- Slow health regeneration for every player's character, once they have been left alone.
-- Roblox's own regeneration is switched off by the empty Health script in StarterCharacterScripts;
-- Regen holds the rule, this service only watches damage and writes the result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Regen = require(ReplicatedStorage.Shared.Rules.Regen)

local TICK_SECONDS = 0.5

local RegenService = {}

local lastHurtAt: { [Player]: number } = {}
local healthWatch: { [Player]: RBXScriptConnection } = {}
local accumulated = 0

-- Waits for the character's Humanoid, so a character that arrives without one yet is still
-- watched. Runs in its own thread: the wait yields.
local function watch(player: Player, character: Model)
	local previous = healthWatch[player]
	if previous ~= nil then
		previous:Disconnect()
		healthWatch[player] = nil
	end
	-- A new character starts unhurt.
	lastHurtAt[player] = nil
	local found = character:WaitForChild("Humanoid", 10)
	-- A newer character may have arrived while waiting; its own watch handles it.
	if found == nil or not found:IsA("Humanoid") or player.Character ~= character then
		return
	end
	local humanoid: Humanoid = found
	local last = humanoid.Health
	healthWatch[player] = humanoid.HealthChanged:Connect(function(health: number)
		if health < last then
			lastHurtAt[player] = os.clock()
		end
		last = health
	end)
end

-- One player's regeneration for this tick.
local function step(player: Player, now: number, elapsed: number)
	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil and humanoid.Health > 0 then
		local new = Regen.step(
			humanoid.Health,
			humanoid.MaxHealth,
			lastHurtAt[player] or -math.huge,
			now,
			elapsed
		)
		if new ~= humanoid.Health then
			humanoid.Health = new
		end
	end
end

local function onHeartbeat(deltaTime: number)
	accumulated += deltaTime
	if accumulated < TICK_SECONDS then
		return
	end
	local elapsed = accumulated
	accumulated = 0
	local now = os.clock()
	local failures = 0
	local firstError = ""
	for _, player in Players:GetPlayers() do
		local ok, err = pcall(step, player, now, elapsed)
		if not ok then
			failures += 1
			if failures == 1 then
				firstError = tostring(err)
			end
		end
	end
	-- One warning per tick, however many players failed.
	if failures > 0 then
		warn(`[IsleOfAvarice] RegenService failed for {failures} player(s): {firstError}`)
	end
end

function RegenService.start()
	local function track(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(watch, player, character)
		end)
		if player.Character ~= nil then
			task.spawn(watch, player, player.Character)
		end
	end
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		local connection = healthWatch[player]
		if connection ~= nil then
			connection:Disconnect()
		end
		healthWatch[player] = nil
		lastHurtAt[player] = nil
	end)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return RegenService
