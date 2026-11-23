--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tiers = require(Shared:WaitForChild("Catalog"):WaitForChild("Tiers"))
local Confirm = require(Shared:WaitForChild("Rules"):WaitForChild("Confirm"))
local Crown = require(Shared:WaitForChild("Rules"):WaitForChild("Crown"))
local LedgerView = require(Shared:WaitForChild("Rules"):WaitForChild("LedgerView"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.UiKit)

type View = LedgerView.View

local LedgerUI = {}

local TEXT_DIM = Color3.fromRGB(130, 130, 135)
local LOCKED_COLOR = Color3.fromRGB(55, 55, 60)
local VAULT_GOLD = Color3.fromRGB(255, 200, 40)
-- An Edict has no tier, so it gets the colour of old paper.
local PARCHMENT = Color3.fromRGB(214, 196, 150)
local CROWN_GOLD = Color3.fromRGB(255, 215, 90)

local panel: Frame? = nil
local slotGrid: ScrollingFrame? = nil
local freeList: ScrollingFrame? = nil
local progressLabel: TextLabel? = nil
local freeLabel: TextLabel? = nil
local vaultLabel: TextLabel? = nil
local crownLabel: TextLabel? = nil
-- What the Crown line is drawn from: the attributes as last given, and whether the last
-- Ledger view was complete.
local shownCrowns: number? = nil
local shownStars: number? = nil
local lastComplete = false
local actionHandler: (request: { [string]: any }) -> () = function(_request: { [string]: any }) end
local vaultHandler: (request: { [string]: any }) -> () = function(_request: { [string]: any }) end
local useHandler: (card: LedgerView.FreeView) -> () = function(_card: LedgerView.FreeView) end

-- The control waiting for its second tap (an unclaim or a discard), and what the current
-- render drew, so an armed control can be redrawn without rebuilding the rows.
local armed: Confirm.Armed? = nil
local slotEntries: { { button: TextButton, slot: LedgerView.SlotView } } = {}
local discardEntries: { { button: TextButton, key: string } } = {}

local function tierColor(tier: Types.Tier): Color3
	local color = Tiers.info[tier].color
	return Color3.fromRGB(color.r, color.g, color.b)
end

local function slotText(slot: LedgerView.SlotView): string
	local text = slot.label .. "\n" .. slot.name
	if slot.spares > 0 then
		text ..= "\nx" .. slot.spares
	end
	return text
end

-- Redraws every control that can be armed from `armed` and the clock.
local function drawArmed()
	local now = os.clock()
	for _, entry in slotEntries do
		local slot = entry.slot
		local button = entry.button
		if Confirm.isArmed(armed, "unclaim:" .. slot.cardId, now) then
			button.Text = slot.label .. "\nTap again\nto unclaim"
			button.BackgroundColor3 = UiKit.ARMED
			button.TextColor3 = UiKit.TEXT_LIGHT
		else
			button.Text = slotText(slot)
			button.BackgroundColor3 = tierColor(slot.tier)
			button.TextColor3 = UiKit.TEXT_DARK
		end
	end
	for _, entry in discardEntries do
		if Confirm.isArmed(armed, entry.key, now) then
			entry.button.Text = "Sure?"
			entry.button.BackgroundColor3 = UiKit.ARMED
		else
			entry.button.Text = "Discard"
			entry.button.BackgroundColor3 = UiKit.BUTTON
		end
	end
end

-- A tap on a risky control: arms it, or (second tap in time) reports that it should go ahead.
local function pressRisky(key: string): boolean
	local nextArmed, go = Confirm.press(armed, key, os.clock())
	armed = nextArmed
	drawArmed()
	if not go then
		-- Puts the control back once its window has passed.
		task.delay(Confirm.WINDOW_SECONDS + 0.1, drawArmed)
	end
	return go
end

local function makeSlot(slot: LedgerView.SlotView, order: number): TextButton
	local button = UiKit.button("Slot" .. slot.label, "", nil, { min = 9, max = 20, wrap = true })
	button.LayoutOrder = order
	button.AutoButtonColor = slot.claimed
	button.Font = Enum.Font.GothamMedium
	if slot.claimed then
		button.BackgroundColor3 = tierColor(slot.tier)
		button.TextColor3 = UiKit.TEXT_DARK
	else
		button.BackgroundColor3 = LOCKED_COLOR
		button.TextColor3 = TEXT_DIM
	end
	button.Text = slotText(slot)
	UiKit.padding(button, 4)
	if slot.vaulted then
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = VAULT_GOLD
		stroke.Thickness = 3
		stroke.Parent = button
	end

	-- A claimed slot has its own guard: the slot and its Vault button share it.
	local vaultButton: TextButton? = nil
	local slotGuard = UiKit.guard(function(inert: boolean)
		UiKit.setEnabled(button, not inert)
		if vaultButton ~= nil then
			UiKit.setEnabled(vaultButton, not inert)
		end
	end)
	if slot.claimed then
		table.insert(slotEntries, { button = button, slot = slot })
		UiKit.onPress(button, function()
			if pressRisky("unclaim:" .. slot.cardId) then
				UiKit.send(slotGuard, function()
					actionHandler({ kind = "unclaim", cardId = slot.cardId })
				end)
			end
		end)
	end
	if slot.vaulted or slot.canVault then
		-- A button on top of the slot takes the click, so the slot's unclaim does not fire.
		local vault = UiKit.button(
			"Vault",
			if slot.vaulted then "Vaulted" else "Vault",
			UDim2.new(0.55, 0, 0, 18),
			{ min = 10, max = 22 }
		)
		vault.AnchorPoint = Vector2.new(1, 1)
		vault.Position = UDim2.fromScale(1, 1)
		vault.ZIndex = button.ZIndex + 1
		if slot.vaulted then
			vault.BackgroundColor3 = VAULT_GOLD
			vault.TextColor3 = UiKit.TEXT_DARK
		end
		UiKit.onPress(vault, function()
			UiKit.send(slotGuard, function()
				vaultHandler({
					kind = if slot.vaulted then "remove" else "add",
					cardId = slot.cardId,
				})
			end)
		end)
		vault.Parent = button
		vaultButton = vault
	end
	return button
end

local function makeFreeRow(card: LedgerView.FreeView): Frame
	local row = Instance.new("Frame")
	row.Name = "Free" .. card.index
	row.LayoutOrder = card.index
	row.Size = UDim2.new(1, 0, 0, 52)
	local tier = card.tier
	row.BackgroundColor3 = if tier ~= nil then tierColor(tier) else PARCHMENT
	UiKit.corner(row, 8)

	local name = UiKit.label(
		"Name",
		card.name,
		UDim2.fromScale(0.5, 1),
		UDim2.fromScale(0, 0),
		{ min = 10, max = 22, wrap = false, color = UiKit.TEXT_DARK }
	)
	UiKit.padding(name, 6)
	name.Parent = row

	-- One request per row: a second click before the Ledger sync would pass the server's
	-- "card on that row" check with the identical card next to it. The row is rebuilt on sync,
	-- and comes back by itself after a second if the server refused.
	local buttons: { TextButton } = {}
	local rowGuard = UiKit.guard(function(inert: boolean)
		for _, button in buttons do
			UiKit.setEnabled(button, not inert)
		end
	end)

	local discard =
		UiKit.button("Discard", "Discard", UDim2.new(0.22, 0, 1, -8), { min = 10, max = 22 })
	discard.AnchorPoint = Vector2.new(1, 0.5)
	discard.Position = UDim2.new(0.99, 0, 0.5, 0)
	table.insert(buttons, discard)
	local discardKey = "discard:" .. card.index .. ":" .. card.cardId
	table.insert(discardEntries, { button = discard, key = discardKey })
	UiKit.onPress(discard, function()
		if pressRisky(discardKey) then
			UiKit.send(rowGuard, function()
				actionHandler({ kind = "discard", freeIndex = card.index, cardId = card.cardId })
			end)
		end
	end)
	discard.Parent = row

	if card.canClaim then
		local claim =
			UiKit.button("Claim", "Claim", UDim2.new(0.22, 0, 1, -8), { min = 10, max = 22 })
		claim.AnchorPoint = Vector2.new(1, 0.5)
		claim.Position = UDim2.new(0.75, 0, 0.5, 0)
		table.insert(buttons, claim)
		UiKit.onPress(claim, function()
			UiKit.send(rowGuard, function()
				actionHandler({ kind = "claim", freeIndex = card.index, cardId = card.cardId })
			end)
		end)
		claim.Parent = row
	elseif card.canUse then
		-- An Edict is used, not claimed; the button sits where Claim would.
		local use = UiKit.button("Use", "Use", UDim2.new(0.22, 0, 1, -8), { min = 10, max = 22 })
		use.AnchorPoint = Vector2.new(1, 0.5)
		use.Position = UDim2.new(0.75, 0, 0.5, 0)
		table.insert(buttons, use)
		UiKit.onPress(use, function()
			-- It only opens a picker, which may be cancelled with no sync to rebuild the row;
			-- the guard's one-second re-arm covers that.
			UiKit.send(rowGuard, function()
				useHandler(card)
			end)
		end)
		use.Parent = row
	end
	return row
end

-- What the "Use" button on an Edict row calls.
function LedgerUI.setUseHandler(handler: (card: LedgerView.FreeView) -> ())
	useHandler = handler
end

-- Redraws the Crown line from the last attributes and the last Ledger view.
local function drawCrown()
	local label = crownLabel
	if label ~= nil then
		label.Text = Crown.bookLine(shownCrowns, shownStars, lastComplete)
	end
end

function LedgerUI.mount(
	playerGui: PlayerGui,
	onAction: (request: { [string]: any }) -> (),
	onVault: (request: { [string]: any }) -> ()
)
	actionHandler = onAction
	vaultHandler = onVault

	local gui = UiKit.screen("LedgerGui", 10)

	local book = UiKit.window("Book", UDim2.fromScale(0.7, 0.7), "big")

	local title = UiKit.label(
		"Title",
		"The Hoarder's Ledger",
		UDim2.fromScale(0.6, 0.08),
		UDim2.fromScale(0.02, 0.02),
		{ min = 10, max = 30, wrap = false, font = Enum.Font.GothamBold }
	)
	title.Parent = book

	local closeButton = UiKit.button(
		"Close",
		"X",
		UDim2.fromScale(0.08, 0.08),
		{ min = 10, max = 22, minSize = Vector2.new(40, 32) }
	)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(0.98, 0.02)
	UiKit.onPress(closeButton, LedgerUI.toggle)
	closeButton.Parent = book

	local progress = UiKit.label(
		"Progress",
		"",
		UDim2.fromScale(0.3, 0.05),
		UDim2.fromScale(0.02, 0.11),
		{ min = 10, max = 20, wrap = false }
	)
	progress.Parent = book
	progressLabel = progress

	local free = UiKit.label(
		"FreeCount",
		"",
		UDim2.fromScale(0.3, 0.05),
		UDim2.fromScale(0.35, 0.11),
		{ min = 10, max = 20, wrap = false }
	)
	free.Parent = book
	freeLabel = free

	local vault = UiKit.label(
		"VaultCount",
		"",
		UDim2.fromScale(0.3, 0.05),
		UDim2.fromScale(0.68, 0.11),
		{ min = 10, max = 20, wrap = false }
	)
	vault.Parent = book
	vaultLabel = vault

	local crownLine = UiKit.label(
		"CrownLine",
		"",
		UDim2.fromScale(0.96, 0.04),
		UDim2.fromScale(0.02, 0.165),
		{ min = 10, max = 18, wrap = false, color = CROWN_GOLD }
	)
	crownLine.Parent = book
	crownLabel = crownLine
	drawCrown()

	local grid = UiKit.scroller("Slots", UDim2.fromScale(0.46, 0.76), UDim2.fromScale(0.02, 0.21))
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.31, 0, 0, 78)
	gridLayout.CellPadding = UDim2.new(0.03, 0, 0, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	grid.Parent = book
	slotGrid = grid

	local list =
		UiKit.scroller("FreeCards", UDim2.fromScale(0.46, 0.76), UDim2.fromScale(0.52, 0.21))
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	list.Parent = book
	freeList = list

	book.Parent = gui
	panel = book

	ContextActionService:BindAction("ToggleLedger", function(_name, state)
		if state == Enum.UserInputState.Begin then
			LedgerUI.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.B)

	gui.Parent = playerGui
end

function LedgerUI.render(view: View)
	local grid = slotGrid
	local list = freeList
	if grid == nil or list == nil then
		return
	end
	if progressLabel ~= nil then
		progressLabel.Text = "Relics: "
			.. view.progressText
			.. (if view.complete then " (complete!)" else "")
	end
	if freeLabel ~= nil then
		freeLabel.Text = "Free slots: " .. view.freeText
	end
	if vaultLabel ~= nil then
		vaultLabel.Text = "Vault: " .. view.vaultText
	end

	lastComplete = view.complete
	drawCrown()

	slotEntries = {}
	discardEntries = {}
	UiKit.clearRows(grid)
	for index, slot in view.slots do
		makeSlot(slot, index).Parent = grid
	end
	UiKit.clearRows(list)
	for _, card in view.free do
		makeFreeRow(card).Parent = list
	end
	-- An armed control stays armed across a sync while its key still exists.
	drawArmed()
end

-- The player's Crowns and Stars attributes (nil while not set yet).
function LedgerUI.setCrown(crowns: number?, stars: number?)
	shownCrowns = crowns
	shownStars = stars
	drawCrown()
end

function LedgerUI.isOpen(): boolean
	local book = panel
	return book ~= nil and book.Visible
end

function LedgerUI.toggle()
	local book = panel
	if book ~= nil then
		book.Visible = not book.Visible
	end
end

return LedgerUI
