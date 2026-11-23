# M8: Launch Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The game is comfortable on a landscape phone (640 by 360 and up): no HUD button sits on the movement thumbstick or the jump button, every window fits under Roblox's top bar, and the party panel and trial HUD share the right edge without covering the controls. A claimed slot is unclaimed, and a free card discarded, only by a second tap within 3 seconds; after any request its row or window stays inert until the server answers (or 1 second); no default borders; one shared UI kit. The region banner gets its own line, the Hush Gardens blight gets a ground tint, the backlog's tests and cheap tidying land, and the review notes a player could meet are fixed.

**Architecture:** As in M1–M7. New rules are pure Luau modules in `src/shared/Rules`, unit-tested with Lune: `HudLayout` (where every HUD control goes for a screen size, inset and touch flag), `Confirm` (the two-tap confirm), and additions to `Hazards` (`landing`, `overlay`), `Sources` (`coinAfter`) and `Leaderboard` (`shouldAskName`). On the client a new `UiKit` module holds the helpers every screen repeated, the one-request guard, the borderless `ScreenGui`, window minimum sizes, the press seam for the play test and the live `HudLayout`; a new `MenuBar` holds the four menu buttons. Server changes are small fixes in existing services.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7.1, Lune 0.11.1, StyLua 2.6.0 (Luau build), Selene 0.31.0, ProfileStore 1.0.3 (vendored), plain Roblox UI instances (`GuiService:GetGuiInset`, `UserInputService.TouchEnabled`, `Camera.ViewportSize`).

**Spec:** `docs/superpowers/specs/2026-11-10-isle-of-avarice-design.md` revision 10 — section 3.16 (all M8 values and rulings), with 3.15 and the Wide Isle spec's section 5 (the blight).

**Branch:** `feat/m8-polish`, based on `feat/m7-endgame` after M7's last commit (2d6ffc6).

## Global Constraints

- No new content, no paid items, no sounds. Tone as before. Player-facing words new in M8: "Tap again to unclaim", "Sure?".
- Every file under `src/` except `src/server/Vendor` starts with `--!strict`. Files under `src/shared/` use no Roblox APIs and require each other only by relative string. Rule functions never mutate their arguments (exception: `RateLimiter.allow`). Selene's standard library here does not know `Random`: use `math.random`.
- The server decides everything; nothing in M8 moves a decision to the client. The two-tap confirm and the inert rows are client comfort only: the server still checks every request, and the play test also fires the remotes directly.
- Card and Coin moves stay atomic: no yielding call between reading and writing, and (new) the Coin move is checked with `Sources.coinAfter` before the first write.
- Ledger changes go through `LedgerService.set`, Coin through `SourceService.addCoin`, damage through `CombatService.damage` / `environmentDamage`.
- **Spec 3.16 values:** thumbstick zone the left 40% × bottom 45%; jump zone 100 × 95 (phone) or 180 × 220; margin 12, gap 6; ability slots 44 to 96 pixels (a tenth of the screen height); menu buttons at most 120 wide, 32 tall on a phone and 36 otherwise; Drop shield at (12, 44) under the top bar, 150 × 32; trial HUD 220 wide with 22-pixel lines on a phone, 300 and 28 otherwise; party panel 220 / 280 wide, at least 46 tall; windows big 600 × 280, small 300 × 240, dialog 300 × 140; Close buttons at least 40 × 32; the two-tap window 3 s; re-arm 1 s; region banner 3 s at 12% from the top, invites at 18% and 28%; blight tint colour (92, 72, 104), Ground, transparency 0.35, beyond 330 studs; a failed board name retried after 300 s.
- DisplayOrder bands: the HUD under every window — `MenuGui` 5, `AbilityGui` 6 (was 11); the windows keep theirs (Ledger 10, Paths 12, Trial 14, Status 15, Edict/Shop/Trade/Party 16, messages 20, ceremony 25, Renounce 26, claim 30).
- `bash scripts/check.sh` passes before every commit. Nothing in it type-checks Luau or runs Roblox APIs: client and server code is proven only by the Studio play test, so read every changed client or server file twice, top to bottom, and check every call into `UiKit` against its real signature.

## Review Focus

1. **Phone layout.** No button on the thumbstick or jump zones at any listed screen size; nothing overlaps; the party panel never covers the menu row, the ability bar or the jump zone and keeps its title row; every window fits 640 × 360 under a 58-pixel top bar. Pinned in Task 1 (`HudLayout` tests), Task 6 to Task 9 (by reading: every placement goes through `UiKit.place` and `UiKit.onLayout`) and the play test (M8.1, M8.2, M8.11).
2. **No stray destructive tap.** Unclaim and Discard need two taps on the same control within 3 s; any other tap or a wait re-arms; a button ignores taps while inert. Pinned in Task 1 (`Confirm`), Task 6 (`UiKit.onPress`) and the play test (M8.4, M8.5).
3. **One request at a time, never stuck.** Every request goes through `UiKit.send`; the row or window comes back on the next view or after 1 s. Pinned by reading Tasks 7–9 and the play test (M8.6).
4. **Atomic Coin moves.** The Edict Hall and trades check `Sources.coinAfter` before any write; `addCoin` uses the same rule; a trade re-syncs on a Coin change without unconfirming a still-covered offer. Pinned in Task 2 (tests), Task 5 (by reading) and the play test (M8.9).
5. **Nothing old drifts.** Every M1–M7 driver check still passes; the refactors (kit, `Hazards.landing`, `Fighters.body`, `Regions.extraCache`, `World.buildings`) change no behaviour. Pinned by the full test suite and the whole play test.

## File Map

```
src/shared/Rules/HudLayout.luau          NEW  HUD rectangles for a screen; window minimum sizes
src/shared/Rules/Confirm.luau            NEW  two-tap confirm
src/shared/Rules/Hazards.luau            + landing (one hit per cycle), overlay (the blight tint's strips)
src/shared/Rules/Sources.luau            + coinAfter
src/shared/Rules/Leaderboard.luau        + NAME_RETRY_SECONDS, shouldAskName
src/shared/Rules/Ledger.luau             sanitize keeps free cards after a gap
src/shared/Catalog/Looks.luau            + blight
src/shared/Catalog/SiteData/HushGardens.luau   HushBlight look "blight"
src/shared/Catalog/Regions.luau          + extraCache
src/shared/Catalog/Sites.luau, SiteData/Scenery.luau, SiteData/SquallSteps.luau   read Regions
src/shared/Catalog/World.luau            + buildings; - islandHalfSize
src/server/HazardService.luau            Hazards.landing, Fighters.body
src/server/ProtectionService.luau        Fighters.body for livingRoot
src/server/RegenService.luau             waits for the Humanoid; pcall per player
src/server/LeaderboardService.luau       retries a failed name lookup
src/server/SiteBuilder.luau              + Island.Blight (the tint)
src/server/WorldBuilder.luau             World.buildings
src/server/SourceService.luau            addCoin via coinAfter; + onCoinChanged
src/server/ShopService.luau              coinAfter before writing
src/server/TradeService.luau             coinAfter before writing; re-sync on Coin change
src/client/UiKit.luau                    NEW
src/client/MenuBar.luau                  NEW  Ledger, Paths, Trade, Party
src/client/Main.client.luau              layout start, MenuBar, region banner, party refresh
src/client/AbilityBar.luau, StatusHUD.luau, Toast.luau, TrialUI.luau      (Task 6)
src/client/LedgerUI.luau, ClaimUI.luau, RenounceUI.luau, CeremonyUI.luau  (Task 7)
src/client/ShopUI.luau, TradeUI.luau, EdictUI.luau, PathUI.luau           (Task 8)
src/client/PartyUI.luau                                                   (Task 9)
tests/hud_layout.spec.luau, tests/confirm.spec.luau   NEW
tests/hazards, sources, leaderboard, sites, ledger, messages, ledger_actions, rate_limiter,
tests/geography, renounce, harness, scenery, world, build .spec.luau; tests/harness.luau
playtest/server/Driver.server.luau       + runM8
playtest/client/Agent.client.luau        + press, togglePaths ops; M8 UI snapshot fields
docs/playtest/M8-checklist.md            NEW
docs/playtest/M1-checklist.md, World-checklist.md   two stale lines
docs/backlog.md                          done items removed, the rest kept under "Left after M8"
README.md                                + Milestone 8
```

---

### Task 1: Layout and confirm rules

Pure rules with exact values. If a test fails, fix the code, not the number, and report it.

**Files:**
- Create: `src/shared/Rules/HudLayout.luau`, `src/shared/Rules/Confirm.luau`
- Test: `tests/hud_layout.spec.luau`, `tests/confirm.spec.luau` (new), `tests/build.spec.luau`

**Interfaces:**
- Produces:
```luau
-- HudLayout.luau
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
HudLayout.MARGIN, GAP, HUD_LINES, SMALL_SIDE, PARTY_MIN_HEIGHT, WINDOW_MIN
HudLayout.overlaps(a: Rect, b: Rect): boolean
HudLayout.dropShield(insetTop: number): Rect
HudLayout.compute(width: number, height: number, insetTop: number, touch: boolean): Layout
HudLayout.partyPanel(layout: Layout, hudLines: number, wanted: number): Rect

-- Confirm.luau
export type Armed = { key: string, at: number }
Confirm.WINDOW_SECONDS = 3
Confirm.press(armed: Armed?, key: string, now: number): (Armed?, boolean)
Confirm.isArmed(armed: Armed?, key: string, now: number): boolean
```

- [ ] **Step 1: Write the failing tests.** `tests/hud_layout.spec.luau`:
```luau
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
		T.truthy(math.abs(l.abilityBar.x + l.abilityBar.width / 2 - size[1] / 2) <= 1, label .. " bar")
		local menuCentre = (l.menu[1].x + l.menu[4].x + l.menu[4].width) / 2
		T.truthy(math.abs(menuCentre - size[1] / 2) <= 1, label .. " menu")
	end
end)

T.test("touch screens: controls clear of the thumbstick and the jump button, apart and on screen", function()
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
end)

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

T.test("odd screen sizes do not error", function()
	for _, size in { { 0, 0 }, { 1, 1 }, { 300, 200 } } do
		local layout = HudLayout.compute(size[1], size[2], 0, true)
		T.eq(#layout.menu, 4)
		HudLayout.partyPanel(layout, 4, 100)
	end
end)
```
`tests/confirm.spec.luau`:
```luau
--!strict
local T = require("./harness")
local Confirm = require("../src/shared/Rules/Confirm")

T.test("the window is 3 seconds", function()
	T.eq(Confirm.WINDOW_SECONDS, 3)
end)

T.test("a first tap arms, a second tap on the same control goes ahead", function()
	local armed, go = Confirm.press(nil, "unclaim:R001", 10)
	T.eq(armed, { key = "unclaim:R001", at = 10 })
	T.eq(go, false)
	local after, go2 = Confirm.press(armed, "unclaim:R001", 12)
	T.eq(after, nil)
	T.eq(go2, true)
end)

T.test("the second tap counts up to exactly 3 seconds later", function()
	local armed = Confirm.press(nil, "k", 10)
	T.eq({ Confirm.press(armed, "k", 13) }, { nil, true })
	local late, go = Confirm.press(armed, "k", 13.01)
	T.eq(late, { key = "k", at = 13.01 })
	T.eq(go, false)
end)

T.test("a tap on another control arms that one instead", function()
	local armed = Confirm.press(nil, "unclaim:R001", 10)
	local other, go = Confirm.press(armed, "unclaim:R002", 11)
	T.eq(other, { key = "unclaim:R002", at = 11 })
	T.eq(go, false)
	T.eq(
		{ Confirm.press(other, "unclaim:R001", 11.5) },
		{ { key = "unclaim:R001", at = 11.5 }, false }
	)
end)

T.test("a clock that went backwards, or is not a number, only arms", function()
	local armed = Confirm.press(nil, "k", 10)
	T.eq({ Confirm.press(armed, "k", 9) }, { { key = "k", at = 9 }, false })
	local again, go = Confirm.press(armed, "k", 0 / 0)
	T.eq(go, false)
	T.eq(again and again.key, "k")
end)

T.test("isArmed", function()
	local armed = Confirm.press(nil, "k", 10)
	T.truthy(Confirm.isArmed(armed, "k", 10))
	T.truthy(Confirm.isArmed(armed, "k", 13))
	T.falsy(Confirm.isArmed(armed, "k", 13.5))
	T.falsy(Confirm.isArmed(armed, "other", 11))
	T.falsy(Confirm.isArmed(nil, "k", 11))
	T.falsy(Confirm.isArmed(armed, "k", 9))
end)

T.test("press does not change the record it is given", function()
	local armed = { key = "k", at = 10 }
	Confirm.press(armed, "k", 11)
	Confirm.press(armed, "j", 11)
	T.eq(armed, { key = "k", at = 10 })
end)
```
`tests/build.spec.luau`: add `Shared.Rules.HudLayout` and `Shared.Rules.Confirm` in the file's `ClassName == "ModuleScript"` form.

- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL (two modules missing).
- [ ] **Step 3: Implement.** `Confirm`: `press` returns `(nil, true)` only when `armed ~= nil`, `armed.key == key`, `now >= armed.at` and `now - armed.at <= WINDOW_SECONDS`; otherwise `({ key = key, at = now }, false)`. `isArmed` is the same condition. `HudLayout`, exactly (comments in the file's own words):
```luau
--!strict
-- Where the always-on HUD controls go on a screen: the menu row, the ability bar, the trial HUD,
-- the party panel and the Drop shield button. Rectangles are whole pixels in full-screen
-- coordinates (y = 0 is the top edge, above Roblox's top bar). On a touch screen the controls
-- keep off the movement thumbstick (bottom left) and the jump button (bottom right).
-- (the two export types from Interfaces)

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
	return a.x < b.x + b.width and b.x < a.x + a.width and a.y < b.y + b.height and b.y < a.y + a.height
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
		jump = { x = width - jumpWidth, y = height - jumpHeight, width = jumpWidth, height = jumpHeight }
		left = thumbWidth + margin
		right = width - jumpWidth - margin
	end
	local band = right - left
	local slot = math.clamp(math.floor(math.min((band - 3 * gap) / 4, height / 10)), SLOT_MIN, SLOT_MAX)
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
	local hudY = if small then insetTop + 8 else insetTop + math.floor((height - insetTop) * 16 / 100)
	local trialHud: Rect = {
		x = width - margin - hudWidth,
		y = hudY,
		width = hudWidth,
		height = HudLayout.HUD_LINES * (lineHeight + 4) - 4,
	}
	local partyWidth = if small then 220 else 280
	-- The panel's column, top to bottom: it must stop above anything in it.
	local column: Rect = { x = width - margin - partyWidth, y = 0, width = partyWidth, height = height }
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
```
The percentages are whole-number arithmetic on purpose: `360 * 0.55` is not exactly 198 in floating point.
- [ ] **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: HUD layout and two-tap confirm rules`

---

### Task 2: Burst, blight-tint, Coin-move and board-name rules

**Files:**
- Modify: `src/shared/Rules/Hazards.luau`, `src/shared/Rules/Sources.luau`, `src/shared/Rules/Leaderboard.luau`, `src/shared/Catalog/Looks.luau`, `src/shared/Catalog/SiteData/HushGardens.luau`
- Test: `tests/hazards.spec.luau`, `tests/sources.spec.luau`, `tests/leaderboard.spec.luau`, `tests/sites.spec.luau`

**Interfaces:**
- Produces:
```luau
-- Hazards.luau (Geography is already required)
Hazards.landing(seen: { [string]: number }?, bursts: { Burst }): ({ Burst }, { [string]: number })
-- The bursts that land now: those whose hazard has not hit in this cycle index. Returns them in
-- order and the new record (seen plus each landing burst's id -> cycle); `seen` is not changed.
Hazards.overlay(hazard: Types.Hazard, strips: { Geography.Strip }): { Geography.Strip }
-- For a region-wide hazard: the parts of its region's ground strips at or beyond its radius from
-- the island centre, judged on each strip's centre line (z). A strip with |z| >= radius is kept
-- whole; otherwise, with c = sqrt(radius^2 - z^2), the part x1..min(x2, -c) when x1 < -c and the
-- part max(x1, c)..x2 when x2 > c. Each piece is a new table. Empty for any other shape.

-- Sources.luau
Sources.coinAfter(coin: number, delta: number): number?
-- coin + delta when delta is finite and the result is finite and >= 0; otherwise nil.

-- Leaderboard.luau
Leaderboard.NAME_RETRY_SECONDS = 300
Leaderboard.shouldAskName(known: boolean, lastTriedAt: number?, now: number): boolean
-- false when known; true when never tried; else now - lastTriedAt >= NAME_RETRY_SECONDS.

-- Looks.luau
blight = look(92, 72, 104, "Ground", 0.35),
```
- `HushGardens.luau`: the `HushBlight` hazard's `look` becomes `"blight"` (it was `"none"`; nothing else reads it: a region-wide hazard has no marker in `Island.Hazards`).

- [ ] **Step 1: Write the failing tests.** `tests/hazards.spec.luau` (add `local Sites = require("../src/shared/Catalog/Sites")` at the top):
```luau
T.test("landing: a burst hits once per cycle of its hazard", function()
	local first = { id = "Vent1", damage = 20, cycle = 7 }
	local landing, seen = Hazards.landing(nil, { first })
	T.eq(landing, { first })
	T.eq(seen, { Vent1 = 7 })
	local again, seen2 = Hazards.landing(seen, { first })
	T.eq(again, {})
	T.eq(seen2, { Vent1 = 7 })
	local nextCycle = { id = "Vent1", damage = 20, cycle = 8 }
	local later, seen3 = Hazards.landing(seen2, { nextCycle })
	T.eq(later, { nextCycle })
	T.eq(seen3, { Vent1 = 8 })
end)

T.test("landing: hazards are counted apart, and the record given is not changed", function()
	local seen = { Vent1 = 7 }
	local landing, record = Hazards.landing(seen, {
		{ id = "Vent1", damage = 20, cycle = 7 },
		{ id = "Vent2", damage = 25, cycle = 7 },
	})
	T.eq(landing, { { id = "Vent2", damage = 25, cycle = 7 } })
	T.eq(record, { Vent1 = 7, Vent2 = 7 })
	T.eq(seen, { Vent1 = 7 })
	T.eq({ Hazards.landing(seen, {}) }, { {}, { Vent1 = 7 } })
end)

T.test("overlay: the blight's ground, cut at its radius", function()
	local blight = Sites.hazardById.HushBlight
	local strips = Geography.strips()
	local pieces = Hazards.overlay(blight, strips)
	T.truthy(#pieces > 0)
	for i, piece in pieces do
		T.eq(piece.region, "HushGardens", `piece {i}`)
		T.truthy(piece.x1 < piece.x2, `piece {i} has length`)
		local nearestX = if piece.x1 <= 0 and piece.x2 >= 0
			then 0
			else math.min(math.abs(piece.x1), math.abs(piece.x2))
		T.truthy(math.sqrt(nearestX ^ 2 + piece.z ^ 2) >= 330 - 1e-6, `piece {i} starts at the edge`)
		T.truthy(
			Hazards.affects(blight, (piece.x1 + piece.x2) / 2, piece.z),
			`piece {i} middle is blighted`
		)
	end
	-- Every Hush Gardens cell centre at or beyond 330 lies on a piece.
	for _, strip in strips do
		if strip.region == "HushGardens" then
			local x = strip.x1 + Geography.CELL / 2
			while x < strip.x2 do
				if math.sqrt(x * x + strip.z * strip.z) >= 330 then
					local covered = false
					for _, piece in pieces do
						if piece.z == strip.z and piece.x1 <= x and x <= piece.x2 then
							covered = true
						end
					end
					T.truthy(covered, `cell at {x}, {strip.z}`)
				end
				x += Geography.CELL
			end
		end
	end
	T.eq(Hazards.overlay(Sites.hazardById.CinderPool1, strips), {})
end)
```
`tests/sources.spec.luau`:
```luau
T.test("coinAfter: the Coin after a move, or nil when the move must be refused", function()
	T.eq(Sources.coinAfter(10, 5), 15)
	T.eq(Sources.coinAfter(10, -10), 0)
	T.eq(Sources.coinAfter(10, -11), nil)
	T.eq(Sources.coinAfter(10, 0 / 0), nil)
	T.eq(Sources.coinAfter(10, math.huge), nil)
	T.eq(Sources.coinAfter(10, -math.huge), nil)
	T.eq(Sources.coinAfter(0 / 0, 5), nil)
	T.eq(Sources.coinAfter(math.huge, -1), nil)
end)
```
`tests/leaderboard.spec.luau`:
```luau
T.test("shouldAskName: once, then again only 300 s after a failed try", function()
	T.eq(Leaderboard.NAME_RETRY_SECONDS, 300)
	T.falsy(Leaderboard.shouldAskName(true, nil, 0), "known")
	T.truthy(Leaderboard.shouldAskName(false, nil, 0), "never tried")
	T.falsy(Leaderboard.shouldAskName(false, 100, 399), "too soon")
	T.truthy(Leaderboard.shouldAskName(false, 100, 400), "300 s later")
	T.falsy(Leaderboard.shouldAskName(true, 100, 1000), "known after a failure")
	T.falsy(Leaderboard.shouldAskName(false, 100, 0 / 0), "a broken clock waits")
end)
```
`tests/sites.spec.luau`:
```luau
T.test("the blight has its own ground look", function()
	T.eq(Sites.hazardById.HushBlight.look, "blight")
	T.eq(Looks.byName.blight, { r = 92, g = 72, b = 104, material = "Ground", transparency = 0.35 })
end)
```
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL.
- [ ] **Step 3: Implement** the five additions above. `SourceService` is not touched here (Task 5 makes `addCoin` use `coinAfter`).
- [ ] **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `feat: burst, blight-tint, Coin-move and board-name rules`

---

### Task 3: The backlog's tests, and tidying in shared code

**Files:**
- Modify: `tests/harness.luau`, `src/shared/Rules/Ledger.luau`, `src/shared/Catalog/Regions.luau`, `src/shared/Catalog/Sites.luau`, `src/shared/Catalog/SiteData/Scenery.luau`, `src/shared/Catalog/SiteData/SquallSteps.luau`, `src/shared/Catalog/World.luau`, `src/server/WorldBuilder.luau`
- Test: `tests/harness.spec.luau`, `tests/ledger.spec.luau`, `tests/messages.spec.luau`, `tests/ledger_actions.spec.luau`, `tests/sources.spec.luau`, `tests/rate_limiter.spec.luau`, `tests/geography.spec.luau`, `tests/renounce.spec.luau`, `tests/world.spec.luau`, `tests/sites.spec.luau`, `tests/scenery.spec.luau`

**Interfaces:**
- `Regions` returns `{ list, byId, wild, extraCache }` with `extraCache = { along = 310, across = -60 }` and the comment "Where Sites puts each wild region's extra Copper cache, in that region's frame."
- `Sites.luau` places the extras with `Geography.place(regionId, Regions.extraCache.along, Regions.extraCache.across)`; `Scenery.luau` drops `COPPER_ALONG` / `COPPER_ACROSS`, requires `../Regions` and uses the same two values; `SquallSteps.luau` drops `BEARING = 60`, requires `../Regions` and uses `Regions.byId.SquallSteps.bearing :: number`.
- `World.luau`: `islandHalfSize` is deleted (local and export); `buildings` is added and exported:
```luau
-- Tallyport's four buildings at the plaza corners: centre x, z; width (x), height, depth (z).
local buildings: { { x: number, z: number, w: number, h: number, d: number } } = {
	{ x = -28, z = -28, w = 16, h = 12, d = 14 },
	{ x = 28, z = -28, w = 12, h = 18, d = 12 },
	{ x = -28, z = 28, w = 14, h = 9, d = 18 },
	{ x = 28, z = 28, w = 18, h = 14, d = 16 },
}
```
  `WorldBuilder.buildTallyport` loops over `World.buildings` instead of its local list (nothing else changes).
- `Ledger.sanitize`'s free list: collect every key of `raw.free` that is a number, `>= 1`, finite and whole; sort them; take the cards in that order (unknown cards skipped) up to `FREE_SLOTS`. Never errors.
- `tests/harness.luau`: `describe(value, seen?)` prints `<cycle>` for a table already being described further up; `deepEqual(a, b, seen?)` records each (a, b) table pair it is comparing and treats a pair met again further down as equal. Both keep their current output for tables without cycles.

- [ ] **Step 1: Write the failing tests.** `tests/harness.spec.luau`:
```luau
T.test("eq and describe survive tables that contain themselves", function()
	local a: any = { n = 1 }
	a.self = a
	local b: any = { n = 1 }
	b.self = b
	T.eq(a, b)
	local c: any = { n = 2 }
	c.self = c
	local ok, err = pcall(T.eq, a, c)
	T.falsy(ok)
	T.truthy(string.find(tostring(err), "<cycle>", 1, true) ~= nil, tostring(err))
end)
```
`tests/ledger.spec.luau`:
```luau
T.test("unclaim does not mutate its input", function()
	local input: LedgerT = { claimed = { R002 = true }, free = { "R001" } }
	Ledger.unclaim(input, "R002")
	T.eq(input, { claimed = { R002 = true }, free = { "R001" } })
end)

T.test("sanitize keeps free cards after a gap, in key order", function()
	local raw: any = {
		claimed = {},
		free = {
			[1] = "R001",
			[3] = "R002",
			[5] = "E001",
			[2.5] = "R003",
			[0] = "R004",
			[-1] = "R006",
			x = "R005",
		},
	}
	T.eq(Ledger.sanitize(raw), { claimed = {}, free = { "R001", "R002", "E001" } })
end)

T.test("sanitize after gaps still cuts free to 20", function()
	local free: { [number]: string } = {}
	for i = 1, 30 do
		free[i * 2] = "R001"
	end
	T.eq(#Ledger.sanitize({ claimed = {}, free = free }).free, Ledger.FREE_SLOTS)
end)
```
`tests/messages.spec.luau`:
```luau
T.test("format: {player}, a missing value, no values and an unknown code", function()
	T.eq(
		Messages.format("LEDGER_COMPLETE", { player = "Ann" }),
		"Ann has claimed every Relic and is Crowned!"
	)
	T.eq(
		Messages.format("CLAIM_LOST", { names = "Barnacle Key" }),
		"{player} took from you: Barnacle Key."
	)
	T.eq(Messages.format("LEDGER_COMPLETE"), "{player} has claimed every Relic and is Crowned!")
	T.eq(Messages.format("NO_SUCH_CODE", { player = "Ann" }), "NO_SUCH_CODE")
end)
```
`tests/ledger_actions.spec.luau`:
```luau
T.test("claim: odd row numbers are BAD_INDEX; an already-claimed card is ALREADY_CLAIMED", function()
	for _, bad in { 1.5, -1, math.huge, -math.huge } do
		T.eq(
			{ LedgerActions.apply(base(), { kind = "claim", freeIndex = bad, cardId = "R001" }) },
			{ nil, "BAD_INDEX" },
			tostring(bad)
		)
	end
	T.eq({
		LedgerActions.apply(
			{ claimed = { R001 = true }, free = { "R001" } },
			{ kind = "claim", freeIndex = 1, cardId = "R001" }
		),
	}, { nil, "ALREADY_CLAIMED" })
end)
```
`tests/sources.spec.luau`:
```luau
T.test("a cache can be collected again once its refill time has passed", function()
	local s0 = Sources.new({ cache })
	local s1 = Sources.tryCollect(s0, Ledger.new(), cache, 100, 10, false, false)
	local _, _, early = Sources.tryCollect(s1, Ledger.new(), cache, 219.9, 10, false, false)
	T.eq(early, "CACHE_EMPTY")
	local s2, l2, code, availableAt =
		Sources.tryCollect(s1, Ledger.new(), cache, 220, 10, false, false)
	T.eq(code, "GOT_CARD")
	T.eq(l2, { claimed = {}, free = { "R007" } })
	T.eq(availableAt, 340)
	T.falsy(Sources.isAvailable(s2, "C007", 339))
end)

T.test("a cache whose Relic is not in the catalog gives nothing and is not used up", function()
	local unknown: Types.Cache =
		{ id = "C099", relicId = "R999", position = { x = 0, y = 0, z = 0 } }
	local s0 = Sources.new({ unknown })
	local s1, l1, code, availableAt =
		Sources.tryCollect(s0, Ledger.new(), unknown, 100, 10, false, false)
	T.eq({ l1, code, availableAt }, { nil, "CACHE_EMPTY", nil })
	T.eq(s1, s0)
end)

T.test("a short hold is refused before an empty or a sealed cache", function()
	local s0 = Sources.new({ cache })
	local used = Sources.tryCollect(s0, Ledger.new(), cache, 100, 10, false, false)
	local _, _, onEmpty = Sources.tryCollect(used, Ledger.new(), cache, 101, 10, false, false, false)
	T.eq(onEmpty, "HOLD_TOO_SHORT")
	local _, _, onSealed = Sources.tryCollect(s0, Ledger.new(), cache, 100, 10, true, false, false)
	T.eq(onSealed, "HOLD_TOO_SHORT")
end)
```
`tests/rate_limiter.spec.luau`:
```luau
T.test("time going backwards gives nothing back and does not move the clock back", function()
	local bucket = RateLimiter.new(10, 100)
	T.eq(drain(bucket, 100), 10)
	T.eq(drain(bucket, 50), 0)
	T.eq(bucket.last, 100)
	T.eq(drain(bucket, 101), 5)
end)
```
`tests/geography.spec.luau`:
```luau
T.test("bearingOf never returns 360", function()
	T.eq(Geography.bearingOf(-1e-15, -100), 0)
	local b = Geography.bearingOf(-1e-9, -100)
	T.truthy(b >= 0 and b < 360, tostring(b))
end)
```
`tests/renounce.spec.luau`:
```luau
T.test("the word: 32 characters is the limit", function()
	local at32 = "RENOUNCE" .. string.rep(" ", 24)
	T.eq(#at32, 32)
	T.eq(Renounce.parse({ kind = "confirm", word = at32 }), { kind = "confirm", word = at32 })
	T.truthy(Renounce.wordMatches(at32))
	local at33 = at32 .. " "
	T.eq(Renounce.parse({ kind = "confirm", word = at33 }), { kind = "confirm", word = "" })
	T.falsy(Renounce.wordMatches(at33))
end)
```
`tests/world.spec.luau`: delete the line `T.eq(World.islandHalfSize, 1380)` from "constants"; add
```luau
T.test("Tallyport's buildings leave the spawn, the clerk, the Tally Stone and the Crown Warden clear", function()
	T.eq(World.buildings, {
		{ x = -28, z = -28, w = 16, h = 12, d = 14 },
		{ x = 28, z = -28, w = 12, h = 18, d = 12 },
		{ x = -28, z = 28, w = 14, h = 9, d = 18 },
		{ x = 28, z = 28, w = 18, h = 14, d = 16 },
	})
	local spots = { World.spawn, World.clerk, World.tallyStone, World.wardens.grand_tally }
	for i, p in spots do
		for j, b in World.buildings do
			T.truthy(
				math.abs(p.x - b.x) >= b.w / 2 + 2 or math.abs(p.z - b.z) >= b.d / 2 + 2,
				`spot {i} inside building {j}`
			)
		end
	end
end)
```
  and in its extra-cache loop replace `Geography.place(region, 310, -60)` with `Geography.place(region, Regions.extraCache.along, Regions.extraCache.across)`. `tests/scenery.spec.luau`: the same replacement (add `local Regions` if the file lacks it — it has it). `tests/sites.spec.luau`: in "six extra Copper caches, one in each wild region" add `T.eq(Regions.extraCache, { along = 310, across = -60 })` as its first line and use the two fields below it; replace `Geography.toFrame(60, push.x, push.z)` with `Geography.toFrame(Regions.byId.SquallSteps.bearing :: number, push.x, push.z)` and `Geography.toFrame(300, h.shape.x, h.shape.z)` with `Geography.toFrame(Regions.byId.BastionReach.bearing :: number, h.shape.x, h.shape.z)` (the comment above the first becomes "toFrame at the Squall Steps bearing").
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL (the harness, `sanitize`, `extraCache` and `buildings` tests; the others may already pass — they pin today's behaviour).
- [ ] **Step 3: Implement** the interface changes above. `WorldBuilder` is the only server file touched; read `buildTallyport` before and after.
- [ ] **Step 4: Run** `bash scripts/check.sh` — Expected: exit 0.
- [ ] **Step 5: Commit** — `test: the backlog's tests; tidy Regions, World, Ledger.sanitize and the harness`

---

### Task 4: Server — hazards, regeneration, board names, the blight tint

**Files:**
- Modify: `src/server/HazardService.luau`, `src/server/ProtectionService.luau`, `src/server/RegenService.luau`, `src/server/LeaderboardService.luau`, `src/server/SiteBuilder.luau`

**Read first:** `HazardService.tickPlayer`, `Fighters.body`, `ProtectionService.livingRoot` and its callers, `RegenService` (all), `LeaderboardService.readPass`, `SiteBuilder.build` and `buildMarker`.

**Interfaces:**
- Consumes: `Hazards.landing`, `Hazards.overlay`, `Geography.strips`, `Geography.CELL`, `Leaderboard.shouldAskName`, `Fighters.body`, `LookPainter.paint`.
- **HazardService:** delete the local `living`; `tickPlayer` starts `local humanoid, root = Fighters.body(player.UserId)` (require `script.Parent.Fighters`). The burst block becomes:
```luau
if #sample.bursts > 0 then
	local landing, record = Hazards.landing(lastBurst[player], sample.bursts)
	lastBurst[player] = record
	for _, burst in landing do
		CombatService.environmentDamage(player, burst.damage, true)
	end
end
```
  The file's header comment says the once-per-cycle rule lives in `Hazards.landing`.
- **ProtectionService:** `livingRoot(player)` becomes `local _, root = Fighters.body(player.UserId) return root` (require `script.Parent.Fighters`; `Fighters` requires no server module, so there is no cycle). `AbilityService.living` already delegates to `Fighters.body` and stays.
- **RegenService:**
  - `watch(player, character)` runs in `task.spawn` (from `CharacterAdded` and for a character already present). It disconnects the old connection and clears `lastHurtAt[player]` first, then `local found = character:WaitForChild("Humanoid", 10)`; it returns when `found` is nil, is not a `Humanoid`, or `player.Character ~= character` (a newer character arrived while waiting; its own `watch` handles it); then connects `HealthChanged` as before.
  - The Heartbeat step moves into `local function step(player: Player, now: number, elapsed: number)`; `onHeartbeat` calls it through `pcall` for each player and warns once per tick with the count and the first error, exactly as `HazardService.runTick` does.
- **LeaderboardService:** `askedName: { [number]: number }` holds the time of the last try. In `readPass`, for each stored entry: skip when `present[id]` or `not Leaderboard.shouldAskName(names[tostring(id)] ~= nil, askedName[id], os.clock())`; else set `askedName[id] = os.clock()` and look the name up as now. A success stores the name, so `shouldAskName` is false from then on; a failure is tried again 300 s later, still only inside the one background thread.
- **SiteBuilder:** `build(island)` also adds a Folder `Blight` to `island`. For every hazard in `Sites.hazards` whose shape kind is `"region"` and whose look is not `"none"` (today only `HushBlight`), and for each `piece` of `Hazards.overlay(hazard, Geography.strips())`: a `Part` named `BlightTint`, anchored, `CanCollide`, `CanQuery`, `CanTouch` and `CastShadow` false, `Size = Vector3.new(piece.x2 - piece.x1, TINT_THICKNESS, Geography.CELL)`, `CFrame = CFrame.new((piece.x1 + piece.x2) / 2, World.groundY + TINT_LIFT, piece.z)`, painted with `LookPainter.paint(part, hazard.look)`; with `TINT_THICKNESS = 0.1` and `TINT_LIFT = 0.1` (under the 0.2-lifted hazard markers, so a spring's disc still shows on top). Not tagged `Hazard` and not in `Island.Hazards`: the play test's W.2 counts that folder. The header comment lists the new folder.

- [ ] **Step 1: Implement.** **Step 2: Run** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `fix: hazards, regeneration and board names on the server; the blight's ground tint`

No new behaviour tests (Task 2 pinned the rules). Pinned by reading: the burst loop applies exactly `landing`; `watch` never connects to an old character; the name lookup is still in `pcall` in the background thread only.

---

### Task 5: Server — Coin moves checked before writing; trades follow Coin

**Files:**
- Modify: `src/server/SourceService.luau`, `src/server/ShopService.luau`, `src/server/TradeService.luau`

**Read first:** `SourceService.addCoin`, `ShopService.handleAction` (the end: `Shop.apply`, `LedgerService.set`, `addCoin`), `TradeService.settle`, `onLedgerChanged`, `start`, `Trade.prune` (a still-covered offer is returned unchanged).

**Interfaces:**
- Consumes: `Sources.coinAfter`.
- Produces:
```luau
SourceService.onCoinChanged(callback: (player: Player, coin: number) -> ()): ()
-- callbacks run in task.spawn after every successful addCoin, like LedgerService.onChanged
```
- **SourceService.addCoin:** `local coin = Sources.coinAfter(data.coin, delta)`; nil → return false; else write, sync (as now), then `task.spawn(callback, player, coin)` for each callback; return true.
- **ShopService.handleAction**, after `Shop.apply` succeeds and before any write: `local delta = newCoin - coinBefore`; `Sources.coinAfter(coinBefore, delta) == nil` → notify `BAD_REQUEST` and return (nothing written). Then `LedgerService.set` as now; then `SourceService.addCoin(player, delta)` (it cannot fail now: same data, no yield, checked).
- **TradeService.settle**, after `Trade.settle` succeeds and before `trades[a] = nil`: if `Sources.coinAfter(heldA, coinA - heldA) == nil or Sources.coinAfter(heldB, coinB - heldB) == nil` then `cancel(ref)` and return. The four writes stay in their order.
- **TradeService.start:** `SourceService.onCoinChanged(function(player) local data = DataService.get(player) if data ~= nil then onLedgerChanged(player, data.ledger) end end)` — so a Coin change prunes an offer the trader can no longer cover (as a Ledger change does) and always re-sends the view, whose "of N" then shows the new Coin. `settle` clears `trades` before its `addCoin` calls, so its own Coin moves re-sync nothing.

- [ ] **Step 1: Implement.** **Step 2: Run** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `fix: Coin moves checked before any write; an open trade follows Coin changes`

Pinned by reading (Review Focus 4): no yield between the check and the writes; `coinAfter` runs before the first write in both services; the coin hook only re-syncs.

---

### Task 6: Client — `UiKit`, the menu row, and the HUD placed for phones

**Files:**
- Create: `src/client/UiKit.luau`, `src/client/MenuBar.luau`
- Modify: `src/client/Main.client.luau`, `src/client/AbilityBar.luau`, `src/client/StatusHUD.luau`, `src/client/Toast.luau`, `src/client/TrialUI.luau`, `src/client/LedgerUI.luau`, `src/client/PathUI.luau`, `src/client/TradeUI.luau`, `src/client/PartyUI.luau`, `tests/build.spec.luau`

**Read first:** every file above; `Main.client.luau`'s mount order and the 0.5 s HUD loop.

**Interfaces:**
- `src/client/UiKit.luau`, exactly this API (comments in the file's own words; the bodies below are the behaviour to keep):
```luau
--!strict
-- The pieces every screen shares: labels, buttons, windows, the borderless ScreenGui, the
-- one-request guard, the press seam for the play test, and where the HUD goes on this screen.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HudLayout =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"):WaitForChild("HudLayout"))

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

function UiKit.corner(parent: Instance, radius: number) end -- UICorner, offset radius
function UiKit.padding(parent: Instance, pixels: number) end -- UIPadding, all four sides
function UiKit.limitText(parent: Instance, minSize: number, maxSize: number) end
-- Transparent background, TextScaled, the options' defaults.
function UiKit.label(name: string, text: string, size: UDim2, position: UDim2, options: TextOptions?): TextLabel end
-- TextScaled, GothamBold, corner 8, AutoButtonColor true, the options' defaults. size nil = left unset.
function UiKit.button(name: string, text: string, size: UDim2?, options: ButtonOptions?): TextButton end
-- Dimmed and inert unless enabled: Active, AutoButtonColor, BackgroundTransparency 0 / 0.6,
-- TextTransparency 0 / 0.5 (the look every window used).
function UiKit.setEnabled(button: GuiButton, enabled: boolean) end
-- Destroys every child that is not a UIComponent.
function UiKit.clearRows(container: Instance) end
-- Transparent, BorderSizePixel 0, ScrollBarThickness (default 6), CanvasSize 0, AutomaticCanvasSize Y.
function UiKit.scroller(name: string, size: UDim2, position: UDim2, thickness: number?): ScrollingFrame end
-- ResetOnSpawn false, the DisplayOrder, IgnoreGuiInset = ignoreInset == true, attribute IsleUi = true,
-- and DescendantAdded sets BorderSizePixel = 0 on every GuiObject placed under it.
function UiKit.screen(name: string, displayOrder: number, ignoreInset: boolean?): ScreenGui end
-- Hidden, centred (anchor and position 0.5), the size, PANEL colour, corner 14, and a
-- UISizeConstraint MinSize = HudLayout.WINDOW_MIN[kind].
function UiKit.window(name: string, size: UDim2, kind: "big" | "small" | "dialog"): Frame end

-- Connects Activated; the handler runs only while button.Active. Also records the handler for press.
function UiKit.onPress(button: GuiButton, handler: () -> ()) end
-- Play-test seam: runs the recorded handler as a tap would, only when the button is Active and it
-- and every GuiObject above it are Visible and its ScreenGui is Enabled. Returns whether it ran.
-- (handlers are kept in a weak-keyed table)
function UiKit.press(button: Instance): boolean end

function UiKit.guard(setInert: (inert: boolean) -> ()): Guard end -- { busy = false, serial = 0, setInert }
-- Busy: returns false, sends nothing. Else busy = true, serial += 1, setInert(true), request(),
-- and after REARM_SECONDS, if still busy with the same serial: busy = false, setInert(false).
function UiKit.send(guard: Guard, request: () -> ()): boolean end
-- The server's next view arrived: serial += 1; if busy, busy = false and setInert(false).
function UiKit.answered(guard: Guard) end

-- Measures the screen (workspace.CurrentCamera.ViewportSize floored, GuiService:GetGuiInset()'s
-- first value's Y, UserInputService.TouchEnabled), keeps the HudLayout, and measures again when
-- the camera's ViewportSize changes or workspace.CurrentCamera is replaced. Call once, first.
function UiKit.startLayout() end
function UiKit.layout(): HudLayout.Layout end -- the last one (measures if none yet; 1280 x 720 with no camera)
-- Calls the callback now with the current layout, and again on every change.
function UiKit.onLayout(callback: (layout: HudLayout.Layout) -> ()) end
-- AnchorPoint 0, Position and Size in offset pixels from a full-screen rectangle; for an object
-- whose ScreenGui does not ignore the inset, y is moved up by the inset. Parent the object first.
function UiKit.place(object: GuiObject, rect: HudLayout.Rect) end

return UiKit
```
- `src/client/MenuBar.luau`:
```luau
MenuBar.mount(playerGui: PlayerGui, handlers: { ledger: () -> (), paths: () -> (), trade: () -> (), party: () -> () }): ()
```
  `UiKit.screen("MenuGui", 5, true)`; four `UiKit.button`s named `LedgerButton` "Ledger", `PathsButton` "Paths", `TradeButton` "Trade", `PartyButton` "Party" (options `{ min = 10, max = 18 }`), each `UiKit.onPress` to its handler, parented to the gui; then `UiKit.onLayout(function(layout) for i, button in buttons do UiKit.place(button, layout.menu[i]) end end)`.
- `TrialUI.shownLines(): number` — how many HUD lines the last `renderHud` drew.
- `Toast.region(text: string): ()` and the play-test seam `Toast.regionText(): string` (the banner's text while visible, else "").

- [ ] **Step 1: `UiKit` and `MenuBar`** as above. Add `Client.UiKit` and `Client.MenuBar` to `tests/build.spec.luau` (the `StarterPlayerScripts.Client.<Name>.ClassName == "ModuleScript"` form).
- [ ] **Step 2: Remove the bottom-left buttons.** Delete the `OpenButton` block in `LedgerUI.mount`, the `openButton` block in `PathUI.mount`, the `TradeButton` block (and its "Above the Ledger button" comment) in `TradeUI.mount`, and the `PartyButton` block (and its comment) in `PartyUI.mount`. `LedgerUI.toggle`, `PathUI.toggle` and the B and P keys stay.
- [ ] **Step 3: `Main.client.luau`.** `UiKit.startLayout()` before the first mount; `MenuBar.mount(playerGui, { ledger = LedgerUI.toggle, paths = PathUI.toggle, trade = function() tradeRequest:FireServer() end, party = function() partyRequest:FireServer() end })` after `PartyUI.mount`; in `refreshHud` the region line becomes `Toast.region(place.name .. ": " .. place.hint)`.
- [ ] **Step 4: `AbilityBar`.** `UiKit.screen("AbilityGui", 6, true)` (was DisplayOrder 11: the HUD now sits under the windows); the bar is parented, then `UiKit.onLayout(function(layout) UiKit.place(bar, layout.abilityBar) end)` (the slots stay square children of a centred `UIListLayout` with padding 6, which fills the rectangle exactly). Slot buttons use `UiKit.onPress`. Its local `addCorner`/`limitText` go; `UiKit.corner`/`UiKit.limitText` replace them.
- [ ] **Step 5: `StatusHUD`.** `UiKit.screen("StatusGui", 15)`. `DropShield` moves to `UDim2.fromOffset(12, 44)` (directly under the Coin line; `HudLayout.dropShield` is the same rectangle in full-screen pixels). The `Lines` frame's y is `44` while the button is hidden and `44 + 36` while it shows: `render` sets it when `showDropShield` changes (keep `shownKey` for the lines). `ConfirmDrop` becomes `UiKit.window("ConfirmDrop", UDim2.fromScale(0.4, 0.22), "dialog")` parented to the gui, with its `Question`, `Yes` and `No` as before (`UiKit.label`, `UiKit.button`, `UiKit.onPress`). The local helpers go.
- [ ] **Step 6: `Toast`.** `UiKit.screen("ToastGui", 20, true)`; the message label as before (`UiKit.corner`, `UiKit.limitText`). A second `TextLabel` named `Region`: anchor (0.5, 0), position (0.5, 0.12), size (0.45, 0.05), a `UISizeConstraint` with MinSize (240, 22), background (25, 22, 30) at transparency 0.35, gold text `Color3.fromRGB(255, 215, 150)`, GothamMedium, TextScaled with limits 10–20, corner 8, hidden. `Toast.region(text)` sets the text, shows it, and hides it 3 s later unless a newer `region` call came (a token, as `CeremonyUI` does). The message queue never sees region text.
- [ ] **Step 7: `TrialUI`.** `UiKit.screen("TrialGui", 14)`. The offer window becomes `UiKit.window("Offer", UDim2.fromScale(0.46, 0.56), "small")` with its body and buttons unchanged in layout (`Accept` and `Close` through `UiKit.onPress`; the dimmed Accept uses `UiKit.setEnabled`). The `Hud` frame is parented, then `UiKit.onLayout(function(layout) lineHeight = layout.hudLineHeight UiKit.place(lines, layout.trialHud) shownKey = "" end)` (forces the next `renderHud` to redraw at the new height); `renderHud` uses `lineHeight` (default 28) for each line's height; it records the number of lines drawn for `shownLines`. The local helpers go.
- [ ] **Step 8:** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `feat: UiKit, the menu row and the HUD placed for phones`

Pinned by reading: every HUD control is placed only through `UiKit.place` inside an `onLayout` callback; no module but `MenuBar` creates a menu button; `Toast.show` is no longer called for regions.

---

### Task 7: Client — the Ledger book, the claim screen, Renounce and the ceremony on the kit; two-tap unclaim and discard

**Files:**
- Modify: `src/client/LedgerUI.luau`, `src/client/ClaimUI.luau`, `src/client/RenounceUI.luau`, `src/client/CeremonyUI.luau`

**Read first:** the four files, `UiKit` (Task 6), `Confirm` (Task 1).

**Rules for every migrated file (Tasks 7–9):** the local `addCorner`, `addPadding`, `limitText`, `makeLabel`, `makeButton`, `setEnabled`, `clearRows` and scroller helpers are deleted and their calls go through `UiKit`; each call keeps the look it had (pass options where the old helper differed from the kit's defaults — for example `LedgerUI`'s labels were not wrapped and had a minimum text size of 10); colours the file defines for itself stay in the file. Every `ScreenGui` comes from `UiKit.screen` with its current name and DisplayOrder; every window from `UiKit.window` with its current name, scale size and the kind in spec 3.16 (it replaces any `UISizeConstraint` the window had); every button handler from `UiKit.onPress`; Close and "Later" buttons get `minSize = Vector2.new(40, 32)`.

- [ ] **Step 1: `LedgerUI`.** `UiKit.screen("LedgerGui", 10)`; `Book` = `UiKit.window("Book", UDim2.fromScale(0.7, 0.7), "big")` (the `CrownLine`, grid and free list keep their scale positions). Two-tap and guards:
  - State: `armed: Confirm.Armed? = nil`; per render, `slotEntries: { { button: TextButton, slot: LedgerView.SlotView } }` for claimed slots and `discardEntries: { { button: TextButton, key: string } }`.
  - `drawArmed()` redraws from `armed` and `os.clock()`: a claimed slot whose key `"unclaim:" .. slot.cardId` is armed reads `slot.label .. "\nTap again\nto unclaim"` on `UiKit.ARMED` with light text; otherwise its usual text and tier colour. A Discard button whose key is armed reads "Sure?" on `UiKit.ARMED`; otherwise "Discard" on the button colour.
  - Each claimed slot has its own guard, `UiKit.guard(function(inert) UiKit.setEnabled(button, not inert) end)`. Its press: `armed, go = Confirm.press(armed, key, os.clock())`, `drawArmed()`; when `go`, `UiKit.send(slotGuard, function() actionHandler({ kind = "unclaim", cardId = slot.cardId }) end)`; otherwise `task.delay(Confirm.WINDOW_SECONDS + 0.1, drawArmed)`. The Vault button on a slot sends through the same slot guard (one tap, as before).
  - Each free row keeps its single guard for all its buttons (it replaces the local `once`/`setInert`, re-arm 1 s for every button — the Use button's old 1-second re-arm is now the rule). Claim and Use: one tap through the row guard. Discard: key `"discard:" .. card.index .. ":" .. card.cardId`, the same `Confirm.press` / `drawArmed` / delayed redraw, and on `go` the discard request through the row guard.
  - `render` rebuilds the rows as now and calls `drawArmed()` at the end, so an armed control stays armed across a sync while its key still exists.
  - The Close button: `UiKit.button("Close", "X", UDim2.fromScale(0.08, 0.08), { minSize = Vector2.new(40, 32) })`.
- [ ] **Step 2: `ClaimUI`.** `UiKit.screen("ClaimGui", 30)`; `Claim` = `UiKit.window("Claim", UDim2.fromScale(0.9, 0.9), "big")` (replaces the 560 × 320 minimum, which overflowed a phone under a 58-pixel top bar; update that comment). Each open cell: its own guard dimming only that cell; the press sends `pickHandler(slot.slot)` through it. The next `ClaimUI.show` (the server's `ClaimUpdate`) rebuilds the cells. `Done` through `UiKit.onPress`.
- [ ] **Step 3: `RenounceUI`.** `UiKit.screen("RenounceGui", 26)`; `Renounce` = `UiKit.window("Renounce", UDim2.fromScale(0.5, 0.6), "small")`. Its `sent` flag and re-arm timer become one window guard (`setInert` = `refreshButtons`, which now reads `guard.busy`); `show` calls `UiKit.answered(guard)`; the countdown keeps its own serial. Confirm: when the word matches, `UiKit.send(guard, ...)`; Keep: `UiKit.send(guard, ...)`.
- [ ] **Step 4: `CeremonyUI`.** `UiKit.screen("CeremonyGui", 25)`; its lines through `UiKit.label` (centred, wrapped, as now).
- [ ] **Step 5:** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `feat: the Ledger, the claim screen, Renounce and the ceremony on the kit; two taps to unclaim or discard`

Pinned by reading (Review Focus 2, 3): no path sends `unclaim` or `discard` without `go`; every send goes through a guard; nothing is left that a refusal can keep dimmed for longer than 1 s.

---

### Task 8: Client — the Edict Hall, trading, Edicts and the Paths on the kit

**Files:**
- Modify: `src/client/ShopUI.luau`, `src/client/TradeUI.luau`, `src/client/EdictUI.luau`, `src/client/PathUI.luau`

**Read first:** the four files, `UiKit`, the migration rules in Task 7.

- [ ] **Step 1: `ShopUI`.** `UiKit.screen("ShopGui", 16)`; `Shop` = `UiKit.window("Shop", UDim2.fromScale(0.7, 0.82), "big")`. One window guard replaces `requestSent`, `viewSerial`, `RETRY_SECONDS` and the redraw-on-retry: `setInert(true)` = the current `dimButtons()`; `setInert(false)` = `restoreButtons()`, which re-applies `setEnabled` from the flags of the last `show` (pack ← `canBuyPack`, each stock button ← its row's `canBuy`, each sell button ← true) without rebuilding a row. Every Buy and Sell goes through `UiKit.send`; `show` ends with `UiKit.answered(guard)`.
- [ ] **Step 2: `TradeUI`.** `UiKit.screen("TradeGui", 16)`; `Trade` = `UiKit.window("Trade", UDim2.fromScale(0.82, 0.8), "big")`; the invite banner moves to y 0.18 (under the region banner, 12% to 17%). One window guard: `setInert` enables or disables every free-row button, the four Coin step buttons and Cancel, then calls `updateConfirm()`; `updateConfirm` enables Confirm only when `ready and not guard.busy`. Every offer, confirm and cancel goes through `UiKit.send`; `render` (a view or nil) calls `UiKit.answered(guard)`. The confirm countdown runs only while a trade is open: `render` with a view starts the loop when it is not running (`while current ~= nil do updateConfirm() task.wait(TICK_SECONDS) end`, then clear the running flag); the loop in `mount` goes. Accept and Decline on the invite hide it first, as now.
- [ ] **Step 3: `EdictUI`.** `UiKit.screen("EdictGui", 16)`; `makeWindow` gains a `kind` and builds on `UiKit.window(name, UDim2.fromScale(0.6, 0.64), kind)`: `RelicPicker` big (its cells are then at least 85 pixels wide on a phone), `PlayerPicker` and `Result` small. The pickers still close before they send (their guard).
- [ ] **Step 4: `PathUI`.** `UiKit.screen("PathGui", 12)`; `Panel` = `UiKit.window("Panel", UDim2.fromScale(0.8, 0.85), "big")`, `Picker` = `UiKit.window("Picker", UDim2.fromScale(0.9, 0.85), "big")` (keep ZIndex 5), `Confirm` = `UiKit.window("Confirm", UDim2.fromScale(0.5, 0.26), "dialog")` (keep ZIndex 50 and 51). The picker's grid cells become 220 pixels tall (from 250) so a whole card fits a phone. One loadout guard for every `Equip…` and `Clear…` button (`setInert` toggles them all with `UiKit.setEnabled`); both requests go through it; `render` ends with `UiKit.answered(guard)`. "Make Calling" stays inert when `not row.canChange` (the press seam respects `Active`).
- [ ] **Step 5:** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `feat: the Edict Hall, trading, Edicts and the Paths on the kit`

---

### Task 9: Client — the party panel fits a phone; whole names in party rows

**Files:**
- Modify: `src/client/PartyUI.luau`, `src/client/Main.client.luau`

**Read first:** `PartyUI` (all), `HudLayout.partyPanel`, `UiKit`, the migration rules in Task 7.

**Interfaces:**
```luau
PartyUI.refresh(localPlayer: Player, hudLines: number): ()   -- hudLines = TrialUI.shownLines()
```
- [ ] **Step 1: Kit and guard.** `UiKit.screen("PartyGui", 16)`; the invite banner at y 0.28 (below the trade invite, 18% to 27%). `pending`/`pendingToken`/`REARM_SECONDS` become one window guard (`setInert` = `setPanelEnabled(not inert)`); `send` is `UiKit.send(guard, …)`; `setParty` calls `UiKit.answered(guard)` and then, as now, `setPanelEnabled(true)` (rows are not rebuilt on every sync).
- [ ] **Step 2: Placement.** Delete `PANEL_WIDTH`, `PANEL_TOP_OFFSET`, `PANEL_BOTTOM_MARGIN` and the panel's `UISizeConstraint`. `sizePanel(frame, rowsHolder, count, hudLines)`: `wanted = PANEL_PAD + TITLE_HEIGHT + ROW_GAP + PANEL_PAD + count * (ROW_HEIGHT + ROW_GAP) - ROW_GAP`; `rect = HudLayout.partyPanel(UiKit.layout(), hudLines, wanted)`; `UiKit.place(frame, rect)`; the rows area is `rect.height - (PANEL_PAD + TITLE_HEIGHT + ROW_GAP + PANEL_PAD)` tall (at least 0; the rows scroll). `redraw` keeps the last `hudLines` given to `refresh` (0 before the first) and passes it on.
- [ ] **Step 3: Rows on two lines** (row height stays 48; the row is the panel's width less 2 × 8 padding and 6 for the scroll bar):
  - Line 1 (y 3, 18 tall): `Name` from x 6 to 64 short of the right edge (`UDim2.new(1, -70, 0, 18)`), `TextScaled = false`, `TextSize = 14`, `TextTruncate = Enum.TextTruncate.AtEnd`, not wrapped — a long name ends in "…" and is never shrunk or cut by a button; `Health` right-aligned at `UDim2.new(1, -4, 0, 3)`, anchor (1, 0), size (56, 18).
  - Line 2 (y 22, 16 tall): `Title` from x 6, width `UDim2.new(1, -(12 + buttonsWidth), 0, 14)` where `buttonsWidth` is 50 with Remove plus 44 with Lead; `Remove` anchor (1, 0) at `UDim2.new(1, -4, 0, 22)`, size (46, 16); `MakeLeader` at `UDim2.new(1, -(4 + (if row.canRemove then 50 else 0)), 0, 22)`, anchor (1, 0), size (40, 16).
  - The bar stays at y 38, 6 tall. Names of the children are unchanged (the play test reads them).
- [ ] **Step 4: `Main.client.luau`:** the HUD loop calls `PartyUI.refresh(localPlayer, TrialUI.shownLines())`.
- [ ] **Step 5:** `bash scripts/check.sh` — Expected: exit 0. **Commit** — `feat: the party panel fits a phone; whole names in party rows`

---

### Task 10: Play test and hand-off

**Files:**
- Modify: `playtest/server/Driver.server.luau`, `playtest/client/Agent.client.luau`, `README.md`, `docs/backlog.md`, `docs/playtest/M1-checklist.md`, `docs/playtest/World-checklist.md`
- Create: `docs/playtest/M8-checklist.md`

The controller (not the implementer) runs Studio and rebuilds `dist/`. The implementer writes the checks and documents.

**Read first:** in `Driver.server.luau` the helpers (`check`, `log`, `waitFor`, `mark`, `noteSince`, `expectNote`, `expectNoNote`, `send`, `fire`, `inspect`, `inspectUntil`, `place`, `put`, `heal`, `health`, `humanoidOf`, `waitAlive`, `waitNoFight`, `setFree`, `setCoin`, `freeOf`, `hasFree`, `coinOf`, `openTrade`), the report handler and its tables (`tradeViews`, `tradeInvites`, `partyInvites`), `runM7` and how `run()` calls each section in its own `xpcall` and restores after it; M3.1's `fresh.pathsButton`. In `Agent.client.luau` the `cmd.OnClientEvent` ops and `inspectUi`.

Lessons the checks must follow (standing): never stand two test players on one spot; after `place`, wait for the server position (`put` does); compare against values read before the action; a check that expects nothing waits, then asserts; every wait has a timeout; restore every seam after the section.

- [ ] **Step 1: Agent.**
  - Requires: `GuiService`, `UserInputService`; `local Client = script.Parent.Parent:WaitForChild("Client")`, `local UiKit = require(Client:WaitForChild("UiKit"))` (the same module table the game's client uses), `local Toast = require(Client:WaitForChild("Toast"))`.
  - `screenRect(object)`: with `gui = object:FindFirstAncestorOfClass("ScreenGui")`, `rel = object.AbsolutePosition - gui.AbsolutePosition`; returns `{ x = rel.X, y = rel.Y + (if gui.IgnoreGuiInset then 0 else GuiService:GetGuiInset().Y), width = object.AbsoluteSize.X, height = object.AbsoluteSize.Y }` (full-screen pixels whatever `AbsolutePosition`'s own origin is).
  - Op `press` (arg: a path like `"LedgerGui/Book/Slots/Slot001"`, each part found with `FindFirstChild` from `playerGui`): `ok = UiKit.press(button)` (false when not found); report `("pressed", { path = arg, ok = ok, active = button.Active, text = button.Text })` read right after the handler ran (nil fields when not found).
  - Op `togglePaths` (arg boolean): sets `PathGui.Panel.Visible`, like `toggleLedger`.
  - `inspectUi` changes: `ui.pathsButton` = `MenuGui.PathsButton` exists. New fields: `ui.isleGuis` (count of `ScreenGui`s in `playerGui` with attribute `IsleUi`); `ui.bordered` (up to 10 full names of `GuiObject`s under those guis with `BorderSizePixel ~= 0`); `ui.oldButtons` (how many of `LedgerGui.OpenButton`, `PathGui.PathsButton`, `TradeGui.TradeButton`, `PartyGui.PartyButton` exist); `ui.layoutIn = { width = math.floor(ViewportSize.X), height = math.floor(ViewportSize.Y), insetY = GuiService:GetGuiInset().Y, touch = UserInputService.TouchEnabled }`; `ui.menu` (`screenRect` of each of the four `MenuGui` buttons, by name); `ui.abilityBar` (`screenRect(AbilityGui.Bar)`); `ui.pathsPanelVisible`; `ui.windowMins` (for `LedgerGui.Book`, `ClaimGui.Claim`, `ShopGui.Shop`, `TradeGui.Trade`, `PathGui.Panel`, `PathGui.Picker`, `PathGui.Confirm`, `EdictGui.RelicPicker`, `EdictGui.PlayerPicker`, `EdictGui.Result`, `TrialGui.Offer`, `RenounceGui.Renounce`, `StatusGui.ConfirmDrop`: by the frame's name, `{ x, y }` of its `UISizeConstraint.MinSize`, or `false`); `ui.freeRows` (by row name `Free<i>`: each child `TextButton` by name → `{ text, active }`); `ui.regionBanner = Toast.regionText()`; `ui.partyPanel = screenRect(PartyGui.Panel)`; each party row gains `truncate = Name.TextTruncate.Name`.
- [ ] **Step 2: Driver.** Require `HudLayout`, `Looks`, `Messages`, `Regions` beside the existing requires; add `local presses = {}` and a `"pressed"` branch in the report handler (`presses[player] = a`); `local function press(player, path)` = `presses[player] = nil`, `send(player, "press", path)`, wait up to 3 s, return `presses[player] or {}`. Update the header comment (M8 after M7; the region banner; the press seam). A `runM8(A, B)` section right after the M7 restore and before M2.15, in its own `xpcall` with `check("M8 section ran to its end", ...)`; after it, outside the `xpcall`, restore: `LedgerService.unlock(A)`, `send(A, "toggleLedger", false)`, `send(A, "togglePaths", false)`, cancel any trade, leave any party (both), both alive in town (`put(A, IN_TOWN, B_TOWN)`, `put(B, B_TOWN, IN_TOWN)`).
  **Setup:** both alive; `ProtectionService.endRespawnShield` and `endMark` on both; `waitNoFight` on both; heal both; A at `TRADE_A`, B at `TRADE_B`. One `check` per line:
  - **M8.1 the kit:** `inspect(A)`: `isleGuis == 14`; `#bordered == 0` (detail: the names); `oldButtons == 0`; the four `menu` entries exist.
  - **M8.2 the layout:** `want = HudLayout.compute(l.width, l.height, l.insetY, l.touch)` from A's `layoutIn`; each `menu[name]` within 1 pixel of `want.menu[i]` (Ledger, Paths, Trade, Party = 1..4) on all four values; `abilityBar` within 1 of `want.abilityBar`. Every `windowMins` entry's `x` and `y` equal `HudLayout.WINDOW_MIN[kind]`'s `width` and `height`, with kinds `Book, Claim, Shop, Trade, Panel, Picker, RelicPicker` big, `PlayerPicker, Result, Offer, Renounce` small, `Confirm, ConfirmDrop` dialog (one check per window).
  - **M8.3 the menu row works:** `press(A, "MenuGui/LedgerButton").ok` → `inspectUntil(A, bookVisible)`; pressed again → closed. `MenuGui/PathsButton` → `pathsPanelVisible`, again → hidden. `MenuGui/TradeButton` → `tradeInvites[B]` becomes a table within 3 s; `send(B, "tradeReply", false)` → A `TRADE_DECLINED`. `MenuGui/PartyButton` → `partyInvites[B]` a table within 3 s; `send(B, "partyReply", false)`.
  - **M8.4 two taps to unclaim:** `setFree(A, {}, { R001 = true, R002 = true })`; `send(A, "toggleLedger", true)`; `inspectUntil` the book's `progress` reads `"Relics: 2 / 50"` (the sync has arrived). `m = mark(A)`; press `LedgerGui/Book/Slots/Slot001` → `text` contains "Tap again"; press it again → `expectNote` `UNCLAIMED` naming R001's name; `hasFree(A, "R001")`. Then `m = mark(A)`; press `Slot002`; `task.wait(3.5)`; `inspect(A)`: `ledgerSlots.Slot002` has no "Tap again" and no `UNCLAIMED` since `m`; press `Slot002` → `expectNoNote` `UNCLAIMED` (this tap only armed again); press `Slot002` → `UNCLAIMED`.
  - **M8.5 two taps to discard:** `setFree(A, { "R003" })`; `inspectUntil` `freeRows.Free1`; `m = mark(A)`; press `LedgerGui/Book/FreeCards/Free1/Discard` → `text == "Sure?"`; `expectNoNote` `DISCARDED`; press it again → `DISCARDED`; `#freeOf(A) == 0`.
  - **M8.6 a refused request's row comes back:** `setFree(A, { "R004" })`; `inspectUntil` `freeRows.Free1.Claim`; `LedgerService.lock(A)`; `m = mark(A)`; `r = press(A, "LedgerGui/Book/FreeCards/Free1/Claim")` → `r.ok` and `r.active == false`; `expectNote` `LEDGER_LOCKED`; `task.wait(1.5)`; `inspect(A).freeRows.Free1.Claim.active == true` (no sync came); `LedgerService.unlock(A)`; press Claim → `CLAIMED`. Close the book.
  - **M8.7 the region banner beside a message:** `put(A, IN_TOWN, B_TOWN)`, `task.wait(1)`; `LedgerService.notify(A, "EDICT_NOT_NOW")`; `place(A, <Thornwood along 290, across 0, y 3>, Vector3.zero)` (from `Geography.place("Thornwood", 290, 0)`); `ui = inspectUntil(A, function(u) return u.regionBanner ~= "" end)`; `ui.regionBanner == "Thornwood: " .. Regions.byId.Thornwood.hint`; `ui.toast == Messages.format("EDICT_NOT_NOW")` (both on screen at once). `put(A, TRADE_A, TRADE_B)`.
  - **M8.8 the blight tint:** `workspace.Island.Blight` has exactly `#Hazards.overlay(Sites.hazardById.HushBlight, Geography.strips())` children; every child is a `Part` named `BlightTint`, anchored, `CanCollide`, `CanQuery`, `CanTouch` false, material `Ground`, colour `Color3.fromRGB(92, 72, 104)` (compare the three bytes), transparency 0.35 (±0.001), not tagged `Hazard`, and `Hazards.affects(HushBlight, p.Position.X, p.Position.Z)`.
  - **M8.9 a Coin change reaches an open trade:** `setCoin(A, 100)`; `openTrade(A, B)` → check; `tradeViews[A].coinHeld == 100`; `SourceService.addCoin(A, 25)` → within 3 s `tradeViews[A].coinHeld == 125`, and `TradeService.session(A) ~= nil` (still open). `send(A, "trade", { kind = "cancel" })` → `TRADE_CANCELLED`.
  - **M8.10 a new character is watched:** `A:LoadCharacter()`; `waitAlive(A)`; `ProtectionService.endRespawnShield(A)`; `put(A, IN_TOWN, B_TOWN)`; `heal(A)`; `humanoidOf(A).Health = 50`; after 5 s `health(A) <= 50.01`; after 9 s more `health(A) >= 52`.
  - **M8.11 the party panel:** A at `IN_TOWN`, B 8 studs away in town; `send(A, "partyRequest")`, wait for `partyInvites[B]`, `send(B, "partyReply", true)`; `ui = inspectUntil(B, partyVisible)`; with `want` from B's `layoutIn`: `ui.partyPanel` does not overlap any `want.menu[i]` nor `want.abilityBar`; its right edge is `layoutIn.width - 12` (±1) and its width `want.partyWidth` (±1); the row for A has `name == A.DisplayName .. " (leader)"` (A asked, so A leads; M6.2 reads the same form) and `truncate == "AtEnd"`. A sends `party { kind = "leave" }`.
- [ ] **Step 3: `docs/playtest/M8-checklist.md`** in the plain style of `docs/playtest/M7-checklist.md` (read it first; "What to do / What should happen"; quote on-screen text exactly). Leave the "Automated run" line as `Automated run: not done yet.` Steps: the menu row (four buttons above the ability bar; B and P still work); the HUD on a phone — in Studio choose the Test tab, then Device, pick a phone in landscape (for example one 640 by 360 or "iPhone SE"), start a test: the thumbstick area bottom left has no button, the jump button bottom right is clear, the trial HUD and party panel at the top right do not cover the menu row; every window on that phone (the Ledger book, the claim screen with every number readable, the Edict Hall, a trade, the Paths panel and the Calling picker, the Summons picker, a trial offer, the Renounce window, "Drop shield?"); two taps to unclaim (the red "Tap again to unclaim", and that waiting 3 seconds puts it back); two taps to discard ("Sure?"); buttons dim for a moment after a tap; no thin dark borders anywhere; the region banner under the message line while a message shows; the blight tint in the Hush Gardens (the purple-grey ground starts where the status line says "Blight"); a long party name ends in "…". Then a short section **On a real phone** (the same checks once on the owner's phone after publishing, see README "How to publish").
- [ ] **Step 4: Other documents.** `README.md`: a **Milestone 8, launch polish** line in "What is in the game now" (the game fits a phone: menu buttons in a row above the ability bar, away from the thumbstick and jump button; windows that fit a small screen; two taps to unclaim a slot or discard a card; the region name in its own line; a tint on the blighted ground); play-test step 11 for `docs/playtest/M8-checklist.md`; the automated play-test sentence names M8. `docs/playtest/M1-checklist.md` step 14: "walk due west out of town" → "walk out of town halfway between the Hush Gardens and Bastion Reach roads". `docs/playtest/World-checklist.md`: after "(Milestone 4 adds six more caches, three of them on top of stone stairways.)" add "Milestone 7 adds seven more: 31 caches in all." `docs/backlog.md`: delete every item M8 did (the UI polish pass, the tests to add, the `Ledger.sanitize` and harness tidying, `buildCache`/building positions, the region banner, "one hit per activation", the extra-cache spot, the blight marker, `living()`, `World.islandHalfSize`, the region bearings, the status column's five lines, the M1 "due west" line, `bearingOf` 360) and keep the rest under a heading **Left after M8** with one line saying why each waits (tuning for the owner's play tests, test-only tightening, the gust push and causeway timing).
- [ ] **Step 5:** `bash scripts/check.sh` and `rojo build playtest.project.json -o build/playtest.rbxl` — Expected: exit 0 and a built file. **Commit** — `test: M8 play-test checks; docs: M8 checklist, README and backlog`
- [ ] **Step 6: The controller runs the play test in Studio** (build `playtest.project.json`, Test → Server & Clients, 2 players) until the driver prints `DONE` with `failed=0`, records the result line in the M8 checklist's "Automated run" line, and rebuilds `dist/IsleOfAvarice.rbxlx` (`bash scripts/check.sh && cp build/IsleOfAvarice.rbxlx dist/IsleOfAvarice.rbxlx`, confirm with `cmp`). If M8.2's rectangles are off by exactly the top-bar inset, the agent's `screenRect` is wrong for that kind of `ScreenGui`: fix the agent, not the game.

---

## Out of scope (later)

Sounds, paid items, global (cross-server) scarcity, guilds, Luau type checking in `check.sh` (no installed tool checks types), a UI size setting, portrait phones, gamepad layout, translations, and the tuning the backlog keeps for the owner's play tests.

## Known limit

`scripts/check.sh` proves the rules and the build. The play test runs in a desktop window, so it proves the layout's wiring (every control where `HudLayout` says for that window) but not a phone: `HudLayout`'s tests cover the phone sizes, and the owner checks a phone by hand in Studio's device emulator and on a real phone.
