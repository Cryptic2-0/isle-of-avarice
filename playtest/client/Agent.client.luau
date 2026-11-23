--!nonstrict
-- Play-test agent. Only in the play-test build (playtest.project.json), never in dist.
-- It does what a player would do (fire the game's own remotes, hold a cache prompt) when
-- the play-test driver asks, and reports back what this client saw: messages, claim
-- screens, hit flashes, ability cooldowns, trial offers and the state of the on-screen UI.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
remotes:WaitForChild("TrialOffer").OnClientEvent:Connect(function(view)
	report:FireServer("offer", view)
end)
-- M5: the Edict result window, the Veil and who has been met, the shop and the trade.
remotes:WaitForChild("EdictResult").OnClientEvent:Connect(function(result)
	report:FireServer("edictResult", result)
end)
remotes:WaitForChild("EdictSync").OnClientEvent:Connect(function(veilSeconds, met)
	report:FireServer("edictSync", veilSeconds, met)
end)
remotes:WaitForChild("ShopOpen").OnClientEvent:Connect(function(view)
	report:FireServer("shop", view)
end)
remotes:WaitForChild("TradeInvite").OnClientEvent:Connect(function(invite)
	report:FireServer("tradeInvite", invite)
end)
remotes:WaitForChild("TradeSync").OnClientEvent:Connect(function(view)
	report:FireServer("tradeSync", view)
end)
-- M6: the party invite and the party as the server last sent them (nil = none).
remotes:WaitForChild("PartyInvite").OnClientEvent:Connect(function(invite)
	report:FireServer("partyInvite", invite)
end)
remotes:WaitForChild("PartySync").OnClientEvent:Connect(function(sync)
	report:FireServer("partySync", sync)
end)
-- M7: the Crowning banner and the Renounce offer (nil = closed).
remotes:WaitForChild("Ceremony").OnClientEvent:Connect(function(payload)
	report:FireServer("ceremony", payload)
end)
remotes:WaitForChild("RenounceOffer").OnClientEvent:Connect(function(offer)
	report:FireServer("renounceOffer", offer)
end)

-- Diagnostics for ProximityPrompts. In the first M7 run every prompt hold after the display went
-- to sleep (Studio logged "onMonitorOff" and "Pushing skip render state") did nothing. So keep
-- count of rendered and simulated frames, and of the prompts the engine says it shows here: the
-- prompt traces then tell "this client draws no frames" apart from "the prompt is not shown"
-- (distance, camera) and from "shown, but the hold did nothing".
local renderFrames, heartbeatFrames = 0, 0
RunService.RenderStepped:Connect(function()
	renderFrames += 1
end)
RunService.Heartbeat:Connect(function()
	heartbeatFrames += 1
end)
local shownPrompts: { [ProximityPrompt]: boolean } = {}
ProximityPromptService.PromptShown:Connect(function(prompt)
	shownPrompts[prompt] = true
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	shownPrompts[prompt] = nil
end)
-- Rendered and simulated frames over the last second, sampled once a second.
local renderRate, heartbeatRate = -1, -1
task.spawn(function()
	local rendering = true
	while true do
		local r0, h0 = renderFrames, heartbeatFrames
		task.wait(1)
		renderRate, heartbeatRate = renderFrames - r0, heartbeatFrames - h0
		-- Tell the driver once when this client stops (or starts again) drawing frames: with
		-- no rendered frames the engine shows no prompt, so no prompt check can pass.
		if rendering and renderRate == 0 then
			rendering = false
			report:FireServer("render", false, heartbeatRate)
		elseif not rendering and renderRate > 0 then
			rendering = true
			report:FireServer("render", true, renderRate)
		end
	end
end)

local function promptState(prompt: ProximityPrompt): string
	local parent = prompt.Parent
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local distance = "?"
	if parent ~= nil and parent:IsA("BasePart") and root ~= nil and root:IsA("BasePart") then
		distance = string.format("%.1f", (root.Position - parent.Position).Magnitude)
	end
	local camera = workspace.CurrentCamera
	local onScreen = "?"
	local cameraAt = "?"
	if camera ~= nil and parent ~= nil and parent:IsA("BasePart") then
		local _, visible = camera:WorldToViewportPoint(parent.Position)
		onScreen = tostring(visible)
		local c = camera.CFrame.Position
		cameraAt = string.format("%.0f, %.0f, %.0f", c.X, c.Y, c.Z)
	end
	return `enabled {prompt.Enabled}, shown {shownPrompts[prompt] == true}, {distance} studs (max {prompt.MaxActivationDistance}), on screen {onScreen}, camera at ({cameraAt}), frames/s render {renderRate} heartbeat {heartbeatRate}`
end

-- Holds a prompt the way the E key would and reports what this client saw: the prompt's state
-- before the hold, and whether the hold began and the prompt fired here.
local function holdPrompt(prompt: ProximityPrompt, label: string)
	local before = promptState(prompt)
	local began, triggered = false, false
	local beganConnection = prompt.PromptButtonHoldBegan:Connect(function()
		began = true
	end)
	local triggeredConnection = prompt.Triggered:Connect(function()
		triggered = true
	end)
	prompt:InputHoldBegin()
	task.wait(prompt.HoldDuration + 0.3)
	prompt:InputHoldEnd()
	task.wait(0.1)
	beganConnection:Disconnect()
	triggeredConnection:Disconnect()
	report:FireServer(
		"promptTrace",
		`{label}: before the hold {before}; here the hold began {began}, triggered {triggered}`
	)
end

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

-- The Tally Stone's Renounce prompt, or nil.
local function stonePromptOf()
	local island = workspace:FindFirstChild("Island")
	local town = island and island:FindFirstChild("Tallyport")
	local model = town and town:FindFirstChild("TallyStone")
	local stone = model and model:FindFirstChild("Stone")
	return stone and stone:FindFirstChild("RenouncePrompt")
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
	-- M7: how many numbered slots the book draws, and its Crown line.
	local slotCount = 0
	for _ in slotTexts do
		slotCount += 1
	end
	ui.ledgerSlotCount = slotCount
	local crownLine = book and book:FindFirstChild("CrownLine")
	ui.crownLine = crownLine and crownLine.Text or ""

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
	-- The menu row owns the Paths button now.
	local menuGui = playerGui:FindFirstChild("MenuGui")
	ui.pathsButton = menuGui ~= nil and menuGui:FindFirstChild("PathsButton") ~= nil
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

	-- M4: the Coin line, the trial HUD, the offer window, the beacon and duel champions.
	local coin = statusGui and statusGui:FindFirstChild("Coin")
	ui.coin = coin and coin.Text or ""
	local trialGui = playerGui:FindFirstChild("TrialGui")
	local trialLines = {}
	local hud = trialGui and trialGui:FindFirstChild("Hud")
	if hud ~= nil then
		for index = 1, 4 do
			local line = hud:FindFirstChild("Line" .. index)
			if line ~= nil then
				trialLines[index] = line.Text
			end
		end
	end
	ui.trialLines = trialLines
	local offer = trialGui and trialGui:FindFirstChild("Offer")
	ui.offerVisible = offer ~= nil and offer.Visible
	local offerBody = offer and offer:FindFirstChild("Body")
	local function offerText(name: string): string
		local label = offerBody and offerBody:FindFirstChild(name)
		return label and label.Text or ""
	end
	ui.offerTitle = offerText("Title")
	ui.offerRelic = offerText("Relic")
	ui.offerNote = offerText("Note")
	local buttons = offer and offer:FindFirstChild("Buttons")
	local accept = buttons and buttons:FindFirstChild("Accept")
	ui.acceptActive = accept ~= nil and accept.Active
	local beacon = workspace:FindFirstChild("TrialBeacon")
	if beacon ~= nil then
		ui.beacon = { x = beacon.Position.X, z = beacon.Position.Z }
	end
	-- Per duel champion, keyed by its owner's user id: does this client draw it?
	local champions = {}
	for _, model in CollectionService:GetTagged("Creature") do
		local owner = model:GetAttribute("OwnerUserId")
		if type(owner) == "number" and owner ~= 0 then
			local shown = false
			for _, part in model:GetChildren() do
				if
					part:IsA("BasePart")
					and part.Name ~= "HumanoidRootPart"
					and part.LocalTransparencyModifier < 1
				then
					shown = true
				end
			end
			champions[tostring(owner)] = shown
		end
	end
	ui.champions = champions

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

	-- M5: the shop, trade and Edict result windows and the Veil line.
	local shopGui = playerGui:FindFirstChild("ShopGui")
	local shop = shopGui and shopGui:FindFirstChild("Shop")
	ui.shopVisible = shop ~= nil and shop.Visible
	local shopCoin = shop and shop:FindFirstChild("Coin")
	ui.shopCoin = shopCoin and shopCoin.Text or ""
	local tradeGui = playerGui:FindFirstChild("TradeGui")
	local trade = tradeGui and tradeGui:FindFirstChild("Trade")
	ui.tradeVisible = trade ~= nil and trade.Visible
	local tradeStatus = trade and trade:FindFirstChild("Status")
	ui.tradeStatus = tradeStatus and tradeStatus.Text or ""
	local invite = tradeGui and tradeGui:FindFirstChild("Invite")
	ui.inviteVisible = invite ~= nil and invite.Visible
	local edictGui = playerGui:FindFirstChild("EdictGui")
	local result = edictGui and edictGui:FindFirstChild("Result")
	ui.resultVisible = result ~= nil and result.Visible
	local resultTitle = result and result:FindFirstChild("Title")
	ui.resultTitle = resultTitle and resultTitle.Text or ""
	ui.veilLine = ""
	local lines = statusGui and statusGui:FindFirstChild("Lines")
	if lines ~= nil then
		for _, label in lines:GetChildren() do
			if label:IsA("TextLabel") and string.sub(label.Text, 1, 6) == "Veiled" then
				ui.veilLine = label.Text
			end
		end
	end

	-- M6: the party panel, the invite banner and the ally markers.
	local partyGui = playerGui:FindFirstChild("PartyGui")
	local partyPanel = partyGui and partyGui:FindFirstChild("Panel")
	ui.partyVisible = partyPanel ~= nil and partyPanel.Visible
	local partyTitle = partyPanel and partyPanel:FindFirstChild("Title")
	ui.partyTitle = partyTitle and partyTitle.Text or ""
	local partyRowList = {}
	local partyRowsFrame = partyPanel and partyPanel:FindFirstChild("Rows")
	if partyRowsFrame ~= nil then
		local frames = {}
		for _, row in partyRowsFrame:GetChildren() do
			if row:IsA("Frame") and string.sub(row.Name, 1, 3) == "Row" then
				table.insert(frames, row)
			end
		end
		table.sort(frames, function(x, y)
			return x.LayoutOrder < y.LayoutOrder
		end)
		for _, row in frames do
			local rowName = row:FindFirstChild("Name")
			local rowHealth = row:FindFirstChild("Health")
			local rowTitle = row:FindFirstChild("Title")
			table.insert(partyRowList, {
				name = rowName and rowName.Text or "",
				health = rowHealth and rowHealth.Text or "",
				title = rowTitle and rowTitle.Text or "",
				remove = row:FindFirstChild("Remove") ~= nil,
				lead = row:FindFirstChild("MakeLeader") ~= nil,
			})
		end
	end
	ui.partyRows = partyRowList
	local partyInvite = partyGui and partyGui:FindFirstChild("Invite")
	ui.partyInviteVisible = partyInvite ~= nil and partyInvite.Visible
	local partyInviteText = partyInvite and partyInvite:FindFirstChild("Text")
	ui.partyInviteText = partyInviteText and partyInviteText.Text or ""
	-- Each marker hangs on its member's character; list the names, sorted.
	local markerNames = {}
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		if otherCharacter ~= nil then
			for _, child in otherCharacter:GetChildren() do
				if child:IsA("BillboardGui") and string.sub(child.Name, 1, 11) == "AllyMarker_" then
					local markerLabel = child:FindFirstChildOfClass("TextLabel")
					table.insert(markerNames, markerLabel and markerLabel.Text or "")
				end
			end
		end
	end
	table.sort(markerNames)
	ui.allyMarkers = markerNames

	-- M7: the Crowning banner, the Renounce window and the Tally Stone's prompt.
	local ceremonyGui = playerGui:FindFirstChild("CeremonyGui")
	local banner = ceremonyGui and ceremonyGui:FindFirstChild("Banner")
	ui.ceremonyVisible = banner ~= nil and banner.Visible
	local bannerLine1 = banner and banner:FindFirstChild("Line1")
	local bannerLine2 = banner and banner:FindFirstChild("Line2")
	ui.ceremonyText = (bannerLine1 and bannerLine1.Text or "")
		.. " / "
		.. (bannerLine2 and bannerLine2.Text or "")
	local renounceGui = playerGui:FindFirstChild("RenounceGui")
	local renounceWindow = renounceGui and renounceGui:FindFirstChild("Renounce")
	ui.renounceVisible = renounceWindow ~= nil and renounceWindow.Visible
	local stonePrompt = stonePromptOf()
	ui.stonePromptEnabled = stonePrompt ~= nil and stonePrompt.Enabled
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
		holdPrompt(prompt, tostring(arg))
		report:FireServer("prompted", arg)
	elseif op == "warden" then
		-- Talk to a Warden the way the E key would.
		local island = workspace:FindFirstChild("Island")
		local warden = island and island:FindFirstChild("Warden_" .. tostring(arg))
		local body = warden and warden:FindFirstChild("Body")
		local prompt = body and body:FindFirstChildOfClass("ProximityPrompt")
		if prompt == nil then
			report:FireServer("error", "no Warden prompt for " .. tostring(arg))
			return
		end
		holdPrompt(prompt, "Warden " .. tostring(arg))
	elseif op == "accept" then
		-- Any value, hostile ones included: the server must check it.
		remotes.TrialAccept:FireServer(arg)
	elseif op == "closeOffer" then
		local trialGui = playerGui:FindFirstChild("TrialGui")
		local offer = trialGui and trialGui:FindFirstChild("Offer")
		if offer ~= nil then
			offer.Visible = false
		end
	elseif op == "toggleLedger" then
		local ledgerGui = playerGui:FindFirstChild("LedgerGui")
		local book = ledgerGui and ledgerGui:FindFirstChild("Book")
		if book ~= nil then
			book.Visible = arg == true
		end
	elseif op == "edict" then
		-- Any table, hostile ones included: the server must check it.
		remotes.EdictUse:FireServer(arg)
	elseif op == "shopOpen" then
		-- Talk to the Edict Hall clerk the way the E key would.
		local island = workspace:FindFirstChild("Island")
		local town = island and island:FindFirstChild("Tallyport")
		local clerk = town and town:FindFirstChild("EdictHallClerk")
		local body = clerk and clerk:FindFirstChild("Body")
		local prompt = body and body:FindFirstChildOfClass("ProximityPrompt")
		if prompt == nil then
			report:FireServer("error", "no clerk prompt")
			return
		end
		holdPrompt(prompt, "clerk")
	elseif op == "shop" then
		remotes.ShopAction:FireServer(arg)
	elseif op == "tradeRequest" then
		remotes.TradeRequest:FireServer()
	elseif op == "tradeReply" then
		remotes.TradeReply:FireServer(arg)
	elseif op == "trade" then
		remotes.TradeAction:FireServer(arg)
	elseif op == "partyRequest" then
		remotes.PartyRequest:FireServer()
	elseif op == "partyReply" then
		-- Any value, hostile ones included: the server must check it.
		remotes.PartyReply:FireServer(arg)
	elseif op == "party" then
		remotes.PartyAction:FireServer(arg)
	elseif op == "renouncePrompt" then
		-- Hold the Tally Stone's prompt the way the E key would.
		local prompt = stonePromptOf()
		if prompt == nil then
			report:FireServer("error", "no Tally Stone prompt")
			return
		end
		holdPrompt(prompt, "Tally Stone")
	elseif op == "renounce" then
		-- Any value, hostile ones included: the server must check it.
		remotes.RenounceAction:FireServer(arg)
	elseif op == "inspect" then
		report:FireServer("ui", inspectUi())
	end
end)

report:FireServer("ready")
