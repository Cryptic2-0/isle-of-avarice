--!strict
-- Strike input and the hit flash. The client only asks to Strike; the server decides the rest.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared:WaitForChild("Rules"):WaitForChild("Combat"))

local FLASH_SECONDS = 0.15

local CombatController = {}

function CombatController.start(strike: () -> (), isBlocked: () -> boolean)
	local lastStrike = -math.huge
	ContextActionService:BindAction("Strike", function(_name, state, _input)
		if state == Enum.UserInputState.Begin and not isBlocked() then
			local now = os.clock()
			if now - lastStrike >= Combat.STRIKE_COOLDOWN then
				lastStrike = now
				strike()
			end
		end
		-- Pass, so clicks still reach the camera and other controls.
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F)
	ContextActionService:SetTitle("Strike", "Strike")
end

-- A brief white flash on a character that was hit.
function CombatController.flash(character: Model)
	local highlight = Instance.new("Highlight")
	highlight.Name = "HitFlash"
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.3
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0
	highlight.Adornee = character
	highlight.Parent = character
	task.delay(FLASH_SECONDS, function()
		highlight:Destroy()
	end)
end

return CombatController
