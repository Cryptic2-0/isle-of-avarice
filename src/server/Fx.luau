--!strict
-- Short-lived, server-made visuals in workspace.Effects: shot rays and burst rings. Shared by
-- AbilityService and CreatureService. Rays and characters pass through all of it.
local Debris = game:GetService("Debris")

local SHOT_WIDTH = 0.3
local SHOT_SECONDS = 0.15
local RING_SECONDS = 0.3
local RING_SEGMENTS = 24
local RING_WIDTH = 0.6
local RING_HEIGHT = 0.2

local Fx = {}

function Fx.folder(): Folder
	local existing = workspace:FindFirstChild("Effects")
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = workspace
	return folder
end

local function effectPart(name: string, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

-- A thin beam from one point to another.
function Fx.ray(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	if not (length > 0 and length < math.huge) then
		return
	end
	local part = effectPart("Shot", color)
	part.Size = Vector3.new(SHOT_WIDTH, SHOT_WIDTH, length)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	part.Parent = Fx.folder()
	Debris:AddItem(part, SHOT_SECONDS)
end

-- A flat ring of the given radius around a point.
function Fx.ring(center: Vector3, radius: number, color: Color3)
	if not (radius > 0 and radius < math.huge) then
		return
	end
	local ring = Instance.new("Model")
	ring.Name = "Ring"
	local segment = 2 * radius * math.sin(math.pi / RING_SEGMENTS) + RING_WIDTH
	for i = 1, RING_SEGMENTS do
		local part = effectPart("Segment", color)
		-- Local X points outwards from the centre, local Z along the ring.
		part.Size = Vector3.new(RING_WIDTH, RING_HEIGHT, segment)
		part.CFrame = CFrame.new(center)
			* CFrame.Angles(0, (i - 1) / RING_SEGMENTS * 2 * math.pi, 0)
			* CFrame.new(radius, 0, 0)
		part.Parent = ring
	end
	ring.Parent = Fx.folder()
	Debris:AddItem(ring, RING_SECONDS)
end

return Fx
