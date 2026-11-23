--!strict
-- The pieces every screen shares: labels, buttons, windows, the borderless ScreenGui, the
-- one-request guard, the press seam for the play test, and where the HUD goes on this screen.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HudLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("HudLayout")
)

local UiKit = {}

UiKit.TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
UiKit.TEXT_DARK = Color3.fromRGB(20, 18, 24)
UiKit.PANEL = Color3.fromRGB(32, 28, 38)
UiKit.BUTTON = Color3.fromRGB(70, 60, 90)
-- A control waiting for its second tap.
UiKit.ARMED = Color3.fromRGB(170, 55, 55)
-- A request's row or window stays inert until the server's next view, or this long (a refusal
-- is answered with a message only).
UiKit.REARM_SECONDS = 1

export type TextOptions = {
	min: number?, -- default 9
	max: number?, -- default 20
	wrap: boolean?, -- default true
	align: Enum.TextXAlignment?, -- default Left
	font: Enum.Font?, -- default GothamMedium
	color: Color3?, -- default TEXT_LIGHT
}
export type ButtonOptions = {
	color: Color3?, -- default BUTTON
	textColor: Color3?, -- default TEXT_LIGHT
	min: number?, -- default 9
	max: number?, -- default 20
	wrap: boolean?, -- default false
	minSize: Vector2?, -- a UISizeConstraint, for Close buttons (40, 32)
}
export type Guard = { busy: boolean, serial: number, setInert: (inert: boolean) -> () }

local FALLBACK_WIDTH, FALLBACK_HEIGHT = 1280, 720

-- What each button's press does, so the play test can tap it. Weak: a destroyed button goes.
local pressHandlers: { [Instance]: () -> () } =
	setmetatable({} :: { [Instance]: () -> () }, { __mode = "k" }) :: any

local currentLayout: HudLayout.Layout? = nil
local currentInset = 0
local lastWidth, lastHeight, lastInset, lastTouch = -1, -1, -1, false
local layoutStarted = false
local layoutListeners: { (layout: HudLayout.Layout) -> () } = {}
local viewportConnection: RBXScriptConnection? = nil

local function pick<T>(value: T?, default: T): T
	if value == nil then
		return default
	end
	return value
end

-- UICorner, offset radius.
function UiKit.corner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

-- UIPadding, all four sides.
function UiKit.padding(parent: Instance, pixels: number)
	local padding = Instance.new("UIPadding")
	local amount = UDim.new(0, pixels)
	padding.PaddingTop = amount
	padding.PaddingBottom = amount
	padding.PaddingLeft = amount
	padding.PaddingRight = amount
	padding.Parent = parent
end

-- UITextSizeConstraint: scaled text stays between the two sizes.
function UiKit.limitText(parent: Instance, minSize: number, maxSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize
	constraint.MaxTextSize = maxSize
	constraint.Parent = parent
end

-- A scaled text label with no background, in the options' defaults.
function UiKit.label(
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	options: TextOptions?
): TextLabel
	local given: TextOptions = options or {}
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.TextColor3 = pick(given.color, UiKit.TEXT_LIGHT)
	label.TextScaled = true
	label.TextWrapped = pick(given.wrap, true)
	label.TextXAlignment = pick(given.align, Enum.TextXAlignment.Left)
	label.Font = pick(given.font, Enum.Font.GothamMedium)
	label.Text = text
	UiKit.limitText(label, pick(given.min, 9), pick(given.max, 20))
	return label
end

-- A scaled bold button with rounded corners; size nil leaves the size unset.
function UiKit.button(name: string, text: string, size: UDim2?, options: ButtonOptions?): TextButton
	local given: ButtonOptions = options or {}
	local button = Instance.new("TextButton")
	button.Name = name
	if size ~= nil then
		button.Size = size
	end
	button.BackgroundColor3 = pick(given.color, UiKit.BUTTON)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.TextColor3 = pick(given.textColor, UiKit.TEXT_LIGHT)
	button.TextScaled = true
	button.TextWrapped = pick(given.wrap, false)
	button.Font = Enum.Font.GothamBold
	button.Text = text
	UiKit.corner(button, 8)
	UiKit.limitText(button, pick(given.min, 9), pick(given.max, 20))
	if given.minSize ~= nil then
		local constraint = Instance.new("UISizeConstraint")
		constraint.MinSize = given.minSize
		constraint.Parent = button
	end
	return button
end

-- Dimmed and inert unless enabled (the look every window used).
function UiKit.setEnabled(button: GuiButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.6
	if button:IsA("TextButton") then
		button.TextTransparency = if enabled then 0 else 0.5
	end
end

-- Destroys every child that is not a UIComponent (a layout, a corner, a constraint).
function UiKit.clearRows(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIComponent") then
			child:Destroy()
		end
	end
end

-- A transparent scrolling list that grows with its rows.
function UiKit.scroller(
	name: string,
	size: UDim2,
	position: UDim2,
	thickness: number?
): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = name
	scroller.Size = size
	scroller.Position = position
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = pick(thickness, 6)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	return scroller
end

-- A ScreenGui that survives respawn, is marked IsleUi, and gives every GuiObject placed under it
-- no border.
function UiKit.screen(name: string, displayOrder: number, ignoreInset: boolean?): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = displayOrder
	gui.IgnoreGuiInset = ignoreInset == true
	gui:SetAttribute("IsleUi", true)
	gui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiObject") then
			descendant.BorderSizePixel = 0
		end
	end)
	return gui
end

-- A hidden, centred, rounded panel that never gets smaller than its kind's minimum.
function UiKit.window(name: string, size: UDim2, kind: "big" | "small" | "dialog"): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = size
	frame.BackgroundColor3 = UiKit.PANEL
	frame.BorderSizePixel = 0
	frame.Visible = false
	UiKit.corner(frame, 14)
	local minimum = if kind == "big"
		then HudLayout.WINDOW_MIN.big
		elseif kind == "small" then HudLayout.WINDOW_MIN.small
		else HudLayout.WINDOW_MIN.dialog
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(minimum.width, minimum.height)
	constraint.Parent = frame
	return frame
end

-- Connects Activated; the handler runs only while button.Active. Also records the handler for press.
function UiKit.onPress(button: GuiButton, handler: () -> ())
	pressHandlers[button] = handler
	-- A handler usually captures its own button, so the weak key alone never lets the entry go
	-- (Luau has no ephemerons): drop it when the button is destroyed.
	button.Destroying:Connect(function()
		pressHandlers[button] = nil
	end)
	button.Activated:Connect(function()
		if button.Active then
			handler()
		end
	end)
end

-- Play-test seam: runs the recorded handler as a tap would, only when the button is Active and it
-- and every GuiObject above it are Visible and its ScreenGui is Enabled. Returns whether it ran.
function UiKit.press(button: Instance): boolean
	local handler = pressHandlers[button]
	if handler == nil or not button:IsA("GuiButton") or not button.Active then
		return false
	end
	local current: Instance? = button
	while current ~= nil do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	handler()
	return true
end

-- A request guard: not busy, nothing answered yet.
function UiKit.guard(setInert: (inert: boolean) -> ()): Guard
	return { busy = false, serial = 0, setInert = setInert }
end

-- Busy: returns false, sends nothing. Else goes inert, sends, and comes back on the server's next
-- view (answered) or after REARM_SECONDS, whichever is first.
function UiKit.send(guard: Guard, request: () -> ()): boolean
	if guard.busy then
		return false
	end
	guard.busy = true
	guard.serial += 1
	local serial = guard.serial
	-- Scheduled before the request so a request that errors cannot leave the guard stuck.
	task.delay(UiKit.REARM_SECONDS, function()
		if guard.busy and guard.serial == serial then
			guard.busy = false
			guard.setInert(false)
		end
	end)
	guard.setInert(true)
	request()
	return true
end

-- The server's next view arrived: comes back at once and cancels the pending re-arm.
function UiKit.answered(guard: Guard)
	guard.serial += 1
	if guard.busy then
		guard.busy = false
		guard.setInert(false)
	end
end

local function measure()
	local camera = workspace.CurrentCamera
	local width, height = FALLBACK_WIDTH, FALLBACK_HEIGHT
	if camera ~= nil then
		width = math.floor(camera.ViewportSize.X)
		height = math.floor(camera.ViewportSize.Y)
	end
	local inset = GuiService:GetGuiInset().Y
	local touch = UserInputService.TouchEnabled
	if
		currentLayout ~= nil
		and width == lastWidth
		and height == lastHeight
		and inset == lastInset
		and touch == lastTouch
	then
		return
	end
	lastWidth, lastHeight, lastInset, lastTouch = width, height, inset, touch
	currentInset = inset
	local layout = HudLayout.compute(width, height, inset, touch)
	currentLayout = layout
	for _, callback in table.clone(layoutListeners) do
		callback(layout)
	end
end

local function watchCamera()
	if viewportConnection ~= nil then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(measure)
	end
	measure()
end

-- Measures the screen, keeps the layout, and measures again when the camera's ViewportSize
-- changes, when the camera is replaced, or when touch support changes. Call once, first.
function UiKit.startLayout()
	if layoutStarted then
		return
	end
	layoutStarted = true
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(measure)
	watchCamera()
end

-- The last layout (measures if none yet; 1280 x 720 with no camera).
function UiKit.layout(): HudLayout.Layout
	if currentLayout == nil then
		measure()
	end
	return currentLayout :: HudLayout.Layout
end

-- Calls the callback now with the current layout, and again on every change.
function UiKit.onLayout(callback: (layout: HudLayout.Layout) -> ())
	table.insert(layoutListeners, callback)
	callback(UiKit.layout())
end

-- Puts the object at a full-screen rectangle (pixels, top left anchor). A ScreenGui that keeps the
-- top bar's inset starts below it, so y moves up by the inset. Parent the object first.
function UiKit.place(object: GuiObject, rect: HudLayout.Rect)
	local gui = object:FindFirstAncestorWhichIsA("ScreenGui")
	local y = rect.y
	if gui ~= nil and not gui.IgnoreGuiInset then
		y -= currentInset
	end
	object.AnchorPoint = Vector2.zero
	object.Position = UDim2.fromOffset(rect.x, y)
	object.Size = UDim2.fromOffset(rect.width, rect.height)
end

return UiKit
