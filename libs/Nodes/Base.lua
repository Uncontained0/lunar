local Node = require("Nodes/Node")

return {
	Block = Node.QuickExtend("Block"),

	UnaryExpression = Node.QuickExtend("UnaryExpression"),
	ParenExpression = Node.QuickExtend("ParenExpression"),
	ValueExpression = Node.QuickExtend("ValueExpression"),
	BinaryExpression = Node.QuickExtend("BinaryExpression"),

	TokenValue = Node.QuickExtend("TokenValue"),
	FunctionValue = Node.QuickExtend("FunctionValue"),
	TableValue = Node.QuickExtend("TableValue"),
	FunctionCallValue = Node.QuickExtend("FunctionCallValue"),
	VarValue = Node.QuickExtend("VarValue"),
	ParenValue = Node.QuickExtend("ParenValue"),

	BracketField = Node.QuickExtend("BracketField"),
	IdentifierField = Node.QuickExtend("IdentifierField"),
	NoKeyField = Node.QuickExtend("NoKeyField"),

	Table = Node.QuickExtend("Table"),

	BracketIndex = Node.QuickExtend("BracketIndex"),
	DotIndex = Node.QuickExtend("DotIndex"),

	NumericFor = Node.QuickExtend("NumericFor"),
	GenericFor = Node.QuickExtend("GenericFor"),

	If = Node.QuickExtend("If"),
	ElseIf = Node.QuickExtend("ElseIf"),

	Break = Node.QuickExtend("Break"),
	Return = Node.QuickExtend("Return"),

	While = Node.QuickExtend("While"),
	Repeat = Node.QuickExtend("Repeat"),

	ParenFunctionArgs = Node.QuickExtend("ParenFunctionArgs"),
	StringFunctionArgs = Node.QuickExtend("StringFunctionArgs"),
	TableFunctionArgs = Node.QuickExtend("TableFunctionArgs"),

	MethodCall = Node.QuickExtend("MethodCall"),

	FunctionArgsCall = Node.QuickExtend("FunctionArgsCall"),
	MethodCallCall = Node.QuickExtend("MethodCallCall"),

	ParenPrefix = Node.QuickExtend("ParenPrefix"),
	IdentifierPrefix = Node.QuickExtend("IdentifierPrefix"),

	CallSuffix = Node.QuickExtend("CallSuffix"),
	IndexSuffix = Node.QuickExtend("IndexSuffix"),

	FunctionBody = Node.QuickExtend("FunctionBody"),
	LocalFunction = Node.QuickExtend("LocalFunction"),
	FunctionName = Node.QuickExtend("FunctionName"),
	FunctionDeclaration = Node.QuickExtend("FunctionDeclaration"),
	FunctionCall = Node.QuickExtend("FunctionCall"),

	VarExpression = Node.QuickExtend("VarExpression"),

	VarExpressionVar = Node.QuickExtend("VarExpressionVar"),
	IdentifierVar = Node.QuickExtend("IdentifierVar"),

	Assignment = Node.QuickExtend("Assignment"),
	LocalAssignment = Node.QuickExtend("LocalAssignment"),

	Do = Node.QuickExtend("Do"),

	AssignmentStatement = Node.QuickExtend("AssignmentStatement"),
	DoStatement = Node.QuickExtend("DoStatement"),
	FunctionCallStatement = Node.QuickExtend("FunctionCallStatement"),
	FunctionDeclarationStatement = Node.QuickExtend("FunctionDeclarationStatement"),
	GenericForStatement = Node.QuickExtend("GenericForStatement"),
	IfStatement = Node.QuickExtend("IfStatement"),
	LocalAssignmentStatement = Node.QuickExtend("LocalAssignmentStatement"),
	LocalFunctionStatement = Node.QuickExtend("LocalFunctionStatement"),
	NumericForStatement = Node.QuickExtend("NumericForStatement"),
	RepeatStatement = Node.QuickExtend("RepeatStatement"),
	WhileStatement = Node.QuickExtend("WhileStatement"),
	ReturnStatement = Node.QuickExtend("ReturnStatement"),
	BreakStatement = Node.QuickExtend("BreakStatement"),
}
