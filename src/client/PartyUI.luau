--!strict
-- Parties: the "Party" button, the invite banner, the party panel and the ally markers. It shows
-- what the server sent and names things in its requests; the server checks every one.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PartyView = require(Shared:WaitForChild("Rules"):WaitForChild("PartyView"))
local Crown = require(Shared:WaitForChild("Rules"):WaitForChild("Crown"))
local HudLayout = require(Shared:WaitForChild("Rules"):WaitForChild("HudLayout"))
local UiKit = require(script.Parent.UiKit)

local ROW_COLOR = Color3.fromRGB(42, 37, 50)
local ACCEPT_COLOR = Color3.fromRGB(60, 130, 80)
local BAR_BACK_COLOR = Color3.fromRGB(20, 18, 24)
local BAR_COLOR = Color3.fromRGB(80, 190, 110)
local ALLY_COLOR = Color3.fromRGB(110, 220, 140)
local TITLE_COLOR = Color3.fromRGB(255, 215, 90)

local PANEL_PAD = 8
local TITLE_HEIGHT = 26
local ROW_HEIGHT = 48
local ROW_GAP = 4
local LEAVE_WIDTH = 64

local PartyUI = {}

type Handlers = {
	reply: (accept: boolean) -> (),
	action: (request: { [string]: any }) -> (),
}

local handlers: Handlers = {
	reply = function(_accept: boolean) end,
	action = function(_request: { [string]: any }) end,
}
local inviteBanner: Frame? = nil
local inviteLabel: TextLabel? = nil
local panel: Frame? = nil
local titleLabel: TextLabel? = nil
local rowsFrame: ScrollingFrame? = nil
local leaveButton: TextButton? = nil
-- The drawn rows by member id, so health updates in place.
local rowFrames: { [number]: Frame } = {}
-- Bumped on every invite change, so an old invite's timer cannot hide a newer one.
local inviteToken = 0

local current: PartyView.Sync? = nil
local selfId = 0
-- Who is drawn, in what order, with which buttons, as one string: rows are rebuilt only when
-- it changes; health changes update the rows in place.
local drawnKey = ""
-- The trial HUD lines the panel sits under; the HUD loop gives it with every refresh.
local lastHudLines = 0
local markers: { [number]: BillboardGui } = {}

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
					UiKit.setEnabled(child, enabled)
				end
			end
		end
	end
	if leaveButton ~= nil then
		UiKit.setEnabled(leaveButton, enabled)
	end
end

-- One request per render: the panel is inert until the next sync (or one second, a refused
-- request sends only a message).
local guard = UiKit.guard(function(inert: boolean)
	setPanelEnabled(not inert)
end)

local function send(request: { [string]: any })
	UiKit.send(guard, function()
		handlers.action(request)
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
	-- Below the trade banner (18% to 27%) so both can show.
	banner.Position = UDim2.fromScale(0.5, 0.28)
	banner.Size = UDim2.fromScale(0.5, 0.09)
	banner.BackgroundColor3 = UiKit.PANEL
	banner.Visible = false
	UiKit.corner(banner, 10)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(300, 44)
	minimum.Parent = banner

	local label = UiKit.label(
		"Text",
		"",
		UDim2.fromScale(0.44, 0.8),
		UDim2.fromScale(0.03, 0.1),
		{ max = 20 }
	)
	label.Parent = banner
	inviteLabel = label

	local accept =
		UiKit.button("Accept", "Accept", UDim2.fromScale(0.24, 0.76), { color = ACCEPT_COLOR })
	accept.Position = UDim2.fromScale(0.49, 0.12)
	UiKit.onPress(accept, function()
		hideInvite()
		handlers.reply(true)
	end)
	accept.Parent = banner

	local decline = UiKit.button("Decline", "Decline", UDim2.fromScale(0.24, 0.76))
	decline.Position = UDim2.fromScale(0.74, 0.12)
	UiKit.onPress(decline, function()
		hideInvite()
		handlers.reply(false)
	end)
	decline.Parent = banner

	banner.Parent = gui
	inviteBanner = banner
end

-- Placed by sizePanel (under the trial HUD, above the menu row); the size here is a first guess.
local function buildPanel(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromOffset(280, 100)
	frame.BackgroundColor3 = UiKit.PANEL
	frame.BackgroundTransparency = 0.15
	frame.Visible = false
	UiKit.corner(frame, 10)

	local title = UiKit.label(
		"Title",
		"",
		UDim2.new(1, -(3 * PANEL_PAD + LEAVE_WIDTH), 0, TITLE_HEIGHT),
		UDim2.fromOffset(PANEL_PAD, PANEL_PAD),
		{ max = 20 }
	)
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	titleLabel = title

	-- In the title row, so it shows whenever the panel does.
	local leave = UiKit.button("Leave", "Leave", UDim2.fromOffset(LEAVE_WIDTH, TITLE_HEIGHT))
	leave.AnchorPoint = Vector2.new(1, 0)
	leave.Position = UDim2.new(1, -PANEL_PAD, 0, PANEL_PAD)
	UiKit.onPress(leave, function()
		send({ kind = "leave" })
	end)
	leave.Parent = frame
	leaveButton = leave

	local rows = UiKit.scroller(
		"Rows",
		UDim2.new(1, -2 * PANEL_PAD, 0, 0),
		UDim2.fromOffset(PANEL_PAD, PANEL_PAD + TITLE_HEIGHT + ROW_GAP),
		4
	)
	rows.ScrollingDirection = Enum.ScrollingDirection.Y
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
	UiKit.corner(frame, 8)

	-- Line 1: the name takes the room left of Health; a long one ends in "..." and is never shrunk.
	local name = UiKit.label(
		"Name",
		row.name,
		UDim2.new(1, -70, 0, 18),
		UDim2.fromOffset(6, 3),
		{ max = 14, wrap = false }
	)
	name.TextScaled = false
	name.TextSize = 14
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = frame

	local health = UiKit.label(
		"Health",
		row.healthText,
		UDim2.fromOffset(56, 18),
		UDim2.new(1, -4, 0, 3),
		{ max = 14, align = Enum.TextXAlignment.Right }
	)
	health.AnchorPoint = Vector2.new(1, 0)
	health.Parent = frame

	-- Line 2: under the name; empty (and so invisible) unless the member is Crowned. It stops
	-- short of the buttons.
	local buttonsWidth = (if row.canRemove then 50 else 0) + (if row.canLead then 44 else 0)
	local crowned = UiKit.label(
		"Title",
		titleOf(row.userId),
		UDim2.new(1, -(12 + buttonsWidth), 0, 14),
		UDim2.fromOffset(6, 22),
		{ max = 12, color = TITLE_COLOR }
	)
	crowned.Parent = frame

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(6, 38)
	bar.Size = UDim2.new(1, -12, 0, 6)
	bar.BackgroundColor3 = BAR_BACK_COLOR
	UiKit.corner(bar, 3)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(row.share, 1)
	fill.BackgroundColor3 = BAR_COLOR
	UiKit.corner(fill, 3)
	fill.Parent = bar
	bar.Parent = frame

	if row.canRemove then
		local remove = UiKit.button("Remove", "Remove", UDim2.fromOffset(46, 16))
		remove.AnchorPoint = Vector2.new(1, 0)
		remove.Position = UDim2.new(1, -4, 0, 22)
		UiKit.setEnabled(remove, not guard.busy)
		UiKit.onPress(remove, function()
			send({ kind = "kick", userId = row.userId })
		end)
		remove.Parent = frame
	end
	if row.canLead then
		local lead = UiKit.button("MakeLeader", "Lead", UDim2.fromOffset(40, 16))
		lead.AnchorPoint = Vector2.new(1, 0)
		lead.Position = UDim2.new(1, -(4 + (if row.canRemove then 50 else 0)), 0, 22)
		UiKit.setEnabled(lead, not guard.busy)
		UiKit.onPress(lead, function()
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
	local label = UiKit.label("Label", name, UDim2.fromScale(1, 1), UDim2.new(), {
		max = 20,
		color = ALLY_COLOR,
		align = Enum.TextXAlignment.Center,
		font = Enum.Font.GothamBold,
	})
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

-- Places the panel under the trial HUD lines shown and above the menu row (the rows then
-- scroll, and the title row with Leave stays on screen).
local function sizePanel(frame: Frame, rowsHolder: ScrollingFrame, count: number, hudLines: number)
	local fixed = PANEL_PAD + TITLE_HEIGHT + ROW_GAP + PANEL_PAD
	local wanted = fixed + count * (ROW_HEIGHT + ROW_GAP) - ROW_GAP
	local rect = HudLayout.partyPanel(UiKit.layout(), hudLines, wanted)
	UiKit.place(frame, rect)
	rowsHolder.Size = UDim2.new(1, -2 * PANEL_PAD, 0, math.max(0, rect.height - fixed))
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
	sizePanel(frame, rowsHolder, #rows, lastHudLines)
	frame.Visible = true
	updateMarkers(sync)
end

function PartyUI.mount(playerGui: PlayerGui, given: Handlers)
	handlers = given
	selfId = Players.LocalPlayer.UserId

	-- With the other windows; below the messages (20).
	local gui = UiKit.screen("PartyGui", 16)

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
	UiKit.answered(guard)
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
function PartyUI.refresh(localPlayer: Player, hudLines: number)
	selfId = localPlayer.UserId
	lastHudLines = hudLines
	redraw()
end

return PartyUI
