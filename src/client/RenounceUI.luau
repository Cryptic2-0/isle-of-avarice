--!strict
-- The Renounce window: the server's offer lines, the word to type, a countdown, Confirm and
-- Keep. It sends what was typed; the server checks the word, the time and everything else.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Renounce = require(Shared:WaitForChild("Rules"):WaitForChild("Renounce"))

-- After a click the buttons stay inert until the next offer arrives or this long passes.
local REARM_SECONDS = 1

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local TEXT_DIM = Color3.fromRGB(170, 165, 160)
local PANEL_COLOR = Color3.fromRGB(32, 28, 38)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)
local CONFIRM_COLOR = Color3.fromRGB(170, 55, 55)
local BOX_COLOR = Color3.fromRGB(20, 18, 24)

local RenounceUI = {}

local window: Frame? = nil
local linesFrame: Frame? = nil
local wordBox: TextBox? = nil
local timerLabel: TextLabel? = nil
local confirmButton: TextButton? = nil
local keepButton: TextButton? = nil
local actionHandler: (request: { [string]: any }) -> () = function(_request: { [string]: any }) end

-- Bumped on every show and every close: stops an old countdown and an old re-arm timer.
local serial = 0
-- One request per render: set on a click, cleared by the next show or the re-arm timer.
local sent = false

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

local function makeButton(name: string, text: string, color: Color3, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = UDim2.fromScale(0.46, 0.12)
	button.BackgroundColor3 = color
	button.TextColor3 = TEXT_LIGHT
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = text
	addCorner(button, 8)
	limitText(button, 10, 22)
	return button
end

-- Dimmed and inert unless `enabled`, as in the trade window.
local function setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.6
	button.TextTransparency = if enabled then 0 else 0.5
end

local function typedWord(): string
	local box = wordBox
	return if box ~= nil then box.Text else ""
end

-- Confirm needs the typed word and no request in flight; Keep needs no request in flight.
local function refreshButtons()
	local confirm = confirmButton
	local keep = keepButton
	if confirm ~= nil then
		setEnabled(confirm, not sent and Renounce.wordMatches(typedWord()))
	end
	if keep ~= nil then
		setEnabled(keep, not sent)
	end
end

-- Sends one request, then waits for the next offer (or one second) before another.
local function send(request: { [string]: any })
	if sent then
		return
	end
	sent = true
	refreshButtons()
	actionHandler(request)
	local mine = serial
	task.delay(REARM_SECONDS, function()
		if serial == mine and sent then
			sent = false
			refreshButtons()
		end
	end)
end

local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function RenounceUI.mount(playerGui: PlayerGui, onAction: (request: { [string]: any }) -> ())
	actionHandler = onAction

	local gui = Instance.new("ScreenGui")
	gui.Name = "RenounceGui"
	gui.ResetOnSpawn = false
	-- Above the Ceremony banner (25) and every other window.
	gui.DisplayOrder = 26

	local frame = Instance.new("Frame")
	frame.Name = "Renounce"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.5, 0.6)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.Visible = false
	addCorner(frame, 14)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(300, 320)
	minimum.Parent = frame

	local title = makeLabel("Title", UDim2.fromScale(0.94, 0.09), UDim2.fromScale(0.03, 0.02), 28)
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
	word.TextColor3 = TEXT_LIGHT
	word.PlaceholderText = "Type RENOUNCE"
	word.PlaceholderColor3 = TEXT_DIM
	word.ClearTextOnFocus = false
	word.TextScaled = true
	word.Font = Enum.Font.GothamBold
	word.Text = ""
	addCorner(word, 8)
	limitText(word, 10, 22)
	word:GetPropertyChangedSignal("Text"):Connect(refreshButtons)
	word.Parent = frame
	wordBox = word

	local timer = makeLabel("Timer", UDim2.fromScale(0.94, 0.07), UDim2.fromScale(0.03, 0.72), 20)
	timer.TextColor3 = TEXT_DIM
	timer.Parent = frame
	timerLabel = timer

	local confirm = makeButton("Confirm", "Renounce", CONFIRM_COLOR, UDim2.fromScale(0.03, 0.85))
	confirm.Activated:Connect(function()
		if sent or not Renounce.wordMatches(typedWord()) then
			return
		end
		send({ kind = "confirm", word = typedWord() })
	end)
	confirm.Parent = frame
	confirmButton = confirm

	local keep = makeButton("Keep", "Keep my Ledger", BUTTON_COLOR, UDim2.fromScale(0.51, 0.85))
	keep.Activated:Connect(function()
		send({ kind = "cancel" })
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
	sent = false
	if offer == nil then
		frame.Visible = false
		return
	end

	for _, child in list:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
	local count = math.max(1, #offer.lines)
	for index, text in offer.lines do
		local label = makeLabel("Line" .. index, UDim2.new(1, 0, 1 / count, -2), UDim2.new(), 16)
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
			timer.Text = "Ends in " .. clock(deadline - os.clock())
			task.wait(0.25)
		end
	end)
end

function RenounceUI.isOpen(): boolean
	local frame = window
	return frame ~= nil and frame.Visible
end

return RenounceUI
