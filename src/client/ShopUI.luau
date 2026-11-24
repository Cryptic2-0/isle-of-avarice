--!strict
-- The Edict Hall window: buy a pack, buy a Relic from the stock, or sell a free-slot card.
-- It shows the view the server sent and asks; the server checks prices and holdings.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared:WaitForChild("Rules"):WaitForChild("Shop"))
local UiKit = require(script.Parent.UiKit)

local TEXT_DIM = Color3.fromRGB(170, 165, 160)
local COIN_COLOR = Color3.fromRGB(255, 215, 90)
local ROW_COLOR = Color3.fromRGB(45, 40, 55)
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
-- What the last view allowed, so a guard coming back restores it without drawing a row again.
local packEnabled = false
local rowButtons: { { button: TextButton, enabled: boolean } } = {}

-- One request per rendered view: a second click before the new view arrives would spend a
-- second identical card or a second purchase.
local guard = UiKit.guard(function(inert: boolean)
	local pack = packButton
	if pack ~= nil then
		UiKit.setEnabled(pack, not inert and packEnabled)
	end
	for _, entry in rowButtons do
		UiKit.setEnabled(entry.button, not inert and entry.enabled)
	end
end)

local function send(request: { [string]: any })
	UiKit.send(guard, function()
		actionHandler(request)
	end)
end

local function makeScroller(name: string, position: UDim2, size: UDim2): ScrollingFrame
	local scroller = UiKit.scroller(name, size, position)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroller
	return scroller
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
	UiKit.corner(row, 8)

	local label =
		UiKit.label("Name", text, UDim2.fromScale(0.46, 0.8), UDim2.fromScale(0.02, 0.1), {
			max = 20,
		})
	label.Parent = row

	local price =
		UiKit.label("Price", priceText, UDim2.fromScale(0.25, 0.8), UDim2.fromScale(0.49, 0.1), {
			max = 18,
			color = COIN_COLOR,
		})
	price.Parent = row

	local button = UiKit.button("Action", buttonText, nil, { color = BUY_COLOR })
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(0.98, 0.5)
	button.Size = UDim2.fromScale(0.21, 0.8)
	button.Parent = row
	return row, button
end

local function hide()
	local frame = window
	if frame ~= nil then
		frame.Visible = false
	end
end

function ShopUI.mount(playerGui: PlayerGui, onAction: (request: { [string]: any }) -> ())
	actionHandler = onAction

	-- With the other windows; below the messages (20).
	local gui = UiKit.screen("ShopGui", 16)

	local frame = UiKit.window("Shop", UDim2.fromScale(0.7, 0.82), "big")

	local title = UiKit.label(
		"Title",
		"Edict Hall",
		UDim2.fromScale(0.5, 0.07),
		UDim2.fromScale(0.04, 0.02),
		{ max = 30, font = Enum.Font.GothamBold }
	)
	title.Parent = frame

	local coin = UiKit.label(
		"Coin",
		"",
		UDim2.fromScale(0.4, 0.07),
		UDim2.fromScale(0.56, 0.02),
		{ max = 24, color = COIN_COLOR, align = Enum.TextXAlignment.Right }
	)
	coin.Parent = frame
	coinLabel = coin

	-- The pack row.
	local pack = UiKit.label(
		"Pack",
		"",
		UDim2.fromScale(0.62, 0.06),
		UDim2.fromScale(0.04, 0.1),
		{ max = 22 }
	)
	pack.Parent = frame
	packLabel = pack
	local odds = UiKit.label(
		"Odds",
		"",
		UDim2.fromScale(0.62, 0.05),
		UDim2.fromScale(0.04, 0.16),
		{ max = 14, color = TEXT_DIM }
	)
	odds.Parent = frame
	oddsLabel = odds
	local buyPack = UiKit.button("BuyPack", "Buy", nil, { color = BUY_COLOR })
	buyPack.AnchorPoint = Vector2.new(1, 0)
	buyPack.Position = UDim2.fromScale(0.96, 0.105)
	buyPack.Size = UDim2.fromScale(0.24, 0.09)
	UiKit.onPress(buyPack, function()
		send({ kind = "pack" })
	end)
	buyPack.Parent = frame
	packButton = buyPack

	-- Relics for sale.
	UiKit.label(
		"StockHeading",
		"Relics for sale",
		UDim2.fromScale(0.9, 0.05),
		UDim2.fromScale(0.04, 0.23),
		{ max = 18 }
	).Parent =
		frame
	local stock = makeScroller("Stock", UDim2.fromScale(0.04, 0.285), UDim2.fromScale(0.92, 0.27))
	stock.Parent = frame
	stockList = stock

	-- Cards to sell.
	UiKit.label(
		"SellHeading",
		"Sell a free-slot card",
		UDim2.fromScale(0.9, 0.05),
		UDim2.fromScale(0.04, 0.575),
		{ max = 18 }
	).Parent =
		frame
	local sell = makeScroller("Sell", UDim2.fromScale(0.04, 0.63), UDim2.fromScale(0.92, 0.22))
	sell.Parent = frame
	sellList = sell

	local close = UiKit.button(
		"Close",
		"Close",
		UDim2.fromScale(0.36, 0.09),
		{ minSize = Vector2.new(40, 32) }
	)
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.fromScale(0.5, 0.97)
	UiKit.onPress(close, hide)
	close.Parent = frame

	frame.Parent = gui
	window = frame
	gui.Parent = playerGui
end

-- Opens the window, or refreshes it when it is already open.
function ShopUI.show(view: Shop.View)
	local frame = window
	local stock = stockList
	local sell = sellList
	if frame == nil or stock == nil or sell == nil then
		return
	end
	if coinLabel ~= nil then
		coinLabel.Text = view.coinText
	end
	if packLabel ~= nil then
		packLabel.Text = view.packText
	end
	if oddsLabel ~= nil then
		oddsLabel.Text = view.oddsText
	end
	packEnabled = view.canBuyPack
	local pack = packButton
	if pack ~= nil then
		UiKit.setEnabled(pack, packEnabled)
	end

	rowButtons = {}
	UiKit.clearRows(stock)
	for index, row in view.stock do
		local made, button = makeRow("Stock_" .. row.relicId, index, row.name, row.priceText, "Buy")
		UiKit.setEnabled(button, row.canBuy)
		table.insert(rowButtons, { button = button, enabled = row.canBuy })
		UiKit.onPress(button, function()
			send({ kind = "relic", relicId = row.relicId })
		end)
		made.Parent = stock
	end

	UiKit.clearRows(sell)
	if #view.sell == 0 then
		local none = UiKit.label(
			"Nothing",
			"Nothing to sell.",
			UDim2.new(1, 0, 0, ROW_HEIGHT),
			UDim2.new(),
			{ max = 18, color = TEXT_DIM }
		)
		none.Parent = sell
	end
	for order, row in view.sell do
		local made, button = makeRow("Sell" .. row.index, order, row.name, row.priceText, "Sell")
		table.insert(rowButtons, { button = button, enabled = true })
		UiKit.onPress(button, function()
			send({ kind = "sell", freeIndex = row.index, cardId = row.cardId })
		end)
		made.Parent = sell
	end
	frame.Visible = true
	UiKit.answered(guard)
end

function ShopUI.isOpen(): boolean
	local frame = window
	return frame ~= nil and frame.Visible
end

return ShopUI
