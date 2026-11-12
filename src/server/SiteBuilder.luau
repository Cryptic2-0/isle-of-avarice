--!strict
-- Builds the island's structures and a visual marker for each hazard.
--   SiteBuilder.build(island)
--       Adds Folder "Features" (one anchored Part for every Sites.features entry) and Folder
--       "Hazards" (one marker Part for every Sites.hazards entry that covers an area) to
--       `island`. Each marker is named with its hazard id, carries the attribute HazardId and
--       the tag "Hazard", and touches nothing: it is only there to be seen. A region-wide
--       hazard has no marker. A tide marker also carries the attribute Rise.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sites = require(ReplicatedStorage.Shared.Catalog.Sites)
local Types = require(ReplicatedStorage.Shared.Types)
local World = require(ReplicatedStorage.Shared.Catalog.World)
local LookPainter = require(script.Parent.LookPainter)

local SiteBuilder = {}

local MARKER_THICKNESS = 0.3
-- Markers float a little above the surface they mark so the ground does not hide them.
local MARKER_LIFT = 0.2
local TIDE_RISE = 3
-- A sign's label floats this far above the top of the part that carries it.
local LABEL_CLEARANCE = 2

-- White bold text over the part (height studs tall), in the style of the training-post label.
-- It sits above the part's top face so the part itself never hides it.
local function addLabel(part: BasePart, text: string, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 70)
	gui.StudsOffset = Vector3.new(0, height / 2 + LABEL_CLEARANCE, 0)
	gui.MaxDistance = 120
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	gui.Parent = part
end

local function buildFeature(parent: Folder, feature: Types.Feature)
	local part = Instance.new("Part")
	part.Name = feature.look
	part.Anchored = true
	local centre = CFrame.new(feature.x, feature.y, feature.z)
	if feature.shape == "cylinder" then
		-- A Roblox cylinder's axis is X: Size is (height, diameter, diameter), and a quarter
		-- turn about Z stands it upright.
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(feature.sy, feature.sx, feature.sx)
		part.CFrame = centre * CFrame.Angles(0, 0, math.rad(90))
	else
		-- A bearing runs clockwise from north (-Z), so the turn about Y is its negative.
		part.Size = Vector3.new(feature.sx, feature.sy, feature.sz)
		part.CFrame = centre * CFrame.Angles(0, -math.rad(feature.yaw), 0)
	end
	LookPainter.paint(part, feature.look)
	part.CanCollide = feature.solid
	if not feature.solid then
		part.CanQuery = false
		part.CanTouch = false
	end
	if feature.text ~= nil then
		addLabel(part, feature.text, feature.sy)
	end
	part.Parent = parent
end

local function buildMarker(parent: Folder, hazard: Types.Hazard)
	local shape = hazard.shape
	if shape.kind == "region" then
		return
	end
	local part = Instance.new("Part")
	part.Name = hazard.id
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local centre = CFrame.new(shape.x, (hazard.markerY or World.groundY) + MARKER_LIFT, shape.z)
	if shape.kind == "circle" then
		-- A flat disc: the cylinder's axis (its X, the thickness) is turned to point up.
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(MARKER_THICKNESS, shape.radius * 2, shape.radius * 2)
		part.CFrame = centre * CFrame.Angles(0, 0, math.rad(90))
	else
		part.Size = Vector3.new(2 * shape.halfAcross, MARKER_THICKNESS, 2 * shape.halfAlong)
		part.CFrame = centre * CFrame.Angles(0, -math.rad(shape.bearing), 0)
	end
	LookPainter.paint(part, hazard.look)
	part:SetAttribute("HazardId", hazard.id)
	CollectionService:AddTag(part, "Hazard")
	if hazard.look == "tide" then
		part:SetAttribute("Rise", TIDE_RISE)
	end
	part.Parent = parent
end

function SiteBuilder.build(island: Folder)
	local features = Instance.new("Folder")
	features.Name = "Features"
	for _, feature in Sites.features do
		buildFeature(features, feature)
	end
	features.Parent = island

	local hazards = Instance.new("Folder")
	hazards.Name = "Hazards"
	for _, hazard in Sites.hazards do
		buildMarker(hazards, hazard)
	end
	hazards.Parent = island
end

return SiteBuilder
