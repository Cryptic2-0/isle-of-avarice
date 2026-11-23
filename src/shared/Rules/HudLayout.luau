--!strict
-- Where the always-on HUD controls go on a screen: the menu row, the ability bar, the trial HUD,
-- the party panel and the Drop shield button. Rectangles are whole pixels in full-screen
-- coordinates (y = 0 is the top edge, above Roblox's top bar). On a touch screen the controls
-- keep off the movement thumbstick (bottom left) and the jump button (bottom right).

export type Rect = { x: number, y: number, width: number, height: number }
export type Layout = {
	touch: boolean,
	small: boolean, -- the shorter screen side is under SMALL_SIDE (a phone)
	thumb: Rect?, -- touch only
	jump: Rect?, -- touch only
	menu: { Rect }, -- Ledger, Paths, Trade, Party, left to right
	abilityBar: Rect,
	trialHud: Rect, -- room for HUD_LINES lines
	hudLineHeight: number,
	partyWidth: number,
	partyMaxBottom: number,
}

local HudLayout = {}

HudLayout.MARGIN = 12
HudLayout.GAP = 6
HudLayout.HUD_LINES = 4
-- A screen whose shorter side is under this is a phone; Roblox then draws a small jump button.
HudLayout.SMALL_SIDE = 500
-- The party panel's padding, title row, gap and padding: its height with no row showing.
HudLayout.PARTY_MIN_HEIGHT = 46
-- The smallest size of each kind of window; a window's share of the screen wins when larger.
HudLayout.WINDOW_MIN = {
	big = { width = 600, height = 280 },
	small = { width = 300, height = 240 },
	dialog = { width = 300, height = 140 },
}

local THUMB_WIDTH_PERCENT = 40
local THUMB_HEIGHT_PERCENT = 45
local SLOT_MIN, SLOT_MAX = 44, 96
local MENU_MAX_WIDTH = 120

function HudLayout.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.width
		and b.x < a.x + a.width
		and a.y < b.y + b.height
		and b.y < a.y + a.height
end

-- Under the Coin line, top left: (12, 44) below the top bar.
function HudLayout.dropShield(insetTop: number): Rect
	return { x = 12, y = insetTop + 44, width = 150, height = 32 }
end

function HudLayout.compute(width: number, height: number, insetTop: number, touch: boolean): Layout
	local margin, gap = HudLayout.MARGIN, HudLayout.GAP
	local small = math.min(width, height) < HudLayout.SMALL_SIDE
	local left, right = margin, width - margin
	local thumb: Rect? = nil
	local jump: Rect? = nil
	if touch then
		local thumbWidth = math.ceil(width * THUMB_WIDTH_PERCENT / 100)
		local thumbHeight = math.floor(height * THUMB_HEIGHT_PERCENT / 100)
		thumb = { x = 0, y = height - thumbHeight, width = thumbWidth, height = thumbHeight }
		local jumpWidth = if small then 100 else 180
		local jumpHeight = if small then 95 else 220
		jump = {
			x = width - jumpWidth,
			y = height - jumpHeight,
			width = jumpWidth,
			height = jumpHeight,
		}
		left = thumbWidth + margin
		right = width - jumpWidth - margin
	end
	local band = right - left
	local slot =
		math.clamp(math.floor(math.min((band - 3 * gap) / 4, height / 10)), SLOT_MIN, SLOT_MAX)
	local barWidth = 4 * slot + 3 * gap
	local abilityBar: Rect = {
		x = left + math.floor((band - barWidth) / 2),
		y = height - margin - slot,
		width = barWidth,
		height = slot,
	}
	local menuWidth = math.min(math.floor((band - 3 * gap) / 4), MENU_MAX_WIDTH)
	local menuHeight = if small then 32 else 36
	local rowX = left + math.floor((band - (4 * menuWidth + 3 * gap)) / 2)
	local menu: { Rect } = {}
	for i = 1, 4 do
		table.insert(menu, {
			x = rowX + (i - 1) * (menuWidth + gap),
			y = abilityBar.y - gap - menuHeight,
			width = menuWidth,
			height = menuHeight,
		})
	end
	local hudWidth = if small then 220 else 300
	local lineHeight = if small then 22 else 28
	local hudY = if small
		then insetTop + 8
		else insetTop + math.floor((height - insetTop) * 16 / 100)
	local trialHud: Rect = {
		x = width - margin - hudWidth,
		y = hudY,
		width = hudWidth,
		height = HudLayout.HUD_LINES * (lineHeight + 4) - 4,
	}
	local partyWidth = if small then 220 else 280
	-- The panel's column, top to bottom: it must stop above anything in it.
	local column: Rect =
		{ x = width - margin - partyWidth, y = 0, width = partyWidth, height = height }
	local partyMaxBottom = height - margin
	local below: { Rect } = table.clone(menu)
	table.insert(below, abilityBar)
	if jump ~= nil then
		table.insert(below, jump)
	end
	for _, rect in below do
		if HudLayout.overlaps(column, rect) then
			partyMaxBottom = math.min(partyMaxBottom, rect.y - gap)
		end
	end
	return {
		touch = touch,
		small = small,
		thumb = thumb,
		jump = jump,
		menu = menu,
		abilityBar = abilityBar,
		trialHud = trialHud,
		hudLineHeight = lineHeight,
		partyWidth = partyWidth,
		partyMaxBottom = partyMaxBottom,
	}
end

-- Right-aligned under the HUD lines shown (6 below the last one), as tall as wanted but no lower
-- than partyMaxBottom, and never shorter than its title row.
function HudLayout.partyPanel(layout: Layout, hudLines: number, wanted: number): Rect
	local top = layout.trialHud.y + hudLines * (layout.hudLineHeight + 4) + 2
	local room = layout.partyMaxBottom - top
	return {
		x = layout.trialHud.x + layout.trialHud.width - layout.partyWidth,
		y = top,
		width = layout.partyWidth,
		height = math.max(math.min(wanted, room), HudLayout.PARTY_MIN_HEIGHT),
	}
end

return HudLayout
