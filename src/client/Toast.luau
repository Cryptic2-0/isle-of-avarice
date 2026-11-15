--!strict
-- Messages at the top of the screen, one at a time. A message stays 3 seconds, or 1.5 when
-- another is waiting. At most 4 wait; a fifth pushes out the one that has waited longest.
local SHOW_SECONDS = 3
local SHORT_SECONDS = 1.5
local MAX_WAITING = 4
local STEP_SECONDS = 0.1

local Toast = {}

local label: TextLabel? = nil
local waiting: { string } = {}
local showing = false

function Toast.mount(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ToastGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20

	local text = Instance.new("TextLabel")
	text.Name = "Message"
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.fromScale(0.5, 0.04)
	text.Size = UDim2.fromScale(0.6, 0.07)
	text.BackgroundColor3 = Color3.fromRGB(25, 22, 30)
	text.BackgroundTransparency = 0.15
	text.TextColor3 = Color3.fromRGB(245, 235, 210)
	text.TextScaled = true
	text.Font = Enum.Font.GothamMedium
	text.Text = ""
	text.Visible = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = text
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = text
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 12
	constraint.MaxTextSize = 28
	constraint.Parent = text

	text.Parent = gui
	label = text
	gui.Parent = playerGui
end

-- Shows `first`, then everything that queues up behind it, then hides the label.
local function run(current: TextLabel, first: string)
	local text: string? = first
	while text ~= nil do
		current.Text = text
		current.Visible = true
		local shownFor = 0
		while shownFor < SHOW_SECONDS and not (#waiting > 0 and shownFor >= SHORT_SECONDS) do
			shownFor += task.wait(STEP_SECONDS)
		end
		text = table.remove(waiting, 1)
	end
	current.Visible = false
	showing = false
end

function Toast.show(text: string)
	local current = label
	if current == nil then
		return
	end
	if showing then
		if #waiting >= MAX_WAITING then
			table.remove(waiting, 1)
		end
		table.insert(waiting, text)
		return
	end
	showing = true
	task.spawn(run, current, text)
end

-- The message on screen and those waiting, oldest first (play-test seam).
function Toast.pending(): { string }
	local list = table.clone(waiting)
	local current = label
	if showing and current ~= nil then
		table.insert(list, 1, current.Text)
	end
	return list
end

return Toast
