--!strict
print("[IsleOfAvarice] client started")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Messages = require(Shared:WaitForChild("Catalog"):WaitForChild("Messages"))
local LedgerView = require(Shared:WaitForChild("Rules"):WaitForChild("LedgerView"))
local LedgerUI = require(script.Parent.LedgerUI)
local Toast = require(script.Parent.Toast)

local remotes = ReplicatedStorage:WaitForChild(Net.FOLDER)
local ledgerSync = remotes:WaitForChild(Net.LedgerSync) :: RemoteEvent
local ledgerAction = remotes:WaitForChild(Net.LedgerAction) :: RemoteEvent
local ledgerRequest = remotes:WaitForChild(Net.LedgerRequest) :: RemoteEvent
local notify = remotes:WaitForChild(Net.Notify) :: RemoteEvent

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

LedgerUI.mount(playerGui, function(request)
	ledgerAction:FireServer(request)
end)
Toast.mount(playerGui)

ledgerSync.OnClientEvent:Connect(function(ledger, vault)
	LedgerUI.render(LedgerView.build(ledger, vault))
end)
notify.OnClientEvent:Connect(function(code, args)
	Toast.show(Messages.format(code, args))
end)

-- The first sync may have fired before this script connected; ask again.
ledgerRequest:FireServer()
