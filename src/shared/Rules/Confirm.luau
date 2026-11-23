--!strict
-- Two-tap confirm for risky buttons: the first tap arms the control, a second tap on the same
-- control within WINDOW_SECONDS goes ahead. Any other tap arms that control instead.
export type Armed = { key: string, at: number }

local Confirm = {}

Confirm.WINDOW_SECONDS = 3

function Confirm.isArmed(armed: Armed?, key: string, now: number): boolean
	return armed ~= nil
		and armed.key == key
		and now >= armed.at
		and now - armed.at <= Confirm.WINDOW_SECONDS
end

-- Returns the new armed record and whether the action should go ahead.
function Confirm.press(armed: Armed?, key: string, now: number): (Armed?, boolean)
	if Confirm.isArmed(armed, key, now) then
		return nil, true
	end
	return { key = key, at = now }, false
end

return Confirm
