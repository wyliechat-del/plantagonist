--[[
	Small helpers for building the HUD in code.
]]

local Ui = {}

function Ui.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local item = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(item :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = item
	end
	item.Parent = props.Parent
	return item
end

function Ui.corner(radius: UDim?): UICorner
	return Ui.make("UICorner", { CornerRadius = radius or UDim.new(0.5, 0) })
end

function Ui.stroke(colour: Color3, thickness: number): UIStroke
	return Ui.make("UIStroke", { Color = colour, Thickness = thickness })
end

function Ui.colour(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

return Ui
