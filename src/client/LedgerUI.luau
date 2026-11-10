--!strict
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tiers = require(Shared:WaitForChild("Catalog"):WaitForChild("Tiers"))
local LedgerView = require(Shared:WaitForChild("Rules"):WaitForChild("LedgerView"))
local Types = require(Shared:WaitForChild("Types"))

type View = LedgerView.View

local LedgerUI = {}

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local TEXT_DIM = Color3.fromRGB(130, 130, 135)
local PANEL_COLOR = Color3.fromRGB(32, 28, 38)
local LOCKED_COLOR = Color3.fromRGB(55, 55, 60)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)

local panel: Frame? = nil
local slotGrid: ScrollingFrame? = nil
local freeList: ScrollingFrame? = nil
local progressLabel: TextLabel? = nil
local freeLabel: TextLabel? = nil
local actionHandler: (request: { [string]: any }) -> () = function(_request: { [string]: any }) end

local function tierColor(tier: Types.Tier): Color3
	local color = Tiers.info[tier].color
	return Color3.fromRGB(color.r, color.g, color.b)
end

local function addCorner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function addPadding(parent: Instance, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.Parent = parent
end

local function limitText(parent: Instance, minSize: number, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = parent
end

local function makeLabel(name: string, size: UDim2, position: UDim2, maxText: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.TextColor3 = TEXT_LIGHT
	label.TextScaled = true
	label.Font = Enum.Font.GothamMedium
	label.Text = ""
	limitText(label, 10, maxText)
	return label
end

local function makeButton(name: string, text: string, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.BackgroundColor3 = BUTTON_COLOR
	button.TextColor3 = TEXT_LIGHT
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.AutoButtonColor = true
	addCorner(button, 8)
	limitText(button, 10, 22)
	return button
end

-- Destroys every child except layout objects.
local function clearRows(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

local function makeSlot(slot: LedgerView.SlotView, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Slot" .. slot.label
	button.LayoutOrder = order
	button.AutoButtonColor = slot.claimed
	button.Font = Enum.Font.GothamMedium
	button.TextScaled = true
	button.TextWrapped = true
	if slot.claimed then
		button.BackgroundColor3 = tierColor(slot.tier)
		button.TextColor3 = Color3.fromRGB(20, 18, 24)
	else
		button.BackgroundColor3 = LOCKED_COLOR
		button.TextColor3 = TEXT_DIM
	end
	local text = slot.label .. "\n" .. slot.name
	if slot.spares > 0 then
		text ..= "\nx" .. slot.spares
	end
	button.Text = text
	addCorner(button, 8)
	addPadding(button, 4)
	limitText(button, 9, 20)
	if slot.claimed then
		button.Activated:Connect(function()
			actionHandler({ kind = "unclaim", cardId = slot.cardId })
		end)
	end
	return button
end

local function makeFreeRow(card: LedgerView.FreeView): Frame
	local row = Instance.new("Frame")
	row.Name = "Free" .. card.index
	row.LayoutOrder = card.index
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BackgroundColor3 = tierColor(card.tier)
	addCorner(row, 8)

	local name = makeLabel("Name", UDim2.fromScale(0.5, 1), UDim2.fromScale(0, 0), 22)
	name.TextColor3 = Color3.fromRGB(20, 18, 24)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = card.name
	addPadding(name, 6)
	name.Parent = row

	local discard = makeButton("Discard", "Discard", UDim2.new(0.22, 0, 1, -8))
	discard.AnchorPoint = Vector2.new(1, 0.5)
	discard.Position = UDim2.new(0.99, 0, 0.5, 0)
	discard.Activated:Connect(function()
		actionHandler({ kind = "discard", freeIndex = card.index, cardId = card.cardId })
	end)
	discard.Parent = row

	if card.canClaim then
		local claim = makeButton("Claim", "Claim", UDim2.new(0.22, 0, 1, -8))
		claim.AnchorPoint = Vector2.new(1, 0.5)
		claim.Position = UDim2.new(0.75, 0, 0.5, 0)
		claim.Activated:Connect(function()
			actionHandler({ kind = "claim", freeIndex = card.index, cardId = card.cardId })
		end)
		claim.Parent = row
	end
	return row
end

function LedgerUI.mount(playerGui: PlayerGui, onAction: (request: { [string]: any }) -> ())
	actionHandler = onAction

	local gui = Instance.new("ScreenGui")
	gui.Name = "LedgerGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10

	local openButton = makeButton("OpenButton", "Ledger", UDim2.fromScale(0.14, 0.07))
	openButton.AnchorPoint = Vector2.new(0, 1)
	openButton.Position = UDim2.fromScale(0.02, 0.97)
	local openLimit = openButton:FindFirstChildOfClass("UITextSizeConstraint")
	if openLimit ~= nil then
		openLimit.MinTextSize = 12
	end
	openButton.Activated:Connect(LedgerUI.toggle)
	openButton.Parent = gui

	local book = Instance.new("Frame")
	book.Name = "Book"
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	book.Position = UDim2.fromScale(0.5, 0.5)
	book.Size = UDim2.fromScale(0.7, 0.7)
	book.BackgroundColor3 = PANEL_COLOR
	book.Visible = false
	addCorner(book, 14)

	local title = makeLabel("Title", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.02, 0.02), 30)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "The Hoarder's Ledger"
	title.Parent = book

	local closeButton = makeButton("Close", "X", UDim2.fromScale(0.08, 0.08))
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(0.98, 0.02)
	closeButton.Activated:Connect(LedgerUI.toggle)
	closeButton.Parent = book

	local progress =
		makeLabel("Progress", UDim2.fromScale(0.46, 0.05), UDim2.fromScale(0.02, 0.11), 20)
	progress.TextXAlignment = Enum.TextXAlignment.Left
	progress.Parent = book
	progressLabel = progress

	local free =
		makeLabel("FreeCount", UDim2.fromScale(0.46, 0.05), UDim2.fromScale(0.52, 0.11), 20)
	free.TextXAlignment = Enum.TextXAlignment.Left
	free.Parent = book
	freeLabel = free

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Slots"
	grid.Position = UDim2.fromScale(0.02, 0.17)
	grid.Size = UDim2.fromScale(0.46, 0.8)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.31, 0, 0, 78)
	gridLayout.CellPadding = UDim2.new(0.03, 0, 0, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	grid.Parent = book
	slotGrid = grid

	local list = Instance.new("ScrollingFrame")
	list.Name = "FreeCards"
	list.Position = UDim2.fromScale(0.52, 0.17)
	list.Size = UDim2.fromScale(0.46, 0.8)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
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

	clearRows(grid)
	for index, slot in view.slots do
		makeSlot(slot, index).Parent = grid
	end
	clearRows(list)
	for _, card in view.free do
		makeFreeRow(card).Parent = list
	end
end

function LedgerUI.toggle()
	local book = panel
	if book ~= nil then
		book.Visible = not book.Visible
	end
end

return LedgerUI
