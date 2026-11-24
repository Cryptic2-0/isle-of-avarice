--!strict
-- Top-left: the Coin line, the status lines (region, safe zone, shields, Marked, Veil, hazards) and
-- the "Drop shield" button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudLayout = require(Shared:WaitForChild("Rules"):WaitForChild("HudLayout"))
local StatusView = require(Shared:WaitForChild("Rules"):WaitForChild("StatusView"))
local UiKit = require(script.Parent.UiKit)

local StatusHUD = {}

local BACKGROUND = Color3.fromRGB(25, 22, 30)
local KIND_COLORS: { [string]: Color3 } = {
	region = Color3.fromRGB(245, 235, 210),
	hazard = Color3.fromRGB(255, 170, 60),
	safe = Color3.fromRGB(90, 200, 110),
	shield = Color3.fromRGB(110, 170, 255),
	marked = Color3.fromRGB(235, 70, 70),
	veil = Color3.fromRGB(170, 140, 220),
}

local COIN_COLOR = Color3.fromRGB(255, 215, 90)
local COIN_HEIGHT = 28
-- Under the Coin line: the Drop shield button sits here, and the lines move below it while it shows.
local DROP_Y = 44
local LINES_BELOW_DROP_Y = DROP_Y + 36

local column: Frame? = nil
local coinLabel: TextLabel? = nil
local dropButton: TextButton? = nil
local confirm: Frame? = nil
-- Text of the lines on screen, so an unchanged render does nothing.
local shownKey = ""
-- Whether the Drop shield button was showing at the last render.
local dropShown = false

local function buildConfirm(gui: ScreenGui, onDropShield: () -> ()): Frame
	local frame = UiKit.window("ConfirmDrop", UDim2.fromScale(0.4, 0.22), "dialog")

	UiKit.label(
		"Question",
		"Other players will be able to attack you. Drop it?",
		UDim2.fromScale(0.9, 0.5),
		UDim2.fromScale(0.05, 0.08),
		{ min = 10, max = 24, align = Enum.TextXAlignment.Center }
	).Parent =
		frame

	local yes = UiKit.button("Yes", "Yes", UDim2.fromScale(0.35, 0.25), { min = 10, max = 20 })
	yes.Position = UDim2.fromScale(0.1, 0.65)
	UiKit.onPress(yes, function()
		frame.Visible = false
		onDropShield()
	end)
	yes.Parent = frame

	local no = UiKit.button("No", "No", UDim2.fromScale(0.35, 0.25), { min = 10, max = 20 })
	no.Position = UDim2.fromScale(0.55, 0.65)
	UiKit.onPress(no, function()
		frame.Visible = false
	end)
	no.Parent = frame

	frame.Parent = gui
	return frame
end

function StatusHUD.mount(playerGui: PlayerGui, onDropShield: () -> ())
	-- The lines sit under every window (the lowest is the Ledger, 10); the dialog is a window of
	-- its own, above them.
	local gui = UiKit.screen("StatusGui", 8)
	local dialogGui = UiKit.screen("DropShieldGui", 15)

	local coin = Instance.new("TextLabel")
	coin.Name = "Coin"
	coin.Position = UDim2.new(0, 12, 0, 12)
	coin.Size = UDim2.new(0, 230, 0, COIN_HEIGHT)
	coin.BackgroundColor3 = BACKGROUND
	coin.BackgroundTransparency = 0.3
	coin.TextColor3 = COIN_COLOR
	coin.TextScaled = true
	coin.TextXAlignment = Enum.TextXAlignment.Left
	coin.Font = Enum.Font.GothamBold
	coin.Text = "Coin: 0"
	UiKit.corner(coin, 6)
	local coinPadding = Instance.new("UIPadding")
	coinPadding.PaddingLeft = UDim.new(0, 8)
	coinPadding.PaddingTop = UDim.new(0, 4)
	coinPadding.PaddingBottom = UDim.new(0, 4)
	coinPadding.Parent = coin
	UiKit.limitText(coin, 10, 20)
	coin.Parent = gui
	coinLabel = coin

	local list = Instance.new("Frame")
	list.Name = "Lines"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, DROP_Y)
	list.Size = UDim2.fromOffset(230, 192)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	list.Parent = gui
	column = list

	-- (12, 44) under the top bar, the same rectangle as HudLayout.dropShield.
	local drop = UiKit.button("DropShield", "Drop shield", UDim2.fromOffset(150, 32), {
		min = 10,
		max = 20,
	})
	drop.Position = UDim2.fromOffset(12, DROP_Y)
	drop.Visible = false
	drop.Parent = gui
	dropButton = drop

	local dialog = buildConfirm(dialogGui, onDropShield)
	confirm = dialog
	UiKit.onPress(drop, function()
		dialog.Visible = true
	end)

	dialogGui.Parent = playerGui
	gui.Parent = playerGui
end

-- "Coin: 120" above the status lines.
function StatusHUD.setCoin(coin: number)
	local label = coinLabel
	if label ~= nil then
		label.Text = "Coin: " .. tostring(math.floor(coin))
	end
end

function StatusHUD.render(lines: { StatusView.Line }, showDropShield: boolean)
	local drop = dropButton
	if drop ~= nil then
		drop.Visible = showDropShield
	end
	local dialog = confirm
	if dialog ~= nil and not showDropShield then
		dialog.Visible = false
	end

	local list = column
	if list == nil then
		return
	end
	-- The lines make room under the button while it shows.
	if showDropShield ~= dropShown then
		dropShown = showDropShield
		list.Position = UDim2.fromOffset(12, if showDropShield then LINES_BELOW_DROP_Y else DROP_Y)
	end
	-- On a touch screen the column stops above the thumbstick: the most urgent lines stay.
	local room = HudLayout.statusLines(UiKit.layout(), UiKit.inset(), showDropShield)
	lines = StatusView.fit(lines, room)
	local parts: { string } = {}
	for _, line in lines do
		table.insert(parts, line.kind .. ":" .. line.text)
	end
	local key = table.concat(parts, "|")
	if key == shownKey then
		return
	end
	shownKey = key

	UiKit.clearRows(list)
	for index, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. index
		label.LayoutOrder = index
		label.Size = UDim2.new(1, 0, 0, 28)
		label.BackgroundColor3 = BACKGROUND
		label.BackgroundTransparency = 0.3
		label.TextColor3 = KIND_COLORS[line.kind] or UiKit.TEXT_LIGHT
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = Enum.Font.GothamBold
		label.Text = line.text
		UiKit.corner(label, 6)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.Parent = label
		UiKit.limitText(label, 10, 20)
		label.Parent = list
	end
end

return StatusHUD
