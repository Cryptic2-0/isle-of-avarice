--!strict
-- A trade between two players as a state machine (spec 3.13): each side's offer, the two
-- confirmations, and the swap. Offers are not held in escrow: `settle` re-checks both live
-- Ledgers and Coin, and swaps everything or nothing. Pure: the server owns the session.
local Cards = require("../Catalog/Cards")
local Ledger = require("./Ledger")
local Types = require("../Types")

type Ledger = Types.Ledger
type Vec3 = Types.Vec3

export type Offer = { cards: { string }, coin: number }
-- `offers` and `confirmed` are keyed by tostring(user id).
export type Session = {
	a: number,
	b: number,
	offers: { [string]: Offer },
	confirmed: { [string]: boolean },
	changedAt: number,
}
export type Body = { userId: number, position: Vec3 }
export type CardView = { cardId: string, name: string }
export type OfferView = { cards: { CardView }, coin: number }
export type FreeRow = { index: number, cardId: string, name: string, offered: boolean }
export type View = {
	otherName: string,
	mine: OfferView,
	theirs: OfferView,
	mineConfirmed: boolean,
	theirsConfirmed: boolean,
	-- Seconds until a confirmation is accepted; 0 when it is now.
	confirmIn: number,
	coinHeld: number,
	status: string,
	free: { FreeRow },
}

local Trade = {}

Trade.MAX_CARDS = 6
Trade.INVITE_RANGE = 15
Trade.KEEP_RANGE = 25
Trade.CONFIRM_DELAY = 2
Trade.INVITE_SECONDS = 20

local function isWholeAmount(n: any): boolean
	return type(n) == "number" and n >= 0 and n < math.huge and n == math.floor(n)
end

-- Written positively so Coin that is not a real number covers nothing.
local function covers(ledger: Ledger, coin: number, offer: Offer): boolean
	return Ledger.holdsFree(ledger, offer.cards) and coin >= offer.coin and coin < math.huge
end

function Trade.new(a: number, b: number, now: number): Session
	return {
		a = a,
		b = b,
		offers = {
			[tostring(a)] = { cards = {}, coin = 0 },
			[tostring(b)] = { cards = {}, coin = 0 },
		},
		confirmed = {},
		changedAt = now,
	}
end

function Trade.has(session: Session, userId: number): boolean
	return userId == session.a or userId == session.b
end

function Trade.other(session: Session, userId: number): number
	return if userId == session.a then session.b else session.a
end

local function withOffer(session: Session, userId: number, offer: Offer, now: number): Session
	local offers = table.clone(session.offers)
	offers[tostring(userId)] = offer
	-- Any change means both must look again.
	return { a = session.a, b = session.b, offers = offers, confirmed = {}, changedAt = now }
end

-- Replaces one side's offer. Raw request: { cards = { card id, ... }, coin = number }. The
-- cards must be in the player's free slots (counting repeats) and the Coin theirs. Both
-- confirmations are cleared, even when the offer is the same as before.
function Trade.setOffer(
	session: Session,
	userId: number,
	raw: any,
	ledger: Ledger?,
	coin: number,
	now: number
): (Session?, string)
	if not Trade.has(session, userId) then
		return nil, "TRADE_NOT_OPEN"
	end
	if ledger == nil then
		return nil, "DATA_NOT_LOADED"
	end
	if type(raw) ~= "table" or type(raw.cards) ~= "table" or not isWholeAmount(raw.coin) then
		return nil, "BAD_REQUEST"
	end
	-- Before the loop, so a huge client list is never walked.
	if #raw.cards > Trade.MAX_CARDS then
		return nil, "TRADE_BAD_OFFER"
	end
	local cards: { string } = {}
	local count = 0
	for key, id in raw.cards do
		count += 1
		-- A list only: keys 1..n in order.
		if key ~= count or Cards.info(id) == nil then
			return nil, "BAD_REQUEST"
		end
		table.insert(cards, id)
	end
	local offer: Offer = { cards = cards, coin = raw.coin }
	if #cards > Trade.MAX_CARDS or not covers(ledger, coin, offer) then
		return nil, "TRADE_BAD_OFFER"
	end
	return withOffer(session, userId, offer, now), "OK"
end

-- Both confirmations cleared and the wait restarted, for a trade that failed at the swap.
function Trade.unconfirm(session: Session, now: number): Session
	return {
		a = session.a,
		b = session.b,
		offers = session.offers,
		confirmed = {},
		changedAt = now,
	}
end

-- The nearest other player within the invite range, or nil. A NaN position is never near.
-- Ties go to the lower id.
function Trade.nearest(asker: Body, others: { Body }): number?
	local bestId: number? = nil
	local best = math.huge
	for _, other in others do
		if other.userId == asker.userId then
			continue
		end
		local a, b = asker.position, other.position
		local gap = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
		if not (gap <= Trade.INVITE_RANGE) then
			continue
		end
		if gap < best or (gap == best and bestId ~= nil and other.userId < bestId) then
			best = gap
			bestId = other.userId
		end
	end
	return bestId
end

-- Refused for 2 seconds after any change, so nobody confirms an offer they have not seen.
-- A clock that is not a number is refused too.
function Trade.confirm(session: Session, userId: number, now: number): (Session?, string)
	if not Trade.has(session, userId) then
		return nil, "TRADE_NOT_OPEN"
	end
	if not (now - session.changedAt >= Trade.CONFIRM_DELAY) then
		return nil, "TRADE_TOO_SOON"
	end
	local confirmed = table.clone(session.confirmed)
	confirmed[tostring(userId)] = true
	return {
		a = session.a,
		b = session.b,
		offers = session.offers,
		confirmed = confirmed,
		changedAt = session.changedAt,
	},
		"OK"
end

function Trade.ready(session: Session): boolean
	return session.confirmed[tostring(session.a)] == true
		and session.confirmed[tostring(session.b)] == true
end

-- Called when a trader's Ledger or Coin changed for any other reason: an offer its owner
-- can no longer cover is emptied (and both must confirm again). Otherwise nothing changes.
function Trade.prune(
	session: Session,
	userId: number,
	ledger: Ledger,
	coin: number,
	now: number
): Session
	if not Trade.has(session, userId) or covers(ledger, coin, session.offers[tostring(userId)]) then
		return session
	end
	return withOffer(session, userId, { cards = {}, coin = 0 }, now)
end

-- The swap. Both must have confirmed, both must still hold what they offered, and both must
-- have room for what they get. Success: both new Ledgers and Coin totals, "TRADE_DONE".
-- Failure: nil, the same Coin, nil, the same Coin, a code. Nothing is half-done.
function Trade.settle(
	session: Session,
	ledgerA: Ledger,
	coinA: number,
	ledgerB: Ledger,
	coinB: number
): (Ledger?, number, Ledger?, number, string)
	if not Trade.ready(session) then
		return nil, coinA, nil, coinB, "TRADE_NOT_OPEN"
	end
	local offerA, offerB = session.offers[tostring(session.a)], session.offers[tostring(session.b)]
	if not covers(ledgerA, coinA, offerA) or not covers(ledgerB, coinB, offerB) then
		return nil, coinA, nil, coinB, "TRADE_BAD_OFFER"
	end
	local leftA, leftB = Ledger.remove(ledgerA, offerA.cards), Ledger.remove(ledgerB, offerB.cards)
	if leftA == nil or leftB == nil then
		return nil, coinA, nil, coinB, "TRADE_BAD_OFFER"
	end
	if
		#leftA.free + #offerB.cards > Ledger.FREE_SLOTS
		or #leftB.free + #offerA.cards > Ledger.FREE_SLOTS
	then
		return nil, coinA, nil, coinB, "TRADE_NO_ROOM"
	end
	for _, id in offerB.cards do
		table.insert(leftA.free, id)
	end
	for _, id in offerA.cards do
		table.insert(leftB.free, id)
	end
	return leftA,
		coinA - offerA.coin + offerB.coin,
		leftB,
		coinB - offerB.coin + offerA.coin,
		"TRADE_DONE"
end

local function offerView(offer: Offer): OfferView
	local cards: { CardView } = {}
	for _, id in offer.cards do
		table.insert(cards, { cardId = id, name = Cards.name(id) })
	end
	return { cards = cards, coin = offer.coin }
end

-- What the trade window shows to `viewerId`: both offers, who has confirmed, and the
-- viewer's own free-slot cards with those on offer marked.
function Trade.view(
	session: Session,
	viewerId: number,
	otherName: string,
	ledger: Ledger,
	coin: number,
	now: number
): View
	local mine = session.offers[tostring(viewerId)]
	local otherId = Trade.other(session, viewerId)
	local mineConfirmed = session.confirmed[tostring(viewerId)] == true
	local theirsConfirmed = session.confirmed[tostring(otherId)] == true

	local onOffer: { [string]: number } = {}
	for _, id in mine.cards do
		onOffer[id] = (onOffer[id] or 0) + 1
	end
	local free: { FreeRow } = {}
	for index, id in ledger.free do
		local left = onOffer[id] or 0
		if left > 0 then
			onOffer[id] = left - 1
		end
		table.insert(
			free,
			{ index = index, cardId = id, name = Cards.name(id), offered = left > 0 }
		)
	end

	local status = "Check both offers, then confirm."
	if mineConfirmed then
		status = `You confirmed. Waiting for {otherName}.`
	elseif theirsConfirmed then
		status = `{otherName} has confirmed.`
	end
	local wait = Trade.CONFIRM_DELAY - (now - session.changedAt)
	return {
		otherName = otherName,
		mine = offerView(mine),
		theirs = offerView(session.offers[tostring(otherId)]),
		mineConfirmed = mineConfirmed,
		theirsConfirmed = theirsConfirmed,
		confirmIn = if wait > 0 then wait else 0,
		coinHeld = if coin >= 0 and coin < math.huge then math.floor(coin) else 0,
		status = status,
		free = free,
	}
end

return Trade
