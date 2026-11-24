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
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local TICK_SECONDS = 0.25
-- An open cell is see-through so the tier colour sits softly on the panel.
local OPEN_TRANSPARENCY = 0.35

local TEXT_DARK = Color3.fromRGB(20, 18, 24)
local TEXT_DIM = Color3.fromRGB(130, 130, 135)
local MISS_COLOR = Color3.fromRGB(40, 40, 45)
local LOCKED_COLOR = Color3.fromRGB(70, 70, 75)

local ClaimUI = {}

local panel: Frame? = nil
local titleLabel: TextLabel? = nil
local picksLabel: TextLabel? = nil
local timerLabel: TextLabel? = nil
local grid: Frame? = nil
local pickHandler: (slot: number) -> () = function(_slot: number) end
local finishHandler: () -> () = function() end

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

local function secondsRemaining(): number
	return math.max(0, deadline - os.clock())
end

local function buildView(claim: BlindClaim.Claim): ClaimView.View
	return ClaimView.build(victimName, claim, claim.expiresAt - secondsRemaining())
end

local function makeCell(slot: ClaimView.SlotView): TextButton
	-- Cell text keeps a minimum of 7 so a phone can read it.
	local cell = UiKit.button("Slot" .. slot.label, "", nil, { min = 7, max = 18, wrap = true })
	cell.LayoutOrder = slot.slot
	cell.Font = Enum.Font.GothamMedium
	cell.AutoButtonColor = slot.state == "open"
	UiKit.padding(cell, 2)

	-- Two lines so the text fits a small cell: the label, then the status or the Relic name.
	local text = slot.label .. "\n" .. slot.name
	if slot.state == "open" then
		cell.BackgroundColor3 = tierColor(slot.tier)
		cell.BackgroundTransparency = OPEN_TRANSPARENCY
		cell.TextColor3 = TEXT_DARK
	elseif slot.state == "taken" then
		cell.BackgroundColor3 = tierColor(slot.tier)
		cell.TextColor3 = TEXT_DARK
		cell.Font = Enum.Font.GothamBold
		text = slot.label .. "\nTaken!"
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 3
		stroke.Parent = cell
	elseif slot.state == "miss" then
		cell.BackgroundColor3 = MISS_COLOR
		cell.TextColor3 = TEXT_DIM
		text = slot.label .. "\nNothing"
	else
		cell.BackgroundColor3 = LOCKED_COLOR
		cell.BackgroundTransparency = 0.4
		cell.TextColor3 = TEXT_DIM
		cell.TextTransparency = 0.4
	end
	cell.Text = text

	if slot.state == "open" then
		-- Each open cell has its own guard: a second tap on it waits for the next view, which
		-- rebuilds the cells. Dimmed here by hand so it comes back to the open look.
		local guard = UiKit.guard(function(inert: boolean)
			cell.Active = not inert
			cell.AutoButtonColor = not inert
			cell.BackgroundTransparency = if inert then 0.7 else OPEN_TRANSPARENCY
			cell.TextTransparency = if inert then 0.5 else 0
		end)
		UiKit.onPress(cell, function()
			UiKit.send(guard, function()
				pickHandler(slot.slot)
			end)
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
	UiKit.clearRows(cells)
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

function ClaimUI.mount(playerGui: PlayerGui, onPick: (slot: number) -> (), onFinish: () -> ())
	pickHandler = onPick
	finishHandler = onFinish

	-- Above the Ledger book (10), the status HUD (15) and messages (20).
	local gui = UiKit.screen("ClaimGui", 30)

	-- A "big" window never gets smaller than the 50 cells need, even on a phone under its top bar.
	local frame = UiKit.window("Claim", UDim2.fromScale(0.9, 0.9), "big")

	local title = UiKit.label(
		"Title",
		"",
		UDim2.fromScale(0.6, 0.08),
		UDim2.fromScale(0.03, 0.02),
		{ min = 10, max = 30, font = Enum.Font.GothamBold }
	)
	title.Parent = frame
	titleLabel = title

	local timer = UiKit.label(
		"Timer",
		"",
		UDim2.fromScale(0.15, 0.08),
		UDim2.fromScale(0.82, 0.02),
		{ min = 10, max = 30, font = Enum.Font.GothamBold, align = Enum.TextXAlignment.Right }
	)
	timer.Parent = frame
	timerLabel = timer

	local hint = UiKit.label(
		"Hint",
		"Pick the Relics you think they hold. You are not told why a pick misses.",
		UDim2.fromScale(0.94, 0.06),
		UDim2.fromScale(0.03, 0.1),
		{ min = 10, max = 18, color = TEXT_DIM }
	)
	hint.Parent = frame

	local picks = UiKit.label(
		"Picks",
		"",
		UDim2.fromScale(0.4, 0.05),
		UDim2.fromScale(0.03, 0.16),
		{ min = 10, max = 20 }
	)
	picks.Parent = frame
	picksLabel = picks

	local cells = Instance.new("Frame")
	cells.Name = "Slots"
	cells.BackgroundTransparency = 1
	cells.Position = UDim2.fromScale(0.03, 0.22)
	cells.Size = UDim2.fromScale(0.94, 0.68)
	local layout = Instance.new("UIGridLayout")
	-- 50 slots: ten columns by five rows.
	layout.CellSize = UDim2.fromScale(0.088, 0.17)
	layout.CellPadding = UDim2.fromScale(0.0133, 0.035)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cells
	cells.Parent = frame
	grid = cells

	local done = UiKit.button("Done", "Done", UDim2.fromScale(0.2, 0.08), { min = 10, max = 22 })
	done.AnchorPoint = Vector2.new(0.5, 1)
	done.Position = UDim2.fromScale(0.5, 0.98)
	-- Asks the server to end the claim now; the screen closes when the server says it ended
	-- (ClaimUpdate nil), so it never hides while the victim's Ledger is still locked. Once the
	-- claim has run out here (time or picks), Done just closes the screen.
	local doneGuard = UiKit.guard(function(inert: boolean)
		UiKit.setEnabled(done, not inert)
	end)
	UiKit.onPress(done, function()
		if currentClaim == nil or not shownOpen then
			ClaimUI.hide()
			return
		end
		UiKit.send(doneGuard, finishHandler)
	end)
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
