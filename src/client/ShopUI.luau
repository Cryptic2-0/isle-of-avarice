--!strict
-- The Edict Hall window: buy a pack, buy a Relic from the stock, or sell a free-slot card.
-- It shows the view the server sent and asks; the server checks prices and holdings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared:WaitForChild("Rules"):WaitForChild("Shop"))
local DialogLayout = require(script.Parent.DialogLayout)

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local TEXT_DIM = Color3.fromRGB(170, 165, 160)
local COIN_COLOR = Color3.fromRGB(255, 215, 90)
local PANEL_COLOR = Color3.fromRGB(32, 28, 38)
local ROW_COLOR = Color3.fromRGB(45, 40, 55)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)
local BUY_COLOR = Color3.fromRGB(60, 130, 80)
local ROW_HEIGHT = 40

local ShopUI = {}

local window: Frame? = nil
local coinLabel: TextLabel? = nil
local packLabel: TextLabel? = nil
local oddsLabel: TextLabel? = nil
local packButton: TextButton? = nil
local stockList: ScrollingFrame? = nil
local sellList: ScrollingFrame? = nil
local actionHandler: (request: { [string]: any }) -> () = function(_request: { [string]: any }) end
-- One request per rendered view: a second click before the new view arrives would spend a
-- second identical card or a second purchase.
local lastView: Shop.View? = nil
local viewSerial = 0
local requestSent = false
local RETRY_SECONDS = 1

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

local function makeScroller(name: string, position: UDim2, size: UDim2): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = name
	scroller.Position = position
	scroller.Size = size
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 6
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroller
	return scroller
end

local function clearRows(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

-- One list row: name on the left, price, then the button.
local function makeRow(
	name: string,
	order: number,
	text: string,
	priceText: string,
	buttonText: string
): (Frame, TextButton)
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	row.BackgroundColor3 = ROW_COLOR
	addCorner(row, 8)

	local label =
		makeLabel("Name", text, UDim2.fromScale(0.46, 0.8), UDim2.fromScale(0.02, 0.1), 20)
	label.Parent = row

	local price =
		makeLabel("Price", priceText, UDim2.fromScale(0.25, 0.8), UDim2.fromScale(0.49, 0.1), 18)
	price.TextColor3 = COIN_COLOR
	price.Parent = row

	local button = makeButton("Action", buttonText, BUY_COLOR)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(0.98, 0.5)
	button.Size = UDim2.fromScale(0.21, 0.8)
	button.Parent = row
	return row, button
end

local function dimButtons()
	for _, container in { stockList, sellList } do
		if container ~= nil then
			for _, descendant in container:GetDescendants() do
				if descendant:IsA("TextButton") then
					setEnabled(descendant, false)
				end
			end
		end
	end
	if packButton ~= nil then
		setEnabled(packButton, false)
	end
end

-- Sends at most one request per view. The server answers every request, but only a success
-- sends a new view; so after a second without one the old view is drawn again, and a refused
-- purchase does not leave the window dead.
local function send(request: { [string]: any })
	if requestSent then
		return
	end
	requestSent = true
	dimButtons()
	actionHandler(request)
	local serial = viewSerial
	task.delay(RETRY_SECONDS, function()
		local view = lastView
		if requestSent and serial == viewSerial and view ~= nil and ShopUI.isOpen() then
			ShopUI.show(view)
		end
	end)
end

local function hide()
	local frame = window
	if frame ~= nil then
		frame.Visible = false
	end
end

function ShopUI.mount(playerGui: PlayerGui, onAction: (request: { [string]: any }) -> ())
	actionHandler = onAction

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false
	-- With the other windows; below the messages (20).
	gui.DisplayOrder = 16

	local frame = Instance.new("Frame")
	frame.Name = "Shop"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.7, 0.82)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.Visible = false
	addCorner(frame, 14)
	local title = makeLabel(
		"Title",
		"Edict Hall",
		UDim2.fromScale(0.5, 0.07),
		UDim2.fromScale(0.04, 0.02),
		30
	)
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local coin = makeLabel("Coin", "", UDim2.fromScale(0.4, 0.07), UDim2.fromScale(0.56, 0.02), 24)
	coin.TextColor3 = COIN_COLOR
	coin.TextXAlignment = Enum.TextXAlignment.Right
	coin.Parent = frame
	coinLabel = coin

	-- The pack row.
	local pack = makeLabel("Pack", "", UDim2.fromScale(0.62, 0.06), UDim2.fromScale(0.04, 0.1), 22)
	pack.Parent = frame
	packLabel = pack
	local odds = makeLabel("Odds", "", UDim2.fromScale(0.62, 0.05), UDim2.fromScale(0.04, 0.16), 14)
	odds.TextColor3 = TEXT_DIM
	odds.Parent = frame
	oddsLabel = odds
	local buyPack = makeButton("BuyPack", "Buy", BUY_COLOR)
	buyPack.AnchorPoint = Vector2.new(1, 0)
	buyPack.Position = UDim2.fromScale(0.96, 0.105)
	buyPack.Size = UDim2.fromScale(0.24, 0.09)
	buyPack.Activated:Connect(function()
		if buyPack.Active then
			send({ kind = "pack" })
		end
	end)
	buyPack.Parent = frame
	packButton = buyPack

	-- Relics for sale.
	local stockHeading = makeLabel(
		"StockHeading",
		"Relics for sale",
		UDim2.fromScale(0.9, 0.05),
		UDim2.fromScale(0.04, 0.23),
		18
	)
	stockHeading.Parent = frame
	local stock = makeScroller("Stock", UDim2.fromScale(0.04, 0.285), UDim2.fromScale(0.92, 0.27))
	stock.Parent = frame
	stockList = stock

	-- Cards to sell.
	local sellHeading = makeLabel(
		"SellHeading",
		"Sell a free-slot card",
		UDim2.fromScale(0.9, 0.05),
		UDim2.fromScale(0.04, 0.575),
		18
	)
	sellHeading.Parent = frame
	local sell = makeScroller("Sell", UDim2.fromScale(0.04, 0.63), UDim2.fromScale(0.92, 0.22))
	sell.Parent = frame
	sellList = sell

	local close = makeButton("Close", "Close", BUTTON_COLOR)
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.fromScale(0.5, 0.97)
	close.Size = UDim2.fromScale(0.36, 0.09)
	close.Activated:Connect(hide)
	close.Parent = frame

	frame.Parent = gui
	window = frame
	gui.Parent = playerGui
	-- Split the space between the pack and the pinned Close button between the two lists.
	DialogLayout.bind(gui, frame, Vector2.new(320, 340), {
		{ object = title, position = UDim2.new(0.04, 0, 0, 6), size = UDim2.new(0.5, 0, 0, 24) },
		{ object = coin, position = UDim2.new(0.56, 0, 0, 6), size = UDim2.new(0.4, 0, 0, 24) },
		{ object = pack, position = UDim2.new(0.04, 0, 0, 32), size = UDim2.new(0.62, 0, 0, 22) },
		{ object = odds, position = UDim2.new(0.04, 0, 0, 54), size = UDim2.new(0.62, 0, 0, 22) },
		{
			object = buyPack,
			position = UDim2.new(0.96, 0, 0, 32),
			size = UDim2.new(0.24, 0, 0, 44),
		},
		{
			object = stockHeading,
			position = UDim2.new(0.04, 0, 0, 80),
			size = UDim2.new(0.92, 0, 0, 18),
		},
		{
			object = stock,
			position = UDim2.new(0.04, 0, 0, 98),
			size = UDim2.new(0.92, 0, 0.5, -90),
		},
		{
			object = sellHeading,
			position = UDim2.new(0.04, 0, 0.5, 14),
			size = UDim2.new(0.92, 0, 0, 18),
		},
		{
			object = sell,
			position = UDim2.new(0.04, 0, 0.5, 32),
			size = UDim2.new(0.92, 0, 0.5, -90),
		},
		{ object = close, position = UDim2.new(0.5, 0, 1, -8), size = UDim2.new(0.36, 0, 0, 44) },
	})
end

-- Opens the window, or refreshes it when it is already open.
function ShopUI.show(view: Shop.View)
	local frame = window
	local stock = stockList
	local sell = sellList
	if frame == nil or stock == nil or sell == nil then
		return
	end
	lastView = view
	viewSerial += 1
	requestSent = false
	if coinLabel ~= nil then
		coinLabel.Text = view.coinText
	end
	if packLabel ~= nil then
		packLabel.Text = view.packText
	end
	if oddsLabel ~= nil then
		oddsLabel.Text = view.oddsText
	end
	local pack = packButton
	if pack ~= nil then
		setEnabled(pack, view.canBuyPack)
	end

	clearRows(stock)
	for index, row in view.stock do
		local made, button = makeRow("Stock_" .. row.relicId, index, row.name, row.priceText, "Buy")
		setEnabled(button, row.canBuy)
		button.Activated:Connect(function()
			if button.Active then
				send({ kind = "relic", relicId = row.relicId })
			end
		end)
		made.Parent = stock
	end

	clearRows(sell)
	if #view.sell == 0 then
		local none = makeLabel(
			"Nothing",
			"Nothing to sell.",
			UDim2.new(1, 0, 0, ROW_HEIGHT),
			UDim2.new(),
			18
		)
		none.TextColor3 = TEXT_DIM
		none.Parent = sell
	end
	for order, row in view.sell do
		local made, button = makeRow("Sell" .. row.index, order, row.name, row.priceText, "Sell")
		button.Activated:Connect(function()
			if button.Active then
				send({ kind = "sell", freeIndex = row.index, cardId = row.cardId })
			end
		end)
		made.Parent = sell
	end
	frame.Visible = true
end

function ShopUI.isOpen(): boolean
	local frame = window
	return frame ~= nil and frame.Visible
end

return ShopUI
