--[[
	Small helpers shared by the server services.
]]

local Util = {}

-- A Color3 from a Config colour { red, green, blue } (0 to 255).
function Util.colour(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local random = Random.new()

-- A number in [0, 1), in the shape Rules functions expect.
function Util.random(): number
	return random:NextNumber()
end

-- A whole number in [min, max].
function Util.roll(min: number, max: number): number
	return random:NextInteger(min, max)
end

function Util.pick<T>(list: { T }): T
	return list[random:NextInteger(1, #list)]
end

-- Creates an anchored part with the given properties.
function Util.part(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = props.Parent
	return part
end

-- A folder in Workspace, created once.
function Util.folder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

-- Adds a name label above a part.
function Util.label(adornee: BasePart, text: string, offset: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(120, 24)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 60
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.4
	textLabel.Parent = gui
	gui.Parent = adornee
end

-- A tiny signal: `connect(fn)` and `fire(...)`.
export type Signal = {
	connect: (self: Signal, fn: (...any) -> ()) -> (),
	fire: (self: Signal, ...any) -> (),
}

function Util.signal(): Signal
	local listeners = {}
	local signal = {}
	function signal.connect(_self, fn)
		table.insert(listeners, fn)
	end
	function signal.fire(_self, ...)
		for _, fn in listeners do
			task.spawn(fn, ...)
		end
	end
	return signal :: any
end

-- Horizontal distance between two positions.
function Util.flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

return Util
