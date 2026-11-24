--!strict
-- The Warden's offer window, the trial HUD (top right) and the beacon over the next course
-- marker. It only shows what the server sent and asks to accept; the server decides the rest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrialView = require(Shared:WaitForChild("Rules"):WaitForChild("TrialView"))
local Types = require(Shared:WaitForChild("Types"))

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local TEXT_DIM = Color3.fromRGB(170, 165, 160)
local TEXT_SEALED = Color3.fromRGB(235, 90, 90)
local TEXT_NOTE = Color3.fromRGB(255, 190, 70)
local PANEL_COLOR = Color3.fromRGB(32, 28, 38)
local BACKGROUND = Color3.fromRGB(25, 22, 30)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)
local ACCEPT_COLOR = Color3.fromRGB(60, 130, 80)
local BEACON_COLOR = Color3.fromRGB(120, 230, 255)
local BEACON_HEIGHT = 40
local HUD_LINE_HEIGHT = 28

local TrialUI = {}

local window: Frame? = nil
local labels: { [string]: TextLabel } = {}
local acceptButton: TextButton? = nil
local hud: Frame? = nil
local beacon: Part? = nil
local acceptHandler: (trialId: string) -> () = function(_trialId: string) end
-- The offer on screen: Accept sends its trial id.
local offered: TrialView.OfferView? = nil
-- Text of the HUD lines on screen, so an unchanged render does nothing.
local shownKey = ""

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

local function makeLabel(name: string, order: number, height: number, maxText: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.LayoutOrder = order
	label.Size = UDim2.fromScale(1, height)
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

local function makeButton(name: string, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromScale(0.44, 1)
	button.BackgroundColor3 = color
	button.TextColor3 = TEXT_LIGHT
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = text
	addCorner(button, 8)
	limitText(button, 10, 22)
	return button
end

local function close()
	local frame = window
	if frame ~= nil then
		frame.Visible = false
	end
	offered = nil
end

function TrialUI.mount(playerGui: PlayerGui, onAccept: (trialId: string) -> ())
	acceptHandler = onAccept

	local gui = Instance.new("ScreenGui")
	gui.Name = "TrialGui"
	gui.ResetOnSpawn = false
	-- Below the status HUD (15) and messages (20), above the Ledger book (10).
	gui.DisplayOrder = 14

	local frame = Instance.new("Frame")
	frame.Name = "Offer"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.46, 0.56)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.Visible = false
	addCorner(frame, 14)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(280, 230)
	minimum.Parent = frame

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromScale(0.05, 0.04)
	body.Size = UDim2.fromScale(0.9, 0.74)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.01, 0)
	layout.Parent = body
	body.Parent = frame

	-- name, share of the body's height, largest text size
	local rows: { { any } } = {
		{ "Title", 0.18, 30 },
		{ "Warden", 0.1, 18 },
		{ "Goal", 0.14, 22 },
		{ "Time", 0.11, 20 },
		{ "Reward", 0.11, 20 },
		{ "Relic", 0.14, 20 },
		{ "Note", 0.14, 20 },
	}
	for order, row in rows do
		local label = makeLabel(row[1], order, row[2], row[3])
		label.Parent = body
		labels[row[1]] = label
	end
	labels.Title.Font = Enum.Font.GothamBold
	labels.Warden.TextColor3 = TEXT_DIM
	labels.Note.TextColor3 = TEXT_NOTE

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.BackgroundTransparency = 1
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.fromScale(0.5, 0.96)
	buttons.Size = UDim2.fromScale(0.9, 0.14)
	buttons.Parent = frame

	local accept = makeButton("Accept", "Accept", ACCEPT_COLOR)
	accept.Position = UDim2.fromScale(0, 0)
	accept.Activated:Connect(function()
		local view = offered
		if view ~= nil and view.canStart then
			close()
			acceptHandler(view.trialId)
		end
	end)
	accept.Parent = buttons
	acceptButton = accept

	local dismiss = makeButton("Close", "Close", BUTTON_COLOR)
	dismiss.AnchorPoint = Vector2.new(1, 0)
	dismiss.Position = UDim2.fromScale(1, 0)
	dismiss.Activated:Connect(close)
	dismiss.Parent = buttons

	frame.Parent = gui
	window = frame

	local lines = Instance.new("Frame")
	lines.Name = "Hud"
	lines.BackgroundTransparency = 1
	lines.AnchorPoint = Vector2.new(1, 0)
	lines.Position = UDim2.new(1, -12, 0.16, 0)
	lines.Size = UDim2.new(0, 300, 0, 4 * (HUD_LINE_HEIGHT + 4))
	local hudLayout = Instance.new("UIListLayout")
	hudLayout.Padding = UDim.new(0, 4)
	hudLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hudLayout.Parent = lines
	lines.Parent = gui
	hud = lines

	gui.Parent = playerGui
end

function TrialUI.showOffer(view: TrialView.OfferView)
	local frame = window
	if frame == nil then
		return
	end
	offered = view
	labels.Title.Text = view.title
	labels.Warden.Text = view.warden
	labels.Goal.Text = view.goal
	labels.Time.Text = view.timeText
	labels.Reward.Text = view.rewardText
	labels.Relic.Text = view.relicText
	labels.Relic.TextColor3 = if view.sealed then TEXT_SEALED else TEXT_LIGHT
	labels.Note.Text = view.note
	local accept = acceptButton
	if accept ~= nil then
		-- Dimmed and inert unless the trial can start.
		accept.Active = view.canStart
		accept.AutoButtonColor = view.canStart
		accept.BackgroundTransparency = if view.canStart then 0 else 0.6
		accept.TextTransparency = if view.canStart then 0 else 0.5
	end
	frame.Visible = true
end

function TrialUI.renderHud(lines: { string })
	local list = hud
	if list == nil then
		return
	end
	local key = table.concat(lines, "|")
	if key == shownKey then
		return
	end
	shownKey = key
	for _, child in list:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
	for index, text in lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. index
		label.LayoutOrder = index
		label.Size = UDim2.new(1, 0, 0, HUD_LINE_HEIGHT)
		label.BackgroundColor3 = BACKGROUND
		label.BackgroundTransparency = 0.3
		label.TextColor3 = TEXT_LIGHT
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Font = Enum.Font.GothamBold
		label.Text = text
		addCorner(label, 6)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.Parent = label
		limitText(label, 9, 18)
		label.Parent = list
	end
end

-- A glowing column over the next course marker, on this client only. nil removes it.
function TrialUI.setBeacon(position: Types.Vec3?)
	if position == nil then
		if beacon ~= nil then
			beacon:Destroy()
			beacon = nil
		end
		return
	end
	local part = beacon
	if part == nil then
		local made = Instance.new("Part")
		made.Name = "TrialBeacon"
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.CastShadow = false
		made.Material = Enum.Material.Neon
		made.Color = BEACON_COLOR
		made.Transparency = 0.5
		made.Size = Vector3.new(1.2, BEACON_HEIGHT, 1.2)
		made.Parent = workspace
		beacon = made
		part = made
	end
	-- The marker is at standing-root height; the column rises from the surface under it.
	local target = CFrame.new(position.x, position.y - 3 + BEACON_HEIGHT / 2, position.z)
	if part.CFrame ~= target then
		part.CFrame = target
	end
end

function TrialUI.isOpen(): boolean
	local frame = window
	return frame ~= nil and frame.Visible
end

return TrialUI
