local Parser = require("Parsers/Parser")
local BaseNodes = require("Nodes/Base")
local UtilNodes = require("Nodes/Util")

local BIN_OPS = {
	"And",
	"Caret",
	"GreaterThan",
	"GreaterThanEquals",
	"LessThan",
	"LessThanEquals",
	"Minus",
	"Or",
	"Percent",
	"Plus",
	"Slash",
	"Star",
	"TildeEquals",
	"Concat",
	"EqualsEquals",
}

local UNARY_OPS = {
	"Minus",
	"Not",
	"Hash",
}

local BIN_OPS_PRECEDENCE = {
	Caret = 8,
	Star = 6,
	Slash = 6,
	Percent = 6,
	Plus = 5,
	Minus = 5,
	Concat = 4,
	LessThan = 3,
	LessThanEquals = 3,
	GreaterThan = 3,
	GreaterThanEquals = 3,
	EqualsEquals = 3,
	TildeEquals = 3,
	And = 2,
	Or = 1,
}

local Base = Parser:extend()

function Base:initialize(...)
	self.meta.super.initialize(self, ...)

	self.LoopStack = { {} }
	self.ReturnStack = { {} }
end

function Base:Parse()
	self.TokenList.Position = 1

	return self:Block().Statements
end

function Base:Block()
	local Statements = {}

	while true do
		local Statement = self:KeepGoing(self.Statement)

		if Statement then
			table.insert(Statements, Statement)
		else
			break
		end
	end

	local Return = self:KeepGoing(self.Return)
	if Return then
		if self:Next("Semicolon") then
			table.insert(Statements, BaseNodes.ReturnStatement:new({ Value = Return, Semicolon = self:Consume() }))
		else
			table.insert(Statements, BaseNodes.ReturnStatement:new(Return))
		end
	end

	local Break = self:KeepGoing(self.Break)
	if Break then
		if self:Next("Semicolon") then
			table.insert(Statements, BaseNodes.BreakStatement:new({ Value = Break, Semicolon = self:Consume() }))
		else
			table.insert(Statements, BaseNodes.BreakStatement:new(Break))
		end
	end

	return BaseNodes.Block:new({ Statements = Statements })
end

function Base:UnaryExpression()
	return BaseNodes.UnaryExpression:new({
		Operator = self:Symbol(unpack(UNARY_OPS)),
		Expression = self:Expression(7),
	})
end

function Base:ParenExpression()
	local LeftParen = self:Symbol("LeftParen")
	local Expression = self:Expression()
	local RightParen = self:Symbol("RightParen")

	return BaseNodes.ParenExpression:new({
		Parens = UtilNodes.Pair:new(LeftParen, RightParen),
		Expression = Expression,
	})
end

function Base:ValueExpression()
	return BaseNodes.ValueExpression:new(self:Value())
end

function Base:PartExpression()
	local UnaryExpression = self:KeepGoing(self.UnaryExpression)
	if UnaryExpression then
		return UnaryExpression
	end

	local ValueExpression = self:KeepGoing(self.ValueExpression)
	if ValueExpression then
		return ValueExpression
	end

	error("No match")
end

function Base:Expression(Precedence)
	Precedence = Precedence or 1
	local CurrentExpression = self:PartExpression()

	while true do
		local OldPosition = self.TokenList.Position
		local Operator = self:KeepGoing(self.Symbol, unpack(BIN_OPS))

		if Operator == nil then
			break
		end

		local OperatorPrecedence = BIN_OPS_PRECEDENCE[Operator.Token]

		if OperatorPrecedence < Precedence then
			self.TokenList.Position = OldPosition
			break
		end

		local NextPrecedence = Precedence - 1
		if Operator.Token == "Caret" or Operator.Token == "Concat" then
			NextPrecedence = Precedence
		end

		CurrentExpression = BaseNodes.BinaryExpression:new({
			Left = CurrentExpression,
			Operator = Operator,
			Right = self:Expression(NextPrecedence),
		})
	end

	return CurrentExpression
end

function Base:Field()
	if self:Next("LeftBracket") then
		local LeftBracket = self:Consume()
		local NameExpression = self:Expression()
		local RightBracket = self:Symbol("RightBracket")
		local Equals = self:Symbol("Equals")
		local Expression = self:Expression()

		return BaseNodes.BracketField:new({
			Brackets = UtilNodes.Pair:new(LeftBracket, RightBracket),
			NameExpression = NameExpression,
			Equals = Equals,
			Expression = Expression,
		})
	elseif self:Next("Identifier") then
		return BaseNodes.IdentifierField:new({
			Identifier = self:Consume(),
			Equals = self:Symbol("Equals"),
			Expression = self:Expression(),
		})
	end

	local Expression = self:KeepGoing(self.Expression)
	if Expression then
		return BaseNodes.NoKeyField:new(Expression)
	end

	error("No match")
end

function Base:Table()
	local LeftBrace = self:Symbol("LeftBrace")
	local Fields = UtilNodes.Punctuated:new()

	while true do
		local Field = self:KeepGoing(self.Field)
		if Field == nil then
			Fields.Active = false
			break
		end

		if self:Next("Comma", "Semicolon") then
			Fields:Push(Field, self:Consume())
		else
			Fields:End(Field)
			break
		end
	end

	return BaseNodes.Table:new({
		Braces = UtilNodes.Pair:new(LeftBrace, self:Symbol("RightBrace")),
		Fields = Fields,
	})
end

function Base:Index()
	if self:Next("LeftBracket") then
		local LeftBracket = self:Consume()
		local Expression = self:Expression()
		local RightBracket = self:Symbol("RightBracket")

		return BaseNodes.BracketIndex:new({
			Brackets = UtilNodes.Pair:new(LeftBracket, RightBracket),
			Expression = Expression,
		})
	elseif self:Next("Dot") then
		local Dot = self:Consume()
		local Identifier = self:Symbol("Identifier")

		return BaseNodes.DotIndex:new({
			Dot = Dot,
			Identifier = Identifier,
		})
	end

	error("No match")
end

function Base:Value()
	if self:Next("Nil", "True", "False", "Number", "String", "Ellipse") then
		return BaseNodes.TokenValue:new(self:Consume())
	end

	local Function = self:KeepGoing(self.Function)
	if Function then
		return BaseNodes.FunctionValue:new(Function)
	end

	local Table = self:KeepGoing(self.Table)
	if Table then
		return BaseNodes.TableValue:new(Table)
	end

	local FunctionCall = self:KeepGoing(self.FunctionCall)
	if FunctionCall then
		return BaseNodes.FunctionCallValue:new(FunctionCall)
	end

	local Var = self:KeepGoing(self.Var)
	if Var then
		return BaseNodes.VarValue:new(Var)
	end

	local ParenExpression = self:KeepGoing(self.ParenExpression)
	if ParenExpression then
		return BaseNodes.ParenValue:new(ParenExpression)
	end

	error("No match")
end

function Base:NumericFor()
	local For = self:Symbol("For")
	local Identifier = self:Symbol("Identifier")
	local Equals = self:Symbol("Equals")
	local StartExpression = self:Expression()
	local StartEndComma = self:Symbol("Comma")
	local EndExpression = self:Expression()
	local EndStepComma, StepExpression

	if self:Next("Comma") then
		EndStepComma = self:Consume()
		StepExpression = self:Expression()
	end

	local Do = self:Symbol("Do")
	table.insert(self.LoopStack, {})
	local Body = self:Block()
	local Breaks = table.remove(self.LoopStack)
	local End = self:Symbol("End")

	return BaseNodes.NumericFor:new({
		For = For,
		Identifier = Identifier,
		Equals = Equals,
		StartExpression = StartExpression,
		StartEndComma = StartEndComma,
		EndExpression = EndExpression,
		EndStepCommma = EndStepComma,
		StepExpression = StepExpression,
		Do = Do,
		Body = Body,
		Breaks = Breaks,
		End = End,
	})
end

function Base:GenericFor()
	local For = self:Symbol("For")
	local Identifiers = UtilNodes.Punctuated:new()

	while true do
		local Identifier = self:Symbol("Identifier")

		if self:Next("Comma") then
			Identifiers:Push(Identifier, self:Consume())
		else
			Identifiers:End(Identifier)
			break
		end
	end

	local In = self:Symbol("In")
	local Expressions = UtilNodes.Punctuated:new()

	while true do
		local Expression = self:Expression()

		if self:Next("Comma") then
			Expressions:Push(Expression, self:Consume())
		else
			Expressions:End(Expression)
			break
		end
	end

	local Do = self:Symbol("Do")
	table.insert(self.LoopStack, {})
	local Body = self:Block()
	local Breaks = table.remove(self.LoopStack)
	local End = self:Symbol("End")

	return BaseNodes.GenericFor:new({
		For = For,
		Identifiers = Identifiers,
		In = In,
		Expressions = Expressions,
		Do = Do,
		Body = Body,
		Breaks = Breaks,
		End = End,
	})
end

function Base:If()
	local If = self:Symbol("If")
	local Condition = self:Expression()
	local Then = self:Symbol("Then")
	local IfBody = self:Block()
	local ElseIfs = {}

	while self:Next("ElseIf") do
		local ElseIf = self:Consume()
		local ElseIfCondition = self:Expression()
		local ElseIfThen = self:Symbol("Then")
		local ElseIfBody = self:Block()

		ElseIfs[#ElseIfs + 1] = BaseNodes.ElseIf:new({
			ElseIf = ElseIf,
			Condition = ElseIfCondition,
			Then = ElseIfThen,
			Body = ElseIfBody,
		})
	end

	local Else, ElseBody

	if self:Next("Else") then
		Else = self:Consume()
		ElseBody = self:Block()
	end

	local End = self:Symbol("End")

	return BaseNodes.If:new({
		If = If,
		Condition = Condition,
		Then = Then,
		Body = IfBody,
		ElseIfs = ElseIfs,
		Else = Else,
		ElseBody = ElseBody,
		End = End,
	})
end

function Base:Break()
	local BreakNode = BaseNodes.Break:new({
		Break = self:Symbol("Break"),
	})

	table.insert(self.LoopStack[#self.LoopStack], BreakNode)

	return BreakNode
end

function Base:While()
	local While = self:Symbol("While")
	local Condition = self:Expression()
	local Do = self:Symbol("Do")
	table.insert(self.LoopStack, {})
	local Body = self:Block()
	local Breaks = table.remove(self.LoopStack)
	local End = self:Symbol("End")

	return BaseNodes.While:new({
		While = While,
		Condition = Condition,
		Do = Do,
		Body = Body,
		Breaks = Breaks,
		End = End,
	})
end

function Base:Repeat()
	local Repeat = self:Symbol("Repeat")
	table.insert(self.LoopStack, {})
	local Body = self:Block()
	local Breaks = table.remove(self.LoopStack)
	local Until = self:Symbol("Until")
	local Condition = self:Expression()

	return BaseNodes.Repeat:new({
		Repeat = Repeat,
		Body = Body,
		Breaks = Breaks,
		Until = Until,
		Condition = Condition,
	})
end

function Base:Return()
	local Return = self:Symbol("Return")
	local Expressions = UtilNodes.Punctuated:new()

	while true do
		local Expression = self:Expression()

		if self:Next("Comma") then
			Expressions:Push(Expression, self:Consume())
		else
			Expressions:End(Expression)
			break
		end
	end

	local ReturnNode = BaseNodes.Return:new({
		Return = Return,
		Expressions = Expressions,
	})

	table.insert(self.ReturnStack[#self.ReturnStack], ReturnNode)

	return ReturnNode
end

function Base:FunctionArgs()
	if self:Next("LeftParen") then
		local LeftParen = self:Consume()
		local Arguments = UtilNodes.Punctuated:new()

		while true do
			local Argument = self:KeepGoing(self.Expression)
			if Argument == nil then
				break
			end

			if self:Next("Comma") then
				Arguments:Push(Argument, self:Consume())
			else
				Arguments:End(Argument)
				break
			end
		end

		local RightParen = self:Symbol("RightParen")

		return BaseNodes.ParenFunctionArgs:new({
			Arguments = Arguments,
			Parens = UtilNodes.Pair:new(LeftParen, RightParen),
		})
	elseif self:Next("String") then
		return BaseNodes.StringFunctionArgs:new(self:Consume())
	end

	local Table = self:KeepGoing(self.Table)
	if Table then
		return BaseNodes.TableFunctionArgs:new(Table)
	end

	error("No match")
end

function Base:MethodCall()
	local Colon = self:Symbol("Colon")
	local Name = self:Symbol("Identifier")
	local Args = self:FunctionArgs()

	return BaseNodes.MethodCall:new({
		Colon = Colon,
		Name = Name,
		Args = Args,
	})
end

function Base:Call()
	local FunctionArgs = self:KeepGoing(self.FunctionArgs)
	if FunctionArgs then
		return BaseNodes.FunctionArgsCall:new(FunctionArgs)
	end

	local MethodCall = self:KeepGoing(self.MethodCall)
	if MethodCall then
		return BaseNodes.MethodCallCall:new(MethodCall)
	end

	error("No match")
end

function Base:Prefix()
	local ParenExpression = self:KeepGoing(self.ParenExpression)
	if ParenExpression then
		return BaseNodes.ParenPrefix:new(ParenExpression)
	end

	if self:Next("Identifier") then
		return BaseNodes.IdentifierPrefix:new(self:Consume())
	end

	error("No match")
end

function Base:Suffix()
	local Call = self:KeepGoing(self.Call)
	if Call then
		return BaseNodes.CallSuffix:new(Call)
	end

	local Index = self:KeepGoing(self.Index)
	if Index then
		return BaseNodes.IndexSuffix:new(Index)
	end

	error("No match")
end

function Base:FunctionBody()
	local LeftParen = self:Symbol("LeftParen")
	local Arguments = UtilNodes.Punctuated:new()

	while self:Next("Identifier", "Ellipse") do
		local Argument = self:Consume()

		if self:Next("Comma") then
			Arguments:Push(Argument, self:Consume())
		else
			Arguments:End(Argument)
			break
		end
	end

	local RightParen = self:Symbol("RightParen")
	table.insert(self.ReturnStack, {})
	local Body = self:Block()
	local Returns = table.remove(self.ReturnStack)
	local End = self:Symbol("End")

	return BaseNodes.FunctionBody:new({
		Arguments = Arguments,
		Body = Body,
		Returns = Returns,
		End = End,
		Parens = UtilNodes.Pair:new(LeftParen, RightParen),
	})
end

function Base:Function()
	local Function = self:Symbol("Function")
	local Body = self:FunctionBody()

	return {
		Function = Function,
		Body = Body,
	}
end

function Base:LocalFunction()
	local Local = self:Symbol("Local")
	local Function = self:Symbol("Function")
	local Identifier = self:Symbol("Identifier")
	local FunctionBody = self:FunctionBody()

	return BaseNodes.LocalFunction:new({
		Local = Local,
		Function = Function,
		Name = Identifier,
		Body = FunctionBody,
	})
end

function Base:FunctionName()
	local Identifiers = UtilNodes.Punctuated:new()

	while true do
		local Identifier = self:Symbol("Identifier")

		if self:Next("Dot") then
			Identifiers:Push(Identifier, self:Consume())
		else
			Identifiers:End(Identifier)
			break
		end
	end

	if self:Next("Colon") then
		local Colon = self:Consume()
		local Method = self:Symbol("Identifier")

		return BaseNodes.FunctionName:new({
			Names = Identifiers,
			Colon = Colon,
			Method = Method,
		})
	end

	return BaseNodes.FunctionName:new({
		Names = Identifiers,
	})
end

function Base:FunctionDeclaration()
	local Function = self:Symbol("Function")
	local FunctionName = self:FunctionName()
	local FunctionBody = self:FunctionBody()

	return BaseNodes.FunctionDeclaration:new({
		Function = Function,
		Name = FunctionName,
		Body = FunctionBody,
	})
end

function Base:FunctionCall()
	local Prefix = self:Prefix()
	local Suffixes = {}

	while true do
		local Suffix = self:KeepGoing(self.Suffix)
		if Suffix then
			table.insert(Suffixes, Suffix)
		else
			break
		end
	end

	assert(Suffixes[#Suffixes] == BaseNodes.CallSuffix, "No match")

	return BaseNodes.FunctionCall:new({
		Prefix = Prefix,
		Suffixes = Suffixes,
	})
end

function Base:VarExpression()
	local Prefix = self:Prefix()
	local Suffixes = {}

	while true do
		local Suffix = self:KeepGoing(self.Suffix)

		if Suffix then
			table.insert(Suffixes, Suffix)
		else
			break
		end
	end

	assert(BaseNodes.IndexSuffix == Suffixes[#Suffixes], "No match")

	return BaseNodes.VarExpression:new({
		Prefix = Prefix,
		Suffixes = Suffixes,
	})
end

function Base:Var()
	local VarExpression = self:KeepGoing(self.VarExpression)
	if VarExpression then
		return BaseNodes.VarExpressionVar:new(VarExpression)
	end

	if self:Next("Identifier") then
		return BaseNodes.IdentifierVar:new(self:Consume())
	end

	error("No match")
end

function Base:Assignment()
	local Vars = UtilNodes.Punctuated:new()

	while true do
		local Var = self:Var()

		if self:Next("Comma") then
			Vars:Push(Var, self:Consume())
		else
			Vars:End(Var)
			break
		end
	end

	local Equals = self:Symbol("Equals")
	local Expressions = UtilNodes.Punctuated:new()

	while true do
		local Expression = self:Expression()

		if self:Next("Comma") then
			Expressions:Push(Expression, self:Consume())
		else
			Expressions:End(Expression)
			break
		end
	end

	return BaseNodes.Assignment:new({
		Vars = Vars,
		Equals = Equals,
		Expressions = Expressions,
	})
end

function Base:LocalAssignment()
	local Local = self:Symbol("Local")
	local Vars = UtilNodes.Punctuated:new()

	while true do
		local Var = self:Var()

		if self:Next("Comma") then
			Vars:Push(Var, self:Consume())
		else
			Vars:End(Var)
			break
		end
	end

	if self:Next("Equals") then
		local Equals = self:Consume()
		local Expressions = UtilNodes.Punctuated:new()

		while true do
			local Expression = self:Expression()

			if self:Next("Comma") then
				Expressions:Push(Expression, self:Consume())
			else
				Expressions:End(Expression)
				break
			end
		end

		return BaseNodes.LocalAssignment:new({
			Local = Local,
			Vars = Vars,
			Equals = Equals,
			Expressions = Expressions,
		})
	else
		return BaseNodes.LocalAssignment:new({
			Local = Local,
			Vars = Vars,
		})
	end
end

function Base:Do()
	local Do = self:Symbol("Do")
	local Body = self:Block()
	local End = self:Symbol("End")

	return BaseNodes.Do:new({
		Do = Do,
		Body = Body,
		End = End,
	})
end

function Base:Statement()
	local Assignment = self:KeepGoing(self.Assignment)
	if Assignment then
		if self:Next("Semicolon") then
			return BaseNodes.AssignmentStatement:new({ Value = Assignment, Semicolon = self:Consume() })
		else
			return BaseNodes.AssignmentStatement:new(Assignment)
		end
	end

	local Do = self:KeepGoing(self.Do)
	if Do then
		if self:Next("Semicolon") then
			return BaseNodes.DoStatement:new({ Value = Do, Semicolon = self:Consume() })
		else
			return BaseNodes.DoStatement:new(Do)
		end
	end

	local FunctionCall = self:KeepGoing(self.FunctionCall)
	if FunctionCall then
		if self:Next("Semicolon") then
			return BaseNodes.FunctionCallStatement:new({ Value = FunctionCall, Semicolon = self:Consume() })
		else
			return BaseNodes.FunctionCallStatement:new(FunctionCall)
		end
	end

	local FunctionDeclaration = self:KeepGoing(self.FunctionDeclaration)
	if FunctionDeclaration then
		if self:Next("Semicolon") then
			return BaseNodes.FunctionDeclarationStatement:new({ Value = FunctionDeclaration, Semicolon = self:Consume() })
		else
			return BaseNodes.FunctionDeclarationStatement:new(FunctionDeclaration)
		end
	end

	local GenericFor = self:KeepGoing(self.GenericFor)
	if GenericFor then
		if self:Next("Semicolon") then
			return BaseNodes.GenericForStatement:new({ Value = GenericFor, Semicolon = self:Consume() })
		else
			return BaseNodes.GenericForStatement:new(GenericFor)
		end
	end

	local If = self:KeepGoing(self.If)
	if If then
		if self:Next("Semicolon") then
			return BaseNodes.IfStatement:new({ Value = If, Semicolon = self:Consume() })
		else
			return BaseNodes.IfStatement:new(If)
		end
	end

	local LocalAssignment = self:KeepGoing(self.LocalAssignment)
	if LocalAssignment then
		if self:Next("Semicolon") then
			return BaseNodes.LocalAssignmentStatement:new({ Value = LocalAssignment, Semicolon = self:Consume() })
		else
			return BaseNodes.LocalAssignmentStatement:new(LocalAssignment)
		end
	end

	local LocalFunction = self:KeepGoing(self.LocalFunction)
	if LocalFunction then
		if self:Next("Semicolon") then
			return BaseNodes.LocalFunctionStatement:new({ Value = LocalFunction, Semicolon = self:Consume() })
		else
			return BaseNodes.LocalFunctionStatement:new(LocalFunction)
		end
	end

	local NumericFor = self:KeepGoing(self.NumericFor)
	if NumericFor then
		if self:Next("Semicolon") then
			return BaseNodes.NumericForStatement:new({ Value = NumericFor, Semicolon = self:Consume() })
		else
			return BaseNodes.NumericForStatement:new(NumericFor)
		end
	end

	local Repeat = self:KeepGoing(self.Repeat)
	if Repeat then
		if self:Next("Semicolon") then
			return BaseNodes.RepeatStatement:new({ Value = Repeat, Semicolon = self:Consume() })
		else
			return BaseNodes.RepeatStatement:new(Repeat)
		end
	end

	local While = self:KeepGoing(self.While)
	if While then
		if self:Next("Semicolon") then
			return BaseNodes.WhileStatement:new({ Value = While, Semicolon = self:Consume() })
		else
			return BaseNodes.WhileStatement:new(While)
		end
	end

	error(
		"No match "
			.. self.TokenList:Peek().Token
			.. " "
			.. self.TokenList:Peek().Location
			.. " '"
			.. string.sub(self.TokenList.Source, self.TokenList:Peek().Start, self.TokenList:Peek().Start + 25)
			.. "'"
	)
end

return Base
