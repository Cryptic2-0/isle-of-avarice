--!strict
print("[IsleOfAvarice] client started")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = Shared:WaitForChild("Rules")
local Net = require(Shared:WaitForChild("Net"))
local Messages = require(Shared:WaitForChild("Catalog"):WaitForChild("Messages"))
local LedgerView = require(Rules:WaitForChild("LedgerView"))
local Protection = require(Rules:WaitForChild("Protection"))
local StatusView = require(Rules:WaitForChild("StatusView"))
local ClaimUI = require(script.Parent.ClaimUI)
local CombatController = require(script.Parent.CombatController)
local LedgerUI = require(script.Parent.LedgerUI)
local StatusHUD = require(script.Parent.StatusHUD)
local Toast = require(script.Parent.Toast)

local HUD_REFRESH_SECONDS = 0.5

local remotes = ReplicatedStorage:WaitForChild(Net.FOLDER)
local ledgerSync = remotes:WaitForChild(Net.LedgerSync) :: RemoteEvent
local ledgerAction = remotes:WaitForChild(Net.LedgerAction) :: RemoteEvent
local ledgerRequest = remotes:WaitForChild(Net.LedgerRequest) :: RemoteEvent
local notify = remotes:WaitForChild(Net.Notify) :: RemoteEvent
local vaultAction = remotes:WaitForChild(Net.VaultAction) :: RemoteEvent
local statusSync = remotes:WaitForChild(Net.StatusSync) :: RemoteEvent
local shieldDrop = remotes:WaitForChild(Net.ShieldDrop) :: RemoteEvent
local strikeRemote = remotes:WaitForChild(Net.Strike) :: RemoteEvent
local hitFx = remotes:WaitForChild(Net.HitFx) :: RemoteEvent
local claimUpdate = remotes:WaitForChild(Net.ClaimUpdate) :: RemoteEvent
local claimPick = remotes:WaitForChild(Net.ClaimPick) :: RemoteEvent

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

LedgerUI.mount(playerGui, function(request)
	ledgerAction:FireServer(request)
end, function(request)
	vaultAction:FireServer(request)
end)
Toast.mount(playerGui)
StatusHUD.mount(playerGui, function()
	shieldDrop:FireServer()
end)
ClaimUI.mount(playerGui, function(slot)
	claimPick:FireServer(slot)
end)
CombatController.start(function()
	strikeRemote:FireServer()
end, function()
	return LedgerUI.isOpen() or ClaimUI.isOpen()
end)

ledgerSync.OnClientEvent:Connect(function(ledger, vault)
	LedgerUI.render(LedgerView.build(ledger, vault))
end)
notify.OnClientEvent:Connect(function(code, args)
	Toast.show(Messages.format(code, args))
end)
claimUpdate.OnClientEvent:Connect(function(payload)
	if payload == nil then
		ClaimUI.hide()
	else
		ClaimUI.show(payload.victimName, payload.claim, payload.secondsLeft)
	end
end)
hitFx.OnClientEvent:Connect(function(victimUserId)
	local victim = Players:GetPlayerByUserId(victimUserId)
	local character = if victim ~= nil then victim.Character else nil
	if character ~= nil then
		CombatController.flash(character)
	end
end)

-- The last status from the server and when it arrived (local clock). Timers count down here.
local lastStatus: StatusView.Status? = nil
local statusAt = 0
statusSync.OnClientEvent:Connect(function(status)
	lastStatus = status
	statusAt = os.clock()
end)

local function localInSafeZone(): boolean
	local character = localPlayer.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local p = root.Position
	return Protection.inSafeZone({ x = p.X, y = p.Y, z = p.Z })
end

local function refreshHud()
	local status = lastStatus
	local shown: StatusView.Status? = nil
	if status ~= nil then
		local elapsed = os.clock() - statusAt
		shown = {
			newShield = status.newShield,
			respawnShieldSeconds = math.max(0, status.respawnShieldSeconds - elapsed),
			markedSeconds = math.max(0, status.markedSeconds - elapsed),
		}
	end
	StatusHUD.render(StatusView.build(shown, localInSafeZone()), shown ~= nil and shown.newShield)
end

task.spawn(function()
	while true do
		refreshHud()
		task.wait(HUD_REFRESH_SECONDS)
	end
end)

-- The first sync may have fired before this script connected; ask again.
ledgerRequest:FireServer()
