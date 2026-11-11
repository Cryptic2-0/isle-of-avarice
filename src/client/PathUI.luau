--!strict
-- Calling picker and Paths panel. Renders a PathView and sends requests; the server decides.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paths = require(Shared:WaitForChild("Catalog"):WaitForChild("Paths"))
local PathView = require(Shared:WaitForChild("Rules"):WaitForChild("PathView"))
local Types = require(Shared:WaitForChild("Types"))

type View = PathView.View
type RowView = PathView.RowView

export type Handlers = {
	pick: (path: string) -> (),
	change: (path: string) -> (),
	loadout: (request: { [string]: any }) -> (),
}

local PathUI = {}

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local TEXT_DIM = Color3.fromRGB(130, 130, 135)
local PANEL_COLOR = Color3.fromRGB(32, 28, 38)
local CARD_COLOR = Color3.fromRGB(46, 40, 56)
local LOCKED_COLOR = Color3.fromRGB(55, 55, 60)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)
local DARK_TEXT = Color3.fromRGB(20, 18, 24)
local ROW_HEIGHT = 196
local FALLBACK_COLOR = Color3.fromRGB(120, 120, 130)

local noop = function(_request: any) end
local handlers: Handlers = { pick = noop, change = noop, loadout = noop }

local panel: Frame? = nil
local picker: Frame? = nil
local confirm: Frame? = nil
local confirmQuestion: TextLabel? = nil
local rowList: ScrollingFrame? = nil
local pickerList: ScrollingFrame? = nil
local slotStrip: Frame? = nil
local callingLabel: TextLabel? = nil
local lastView: View? = nil
local pendingChange = ""
local dismissedPicker = false

local function pathColor(path: string): Color3
	local info = Paths.info[path :: Types.PathId]
	if info == nil then
		return FALLBACK_COLOR
	end
	return Color3.fromRGB(info.color.r, info.color.g, info.color.b)
end

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

local function makeLabel(name: string, size: UDim2, position: UDim2, maxText: number): TextLabel
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
	label.Text = ""
	limitText(label, 9, maxText)
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
	limitText(button, 10, 20)
	return button
end

local function makeScroller(name: string, size: UDim2, position: UDim2): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = name
	scroller.Size = size
	scroller.Position = position
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 6
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	return scroller
end

local function clearRows(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

-- The first empty loadout slot, or 4 when all are full (the server decides what happens then).
local function equipSlot(): number
	local view = lastView
	if view ~= nil then
		for _, slot in view.slots do
			if slot.abilityId == "" then
				return slot.slot
			end
		end
	end
	return 4
end

local function askChange(row: RowView)
	local dialog = confirm
	local question = confirmQuestion
	if dialog == nil or question == nil then
		return
	end
	pendingChange = row.path
	question.Text = "Change your Calling to "
		.. row.name
		.. "? Levels are kept; learning rates change."
	dialog.Visible = true
end

local function makeAbility(row: RowView, index: number): Frame
	local ability = row.abilities[index]
	local frame = Instance.new("Frame")
	frame.Name = "Ability" .. ability.id
	frame.Position = UDim2.new(0.01 + (index - 1) * 0.33, 0, 0, 62)
	frame.Size = UDim2.new(0.32, 0, 0, 126)
	frame.BackgroundColor3 = if ability.unlocked then CARD_COLOR else LOCKED_COLOR
	addCorner(frame, 8)

	local name = makeLabel("Name", UDim2.new(0.94, 0, 0, 22), UDim2.new(0.03, 0, 0, 4), 18)
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = if ability.unlocked then TEXT_LIGHT else TEXT_DIM
	name.Text = ability.name
	name.Parent = frame

	local description =
		makeLabel("Description", UDim2.new(0.94, 0, 0, 60), UDim2.new(0.03, 0, 0, 28), 15)
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.TextColor3 = if ability.unlocked then TEXT_LIGHT else TEXT_DIM
	description.Text = ability.description
	description.Parent = frame

	local bottomSize = UDim2.new(0.94, 0, 0, 28)
	local bottomPosition = UDim2.new(0.03, 0, 1, -32)
	if not ability.unlocked then
		local locked = makeLabel("Locked", bottomSize, bottomPosition, 16)
		locked.TextColor3 = TEXT_DIM
		locked.Text = "Level " .. ability.unlockLevel
		locked.Parent = frame
	elseif ability.equippedSlot > 0 then
		local equipped = makeLabel("Equipped", bottomSize, bottomPosition, 16)
		equipped.Text = "Equipped (slot " .. ability.equippedSlot .. ")"
		equipped.Parent = frame
	else
		local equip = makeButton("Equip" .. ability.id, "Equip", bottomSize)
		equip.Position = bottomPosition
		equip.Activated:Connect(function()
			handlers.loadout({ slot = equipSlot(), abilityId = ability.id })
		end)
		equip.Parent = frame
	end
	return frame
end

local function makeRow(row: RowView, order: number, needsCalling: boolean): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Row" .. row.path
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = PANEL_COLOR
	addCorner(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = pathColor(row.path)
	stroke.Thickness = if row.isCalling then 3 else 1
	stroke.Parent = frame

	local header = makeLabel("Header", UDim2.new(0.6, 0, 0, 28), UDim2.new(0.02, 0, 0, 6), 22)
	header.Font = Enum.Font.GothamBold
	header.TextColor3 = pathColor(row.path)
	header.Text = row.name .. "  Lv " .. row.level .. (if row.isCalling then "  (Calling)" else "")
	header.Parent = frame

	local detail = makeLabel("Detail", UDim2.new(0.96, 0, 0, 22), UDim2.new(0.02, 0, 0, 36), 16)
	detail.Text = row.style .. "  |  XP " .. row.xpText .. "  |  Rate " .. row.rateText
	detail.Parent = frame

	for index = 1, #row.abilities do
		makeAbility(row, index).Parent = frame
	end

	if needsCalling then
		local choose = makeButton("Choose", "Choose", UDim2.new(0.3, 0, 0, 28))
		choose.AnchorPoint = Vector2.new(1, 0)
		choose.Position = UDim2.new(0.98, 0, 0, 6)
		choose.Activated:Connect(function()
			handlers.pick(row.path)
		end)
		choose.Parent = frame
	elseif row.changeText ~= "" then
		local make = makeButton(
			"MakeCalling",
			"Make Calling (" .. row.changeText .. ")",
			UDim2.new(0.36, 0, 0, 28)
		)
		make.AnchorPoint = Vector2.new(1, 0)
		make.Position = UDim2.new(0.98, 0, 0, 6)
		make.Active = row.canChange
		make.AutoButtonColor = row.canChange
		if not row.canChange then
			make.BackgroundColor3 = LOCKED_COLOR
			make.TextColor3 = TEXT_DIM
		end
		make.Activated:Connect(function()
			if row.canChange then
				askChange(row)
			end
		end)
		make.Parent = frame
	end
	return frame
end

local function makeCard(row: RowView, order: number): Frame
	local card = Instance.new("Frame")
	card.Name = "Card" .. row.path
	card.LayoutOrder = order
	card.BackgroundColor3 = pathColor(row.path)
	addCorner(card, 10)

	local name = makeLabel("Name", UDim2.new(0.92, 0, 0, 26), UDim2.new(0.04, 0, 0, 6), 22)
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = DARK_TEXT
	name.Text = row.name
	name.Parent = card

	local style = makeLabel("Style", UDim2.new(0.92, 0, 0, 20), UDim2.new(0.04, 0, 0, 32), 16)
	style.TextColor3 = DARK_TEXT
	style.Text = row.style
	style.Parent = card

	local lines: { string } = {}
	for _, ability in row.abilities do
		table.insert(lines, ability.name .. ": " .. ability.description)
	end
	local abilities =
		makeLabel("Abilities", UDim2.new(0.92, 0, 1, -98), UDim2.new(0.04, 0, 0, 56), 15)
	abilities.TextYAlignment = Enum.TextYAlignment.Top
	abilities.TextColor3 = DARK_TEXT
	abilities.Text = table.concat(lines, "\n")
	abilities.Parent = card

	local choose = makeButton("Choose", "Choose", UDim2.new(0.92, 0, 0, 30))
	choose.AnchorPoint = Vector2.new(0.5, 1)
	choose.Position = UDim2.new(0.5, 0, 1, -6)
	choose.Activated:Connect(function()
		handlers.pick(row.path)
	end)
	choose.Parent = card
	return card
end

local function buildConfirm(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "Confirm"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.5, 0.26)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.Visible = false
	frame.ZIndex = 50
	addCorner(frame, 12)

	local question =
		makeLabel("Question", UDim2.fromScale(0.9, 0.5), UDim2.fromScale(0.05, 0.08), 24)
	question.TextXAlignment = Enum.TextXAlignment.Center
	question.ZIndex = 51
	question.Parent = frame
	confirmQuestion = question

	local yes = makeButton("Yes", "Yes", UDim2.fromScale(0.35, 0.25))
	yes.Position = UDim2.fromScale(0.1, 0.65)
	yes.ZIndex = 51
	yes.Activated:Connect(function()
		frame.Visible = false
		local path = pendingChange
		pendingChange = ""
		if path ~= "" then
			handlers.change(path)
		end
	end)
	yes.Parent = frame

	local no = makeButton("No", "No", UDim2.fromScale(0.35, 0.25))
	no.Position = UDim2.fromScale(0.55, 0.65)
	no.ZIndex = 51
	no.Activated:Connect(function()
		frame.Visible = false
		pendingChange = ""
	end)
	no.Parent = frame

	frame.Parent = gui
	confirm = frame
end

local function buildPicker(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "Picker"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.9, 0.85)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.Visible = false
	frame.ZIndex = 5
	addCorner(frame, 14)

	local title = makeLabel("Title", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.02, 0.02), 30)
	title.Font = Enum.Font.GothamBold
	title.Text = "Choose your Calling"
	title.Parent = frame

	local later = makeButton("Later", "Later", UDim2.fromScale(0.14, 0.08))
	later.AnchorPoint = Vector2.new(1, 0)
	later.Position = UDim2.fromScale(0.98, 0.02)
	later.Activated:Connect(function()
		dismissedPicker = true
		frame.Visible = false
	end)
	later.Parent = frame

	local list = makeScroller("Cards", UDim2.fromScale(0.96, 0.84), UDim2.fromScale(0.02, 0.13))
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.32, 0, 0, 250)
	grid.CellPadding = UDim2.new(0.01, 0, 0, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	list.Parent = frame
	pickerList = list

	frame.Parent = gui
	picker = frame
end

local function buildPanel(gui: ScreenGui)
	local book = Instance.new("Frame")
	book.Name = "Panel"
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	book.Position = UDim2.fromScale(0.5, 0.5)
	book.Size = UDim2.fromScale(0.8, 0.85)
	book.BackgroundColor3 = PANEL_COLOR
	book.Visible = false
	addCorner(book, 14)

	local title =
		makeLabel("CallingText", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.02, 0.02), 30)
	title.Font = Enum.Font.GothamBold
	title.Parent = book
	callingLabel = title

	local close = makeButton("Close", "X", UDim2.fromScale(0.08, 0.08))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(0.98, 0.02)
	close.Activated:Connect(PathUI.toggle)
	close.Parent = book

	local strip = Instance.new("Frame")
	strip.Name = "Loadout"
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromScale(0.02, 0.11)
	strip.Size = UDim2.fromScale(0.96, 0.09)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0.01, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip
	strip.Parent = book
	slotStrip = strip

	local list = makeScroller("Rows", UDim2.fromScale(0.96, 0.77), UDim2.fromScale(0.02, 0.21))
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = list
	list.Parent = book
	rowList = list

	book.Parent = gui
	panel = book
end

function PathUI.mount(playerGui: PlayerGui, given: Handlers)
	handlers = given

	local gui = Instance.new("ScreenGui")
	gui.Name = "PathGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12

	local openButton = makeButton("PathsButton", "Paths", UDim2.fromScale(0.14, 0.07))
	openButton.AnchorPoint = Vector2.new(0, 1)
	openButton.Position = UDim2.fromScale(0.02, 0.89)
	local openLimit = openButton:FindFirstChildOfClass("UITextSizeConstraint")
	if openLimit ~= nil then
		openLimit.MinTextSize = 12
	end
	openButton.Activated:Connect(PathUI.toggle)
	openButton.Parent = gui

	buildPicker(gui)
	buildPanel(gui)
	buildConfirm(gui)

	ContextActionService:BindAction("TogglePaths", function(_name, state)
		if state == Enum.UserInputState.Begin then
			PathUI.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.P)

	gui.Parent = playerGui
end

function PathUI.render(view: View)
	lastView = view
	local rows = rowList
	local cards = pickerList
	local strip = slotStrip
	local pick = picker
	if rows == nil or cards == nil or strip == nil or pick == nil then
		return
	end
	if callingLabel ~= nil then
		callingLabel.Text = view.callingText
	end

	clearRows(strip)
	for _, slot in view.slots do
		local empty = slot.abilityId == ""
		local cell = Instance.new("Frame")
		cell.Name = "Slot" .. slot.slot
		cell.LayoutOrder = slot.slot
		cell.Size = UDim2.new(0.2425, 0, 1, 0)
		cell.BackgroundColor3 = if empty then LOCKED_COLOR else CARD_COLOR
		addCorner(cell, 8)
		local text = makeLabel("Name", UDim2.new(0.74, 0, 1, 0), UDim2.fromScale(0.04, 0), 18)
		text.TextColor3 = if empty then TEXT_DIM else TEXT_LIGHT
		text.Text = slot.slot .. ": " .. (if empty then "Empty" else slot.name)
		text.Parent = cell
		if not empty then
			local clear = makeButton("Clear" .. slot.slot, "×", UDim2.new(0.2, 0, 0.8, 0))
			clear.AnchorPoint = Vector2.new(1, 0.5)
			clear.Position = UDim2.fromScale(0.98, 0.5)
			clear.Activated:Connect(function()
				handlers.loadout({ slot = slot.slot, abilityId = "" })
			end)
			clear.Parent = cell
		end
		cell.Parent = strip
	end

	clearRows(rows)
	for index, row in view.rows do
		makeRow(row, index, view.needsCalling).Parent = rows
	end

	clearRows(cards)
	if view.needsCalling then
		for index, row in view.rows do
			makeCard(row, index).Parent = cards
		end
	end
	pick.Visible = view.needsCalling and not dismissedPicker
end

function PathUI.isOpen(): boolean
	local book = panel
	local pick = picker
	return (book ~= nil and book.Visible) or (pick ~= nil and pick.Visible)
end

function PathUI.toggle()
	local book = panel
	if book ~= nil then
		book.Visible = not book.Visible
	end
end

return PathUI
