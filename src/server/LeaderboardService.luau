--!strict
-- The all-time board of the Crowned on the Tally Stone. One background thread writes players'
-- Crown counts to an ordered data store, reads the top rows back and redraws the stone. Every
-- data store and name call is in pcall and lives only in this thread, so a failing store never
-- slows the game and the board still shows this server's players.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leaderboard = require(ReplicatedStorage.Shared.Rules.Leaderboard)
local DataService = require(script.Parent.DataService)
local LaunchConfig = require(script.Parent.LaunchConfig)

export type Backend = {
	write: (userId: number, crowns: number) -> boolean, -- true when stored
	readTop: (count: number) -> { Leaderboard.Entry }?, -- nil when it could not read
}

local LeaderboardService = {}

local TAG = "TallyStone"
local ROUND_SECONDS = 2
local EARLY_READ_SECONDS = 5

local realBackend: Backend? = nil
local backend: Backend? = nil
local stored: { Leaderboard.Entry } = {}
local online = false
local lastReadAt = -math.huge
local readSoon = false
local lastFailAt: { [Player]: number } = {}
local names: { [string]: string } = {}
local askedName: { [number]: boolean } = {}
local view: Leaderboard.View = Leaderboard.view({}, {}, false)
local busy = false
local warned: { [string]: boolean } = {}

-- The first failure of each kind warns; later ones are silent.
local function warnOnce(kind: string, message: unknown)
	if warned[kind] then
		return
	end
	warned[kind] = true
	warn(`[IsleOfAvarice] board: {kind} failed: {message}`)
end

-- The ordered data store, or nil (an unpublished place has none).
local function makeRealBackend(): Backend?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(LaunchConfig.BOARD_STORE)
	end)
	if not ok or result == nil then
		warnOnce("store", result)
		return nil
	end
	local store = result :: any
	return {
		write = function(userId: number, crowns: number): boolean
			-- Only Studio test players have ids below 1, and Leaderboard.fromPage cannot read
			-- such a key back, so the real store is never asked to keep one. Counts as a
			-- failed write: it is retried only after RETRY_SECONDS, and it never warns.
			if userId < 1 then
				return false
			end
			local wrote, err = pcall(store.UpdateAsync, store, tostring(userId), function(old: any)
				return Leaderboard.keep(old, crowns)
			end)
			if not wrote then
				warnOnce("write", err)
			end
			return wrote
		end,
		readTop = function(count: number): { Leaderboard.Entry }?
			local read, page = pcall(function()
				return store:GetSortedAsync(false, count):GetCurrentPage()
			end)
			if not read then
				warnOnce("read", page)
				return nil
			end
			return Leaderboard.fromPage(page)
		end,
	}
end

-- Writes the view onto the Tally Stone's board.
local function draw()
	for _, stone in CollectionService:GetTagged(TAG) do
		local board = stone:FindFirstChild("Board")
		if board == nil then
			continue
		end
		local title = board:FindFirstChild("Title")
		if title ~= nil and title:IsA("TextLabel") then
			title.Text = view.title
		end
		local subtitle = board:FindFirstChild("Subtitle")
		if subtitle ~= nil and subtitle:IsA("TextLabel") then
			subtitle.Text = view.subtitle
		end
		for i = 1, Leaderboard.ROWS do
			local row = board:FindFirstChild("Row" .. i)
			if row ~= nil and row:IsA("TextLabel") then
				row.Text = view.rows[i] or ""
			end
		end
	end
end

local function writePass()
	local current = backend
	if current == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data == nil then
			continue
		end
		local crowns = data.crown.crowns
		if
			not Leaderboard.shouldWrite(
				crowns,
				data.crown.boardCrowns,
				lastFailAt[player],
				os.clock()
			)
		then
			continue
		end
		local ok = current.write(player.UserId, crowns)
		-- The write yielded: the player may have left since.
		if player.Parent ~= Players then
			continue
		end
		if ok then
			local after = DataService.get(player)
			if after ~= nil then
				after.crown.boardCrowns = math.max(after.crown.boardCrowns, crowns)
			end
			readSoon = true
			lastFailAt[player] = nil
		else
			lastFailAt[player] = os.clock()
		end
	end
end

local function readPass()
	local sinceRead = os.clock() - lastReadAt
	if
		not (
			sinceRead >= Leaderboard.REFRESH_SECONDS
			or (readSoon and sinceRead >= EARLY_READ_SECONDS)
		)
	then
		return
	end
	lastReadAt = os.clock()
	readSoon = false
	local current = backend
	local rows = if current ~= nil then current.readTop(Leaderboard.ROWS) else nil
	if rows == nil then
		online = false
		return
	end
	stored = rows
	online = true
	local present: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		present[player.UserId] = true
	end
	for _, entry in rows do
		local id = entry.userId
		if present[id] or askedName[id] then
			continue
		end
		askedName[id] = true
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
		if ok and type(name) == "string" then
			names[tostring(id)] = name
		else
			warnOnce("name", name)
		end
	end
end

local function drawPass()
	local live: { Leaderboard.Entry } = {}
	for _, player in Players:GetPlayers() do
		names[tostring(player.UserId)] = player.Name
		local data = DataService.get(player)
		if data ~= nil and data.crown.crowns >= 1 then
			table.insert(live, { userId = player.UserId, crowns = data.crown.crowns })
		end
	end
	local base: { Leaderboard.Entry } = if online then stored else {}
	view = Leaderboard.view(Leaderboard.merge(base, live), names, online)
	draw()
end

local function runRound()
	busy = true
	local ok, err = pcall(function()
		writePass()
		readPass()
		drawPass()
	end)
	busy = false
	if not ok then
		warnOnce("round", err)
	end
end

-- Play-test seam: nil puts the real ordered data store back.
function LeaderboardService.setBackend(newBackend: Backend?)
	backend = newBackend or realBackend
	stored = {}
	online = false
	lastReadAt = -math.huge
	table.clear(lastFailAt)
end

-- Play-test seam: one write pass, one read, one draw, now.
function LeaderboardService.refreshNow()
	while busy do
		task.wait(0.1)
	end
	lastReadAt = -math.huge
	runRound()
end

-- Play-test seam: the view last drawn.
function LeaderboardService.board(): Leaderboard.View
	return view
end

function LeaderboardService.isOnline(): boolean
	return online
end

function LeaderboardService.start()
	realBackend = makeRealBackend()
	backend = realBackend
	Players.PlayerRemoving:Connect(function(player)
		lastFailAt[player] = nil
	end)
	task.spawn(function()
		while true do
			if not busy then
				runRound()
			end
			task.wait(ROUND_SECONDS)
		end
	end)
end

return LeaderboardService
