--!strict
-- The Warden's offer window, the trial HUD (top right) and the beacon over the next course
-- marker. It only shows what the server sent and asks to accept; the server decides the rest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TrialView = require(Shared:WaitForChild("Rules"):WaitForChild("TrialView"))
local Types = require(Shared:WaitForChild("Types"))
local UiKit = require(script.Parent.UiKit)

local TEXT_DIM = Color3.fromRGB(170, 165, 160)
local TEXT_SEALED = Color3.fromRGB(235, 90, 90)
local TEXT_NOTE = Color3.fromRGB(255, 190, 70)
local BACKGROUND = Color3.fromRGB(25, 22, 30)
local ACCEPT_COLOR = Color3.fromRGB(60, 130, 80)
local BEACON_COLOR = Color3.fromRGB(120, 230, 255)
local BEACON_HEIGHT = 40
local DEFAULT_LINE_HEIGHT = 28

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
-- Each HUD line's height for this screen, and how many lines the last render drew.
local lineHeight = DEFAULT_LINE_HEIGHT
local drawnLines = 0

local function close()
	local frame = window
	if frame ~= nil then
		frame.Visible = false
	end
	offered = nil
end

function TrialUI.mount(playerGui: PlayerGui, onAccept: (trialId: string) -> ())
	acceptHandler = onAccept

	-- Below the status HUD (15) and messages (20), above the Ledger book (10).
	local gui = UiKit.screen("TrialGui", 14)

	local frame = UiKit.window("Offer", UDim2.fromScale(0.46, 0.56), "small")

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
		local label =
			UiKit.label(row[1], "", UDim2.fromScale(1, row[2]), UDim2.new(), { max = row[3] })
		label.LayoutOrder = order
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

	local accept = UiKit.button(
		"Accept",
		"Accept",
		UDim2.fromScale(0.44, 1),
		{ color = ACCEPT_COLOR, min = 10, max = 22 }
	)
	accept.Position = UDim2.fromScale(0, 0)
	UiKit.onPress(accept, function()
		local view = offered
		if view ~= nil and view.canStart then
			close()
			acceptHandler(view.trialId)
		end
	end)
	accept.Parent = buttons
	acceptButton = accept

	local dismiss = UiKit.button(
		"Close",
		"Close",
		UDim2.fromScale(0.44, 1),
		{ min = 10, max = 22, minSize = Vector2.new(40, 32) }
	)
	dismiss.AnchorPoint = Vector2.new(1, 0)
	dismiss.Position = UDim2.fromScale(1, 0)
	UiKit.onPress(dismiss, close)
	dismiss.Parent = buttons

	frame.Parent = gui
	window = frame

	local lines = Instance.new("Frame")
	lines.Name = "Hud"
	lines.BackgroundTransparency = 1
	local hudLayout = Instance.new("UIListLayout")
	hudLayout.Padding = UDim.new(0, 4)
	hudLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hudLayout.Parent = lines
	lines.Parent = gui
	hud = lines
	UiKit.onLayout(function(screenLayout)
		lineHeight = screenLayout.hudLineHeight
		UiKit.place(lines, screenLayout.trialHud)
		-- Forces the next renderHud to draw the lines again at the new height.
		shownKey = ""
	end)

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
	labels.Relic.TextColor3 = if view.sealed then TEXT_SEALED else UiKit.TEXT_LIGHT
	labels.Note.Text = view.note
	local accept = acceptButton
	if accept ~= nil then
		-- Dimmed and inert unless the trial can start.
		UiKit.setEnabled(accept, view.canStart)
	end
	frame.Visible = true
end

-- How many HUD lines the last renderHud drew (play-test seam).
function TrialUI.shownLines(): number
	return drawnLines
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
	drawnLines = #lines
	UiKit.clearRows(list)
	for index, text in lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. index
		label.LayoutOrder = index
		label.Size = UDim2.new(1, 0, 0, lineHeight)
		label.BackgroundColor3 = BACKGROUND
		label.BackgroundTransparency = 0.3
		label.TextColor3 = UiKit.TEXT_LIGHT
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Right
		label.Font = Enum.Font.GothamBold
		label.Text = text
		UiKit.corner(label, 6)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 4)
		padding.PaddingBottom = UDim.new(0, 4)
		padding.Parent = label
		UiKit.limitText(label, 9, 18)
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
