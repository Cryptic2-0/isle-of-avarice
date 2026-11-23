--!strict
-- The Renounce window: the server's offer lines, the word to type, a countdown, Confirm and
-- Keep. It sends what was typed; the server checks the word, the time and everything else.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Renounce = require(Shared:WaitForChild("Rules"):WaitForChild("Renounce"))
local UiKit = require(script.Parent.UiKit)

local TEXT_DIM = Color3.fromRGB(170, 165, 160)
local BOX_COLOR = Color3.fromRGB(20, 18, 24)

local RenounceUI = {}

local window: Frame? = nil
local linesFrame: Frame? = nil
local wordBox: TextBox? = nil
local timerLabel: TextLabel? = nil
local confirmButton: TextButton? = nil
local keepButton: TextButton? = nil
local actionHandler: (request: { [string]: any }) -> () = function(_request: { [string]: any }) end

-- Bumped on every show and every close: stops an old countdown.
local serial = 0
-- One request per render: busy after a click, cleared by the next show or the re-arm timer.
local refreshButtons: () -> ()
local guard = UiKit.guard(function(_inert: boolean)
	refreshButtons()
end)

local function typedWord(): string
	local box = wordBox
	return if box ~= nil then box.Text else ""
end

-- Confirm needs the typed word and no request in flight; Keep needs no request in flight.
refreshButtons = function()
	local confirm = confirmButton
	local keep = keepButton
	if confirm ~= nil then
		UiKit.setEnabled(confirm, not guard.busy and Renounce.wordMatches(typedWord()))
	end
	if keep ~= nil then
		UiKit.setEnabled(keep, not guard.busy)
	end
end

local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function makeLine(name: string, size: UDim2, position: UDim2, max: number): TextLabel
	return UiKit.label(name, "", size, position, { min = 9, max = max })
end

function RenounceUI.mount(playerGui: PlayerGui, onAction: (request: { [string]: any }) -> ())
	actionHandler = onAction

	-- Above the Ceremony banner (25) and every other window.
	local gui = UiKit.screen("RenounceGui", 26)

	local frame = UiKit.window("Renounce", UDim2.fromScale(0.5, 0.6), "small")

	local title = makeLine("Title", UDim2.fromScale(0.94, 0.09), UDim2.fromScale(0.03, 0.02), 28)
	title.Font = Enum.Font.GothamBold
	title.Text = "Renounce the Ledger?"
	title.Parent = frame

	local lines = Instance.new("Frame")
	lines.Name = "Lines"
	lines.BackgroundTransparency = 1
	lines.Position = UDim2.fromScale(0.03, 0.12)
	lines.Size = UDim2.fromScale(0.94, 0.46)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = lines
	lines.Parent = frame
	linesFrame = lines

	local word = Instance.new("TextBox")
	word.Name = "Word"
	word.Position = UDim2.fromScale(0.03, 0.6)
	word.Size = UDim2.fromScale(0.94, 0.1)
	word.BackgroundColor3 = BOX_COLOR
	word.TextColor3 = UiKit.TEXT_LIGHT
	word.PlaceholderText = "Type RENOUNCE"
	word.PlaceholderColor3 = TEXT_DIM
	word.ClearTextOnFocus = false
	word.TextScaled = true
	word.Font = Enum.Font.GothamBold
	word.Text = ""
	UiKit.corner(word, 8)
	UiKit.limitText(word, 10, 22)
	word:GetPropertyChangedSignal("Text"):Connect(refreshButtons)
	word.Parent = frame
	wordBox = word

	local timer = makeLine("Timer", UDim2.fromScale(0.94, 0.07), UDim2.fromScale(0.03, 0.72), 20)
	timer.TextColor3 = TEXT_DIM
	timer.Parent = frame
	timerLabel = timer

	local confirm = UiKit.button(
		"Confirm",
		"Renounce",
		UDim2.fromScale(0.46, 0.12),
		{ color = UiKit.ARMED, min = 10, max = 22 }
	)
	confirm.Position = UDim2.fromScale(0.03, 0.85)
	UiKit.onPress(confirm, function()
		if guard.busy or not Renounce.wordMatches(typedWord()) then
			return
		end
		local typed = typedWord()
		UiKit.send(guard, function()
			actionHandler({ kind = "confirm", word = typed })
		end)
	end)
	confirm.Parent = frame
	confirmButton = confirm

	local keep =
		UiKit.button("Keep", "Keep my Ledger", UDim2.fromScale(0.46, 0.12), { min = 10, max = 22 })
	keep.Position = UDim2.fromScale(0.51, 0.85)
	UiKit.onPress(keep, function()
		UiKit.send(guard, function()
			actionHandler({ kind = "cancel" })
		end)
	end)
	keep.Parent = frame
	keepButton = keep

	frame.Parent = gui
	window = frame
	gui.Parent = playerGui
end

-- Opens the window on the offer, or closes it on nil. The window closes only here: the server
-- answers every action.
function RenounceUI.show(offer: { lines: { string }, seconds: number }?)
	local frame = window
	local list = linesFrame
	local box = wordBox
	local timer = timerLabel
	if frame == nil or list == nil or box == nil or timer == nil then
		return
	end
	serial += 1
	UiKit.answered(guard)
	if offer == nil then
		frame.Visible = false
		return
	end

	UiKit.clearRows(list)
	local count = math.max(1, #offer.lines)
	for index, text in offer.lines do
		local label = makeLine("Line" .. index, UDim2.new(1, 0, 1 / count, -2), UDim2.new(), 16)
		label.LayoutOrder = index
		label.Text = text
		label.Parent = list
	end
	box.Text = ""
	refreshButtons()

	local mine = serial
	local deadline = os.clock() + math.max(0, offer.seconds)
	timer.Text = "Ends in " .. clock(offer.seconds)
	frame.Visible = true
	task.spawn(function()
		while serial == mine and frame.Visible do
			local left = deadline - os.clock()
			timer.Text = "Ends in " .. clock(left)
			if left <= 0 then
				-- The server dropped the offer at the same moment.
				frame.Visible = false
				break
			end
			task.wait(0.25)
		end
	end)
end

function RenounceUI.isOpen(): boolean
	local frame = window
	return frame ~= nil and frame.Visible
end

return RenounceUI
