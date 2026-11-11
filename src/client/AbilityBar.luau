--!strict
-- Bottom-centre ability bar: four slots (keys 1-4), tap or click to cast.
-- The server decides whether a cast works; the cooldown overlay here is display only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PathView = require(Shared:WaitForChild("Rules"):WaitForChild("PathView"))

local AbilityBar = {}

local SLOT_COUNT = 4
local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)
local DIM_COLOR = Color3.fromRGB(45, 42, 52)
local OVERLAY_COLOR = Color3.fromRGB(10, 8, 14)

type Slot = {
	button: TextButton,
	overlay: Frame,
	timeLabel: TextLabel,
	nameLabel: TextLabel,
	endsAt: number,
	total: number,
}

local slots: { [number]: Slot } = {}
local ticking: RBXScriptConnection? = nil

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

local function tick()
	local now = os.clock()
	local anyActive = false
	for _, slot in slots do
		local remaining = slot.endsAt - now
		if remaining > 0 and slot.total > 0 then
			anyActive = true
			slot.overlay.Visible = true
			slot.overlay.Size = UDim2.fromScale(1, math.min(1, remaining / slot.total))
			slot.timeLabel.Text = tostring(math.ceil(remaining))
		elseif slot.overlay.Visible then
			slot.overlay.Visible = false
			slot.timeLabel.Text = ""
		end
	end
	if not anyActive and ticking ~= nil then
		ticking:Disconnect()
		ticking = nil
	end
end

local function buildSlot(parent: Frame, index: number, onCast: (slot: number) -> ()): Slot
	local button = Instance.new("TextButton")
	button.Name = "Slot" .. index
	button.LayoutOrder = index
	button.Size = UDim2.fromScale(1, 1)
	button.SizeConstraint = Enum.SizeConstraint.RelativeYY
	button.BackgroundColor3 = DIM_COLOR
	button.Text = ""
	addCorner(button, 8)

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.BackgroundTransparency = 1
	key.Position = UDim2.fromScale(0.06, 0.04)
	key.Size = UDim2.fromScale(0.3, 0.3)
	key.TextColor3 = TEXT_LIGHT
	key.TextScaled = true
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.Font = Enum.Font.GothamBold
	key.Text = tostring(index)
	limitText(key, 8, 18)
	key.Parent = button

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "AbilityName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromScale(0.05, 0.32)
	nameLabel.Size = UDim2.fromScale(0.9, 0.62)
	nameLabel.TextColor3 = TEXT_LIGHT
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.Text = "—"
	nameLabel.TextTransparency = 0.6
	limitText(nameLabel, 8, 16)
	nameLabel.Parent = button

	local overlay = Instance.new("Frame")
	overlay.Name = "Cooldown"
	overlay.AnchorPoint = Vector2.new(0, 1)
	overlay.Position = UDim2.fromScale(0, 1)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = OVERLAY_COLOR
	overlay.BackgroundTransparency = 0.35
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	addCorner(overlay, 8)
	overlay.Parent = button

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "Seconds"
	timeLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	timeLabel.Position = UDim2.fromScale(0.5, 0.5)
	timeLabel.Size = UDim2.fromScale(0.6, 0.4)
	timeLabel.BackgroundTransparency = 1
	timeLabel.TextColor3 = TEXT_LIGHT
	timeLabel.TextScaled = true
	timeLabel.Font = Enum.Font.GothamBold
	timeLabel.Text = ""
	limitText(timeLabel, 10, 24)
	timeLabel.ZIndex = 3
	timeLabel.Parent = button

	button.Activated:Connect(function()
		onCast(index)
	end)
	button.Parent = parent
	return {
		button = button,
		overlay = overlay,
		timeLabel = timeLabel,
		nameLabel = nameLabel,
		endsAt = 0,
		total = 0,
	}
end

function AbilityBar.mount(playerGui: PlayerGui, onCast: (slot: number) -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 0.97)
	bar.Size = UDim2.fromScale(0.34, 0.1)
	bar.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	for index = 1, SLOT_COUNT do
		slots[index] = buildSlot(bar, index, onCast)
	end
	bar.Parent = gui
	gui.Parent = playerGui
end

function AbilityBar.render(views: { PathView.SlotView })
	for _, view in views do
		local slot = slots[view.slot]
		if slot ~= nil then
			local empty = view.name == ""
			slot.nameLabel.Text = if empty then "—" else view.name
			slot.button.BackgroundColor3 = if empty then DIM_COLOR else BUTTON_COLOR
			slot.nameLabel.TextTransparency = if empty then 0.6 else 0
		end
	end
end

function AbilityBar.startCooldown(slotIndex: number, seconds: number)
	local slot = slots[slotIndex]
	if slot == nil or seconds <= 0 then
		return
	end
	slot.total = seconds
	slot.endsAt = os.clock() + seconds
	tick()
	if ticking == nil then
		ticking = RunService.RenderStepped:Connect(tick)
	end
end

return AbilityBar
