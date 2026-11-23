--!strict
-- Trading: the "Trade" button, the invite banner and the trade window. It shows the view the
-- server sent and sends the player's whole new offer on every change; the server checks it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trade = require(Shared:WaitForChild("Rules"):WaitForChild("Trade"))
local UiKit = require(script.Parent.UiKit)

local TEXT_DIM = Color3.fromRGB(170, 165, 160)
local COIN_COLOR = Color3.fromRGB(255, 215, 90)
local COLUMN_COLOR = Color3.fromRGB(42, 37, 50)
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
local cancelButton: TextButton? = nil
-- The buttons that go inert with the window while a request is out (Confirm has its own rule).
local freeButtons: { TextButton } = {}
local coinButtons: { TextButton } = {}
-- The view on screen and when it arrived (local clock); the confirm wait counts down from it.
local current: Trade.View? = nil
local arrivedAt = 0
local ticking = false
-- Bumped on every invite change, so an old invite's timer cannot hide a newer one.
local inviteToken = 0

-- Confirm is inert after you confirmed, while the server's wait has not passed and while a
-- request is out.
local updateConfirm: () -> ()

-- One request at a time: the whole window waits for the server's next view.
local guard: UiKit.Guard = UiKit.guard(function(inert: boolean)
	for _, button in freeButtons do
		UiKit.setEnabled(button, not inert)
	end
	for _, button in coinButtons do
		UiKit.setEnabled(button, not inert)
	end
	local cancel = cancelButton
	if cancel ~= nil then
		UiKit.setEnabled(cancel, not inert)
	end
	updateConfirm()
end)

function updateConfirm()
	local view = current
	local button = confirmButton
	if view == nil or button == nil then
		return
	end
	local waited = os.clock() - arrivedAt
	local ready = not view.mineConfirmed and waited >= view.confirmIn
	UiKit.setEnabled(button, ready and not guard.busy)
	if view.mineConfirmed then
		button.Text = "Confirmed"
	elseif ready then
		button.Text = "Confirm"
	else
		button.Text = "Confirm (" .. math.ceil(view.confirmIn - waited) .. ")"
	end
end

local function sendAction(request: { [string]: any })
	UiKit.send(guard, function()
		handlers.action(request)
	end)
end

local function makeList(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	local scroller = UiKit.scroller("Cards", size, position, 5)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroller
	scroller.Parent = parent
	return scroller
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
	UiKit.corner(column, 10)
	local title = UiKit.label(
		"Heading",
		heading,
		UDim2.fromScale(0.92, 0.09),
		UDim2.fromScale(0.04, 0.02),
		{ max = 18, font = Enum.Font.GothamBold }
	)
	title.Parent = column
	column.Parent = parent
	return column
end

local function cardNames(cards: { Trade.CardView }, list: ScrollingFrame)
	UiKit.clearRows(list)
	for index, card in cards do
		local label =
			UiKit.label("Card" .. index, card.name, UDim2.new(1, -6, 0, 28), UDim2.new(), {
				max = 18,
			})
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
	sendAction({ kind = "offer", cards = cards, coin = coin })
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
	-- Below the region banner (top 12% to 17%).
	banner.Position = UDim2.fromScale(0.5, 0.18)
	banner.Size = UDim2.fromScale(0.5, 0.09)
	banner.BackgroundColor3 = UiKit.PANEL
	banner.Visible = false
	UiKit.corner(banner, 10)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(300, 44)
	minimum.Parent = banner

	local label = UiKit.label(
		"Text",
		"",
		UDim2.fromScale(0.44, 0.8),
		UDim2.fromScale(0.03, 0.1),
		{ max = 20 }
	)
	label.Parent = banner
	inviteLabel = label

	local accept = UiKit.button("Accept", "Accept", nil, { color = ACCEPT_COLOR })
	accept.Position = UDim2.fromScale(0.49, 0.12)
	accept.Size = UDim2.fromScale(0.24, 0.76)
	UiKit.onPress(accept, function()
		hideInvite()
		handlers.reply(true)
	end)
	accept.Parent = banner

	local decline = UiKit.button("Decline", "Decline", nil)
	decline.Position = UDim2.fromScale(0.74, 0.12)
	decline.Size = UDim2.fromScale(0.24, 0.76)
	UiKit.onPress(decline, function()
		hideInvite()
		handlers.reply(false)
	end)
	decline.Parent = banner

	banner.Parent = gui
	inviteBanner = banner
end

local function buildWindow(gui: ScreenGui)
	local frame = UiKit.window("Trade", UDim2.fromScale(0.82, 0.8), "big")

	local title = UiKit.label(
		"Title",
		"",
		UDim2.fromScale(0.92, 0.08),
		UDim2.fromScale(0.04, 0.02),
		{ max = 28, font = Enum.Font.GothamBold }
	)
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
	local give = UiKit.label(
		"Coin",
		"",
		UDim2.fromScale(0.92, 0.1),
		UDim2.fromScale(0.04, 0.6),
		{ max = 18, color = COIN_COLOR }
	)
	give.Parent = mine
	mineCoin = give
	for index, step in COIN_STEPS do
		local text = if step > 0 then "+" .. step else tostring(step)
		local button = UiKit.button("Coin" .. text, text, nil)
		button.Position = UDim2.fromScale(0.04 + (index - 1) * 0.24, 0.73)
		button.Size = UDim2.fromScale(0.22, 0.2)
		UiKit.onPress(button, function()
			changeCoin(step)
		end)
		button.Parent = mine
		table.insert(coinButtons, button)
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
	local get = UiKit.label(
		"Coin",
		"",
		UDim2.fromScale(0.92, 0.1),
		UDim2.fromScale(0.04, 0.6),
		{ max = 18, color = COIN_COLOR }
	)
	get.Parent = theirs
	theirCoin = get

	local status = UiKit.label(
		"Status",
		"",
		UDim2.fromScale(0.96, 0.08),
		UDim2.fromScale(0.02, 0.74),
		{ max = 18, color = TEXT_DIM }
	)
	status.Parent = frame
	statusLabel = status

	local confirm = UiKit.button("Confirm", "Confirm", nil, { color = ACCEPT_COLOR })
	confirm.AnchorPoint = Vector2.new(0, 1)
	confirm.Position = UDim2.fromScale(0.1, 0.96)
	confirm.Size = UDim2.fromScale(0.35, 0.1)
	UiKit.onPress(confirm, function()
		sendAction({ kind = "confirm" })
	end)
	confirm.Parent = frame
	confirmButton = confirm

	local cancel = UiKit.button("Cancel", "Cancel", nil)
	cancel.AnchorPoint = Vector2.new(1, 1)
	cancel.Position = UDim2.fromScale(0.9, 0.96)
	cancel.Size = UDim2.fromScale(0.35, 0.1)
	UiKit.onPress(cancel, function()
		sendAction({ kind = "cancel" })
	end)
	cancel.Parent = frame
	cancelButton = cancel

	frame.Parent = gui
	window = frame
end

function TradeUI.mount(playerGui: PlayerGui, given: Handlers)
	handlers = given

	-- With the other windows; below the messages (20).
	local gui = UiKit.screen("TradeGui", 16)

	buildInvite(gui)
	buildWindow(gui)
	gui.Parent = playerGui
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

-- The confirm wait counts down here, not on the server; the loop runs only while a trade is open.
local function startTicking()
	if ticking then
		return
	end
	ticking = true
	task.spawn(function()
		while current ~= nil do
			updateConfirm()
			task.wait(TICK_SECONDS)
		end
		ticking = false
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
		UiKit.answered(guard)
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

	UiKit.clearRows(free)
	freeButtons = {}
	for _, row in view.free do
		local button = UiKit.button("Free" .. row.index, row.name, nil, {
			color = FREE_COLOR,
			textColor = UiKit.TEXT_DARK,
		})
		button.LayoutOrder = row.index
		button.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
		if row.offered then
			-- The marked look: green with a border.
			button.BackgroundColor3 = OFFERED_COLOR
			local stroke = Instance.new("UIStroke")
			stroke.Color = UiKit.TEXT_LIGHT
			stroke.Thickness = 2
			stroke.Parent = button
		end
		UiKit.onPress(button, function()
			toggleCard(row)
		end)
		button.Parent = free
		table.insert(freeButtons, button)
	end
	updateConfirm()
	frame.Visible = true
	startTicking()
	UiKit.answered(guard)
end

function TradeUI.isOpen(): boolean
	local frame = window
	return frame ~= nil and frame.Visible
end

return TradeUI
