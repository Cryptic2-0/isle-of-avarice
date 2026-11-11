--!strict
-- The blind-claim screen. It shows every numbered slot face down: nothing tells the
-- killer whether the victim holds a Relic, only what each pick turned out to be.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Tiers = require(Shared:WaitForChild("Catalog"):WaitForChild("Tiers"))
local Rules = Shared:WaitForChild("Rules")
local BlindClaim = require(Rules:WaitForChild("BlindClaim"))
local ClaimView = require(Rules:WaitForChild("ClaimView"))
local Types = require(Shared:WaitForChild("Types"))

local TICK_SECONDS = 0.25

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local TEXT_DARK = Color3.fromRGB(20, 18, 24)
local TEXT_DIM = Color3.fromRGB(130, 130, 135)
local PANEL_COLOR = Color3.fromRGB(32, 28, 38)
local MISS_COLOR = Color3.fromRGB(40, 40, 45)
local LOCKED_COLOR = Color3.fromRGB(70, 70, 75)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)

local ClaimUI = {}

local panel: Frame? = nil
local titleLabel: TextLabel? = nil
local picksLabel: TextLabel? = nil
local timerLabel: TextLabel? = nil
local grid: Frame? = nil
local pickHandler: (slot: number) -> () = function(_slot: number) end

-- What is on screen. The deadline is on the local clock: the server's expiresAt is on the
-- server's clock and is never compared with local time.
local victimName = ""
local currentClaim: BlindClaim.Claim? = nil
local deadline = 0
local shownOpen = false
local ticking = false

local function tierColor(tier: Types.Tier): Color3
	local color = Tiers.info[tier].color
	return Color3.fromRGB(color.r, color.g, color.b)
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
	label.Font = Enum.Font.GothamMedium
	label.Text = ""
	limitText(label, 10, maxText)
	return label
end

local function secondsRemaining(): number
	return math.max(0, deadline - os.clock())
end

local function buildView(claim: BlindClaim.Claim): ClaimView.View
	return ClaimView.build(victimName, claim, claim.expiresAt - secondsRemaining())
end

local function makeCell(slot: ClaimView.SlotView): TextButton
	local cell = Instance.new("TextButton")
	cell.Name = "Slot" .. slot.label
	cell.LayoutOrder = slot.slot
	cell.Font = Enum.Font.GothamMedium
	cell.TextScaled = true
	cell.TextWrapped = true
	cell.AutoButtonColor = slot.state == "open"
	addCorner(cell, 8)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = cell
	limitText(cell, 9, 20)

	local text = slot.label .. "\n" .. slot.name
	if slot.state == "open" then
		cell.BackgroundColor3 = tierColor(slot.tier)
		cell.BackgroundTransparency = 0.35
		cell.TextColor3 = TEXT_DARK
	elseif slot.state == "taken" then
		cell.BackgroundColor3 = tierColor(slot.tier)
		cell.TextColor3 = TEXT_DARK
		cell.Font = Enum.Font.GothamBold
		text ..= "\nTaken!"
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 3
		stroke.Parent = cell
	elseif slot.state == "miss" then
		cell.BackgroundColor3 = MISS_COLOR
		cell.TextColor3 = TEXT_DIM
		text ..= "\nNothing"
	else
		cell.BackgroundColor3 = LOCKED_COLOR
		cell.BackgroundTransparency = 0.4
		cell.TextColor3 = TEXT_DIM
		cell.TextTransparency = 0.4
	end
	cell.Text = text

	if slot.state == "open" then
		cell.Activated:Connect(function()
			pickHandler(slot.slot)
		end)
	end
	return cell
end

local function render()
	local claim = currentClaim
	local cells = grid
	if claim == nil or cells == nil then
		return
	end
	local view = buildView(claim)
	shownOpen = view.open
	if titleLabel ~= nil then
		titleLabel.Text = view.title
	end
	if picksLabel ~= nil then
		picksLabel.Text = view.picksText
	end
	if timerLabel ~= nil then
		timerLabel.Text = `{view.secondsLeft}s`
	end
	for _, child in cells:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
	for _, slot in view.slots do
		makeCell(slot).Parent = cells
	end
end

-- Counts down locally while the screen is open; redraws the slots when time runs out.
local function startTicking()
	if ticking then
		return
	end
	ticking = true
	task.spawn(function()
		while ClaimUI.isOpen() do
			local claim = currentClaim
			if claim ~= nil then
				local view = buildView(claim)
				if view.open ~= shownOpen then
					render()
				elseif timerLabel ~= nil then
					timerLabel.Text = `{view.secondsLeft}s`
				end
			end
			task.wait(TICK_SECONDS)
		end
		ticking = false
	end)
end

function ClaimUI.mount(playerGui: PlayerGui, onPick: (slot: number) -> ())
	pickHandler = onPick

	local gui = Instance.new("ScreenGui")
	gui.Name = "ClaimGui"
	gui.ResetOnSpawn = false
	-- Above the Ledger book (10), the status HUD (15) and messages (20).
	gui.DisplayOrder = 30

	local frame = Instance.new("Frame")
	frame.Name = "Claim"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.55)
	frame.Size = UDim2.fromScale(0.7, 0.7)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.Visible = false
	addCorner(frame, 14)

	local title = makeLabel("Title", UDim2.fromScale(0.6, 0.08), UDim2.fromScale(0.03, 0.03), 30)
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame
	titleLabel = title

	local timer = makeLabel("Timer", UDim2.fromScale(0.15, 0.08), UDim2.fromScale(0.82, 0.03), 30)
	timer.Font = Enum.Font.GothamBold
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.Parent = frame
	timerLabel = timer

	local hint = makeLabel("Hint", UDim2.fromScale(0.94, 0.06), UDim2.fromScale(0.03, 0.11), 18)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = TEXT_DIM
	hint.Text = "Pick the Relics you think they hold. You are not told why a pick misses."
	hint.Parent = frame

	local picks = makeLabel("Picks", UDim2.fromScale(0.4, 0.05), UDim2.fromScale(0.03, 0.18), 20)
	picks.TextXAlignment = Enum.TextXAlignment.Left
	picks.Parent = frame
	picksLabel = picks

	local cells = Instance.new("Frame")
	cells.Name = "Slots"
	cells.BackgroundTransparency = 1
	cells.Position = UDim2.fromScale(0.03, 0.25)
	cells.Size = UDim2.fromScale(0.94, 0.6)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromScale(0.235, 0.3)
	layout.CellPadding = UDim2.fromScale(0.02, 0.04)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cells
	cells.Parent = frame
	grid = cells

	local done = Instance.new("TextButton")
	done.Name = "Done"
	done.AnchorPoint = Vector2.new(0.5, 1)
	done.Position = UDim2.fromScale(0.5, 0.97)
	done.Size = UDim2.fromScale(0.2, 0.08)
	done.BackgroundColor3 = BUTTON_COLOR
	done.TextColor3 = TEXT_LIGHT
	done.TextScaled = true
	done.Font = Enum.Font.GothamBold
	done.Text = "Done"
	addCorner(done, 8)
	limitText(done, 10, 22)
	-- Hides the screen here only; the server ends the claim on its own timer.
	done.Activated:Connect(ClaimUI.hide)
	done.Parent = frame

	frame.Parent = gui
	panel = frame
	gui.Parent = playerGui
end

function ClaimUI.show(name: string, claim: BlindClaim.Claim, secondsLeft: number)
	local frame = panel
	if frame == nil then
		return
	end
	victimName = name
	currentClaim = claim
	deadline = os.clock() + math.max(0, secondsLeft)
	frame.Visible = true
	render()
	startTicking()
end

function ClaimUI.hide()
	currentClaim = nil
	local frame = panel
	if frame ~= nil then
		frame.Visible = false
	end
end

function ClaimUI.isOpen(): boolean
	local frame = panel
	return frame ~= nil and frame.Visible
end

return ClaimUI
