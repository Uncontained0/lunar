local Object = require("core").Object

local Node = {}

Node.EnumValue = Object:extend()

Node.EnumValue.meta.__eq = function(self, other)
	return self.EnumValueId ~= nil and self.EnumValueId == Other.EnumValueId
end

function Node.EnumValue:initialize(Identifier, Values)
	self.EnumValueId = Identifier

	for i, v in pairs(Values) do
		self[i] = v
	end
end

Node.Enum = Object:extend()

local Id = 0

function Node.Enum:initialize(Options)
	for _, v in pairs(Options) do
		Id = Id + 1

		self[v] = Node.EnumValue:new(Id, {})
	end
end

Node.Node = Object:extend()

return Node