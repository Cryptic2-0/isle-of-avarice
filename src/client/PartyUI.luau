--!strict
-- Parties: the "Party" button, the invite banner, the party panel and the ally markers. It shows
-- what the server sent and names things in its requests; the server checks every one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PartyView = require(Shared:WaitForChild("Rules"):WaitForChild("PartyView"))
local Crown = require(Shared:WaitForChild("Rules"):WaitForChild("Crown"))

local TEXT_LIGHT = Color3.fromRGB(245, 235, 210)
local PANEL_COLOR = Color3.fromRGB(32, 28, 38)
local ROW_COLOR = Color3.fromRGB(42, 37, 50)
local BUTTON_COLOR = Color3.fromRGB(70, 60, 90)
local ACCEPT_COLOR = Color3.fromRGB(60, 130, 80)
local BAR_BACK_COLOR = Color3.fromRGB(20, 18, 24)
local BAR_COLOR = Color3.fromRGB(80, 190, 110)
local ALLY_COLOR = Color3.fromRGB(110, 220, 140)
local TITLE_COLOR = Color3.fromRGB(255, 215, 90)

local PANEL_WIDTH = 280
local PANEL_PAD = 8
local TITLE_HEIGHT = 26
local ROW_HEIGHT = 48
local ROW_GAP = 4
local LEAVE_WIDTH = 64
-- Kept free below the panel so it never reaches the bottom edge of the screen.
local PANEL_BOTTOM_MARGIN = 12
-- The trial HUD at the top right is four 28-pixel lines with 4 between (128); stay under it.
local PANEL_TOP_OFFSET = 146
-- A refused request sends only a message, not a sync; buttons come back after this long.
local REARM_SECONDS = 1

local PartyUI = {}

type Handlers = {
	request: () -> (),
	reply: (accept: boolean) -> (),
	action: (request: { [string]: any }) -> (),
}

local handlers: Handlers = {
	request = function() end,
	reply = function(_accept: boolean) end,
	action = function(_request: { [string]: any }) end,
}
local inviteBanner: Frame? = nil
local inviteLabel: TextLabel? = nil
local panel: Frame? = nil
local titleLabel: TextLabel? = nil
local rowsFrame: ScrollingFrame? = nil
local leaveButton: TextButton? = nil
local screenGui: ScreenGui? = nil
-- The drawn rows by member id, so health updates in place.
local rowFrames: { [number]: Frame } = {}
-- Bumped on every invite change, so an old invite's timer cannot hide a newer one.
local inviteToken = 0

local current: PartyView.Sync? = nil
local selfId = 0
-- Who is drawn, in what order, with which buttons, as one string: rows are rebuilt only when
-- it changes; health changes update the rows in place.
local drawnKey = ""
-- One request per render: set on a click, cleared by the next sync or the re-arm timer.
local pending = false
local pendingToken = 0
local markers: { [number]: BillboardGui } = {}

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

local function makeLabel(
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	maxText: number
): TextLabel
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
	label.Text = text
	limitText(label, 9, maxText)
	return label
end

local function makeButton(name: string, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = color
	button.TextColor3 = TEXT_LIGHT
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = text
	addCorner(button, 8)
	limitText(button, 9, 20)
	return button
end

-- Dimmed and inert unless `enabled`, as in the trade window.
local function setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = enabled
	button.BackgroundTransparency = if enabled then 0 else 0.6
	button.TextTransparency = if enabled then 0 else 0.5
end

-- Destroys the children of the given class (the rows, not the list layout).
local function clearChildren(container: Instance, className: string)
	for _, child in container:GetChildren() do
		if child:IsA(className) then
			child:Destroy()
		end
	end
end

-- Every panel button, so one click can make them all inert.
local function setPanelEnabled(enabled: boolean)
	local rows = rowsFrame
	if rows ~= nil then
		for _, row in rows:GetChildren() do
			for _, child in row:GetChildren() do
				if child:IsA("TextButton") then
					setEnabled(child, enabled)
				end
			end
		end
	end
	if leaveButton ~= nil then
		setEnabled(leaveButton, enabled)
	end
end

-- Sends one request, then waits for the next sync (or one second) before another.
local function send(request: { [string]: any })
	if pending then
		return
	end
	pending = true
	pendingToken += 1
	local token = pendingToken
	setPanelEnabled(false)
	handlers.action(request)
	task.delay(REARM_SECONDS, function()
		if pendingToken == token and pending then
			pending = false
			setPanelEnabled(true)
		end
	end)
end

local function hideInvite()
	inviteToken += 1
	local banner = inviteBanner
	if banner ~= nil then
		banner.Visible = false
	end
end

local function buildInvite(gui: ScreenGui)
	local banner = Instance.new("Frame")
	banner.Name = "Invite"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	-- Below the trade banner (12% to 21%) so both can show.
	banner.Position = UDim2.fromScale(0.5, 0.22)
	banner.Size = UDim2.fromScale(0.5, 0.09)
	banner.BackgroundColor3 = PANEL_COLOR
	banner.Visible = false
	addCorner(banner, 10)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(300, 44)
	minimum.Parent = banner

	local label = makeLabel("Text", "", UDim2.fromScale(0.44, 0.8), UDim2.fromScale(0.03, 0.1), 20)
	label.Parent = banner
	inviteLabel = label

	local accept = makeButton("Accept", "Accept", ACCEPT_COLOR)
	accept.Position = UDim2.fromScale(0.49, 0.12)
	accept.Size = UDim2.fromScale(0.24, 0.76)
	accept.Activated:Connect(function()
		hideInvite()
		handlers.reply(true)
	end)
	accept.Parent = banner

	local decline = makeButton("Decline", "Decline", BUTTON_COLOR)
	decline.Position = UDim2.fromScale(0.74, 0.12)
	decline.Size = UDim2.fromScale(0.24, 0.76)
	decline.Activated:Connect(function()
		hideInvite()
		handlers.reply(false)
	end)
	decline.Parent = banner

	banner.Parent = gui
	inviteBanner = banner
end

local function buildPanel(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	-- Under the trial HUD (anchor top right, 16% down, 128 pixels tall).
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, -12, 0.16, PANEL_TOP_OFFSET)
	frame.Size = UDim2.fromOffset(PANEL_WIDTH, 100)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.BackgroundTransparency = 0.15
	frame.Visible = false
	addCorner(frame, 10)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(PANEL_WIDTH, 0)
	minimum.Parent = frame

	local title = makeLabel(
		"Title",
		"",
		UDim2.new(1, -(3 * PANEL_PAD + LEAVE_WIDTH), 0, TITLE_HEIGHT),
		UDim2.fromOffset(PANEL_PAD, PANEL_PAD),
		20
	)
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	titleLabel = title

	-- In the title row, so it shows whenever the panel does.
	local leave = makeButton("Leave", "Leave", BUTTON_COLOR)
	leave.AnchorPoint = Vector2.new(1, 0)
	leave.Position = UDim2.new(1, -PANEL_PAD, 0, PANEL_PAD)
	leave.Size = UDim2.fromOffset(LEAVE_WIDTH, TITLE_HEIGHT)
	leave.Activated:Connect(function()
		send({ kind = "leave" })
	end)
	leave.Parent = frame
	leaveButton = leave

	local rows = Instance.new("ScrollingFrame")
	rows.Name = "Rows"
	rows.BackgroundTransparency = 1
	rows.BorderSizePixel = 0
	rows.Position = UDim2.fromOffset(PANEL_PAD, PANEL_PAD + TITLE_HEIGHT + ROW_GAP)
	rows.Size = UDim2.new(1, -2 * PANEL_PAD, 0, 0)
	rows.CanvasSize = UDim2.new()
	rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rows.ScrollingDirection = Enum.ScrollingDirection.Y
	rows.ScrollBarThickness = 4
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.Parent = rows
	rows.Parent = frame
	rowsFrame = rows

	frame.Parent = gui
	panel = frame
end

-- The Crowned title of a member, from the attributes the server keeps on their Player (empty
-- when not Crowned or when the Player is gone).
local function titleOf(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player == nil then
		return ""
	end
	return Crown.title(player:GetAttribute("Crowns"), player:GetAttribute("Stars"))
end

local function buildRow(row: PartyView.Row, index: number, parent: Instance)
	local frame = Instance.new("Frame")
	frame.Name = "Row" .. row.userId
	frame.LayoutOrder = index
	-- Leaves room for the scroll bar.
	frame.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = ROW_COLOR
	addCorner(frame, 8)

	local name = makeLabel("Name", row.name, UDim2.fromOffset(98, 18), UDim2.fromOffset(6, 3), 14)
	name.Parent = frame

	local health =
		makeLabel("Health", row.healthText, UDim2.fromOffset(60, 18), UDim2.fromOffset(104, 3), 14)
	health.TextXAlignment = Enum.TextXAlignment.Right
	health.Parent = frame

	-- Under the name; empty (and so invisible) unless the member is Crowned.
	local crowned = makeLabel(
		"Title",
		titleOf(row.userId),
		UDim2.new(1, -12, 0, 14),
		UDim2.fromOffset(6, 22),
		12
	)
	crowned.TextColor3 = TITLE_COLOR
	crowned.Parent = frame

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(6, 38)
	bar.Size = UDim2.new(1, -12, 0, 6)
	bar.BackgroundColor3 = BAR_BACK_COLOR
	addCorner(bar, 3)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(row.share, 1)
	fill.BackgroundColor3 = BAR_COLOR
	addCorner(fill, 3)
	fill.Parent = bar
	bar.Parent = frame

	if row.canRemove then
		local remove = makeButton("Remove", "Remove", BUTTON_COLOR)
		remove.AnchorPoint = Vector2.new(1, 0)
		remove.Position = UDim2.new(1, -4, 0, 3)
		remove.Size = UDim2.fromOffset(46, 18)
		setEnabled(remove, not pending)
		remove.Activated:Connect(function()
			send({ kind = "kick", userId = row.userId })
		end)
		remove.Parent = frame
	end
	if row.canLead then
		local lead = makeButton("MakeLeader", "Lead", BUTTON_COLOR)
		lead.AnchorPoint = Vector2.new(1, 0)
		lead.Position = UDim2.new(1, -54, 0, 3)
		lead.Size = UDim2.fromOffset(40, 18)
		setEnabled(lead, not pending)
		lead.Activated:Connect(function()
			send({ kind = "promote", userId = row.userId })
		end)
		lead.Parent = frame
	end
	frame.Parent = parent
	rowFrames[row.userId] = frame
end

local function removeMarker(userId: number)
	local marker = markers[userId]
	if marker ~= nil then
		marker:Destroy()
		markers[userId] = nil
	end
end

local function clearMarkers()
	for userId in markers do
		removeMarker(userId)
	end
end

local function makeMarker(userId: number, name: string, head: BasePart, character: Model)
	local gui = Instance.new("BillboardGui")
	gui.Name = "AllyMarker_" .. userId
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	-- Above the MARKED tag.
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.Size = UDim2.fromOffset(140, 26)
	local label = makeLabel("Label", name, UDim2.fromScale(1, 1), UDim2.new(), 20)
	label.TextColor3 = ALLY_COLOR
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = character
	markers[userId] = gui
end

-- One marker per ally whose character has a Head; re-pointed after a respawn, dropped when the
-- ally leaves the party. The name is the plain one from the last sync.
local function updateMarkers(sync: PartyView.Sync)
	local wanted: { [number]: boolean } = {}
	for _, userId in PartyView.allyIds(sync, selfId) do
		local name = ""
		for _, member in sync.members do
			if member.userId == userId then
				name = member.name
			end
		end
		local player = Players:GetPlayerByUserId(userId)
		local character = if player ~= nil then player.Character else nil
		local head = if character ~= nil then character:FindFirstChild("Head") else nil
		if character ~= nil and head ~= nil and head:IsA("BasePart") then
			wanted[userId] = true
			local marker = markers[userId]
			if marker ~= nil and (marker.Adornee ~= head or marker.Parent ~= character) then
				removeMarker(userId)
				marker = nil
			end
			if marker == nil then
				makeMarker(userId, name, head, character)
			else
				local label = marker:FindFirstChild("Label")
				if label ~= nil and label:IsA("TextLabel") and label.Text ~= name then
					label.Text = name
				end
			end
		end
	end
	for userId in markers do
		if not wanted[userId] then
			removeMarker(userId)
		end
	end
end

-- Each member's health from their character, if it has one; a missing entry shows as unknown.
local function readHealths(sync: PartyView.Sync): { [string]: PartyView.Health }
	local healths: { [string]: PartyView.Health } = {}
	for _, member in sync.members do
		local player = Players:GetPlayerByUserId(member.userId)
		local character = if player ~= nil then player.Character else nil
		local humanoid = if character ~= nil
			then character:FindFirstChildOfClass("Humanoid")
			else nil
		if humanoid ~= nil then
			healths[tostring(member.userId)] =
				{ health = humanoid.Health, max = humanoid.MaxHealth }
		end
	end
	return healths
end

-- What decides the rows' shape: who, in what order, the leader mark and the buttons. Health is
-- not part of it.
local function rowsKey(rows: { PartyView.Row }): string
	local parts: { string } = {}
	for _, row in rows do
		table.insert(
			parts,
			string.format(
				"%d|%s|%s|%s",
				row.userId,
				row.name,
				tostring(row.canRemove),
				tostring(row.canLead)
			)
		)
	end
	return table.concat(parts, ";")
end

-- Sets the panel's height: all the rows, but no lower than the screen allows (the rows then
-- scroll, and the title row with Leave stays on screen).
local function sizePanel(frame: Frame, rowsHolder: ScrollingFrame, count: number)
	local wanted = count * (ROW_HEIGHT + ROW_GAP) - ROW_GAP
	local fixed = PANEL_PAD + TITLE_HEIGHT + ROW_GAP + PANEL_PAD
	local gui = screenGui
	local height = if gui ~= nil then gui.AbsoluteSize.Y else 0
	local rowsHeight = wanted
	if height > 0 then
		local top = 0.16 * height + PANEL_TOP_OFFSET
		local room = height - top - PANEL_BOTTOM_MARGIN - fixed
		rowsHeight = math.min(wanted, math.max(room, ROW_HEIGHT))
	end
	rowsHolder.Size = UDim2.new(1, -2 * PANEL_PAD, 0, rowsHeight)
	frame.Size = UDim2.fromOffset(PANEL_WIDTH, fixed + rowsHeight)
end

-- Redraws the panel and markers from the current party. Rows are rebuilt only when who is in
-- the party, the order, the leader or the viewer's buttons changed; otherwise each row's health
-- text and bar are updated where they stand, so a tap on a button is never lost to a rebuild.
local function redraw()
	local frame = panel
	local rowsHolder = rowsFrame
	local sync = current
	if frame == nil or rowsHolder == nil or sync == nil then
		return
	end
	local rows = PartyView.rows(sync, selfId, readHealths(sync))
	local key = rowsKey(rows)
	if titleLabel ~= nil then
		local title = PartyView.title(sync)
		if titleLabel.Text ~= title then
			titleLabel.Text = title
		end
	end
	if key ~= drawnKey then
		drawnKey = key
		clearChildren(rowsHolder, "Frame")
		table.clear(rowFrames)
		for index, row in rows do
			buildRow(row, index, rowsHolder)
		end
	else
		for _, row in rows do
			local frameOfRow = rowFrames[row.userId]
			if frameOfRow == nil then
				continue
			end
			local health = frameOfRow:FindFirstChild("Health")
			if health ~= nil and health:IsA("TextLabel") and health.Text ~= row.healthText then
				health.Text = row.healthText
			end
			-- Titles can change without a rebuild.
			local crowned = frameOfRow:FindFirstChild("Title")
			if crowned ~= nil and crowned:IsA("TextLabel") then
				local title = titleOf(row.userId)
				if crowned.Text ~= title then
					crowned.Text = title
				end
			end
			local bar = frameOfRow:FindFirstChild("Bar")
			local fill = if bar ~= nil then bar:FindFirstChild("Fill") else nil
			if fill ~= nil and fill:IsA("Frame") then
				fill.Size = UDim2.fromScale(row.share, 1)
			end
		end
	end
	sizePanel(frame, rowsHolder, #rows)
	frame.Visible = true
	updateMarkers(sync)
end

function PartyUI.mount(playerGui: PlayerGui, given: Handlers)
	handlers = given
	selfId = Players.LocalPlayer.UserId

	local gui = Instance.new("ScreenGui")
	gui.Name = "PartyGui"
	gui.ResetOnSpawn = false
	-- With the other windows; below the messages (20).
	gui.DisplayOrder = 16
	screenGui = gui

	-- Above the Trade button: the Ledger button fills 90% to 97% (bottom left), Paths 82% to 89%,
	-- Trade 74% to 81%, and this one 66% to 73%.
	local button = makeButton("PartyButton", "Party", BUTTON_COLOR)
	button.AnchorPoint = Vector2.new(0, 1)
	button.Position = UDim2.fromScale(0.02, 0.73)
	button.Size = UDim2.fromScale(0.14, 0.07)
	local limit = button:FindFirstChildOfClass("UITextSizeConstraint")
	if limit ~= nil then
		limit.MinTextSize = 12
	end
	button.Activated:Connect(function()
		handlers.request()
	end)
	button.Parent = gui

	buildInvite(gui)
	buildPanel(gui)
	gui.Parent = playerGui
end

-- A banner asking to join a party; it goes away by itself after `seconds`. nil hides it.
function PartyUI.showInvite(invite: { from: string, seconds: number }?)
	local banner = inviteBanner
	local label = inviteLabel
	if banner == nil or label == nil then
		return
	end
	hideInvite()
	if invite == nil then
		return
	end
	label.Text = PartyView.inviteText(invite.from)
	banner.Visible = true
	local token = inviteToken
	task.delay(invite.seconds, function()
		if inviteToken == token then
			hideInvite()
		end
	end)
end

-- The party as the server sees it. nil hides the panel and removes every marker.
function PartyUI.setParty(sync: PartyView.Sync?)
	current = sync
	-- A new sync answers whatever was sent: the buttons come back.
	pending = false
	pendingToken += 1
	-- Rows are no longer rebuilt on every sync, so the buttons are re-enabled explicitly.
	setPanelEnabled(true)
	if sync == nil then
		drawnKey = ""
		if panel ~= nil then
			panel.Visible = false
		end
		if rowsFrame ~= nil then
			clearChildren(rowsFrame, "Frame")
		end
		table.clear(rowFrames)
		clearMarkers()
		return
	end
	redraw()
end

-- Called a few times a second: re-reads ally health, updates the rows in place, keeps markers right.
function PartyUI.refresh(localPlayer: Player)
	selfId = localPlayer.UserId
	redraw()
end

return PartyUI
