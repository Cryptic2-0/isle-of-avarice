--!nonstrict
-- Play-test agent. Only in the play-test build (playtest.project.json), never in dist.
-- It does what a player would do (fire the game's own remotes, hold a cache prompt) when
-- the play-test driver asks, and reports back what this client saw: messages, claim
-- screens, hit flashes and the state of the on-screen UI.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playtest = ReplicatedStorage:WaitForChild("Playtest")
local cmd = playtest:WaitForChild("Cmd")
local report = playtest:WaitForChild("Report")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Protection = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("Protection")
)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

remotes:WaitForChild("Notify").OnClientEvent:Connect(function(code, args)
	report:FireServer("notify", code, args)
end)
remotes:WaitForChild("ClaimUpdate").OnClientEvent:Connect(function(payload)
	report:FireServer("claim", payload)
end)
remotes:WaitForChild("HitFx").OnClientEvent:Connect(function(victimUserId)
	report:FireServer("hitfx", victimUserId)
end)
remotes:WaitForChild("StatusSync").OnClientEvent:Connect(function(status)
	report:FireServer("status", status)
end)

local function texts(container: Instance?): { string }
	local result = {}
	if container == nil then
		return result
	end
	for _, child in container:GetChildren() do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			table.insert(result, child.Name .. "=" .. child.Text)
		end
	end
	table.sort(result)
	return result
end

-- A snapshot of the game's UI as this player sees it.
local function inspectUi()
	local ui = {}
	local ledgerGui = playerGui:FindFirstChild("LedgerGui")
	ui.ledgerGui = ledgerGui ~= nil
	local book = ledgerGui and ledgerGui:FindFirstChild("Book")
	ui.bookVisible = book ~= nil and book.Visible
	local vaultButtons = {}
	local slotTexts = {}
	if book ~= nil then
		local slots = book:FindFirstChild("Slots")
		if slots ~= nil then
			for _, slot in slots:GetChildren() do
				if slot:IsA("TextButton") then
					slotTexts[slot.Name] = slot.Text
					local vaultButton = slot:FindFirstChild("Vault")
					if vaultButton ~= nil then
						vaultButtons[slot.Name] = vaultButton.Text
					end
				end
			end
		end
		local vaultCount = book:FindFirstChild("VaultCount")
		ui.vaultCount = vaultCount and vaultCount.Text
		local progress = book:FindFirstChild("Progress")
		ui.progress = progress and progress.Text
	end
	ui.ledgerSlots = slotTexts
	ui.vaultButtons = vaultButtons

	local statusGui = playerGui:FindFirstChild("StatusGui")
	ui.statusLines = texts(statusGui and statusGui:FindFirstChild("Lines"))
	local drop = statusGui and statusGui:FindFirstChild("DropShield")
	ui.dropShieldVisible = drop ~= nil and drop.Visible

	local claimGui = playerGui:FindFirstChild("ClaimGui")
	local claim = claimGui and claimGui:FindFirstChild("Claim")
	ui.claimVisible = claim ~= nil and claim.Visible
	local claimSlots = {}
	if claim ~= nil then
		local slots = claim:FindFirstChild("Slots")
		if slots ~= nil then
			for _, slot in slots:GetChildren() do
				if slot:IsA("TextButton") then
					claimSlots[slot.Name] = slot.Text
				end
			end
		end
		local title = claim:FindFirstChild("Title")
		ui.claimTitle = title and title.Text
		local picks = claim:FindFirstChild("Picks")
		ui.claimPicks = picks and picks.Text
	end
	ui.claimSlots = claimSlots

	local toastGui = playerGui:FindFirstChild("ToastGui")
	local message = toastGui and toastGui:FindFirstChild("Message")
	ui.toast = message and message.Visible and message.Text or ""

	ui.strikeBound = next(ContextActionService:GetBoundActionInfo("Strike")) ~= nil

	-- What this client itself computes for the safe zone (same inputs as the HUD).
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root ~= nil then
		local p = root.Position
		ui.rootPos = string.format("%.1f, %.1f, %.1f", p.X, p.Y, p.Z)
		local ok, result = pcall(function()
			return Protection.inSafeZone({ x = p.X, y = p.Y, z = p.Z })
		end)
		ui.clientSafe = if ok then tostring(result) else "error: " .. tostring(result)
	else
		ui.rootPos = "no character"
	end
	return ui
end

cmd.OnClientEvent:Connect(function(op, arg)
	if op == "strike" then
		remotes.Strike:FireServer()
	elseif op == "dropShield" then
		remotes.ShieldDrop:FireServer()
	elseif op == "ledger" then
		remotes.LedgerAction:FireServer(arg)
	elseif op == "vault" then
		remotes.VaultAction:FireServer(arg)
	elseif op == "pick" then
		remotes.ClaimPick:FireServer(arg)
	elseif op == "prompt" then
		-- Hold the cache's prompt the way the E key would.
		local island = workspace:FindFirstChild("Island")
		local cache = island and island:FindFirstChild(arg)
		local prompt = cache and cache:FindFirstChildOfClass("ProximityPrompt")
		if prompt == nil then
			report:FireServer("error", "no prompt for " .. tostring(arg))
			return
		end
		prompt:InputHoldBegin()
		task.wait(prompt.HoldDuration + 0.3)
		prompt:InputHoldEnd()
		report:FireServer("prompted", arg)
	elseif op == "toggleLedger" then
		local ledgerGui = playerGui:FindFirstChild("LedgerGui")
		local book = ledgerGui and ledgerGui:FindFirstChild("Book")
		if book ~= nil then
			book.Visible = arg == true
		end
	elseif op == "inspect" then
		report:FireServer("ui", inspectUi())
	end
end)

report:FireServer("ready")
