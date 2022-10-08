local Object = require("core").Object

local Node = Object:extend()

Node.NodeType = "None"

function Node:initialize(Values)
	self.NodeType = self.NodeType

	if Values == nil then
		return
	elseif getmetatable(Values) == nil then
		for i, v in pairs(Values) do
			self[i] = v
		end
	else
		self.Value = Values
	end
end

function Node.meta.__eq(self, other)
	return self.NodeType == other.NodeType
end

function Node.QuickExtend(NodeType)
	local NewNode = Node:extend()
	NewNode.NodeType = NodeType
	return NewNode
end

return Node