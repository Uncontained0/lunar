local Object = require("core").Object

local Node = {}

Node.EnumValue = Object:extend()

local function EqualityCheck(self, other)
	return getmetatable(self).__id == getmetatable(other).__id
end

function Node.EnumValue:initialize(Identifier, Values)
	getmetatable(self).__eq = EqualityCheck
	getmetatable(self).__id = Identifier

	for i, v in pairs(Values) do
		self[i] = v
	end
end

Node.Enum = Object:extend()

local Id = 0

function Node.Enum:initialize(Options)
	for _, v in pairs(Options) do
		Id = Id + 1

		print(v, Id)

		local Value = setmetatable({}, {
			__eq = EqualityCheck,
			__id = Id,
			__call = function(t, Values)
				if getmetatable(Values) == nil then
					return Node.EnumValue:new(getmetatable(t).__id, Values)
				else
					return Node.EnumValue:new(getmetatable(t).__id, { Value = Values })
				end
			end
		})

		self[v] = Value
	end
end

Node.Node = Object:extend()

return Node