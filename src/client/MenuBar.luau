--!strict
-- The menu row: Ledger, Paths, Trade, Party in one row above the ability bar, off the thumbstick
-- and the jump button. B and P still open the Ledger and the Paths panel.
local UiKit = require(script.Parent.UiKit)

local MenuBar = {}

export type Handlers = {
	ledger: () -> (),
	paths: () -> (),
	trade: () -> (),
	party: () -> (),
}

function MenuBar.mount(playerGui: PlayerGui, handlers: Handlers)
	local gui = UiKit.screen("MenuGui", 5, true)
	local options = { min = 10, max = 18 }
	local buttons: { TextButton } = {
		UiKit.button("LedgerButton", "Ledger", nil, options),
		UiKit.button("PathsButton", "Paths", nil, options),
		UiKit.button("TradeButton", "Trade", nil, options),
		UiKit.button("PartyButton", "Party", nil, options),
	}
	UiKit.onPress(buttons[1], handlers.ledger)
	UiKit.onPress(buttons[2], handlers.paths)
	UiKit.onPress(buttons[3], handlers.trade)
	UiKit.onPress(buttons[4], handlers.party)
	for _, button in buttons do
		button.Parent = gui
	end
	UiKit.onLayout(function(layout)
		for index, button in buttons do
			UiKit.place(button, layout.menu[index])
		end
	end)
	gui.Parent = playerGui
end

return MenuBar
