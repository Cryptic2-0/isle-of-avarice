--!strict
local T = require("./harness")
local HudLayout = require("../src/shared/Rules/HudLayout")

type Rect = HudLayout.Rect

local SCREENS = {
	{ 640, 360 },
	{ 667, 375 },
	{ 740, 360 },
	{ 844, 390 },
	{ 932, 430 },
	{ 1024, 768 },
	{ 1180, 820 },
	{ 1366, 1024 },
	{ 1280, 720 },
	{ 1920, 1080 },
}
local INSETS = { 36, 58 }

-- Every always-on control, by name.
local function controls(layout: HudLayout.Layout, insetTop: number): { [string]: Rect }
	local list: { [string]: Rect } = {
		abilityBar = layout.abilityBar,
		dropShield = HudLayout.dropShield(insetTop),
		trialHud = layout.trialHud,
	}
	for i, rect in layout.menu do
		list["menu" .. i] = rect
	end
	return list
end

T.test("constants", function()
	T.eq(HudLayout.MARGIN, 12)
	T.eq(HudLayout.GAP, 6)
	T.eq(HudLayout.HUD_LINES, 4)
	T.eq(HudLayout.SMALL_SIDE, 500)
	T.eq(HudLayout.PARTY_MIN_HEIGHT, 46)
	T.eq(HudLayout.WINDOW_MIN, {
		big = { width = 600, height = 280 },
		small = { width = 300, height = 240 },
		dialog = { width = 300, height = 140 },
	})
end)

T.test("overlaps: shared area only, touching edges do not count", function()
	local a = { x = 0, y = 0, width = 10, height = 10 }
	T.truthy(HudLayout.overlaps(a, { x = 9, y = 9, width = 5, height = 5 }))
	T.falsy(HudLayout.overlaps(a, { x = 10, y = 0, width = 5, height = 5 }))
	T.falsy(HudLayout.overlaps(a, { x = 0, y = 10, width = 5, height = 5 }))
end)

T.test("a 640 x 360 phone under a 58-pixel top bar: the exact layout", function()
	local layout = HudLayout.compute(640, 360, 58, true)
	T.eq(layout.small, true)
	T.eq(layout.touch, true)
	T.eq(layout.thumb, { x = 0, y = 198, width = 256, height = 162 })
	T.eq(layout.jump, { x = 540, y = 265, width = 100, height = 95 })
	T.eq(layout.abilityBar, { x = 301, y = 304, width = 194, height = 44 })
	T.eq(layout.menu, {
		{ x = 269, y = 266, width = 60, height = 32 },
		{ x = 335, y = 266, width = 60, height = 32 },
		{ x = 401, y = 266, width = 60, height = 32 },
		{ x = 467, y = 266, width = 60, height = 32 },
	})
	T.eq(layout.trialHud, { x = 408, y = 66, width = 220, height = 100 })
	T.eq(layout.hudLineHeight, 22)
	T.eq(layout.partyWidth, 220)
	T.eq(layout.partyMaxBottom, 259)
	T.eq(HudLayout.partyPanel(layout, 2, 200), { x = 408, y = 120, width = 220, height = 139 })
	T.eq(HudLayout.partyPanel(layout, 4, 200), { x = 408, y = 172, width = 220, height = 87 })
	T.eq(HudLayout.partyPanel(layout, 2, 60), { x = 408, y = 120, width = 220, height = 60 })
	T.eq(HudLayout.dropShield(58), { x = 12, y = 102, width = 150, height = 32 })
end)

T.test("a desktop screen: no touch zones, the bar and the menu centred", function()
	local layout = HudLayout.compute(1920, 1080, 58, false)
	T.eq(layout.small, false)
	T.eq(layout.thumb, nil)
	T.eq(layout.jump, nil)
	T.eq(layout.abilityBar, { x = 759, y = 972, width = 402, height = 96 })
	T.eq(layout.menu[1], { x = 711, y = 930, width = 120, height = 36 })
	T.eq(layout.trialHud, { x = 1608, y = 221, width = 300, height = 124 })
	T.eq(layout.hudLineHeight, 28)
	T.eq(layout.partyWidth, 280)
	T.eq(layout.partyMaxBottom, 1068)
	for _, size in { { 1280, 720 }, { 1366, 768 }, { 1920, 1080 } } do
		local l = HudLayout.compute(size[1], size[2], 36, false)
		local label = `{size[1]}x{size[2]}`
		T.truthy(
			math.abs(l.abilityBar.x + l.abilityBar.width / 2 - size[1] / 2) <= 1,
			label .. " bar"
		)
		local menuCentre = (l.menu[1].x + l.menu[4].x + l.menu[4].width) / 2
		T.truthy(math.abs(menuCentre - size[1] / 2) <= 1, label .. " menu")
	end
end)

T.test(
	"touch screens: controls clear of the thumbstick and the jump button, apart and on screen",
	function()
		for _, size in SCREENS do
			for _, inset in INSETS do
				local w, h = size[1], size[2]
				local layout = HudLayout.compute(w, h, inset, true)
				local label = `{w}x{h} inset {inset}`
				local thumb = layout.thumb :: Rect
				local jump = layout.jump :: Rect
				local list = controls(layout, inset)
				for name, rect in list do
					T.falsy(HudLayout.overlaps(rect, thumb), `{label}: {name} on the thumbstick`)
					T.falsy(HudLayout.overlaps(rect, jump), `{label}: {name} on the jump button`)
					T.truthy(
						rect.x >= 0
							and rect.y >= inset
							and rect.x + rect.width <= w
							and rect.y + rect.height <= h,
						`{label}: {name} on screen`
					)
				end
				for a, ra in list do
					for b, rb in list do
						if a < b then
							T.falsy(HudLayout.overlaps(ra, rb), `{label}: {a} overlaps {b}`)
						end
					end
				end
				for i, rect in layout.menu do
					T.truthy(rect.width >= 44 and rect.height >= 32, `{label}: menu {i} big enough`)
				end
				T.truthy(layout.abilityBar.height >= 44, `{label}: ability slots big enough`)
			end
		end
	end
)

T.test("the party panel stays above what is below it and keeps its title row", function()
	for _, size in SCREENS do
		for _, inset in INSETS do
			for _, touch in { true, false } do
				local w, h = size[1], size[2]
				local layout = HudLayout.compute(w, h, inset, touch)
				for shown = 0, HudLayout.HUD_LINES do
					local label = `{w}x{h} inset {inset} touch {touch} lines {shown}`
					local panel = HudLayout.partyPanel(layout, shown, 1000)
					T.truthy(panel.height >= HudLayout.PARTY_MIN_HEIGHT, label .. ": title row")
					T.eq(panel.width, layout.partyWidth, label)
					T.eq(panel.x + panel.width, w - HudLayout.MARGIN, label .. ": right edge")
					T.truthy(panel.y + panel.height <= layout.partyMaxBottom, label .. ": bottom")
					for i, rect in layout.menu do
						T.falsy(HudLayout.overlaps(panel, rect), `{label}: menu {i}`)
					end
					T.falsy(HudLayout.overlaps(panel, layout.abilityBar), label .. ": bar")
					if layout.jump ~= nil then
						T.falsy(HudLayout.overlaps(panel, layout.jump :: Rect), label .. ": jump")
					end
					local linesBottom = layout.trialHud.y + shown * (layout.hudLineHeight + 4)
					T.truthy(panel.y >= linesBottom, label .. ": under the HUD lines")
				end
			end
		end
	end
end)

T.test("every window kind fits a 640 x 360 phone under a 58-pixel top bar", function()
	for name, size in HudLayout.WINDOW_MIN do
		T.truthy(size.width <= 640 - 16 and size.height <= 360 - 58 - 16, name)
	end
end)

T.test("a window's minimum is capped to the area on a 568 x 320 phone under its top bar", function()
	-- 58-pixel top bar: the area is 568 x 262; a window keeps a 12-pixel margin all round.
	T.eq(HudLayout.windowMin("big", 568, 262), { width = 544, height = 238 })
	T.eq(HudLayout.windowMin("small", 568, 262), { width = 300, height = 238 })
	T.eq(HudLayout.windowMin("dialog", 568, 262), { width = 300, height = 140 })
	-- A large screen keeps each kind's own minimum.
	for kind, size in HudLayout.WINDOW_MIN do
		T.eq(HudLayout.windowMin(kind, 1280, 684), size, kind)
	end
end)

T.test("a capped window minimum always fits the area", function()
	for _, size in SCREENS do
		for _, inset in INSETS do
			local area = size[2] - inset
			for kind in HudLayout.WINDOW_MIN do
				local least = HudLayout.windowMin(kind, size[1], area)
				local label = `{kind} on {size[1]}x{size[2]} inset {inset}`
				T.truthy(least.width <= size[1] - 2 * HudLayout.MARGIN, label .. ": width")
				T.truthy(least.height <= area - 2 * HudLayout.MARGIN, label .. ": height")
			end
		end
	end
	-- A screen smaller than two margins gives 0, never a negative size.
	T.eq(HudLayout.windowMin("big", 10, 0), { width = 0, height = 0 })
end)

T.test("odd screen sizes do not error", function()
	for _, size in { { 0, 0 }, { 1, 1 }, { 300, 200 } } do
		local layout = HudLayout.compute(size[1], size[2], 0, true)
		T.eq(#layout.menu, 4)
		HudLayout.partyPanel(layout, 4, 100)
	end
end)

T.test("party rows are 40 px on touch and 48 elsewhere", function()
	T.eq(HudLayout.compute(640, 360, 58, true).partyRowHeight, 40)
	T.eq(HudLayout.compute(1280, 720, 36, false).partyRowHeight, 48)
end)

T.test("a 4-line trial HUD on the phone still leaves one whole party row", function()
	local layout = HudLayout.compute(640, 360, 58, true)
	local panel = HudLayout.partyPanel(layout, 4, 1000)
	T.truthy(panel.height - HudLayout.PARTY_MIN_HEIGHT >= layout.partyRowHeight)
end)

T.test("the status column stays above the thumbstick on a touch screen", function()
	for _, size in SCREENS do
		for _, inset in INSETS do
			for _, drop in { true, false } do
				local layout = HudLayout.compute(size[1], size[2], inset, true)
				local count = HudLayout.statusLines(layout, inset, drop)
				local top = inset + 44 + (if drop then 36 else 0)
				local thumb = layout.thumb :: Rect
				local label = `{size[1]}x{size[2]} inset {inset} drop {drop}`
				T.truthy(count >= 0, label)
				if count > 0 then
					T.truthy(top + count * 32 - 4 <= thumb.y - HudLayout.GAP, label .. ": bottom")
					-- One more line would not fit.
					T.truthy(
						top + (count + 1) * 32 - 4 > thumb.y - HudLayout.GAP,
						label .. ": full"
					)
				end
			end
		end
	end
end)

T.test("the status column on the 640 x 360 phone holds two lines, one with Drop shield", function()
	local layout = HudLayout.compute(640, 360, 58, true)
	T.eq(HudLayout.statusLines(layout, 58, false), 2)
	T.eq(HudLayout.statusLines(layout, 58, true), 1)
end)

T.test("the status column is not capped without a touch screen", function()
	local layout = HudLayout.compute(1280, 720, 36, false)
	T.truthy(HudLayout.statusLines(layout, 36, true) >= 6)
end)

T.test("the party invite banner sits below the trade invite banner", function()
	for _, area in { 200, 302, 500, 684, 1000, 1044 } do
		local tradeTop = math.floor(area * 18 / 100)
		local tradeBottom = tradeTop + math.max(44, math.floor(area * 9 / 100))
		local top = HudLayout.partyBannerTop(area)
		T.truthy(top >= tradeBottom + 4, `area {area}: no overlap`)
		T.truthy(top >= math.floor(area * 28 / 100), `area {area}: not above 28%`)
	end
	-- The 302-pixel area of a 640 x 360 phone under a 58-pixel top bar.
	T.eq(HudLayout.partyBannerTop(302), 104)
end)
