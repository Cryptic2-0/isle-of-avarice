--!strict
-- Using an Edict: the Relic picker (Summons), the player picker (Passage) and the result
-- window (Summons and Audit). It sends what the player picked; the server decides the rest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = Shared:WaitForChild("Catalog")
local Edicts = require(Catalog:WaitForChild("Edicts"))
local Relics = require(Catalog:WaitForChild("Relics"))
local Tiers = require(Catalog:WaitForChild("Tiers"))
local LedgerView = require(Shared:WaitForChild("Rules"):WaitForChild("LedgerView"))
local UiKit = require(script.Parent.UiKit)

local TEXT_DIM = Color3.fromRGB(170, 165, 160)
local ROW_HEIGHT = 40

local EdictUI = {}

local relicWindow: Frame? = nil
local playerWindow: Frame? = nil
local resultWindow: Frame? = nil
local playerList: ScrollingFrame? = nil
local resultList: ScrollingFrame? = nil
local resultTitle: TextLabel? = nil
local useHandler: (request: { [string]: any }) -> () = function(_request: { [string]: any }) end
-- The Edict the open picker was opened for.
local pending: LedgerView.FreeView? = nil
local met: { { userId: number, name: string } } = {}

-- This file's text is a little larger than the kit's default.
local function makeLabel(name: string, text: string, size: UDim2, position: UDim2): TextLabel
	return UiKit.label(name, text, size, position, { min = 10, max = 22 })
end

local function makeScroller(): ScrollingFrame
	return UiKit.scroller("List", UDim2.fromScale(0.92, 0.66), UDim2.fromScale(0.04, 0.15))
end

-- A hidden, centred window with a title and a bottom button.
local function makeWindow(
	gui: ScreenGui,
	name: string,
	kind: "big" | "small",
	title: string,
	bottomText: string,
	onBottom: () -> ()
): Frame
	local frame = UiKit.window(name, UDim2.fromScale(0.6, 0.64), kind)

	local heading =
		makeLabel("Title", title, UDim2.fromScale(0.92, 0.1), UDim2.fromScale(0.04, 0.03))
	heading.Font = Enum.Font.GothamBold
	heading.Parent = frame

	local bottom = UiKit.button(
		bottomText,
		bottomText,
		UDim2.fromScale(0.4, 0.1),
		{ wrap = true, minSize = Vector2.new(40, 32) }
	)
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.fromScale(0.5, 0.97)
	UiKit.onPress(bottom, onBottom)
	bottom.Parent = frame

	frame.Parent = gui
	return frame
end

local function hide(frame: Frame?)
	if frame ~= nil then
		frame.Visible = false
	end
end

-- Closing a picker also forgets the card it was for.
local function closePicker(frame: Frame?)
	hide(frame)
	pending = nil
end

local function fillPlayers()
	local list = playerList
	if list == nil then
		return
	end
	UiKit.clearRows(list)
	local card = pending
	if #met == 0 then
		local none = makeLabel(
			"None",
			"You have not met anyone this session.",
			UDim2.new(1, 0, 0, ROW_HEIGHT * 2),
			UDim2.new()
		)
		none.TextColor3 = TEXT_DIM
		none.Parent = list
		return
	end
	for index, person in met do
		local button = UiKit.button("Player" .. index, person.name, nil, { wrap = true })
		button.LayoutOrder = index
		button.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
		UiKit.onPress(button, function()
			-- Closing first, so a second click cannot send twice.
			closePicker(playerWindow)
			if card ~= nil then
				useHandler({
					freeIndex = card.index,
					cardId = card.cardId,
					targetId = person.userId,
				})
			end
		end)
		button.Parent = list
	end
end

function EdictUI.mount(playerGui: PlayerGui, onUse: (request: { [string]: any }) -> ())
	useHandler = onUse

	-- With the other windows; below the messages (20).
	local gui = UiKit.screen("EdictGui", 16)

	-- Relic picker: a grid of every Relic, six to a row (at least 85 pixels wide on a phone).
	local relics = makeWindow(
		gui,
		"RelicPicker",
		"big",
		"Summons: which Relic?",
		"Cancel",
		function()
			closePicker(relicWindow)
		end
	)
	local grid = makeScroller()
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.155, 0, 0, 64)
	gridLayout.CellPadding = UDim2.new(0.012, 0, 0, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	for index, relic in Relics.list do
		local color = Tiers.info[relic.tier].color
		local text = string.sub(relic.id, 2) .. "\n" .. relic.name
		local button = UiKit.button("Relic" .. relic.id, text, nil, {
			color = Color3.fromRGB(color.r, color.g, color.b),
			textColor = UiKit.TEXT_DARK,
			wrap = true,
		})
		button.LayoutOrder = index
		UiKit.onPress(button, function()
			local card = pending
			closePicker(relicWindow)
			if card ~= nil then
				useHandler({ freeIndex = card.index, cardId = card.cardId, relicId = relic.id })
			end
		end)
		button.Parent = grid
	end
	grid.Parent = relics
	relicWindow = relics

	-- Player picker: one button per player met this session.
	local players = makeWindow(
		gui,
		"PlayerPicker",
		"small",
		"Passage: to whom?",
		"Cancel",
		function()
			closePicker(playerWindow)
		end
	)
	local people = makeScroller()
	local peopleLayout = Instance.new("UIListLayout")
	peopleLayout.Padding = UDim.new(0, 6)
	peopleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	peopleLayout.Parent = people
	people.Parent = players
	playerList = people
	playerWindow = players

	-- Result: what a Summons or an Audit found.
	local result = makeWindow(gui, "Result", "small", "", "Close", function()
		hide(resultWindow)
	end)
	local heading = result:FindFirstChild("Title")
	if heading ~= nil and heading:IsA("TextLabel") then
		resultTitle = heading
	end
	local lines = makeScroller()
	local linesLayout = Instance.new("UIListLayout")
	linesLayout.Padding = UDim.new(0, 4)
	linesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	linesLayout.Parent = lines
	lines.Parent = result
	resultList = lines
	resultWindow = result

	gui.Parent = playerGui
end

-- The Ledger's "Use" button: ask for what the Edict needs, or use it at once.
function EdictUI.use(card: LedgerView.FreeView)
	local edict = Edicts.byId[card.cardId]
	if edict == nil then
		return
	end
	if edict.needs == "relic" then
		local frame = relicWindow
		if frame ~= nil then
			pending = card
			frame.Visible = true
		end
	elseif edict.needs == "player" then
		local frame = playerWindow
		if frame ~= nil then
			pending = card
			fillPlayers()
			frame.Visible = true
		end
	else
		useHandler({ freeIndex = card.index, cardId = card.cardId })
	end
end

-- The players met this session; the picker refreshes when it is open.
function EdictUI.setMet(list: { { userId: number, name: string } })
	met = list
	local frame = playerWindow
	if frame ~= nil and frame.Visible then
		fillPlayers()
	end
end

function EdictUI.showResult(result: { title: string, lines: { string } })
	local frame = resultWindow
	local list = resultList
	if frame == nil or list == nil then
		return
	end
	local heading = resultTitle
	if heading ~= nil then
		heading.Text = result.title
	end
	UiKit.clearRows(list)
	for index, line in result.lines do
		local label = makeLabel("Line" .. index, line, UDim2.new(1, -8, 0, 28), UDim2.new())
		label.LayoutOrder = index
		label.Parent = list
	end
	frame.Visible = true
end

function EdictUI.isOpen(): boolean
	local relics = relicWindow
	local players = playerWindow
	local result = resultWindow
	return (relics ~= nil and relics.Visible)
		or (players ~= nil and players.Visible)
		or (result ~= nil and result.Visible)
end

return EdictUI
