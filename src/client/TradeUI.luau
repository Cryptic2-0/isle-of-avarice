--!strict
-- Trading: the "Trade" button, the invite banner and the trade window. It shows the view the
-- server sent and sends the player's whole new offer on every change; the server checks it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trade = require(Shared:WaitForChild("Rules"):WaitForChild("Trade"))

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local TEXT_DIM = Color3.fromRGB(170, 165, 160)
local TEXT_DARK = Color3.fromRGB(20, 18, 24)
local COIN_COLOR = Color3.fromRGB(255, 215, 90)
local PANEL_COLOR = Color3.fromRGB(32, 28, 38)
local COLUMN_COLOR = Color3.fromRGB(42, 37, 50)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)
local ACCEPT_COLOR = Color3.fromRGB(60, 130, 80)
local FREE_COLOR = Color3.fromRGB(214, 196, 150)
local OFFERED_COLOR = Color3.fromRGB(110, 190, 120)
local COIN_STEPS = { -10, -1, 1, 10 }
local ROW_HEIGHT = 36
local TICK_SECONDS = 0.2

local TradeUI = {}

type Handlers = {
	request: () -> (),
	reply: (accept: boolean) -> (),
	action: (request: { [string]: any }) -> (),
}

local handlers: Handlers = {
	request = function() end,
	reply = function(_accept: boolean) end,
	action = function(_request: { [string]: any }) end,
}
local window: Frame? = nil
local inviteBanner: Frame? = nil
local inviteLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local freeList: ScrollingFrame? = nil
local mineCards: ScrollingFrame? = nil
local theirCards: ScrollingFrame? = nil
local mineCoin: TextLabel? = nil
local theirCoin: TextLabel? = nil
local confirmButton: TextButton? = nil
-- The view on screen and when it arrived (local clock); the confirm wait counts down from it.
local current: Trade.View? = nil
local arrivedAt = 0
-- Bumped on every invite change, so an old invite's timer cannot hide a newer one.
local inviteToken = 0

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function limitText(parent: Instance, minSize: number, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = parent
end

local function makeLabel(
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	maxText: number
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = TEXT_LIGHT
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	limitText(label, 9, maxText)
	return label
end

local function makeButton(name: string, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = color
	button.TextColor3 = TEXT_LIGHT
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = text
	addCorner(button, 8)
	limitText(button, 9, 20)
	return button
end

-- Dimmed and inert unless `enabled`, as in the trial window.
local function setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.6
	button.TextTransparency = if enabled then 0 else 0.5
end

local function makeList(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Cards"
	scroller.Position = position
	scroller.Size = size
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 5
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroller
	scroller.Parent = parent
	return scroller
end

local function clearRows(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

-- A column frame with its heading; the caller adds the rest.
local function makeColumn(
	parent: Instance,
	name: string,
	heading: string,
	position: UDim2,
	size: UDim2
): Frame
	local column = Instance.new("Frame")
	column.Name = name
	column.Position = position
	column.Size = size
	column.BackgroundColor3 = COLUMN_COLOR
	addCorner(column, 10)
	local title =
		makeLabel("Heading", heading, UDim2.fromScale(0.92, 0.09), UDim2.fromScale(0.04, 0.02), 18)
	title.Font = Enum.Font.GothamBold
	title.Parent = column
	column.Parent = parent
	return column
end

local function cardNames(cards: { Trade.CardView }, list: ScrollingFrame)
	clearRows(list)
	for index, card in cards do
		local label =
			makeLabel("Card" .. index, card.name, UDim2.new(1, -6, 0, 28), UDim2.new(), 18)
		label.LayoutOrder = index
		label.Parent = list
	end
end

-- The whole offer as it is now, as plain card ids.
local function offerIds(view: Trade.View): { string }
	local ids: { string } = {}
	for _, card in view.mine.cards do
		table.insert(ids, card.cardId)
	end
	return ids
end

local function sendOffer(cards: { string }, coin: number)
	handlers.action({ kind = "offer", cards = cards, coin = coin })
end

-- A free-slot click adds that card to the offer, or takes it out again.
local function toggleCard(row: Trade.FreeRow)
	local view = current
	if view == nil then
		return
	end
	local ids = offerIds(view)
	if row.offered then
		local at = table.find(ids, row.cardId)
		if at ~= nil then
			table.remove(ids, at)
		end
	elseif #ids >= Trade.MAX_CARDS then
		return
	else
		table.insert(ids, row.cardId)
	end
	sendOffer(ids, view.mine.coin)
end

local function changeCoin(step: number)
	local view = current
	if view == nil then
		return
	end
	local coin = math.clamp(view.mine.coin + step, 0, math.max(0, view.coinHeld))
	-- Already at the limit: nothing to send.
	if coin == view.mine.coin then
		return
	end
	sendOffer(offerIds(view), coin)
end

-- Confirm is inert after you confirmed and while the server's wait has not passed.
local function updateConfirm()
	local view = current
	local button = confirmButton
	if view == nil or button == nil then
		return
	end
	local waited = os.clock() - arrivedAt
	local ready = not view.mineConfirmed and waited >= view.confirmIn
	setEnabled(button, ready)
	if view.mineConfirmed then
		button.Text = "Confirmed"
	elseif ready then
		button.Text = "Confirm"
	else
		button.Text = "Confirm (" .. math.ceil(view.confirmIn - waited) .. ")"
	end
end

local function hideInvite()
	inviteToken += 1
	local banner = inviteBanner
	if banner ~= nil then
		banner.Visible = false
	end
end

local function buildInvite(gui: ScreenGui)
	local banner = Instance.new("Frame")
	banner.Name = "Invite"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	-- Below the message line (top 4% to 11%).
	banner.Position = UDim2.fromScale(0.5, 0.12)
	banner.Size = UDim2.fromScale(0.5, 0.09)
	banner.BackgroundColor3 = PANEL_COLOR
	banner.Visible = false
	addCorner(banner, 10)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(300, 44)
	minimum.Parent = banner

	local label = makeLabel("Text", "", UDim2.fromScale(0.44, 0.8), UDim2.fromScale(0.03, 0.1), 20)
	label.Parent = banner
	inviteLabel = label

	local accept = makeButton("Accept", "Accept", ACCEPT_COLOR)
	accept.Position = UDim2.fromScale(0.49, 0.12)
	accept.Size = UDim2.fromScale(0.24, 0.76)
	accept.Activated:Connect(function()
		hideInvite()
		handlers.reply(true)
	end)
	accept.Parent = banner

	local decline = makeButton("Decline", "Decline", BUTTON_COLOR)
	decline.Position = UDim2.fromScale(0.74, 0.12)
	decline.Size = UDim2.fromScale(0.24, 0.76)
	decline.Activated:Connect(function()
		hideInvite()
		handlers.reply(false)
	end)
	decline.Parent = banner

	banner.Parent = gui
	inviteBanner = banner
end

local function buildWindow(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "Trade"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.82, 0.8)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.Visible = false
	addCorner(frame, 14)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(340, 320)
	minimum.Parent = frame

	local title =
		makeLabel("Title", "", UDim2.fromScale(0.92, 0.08), UDim2.fromScale(0.04, 0.02), 28)
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	titleLabel = title

	-- Left: your free-slot cards, click to offer.
	local free = makeColumn(
		frame,
		"FreeSlots",
		"Your free slots",
		UDim2.fromScale(0.02, 0.12),
		UDim2.fromScale(0.3, 0.6)
	)
	freeList = makeList(free, UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.92, 0.86))

	-- Middle: what you give, with the Coin steps.
	local mine = makeColumn(
		frame,
		"Mine",
		"You give",
		UDim2.fromScale(0.34, 0.12),
		UDim2.fromScale(0.32, 0.6)
	)
	mineCards = makeList(mine, UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.92, 0.46))
	local give = makeLabel("Coin", "", UDim2.fromScale(0.92, 0.1), UDim2.fromScale(0.04, 0.6), 18)
	give.TextColor3 = COIN_COLOR
	give.Parent = mine
	mineCoin = give
	for index, step in COIN_STEPS do
		local text = if step > 0 then "+" .. step else tostring(step)
		local button = makeButton("Coin" .. text, text, BUTTON_COLOR)
		button.Position = UDim2.fromScale(0.04 + (index - 1) * 0.24, 0.73)
		button.Size = UDim2.fromScale(0.22, 0.2)
		button.Activated:Connect(function()
			changeCoin(step)
		end)
		button.Parent = mine
	end

	-- Right: what you get.
	local theirs = makeColumn(
		frame,
		"Theirs",
		"You get",
		UDim2.fromScale(0.68, 0.12),
		UDim2.fromScale(0.3, 0.6)
	)
	theirCards = makeList(theirs, UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.92, 0.46))
	local get = makeLabel("Coin", "", UDim2.fromScale(0.92, 0.1), UDim2.fromScale(0.04, 0.6), 18)
	get.TextColor3 = COIN_COLOR
	get.Parent = theirs
	theirCoin = get

	local status =
		makeLabel("Status", "", UDim2.fromScale(0.96, 0.08), UDim2.fromScale(0.02, 0.74), 18)
	status.TextColor3 = TEXT_DIM
	status.Parent = frame
	statusLabel = status

	local confirm = makeButton("Confirm", "Confirm", ACCEPT_COLOR)
	confirm.AnchorPoint = Vector2.new(0, 1)
	confirm.Position = UDim2.fromScale(0.1, 0.96)
	confirm.Size = UDim2.fromScale(0.35, 0.1)
	confirm.Activated:Connect(function()
		if confirm.Active then
			handlers.action({ kind = "confirm" })
		end
	end)
	confirm.Parent = frame
	confirmButton = confirm

	local cancel = makeButton("Cancel", "Cancel", BUTTON_COLOR)
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.Position = UDim2.fromScale(0.9, 0.96)
	cancel.Size = UDim2.fromScale(0.35, 0.1)
	cancel.Activated:Connect(function()
		handlers.action({ kind = "cancel" })
	end)
	cancel.Parent = frame

	frame.Parent = gui
	window = frame
end

function TradeUI.mount(playerGui: PlayerGui, given: Handlers)
	handlers = given

	local gui = Instance.new("ScreenGui")
	gui.Name = "TradeGui"
	gui.ResetOnSpawn = false
	-- With the other windows; below the messages (20).
	gui.DisplayOrder = 16

	-- Above the Ledger button (bottom 97%, height 7%) and the Paths button (bottom 89%).
	local button = makeButton("TradeButton", "Trade", BUTTON_COLOR)
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.fromScale(0.02, 0.81)
	button.Size = UDim2.fromScale(0.14, 0.07)
	local limit = button:FindFirstChildOfClass("UITextSizeConstraint")
	if limit ~= nil then
		limit.MinTextSize = 12
	end
	button.Activated:Connect(function()
		handlers.request()
	end)
	button.Parent = gui

	buildInvite(gui)
	buildWindow(gui)
	gui.Parent = playerGui

	-- The confirm wait counts down here, not on the server.
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			updateConfirm()
		end
	end)
end

-- A banner asking to trade; it goes away by itself after `seconds`. nil hides it.
function TradeUI.showInvite(invite: { from: string, seconds: number }?)
	local banner = inviteBanner
	local label = inviteLabel
	if banner == nil or label == nil then
		return
	end
	hideInvite()
	if invite == nil then
		return
	end
	label.Text = invite.from .. " wants to trade"
	banner.Visible = true
	local token = inviteToken
	task.delay(invite.seconds, function()
		if inviteToken == token then
			hideInvite()
		end
	end)
end

-- Shows the trade as the server sees it. nil closes the window.
function TradeUI.render(view: Trade.View?)
	local frame = window
	local free = freeList
	local mine = mineCards
	local theirs = theirCards
	if frame == nil or free == nil or mine == nil or theirs == nil then
		return
	end
	current = view
	if view == nil then
		frame.Visible = false
		return
	end
	arrivedAt = os.clock()
	if titleLabel ~= nil then
		titleLabel.Text = "Trade with " .. view.otherName
	end
	if statusLabel ~= nil then
		statusLabel.Text = view.status
	end
	if mineCoin ~= nil then
		mineCoin.Text = "Coin: " .. view.mine.coin .. " (of " .. view.coinHeld .. ")"
	end
	if theirCoin ~= nil then
		theirCoin.Text = "Coin: " .. view.theirs.coin
	end
	cardNames(view.mine.cards, mine)
	cardNames(view.theirs.cards, theirs)

	clearRows(free)
	for _, row in view.free do
		local button = makeButton("Free" .. row.index, row.name, FREE_COLOR)
		button.LayoutOrder = row.index
		button.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
		button.TextColor3 = TEXT_DARK
		if row.offered then
			-- The marked look: green with a border.
			button.BackgroundColor3 = OFFERED_COLOR
			local stroke = Instance.new("UIStroke")
			stroke.Color = TEXT_LIGHT
			stroke.Thickness = 2
			stroke.Parent = button
		end
		button.Activated:Connect(function()
			toggleCard(row)
		end)
		button.Parent = free
	end
	updateConfirm()
	frame.Visible = true
end

function TradeUI.isOpen(): boolean
	local frame = window
	return frame ~= nil and frame.Visible
end

return TradeUI
