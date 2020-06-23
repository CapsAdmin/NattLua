local Scale = {} as {
	scale = number,
}

function Scale:SetScale(scale: number)
	self.scale = scale
end

function Scale:GetScale(): number
	return self.scale
end


local Alpha = {} as {
	alpha = number,
}

function Alpha:SetHidden()
	self.alpha = 0
end

function Alpha:SetVisible()
	self.alpha = 1
end

function Alpha:SetAlpha(alpha: number)
	self.alpha = alpha
end

local Sprite = {} as {
	name = string,
	x = number,
	y = number,
}

local type MergeTables = function(bases)
	local merged = types.Dictionary:new()

	for _, base in bases:pairs() do
		for k, v in base:pairs() do
			merged:Set(k, v)
		end
	end

	merged:Set("__index", merged)

	return merged
end

--[[
	{
		[1 .. inf] = {
			[string] = any
		}
	}
]]
local function new(bases: {[1 .. inf] = {[string] = any}}): MergeTables(bases)
	local meta = {}
	
	for _, base in ipairs(bases) do
		for k, v in pairs(base) do
			meta[k] = v
		end
	end

	meta.__index = meta

	return setmetatable({}, meta)
end

local obj = new({Scale, Alpha, Sprite})

obj:SetScale(2)
print(obj:GetScale())


function test(list: {[1 .. inf] = number})
	return list
end

test({1,2,3})