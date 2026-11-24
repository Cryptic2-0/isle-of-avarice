--!nonstrict
-- Play-test agent. Only in the play-test build (playtest.project.json), never in dist.
-- It does what a player would do (fire the game's own remotes, hold a cache prompt) when
-- the play-test driver asks, and reports back what this client saw: messages, claim
-- screens, hit flashes, ability cooldowns and the state of the on-screen UI.
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
remotes:WaitForChild("AbilityCooldown").OnClientEvent:Connect(function(slot, seconds)
	report:FireServer("cooldown", slot, seconds)
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

	-- Calling picker and Paths panel.
	local pathGui = playerGui:FindFirstChild("PathGui")
	ui.pathsButton = pathGui ~= nil and pathGui:FindFirstChild("PathsButton") ~= nil
	local picker = pathGui and pathGui:FindFirstChild("Picker")
	ui.pickerVisible = picker ~= nil and picker.Visible
	local cards = picker and picker:FindFirstChild("Cards")
	local cardCount = 0
	if cards ~= nil then
		for _, card in cards:GetChildren() do
			if card:IsA("Frame") then
				cardCount += 1
			end
		end
	end
	ui.pickerCards = cardCount
	local panel = pathGui and pathGui:FindFirstChild("Panel")
	local callingText = panel and panel:FindFirstChild("CallingText")
	ui.callingText = callingText and callingText.Text or ""
	-- Each Path row: its header, detail line and Calling button (or "").
	local pathRows = {}
	local rows = panel and panel:FindFirstChild("Rows")
	if rows ~= nil then
		for _, row in rows:GetChildren() do
			if row:IsA("Frame") then
				local header = row:FindFirstChild("Header")
				local detail = row:FindFirstChild("Detail")
				local make = row:FindFirstChild("MakeCalling") or row:FindFirstChild("Choose")
				pathRows[string.sub(row.Name, 4)] = {
					header = header and header.Text or "",
					detail = detail and detail.Text or "",
					button = make and make.Text or "",
				}
			end
		end
	end
	ui.pathRows = pathRows
	-- The panel's loadout strip, slots 1 to 4 ("" when missing).
	local loadoutSlots = {}
	local strip = panel and panel:FindFirstChild("Loadout")
	for slot = 1, 4 do
		local cell = strip and strip:FindFirstChild("Slot" .. slot)
		local name = cell and cell:FindFirstChild("Name")
		loadoutSlots[slot] = name and name.Text or ""
	end
	ui.loadoutSlots = loadoutSlots

	-- The ability bar: each slot's ability name and cooldown seconds ("" when missing).
	local abilityGui = playerGui:FindFirstChild("AbilityGui")
	local bar = abilityGui and abilityGui:FindFirstChild("Bar")
	local abilitySlots = {}
	local abilitySeconds = {}
	for slot = 1, 4 do
		local button = bar and bar:FindFirstChild("Slot" .. slot)
		local name = button and button:FindFirstChild("AbilityName")
		local seconds = button and button:FindFirstChild("Seconds")
		abilitySlots[slot] = name and name.Text or ""
		abilitySeconds[slot] = seconds and seconds.Text or ""
	end
	ui.abilitySlots = abilitySlots
	ui.abilitySeconds = abilitySeconds

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
	elseif op == "pickCalling" then
		remotes.PickCalling:FireServer(arg)
	elseif op == "changeCalling" then
		remotes.ChangeCalling:FireServer(arg)
	elseif op == "loadout" then
		remotes.LoadoutAction:FireServer(arg)
	elseif op == "cast" then
		remotes.CastAbility:FireServer(arg)
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
