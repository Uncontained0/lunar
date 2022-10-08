local Generator = require("Generators/Generator")
local BaseNodes = require("Nodes/Base")

local Base = Generator:extend()

function Base:Generate()
	local Output = ""

	while self:Peek() do
		Output = Output .. self:Statement(self:Next())
	end

	return Output
end

function Base:Token(Token)
	local Output = ""

	for _, v in ipairs(Token.LeadingTrivia) do
		Output = Output .. v.Value
	end

	Output = Output .. Token.Value

	for _, v in ipairs(Token.TrailingTrivia) do
		Output = Output .. v.Value
	end

	return Output
end

function Base:Block(Block)
	local Output = ""

	for _, v in ipairs(Block.Statements) do
		Output = Output .. self:Statement(v)
	end

	return Output
end

function Base:UnaryExpression(Expression)
	return self:Token(Expression.Operator) .. self:Expression(Expression.Expression)
end

function Base:ParenExpression(Expression)
	return self:Token(Expression.Parens.Left) .. self:Expression(Expression.Expression) .. self:Token(Expression.Parens.Right)
end

function Base:ValueExpression(Expression)
	return self:Value(Expression.Value)
end

function Base:BinaryExpression(Expression)
	return self:Expression(Expression.Left) .. self:Token(Expression.Operator) .. self:Expression(Expression.Right)
end

function Base:Expression(Expression)
	if Expression == BaseNodes.UnaryExpression then
		return self:UnaryExpression(Expression)
	elseif Expression == BaseNodes.ParenExpression then
		return self:ParenExpression(Expression)
	elseif Expression == BaseNodes.ValueExpression then
		return self:ValueExpression(Expression)
	elseif Expression == BaseNodes.BinaryExpression then
		return self:BinaryExpression(Expression)
	end

	error("No match")
end

function Base:Field(Field)
	if Field == BaseNodes.BracketField then
		return self:Token(Field.Brackets.Left)
			.. self:Expression(Field.NameExpression)
			.. self:Token(Field.Brackets.Right)
			.. self:Token(Field.Equals)
			.. self:Expression(Field.Expression)
	elseif Field == BaseNodes.IdentifierField then
		return self:Token(Field.Identifier) .. self:Token(Field.Equals) .. self:Expression(Field.Expression)
	elseif Field == BaseNodes.NoKeyField then
		return self:Expression(Field.Value)
	end

	error("No match")
end

function Base:Table(Table)
	local Output = self:Token(Table.Braces.Left)

	for _, v in ipairs(Table.Fields.Items) do
		Output = Output .. self:Field(v.Item)

		if v.Separator then
			Output = Output .. self:Token(v.Separator)
		end
	end

	return Output .. self:Token(Table.Braces.Right)
end

function Base:Index(Index)
	if Index == BaseNodes.BracketIndex then
		return self:Token(Index.Brackets.Left)
			.. self:Expression(Index.Expression)
			.. self:Token(Index.Brackets.Right)
	elseif Index == BaseNodes.DotIndex then
		return self:Token(Index.Dot) .. self:Token(Index.Identifier)
	end

	error("No match")
end

function Base:Value(Value)
	if Value == BaseNodes.TokenValue then
		return self:Token(Value.Value)
	elseif Value == BaseNodes.FunctionValue then
		return self:Function(Value.Value)
	elseif Value == BaseNodes.TableValue then
		return self:Table(Value.Value)
	elseif Value == BaseNodes.FunctionCallValue then
		return self:FunctionCall(Value.Value)
	elseif Value == BaseNodes.VarValue then
		return self:Var(Value.Value)
	elseif Value == BaseNodes.ParenValue then
		return self:ParenExpression(Value.Value)
	end

	error("No match")
end

function Base:NumericFor(For)
	local Output = self:Token(For.For)
		.. self:Token(For.Identifier)
		.. self:Token(For.Equals)
		.. self:Expression(For.StartExpression)
		.. self:Token(For.StartEndComma)
		.. self:Expression(For.EndExpression)
	
	if For.EndStepComma then
		Output = Output .. self:Token(For.EndStepComma) .. self:Expression(For.StepExpression)
	end

	return Output .. self:Token(For.Do) .. self:Block(For.Body) .. self:Token(For.End)
end

function Base:GenericFor(For)
	local Output = self:Token(For.For)

	for _, v in ipairs(For.Identifiers.Items) do
		Output = Output .. self:Token(v.Item)

		if v.Separator then
			Output = Output .. self:Token(v.Separator)
		end
	end

	Output = Output .. self:Token(For.In)

	for _, v in ipairs(For.Expressions.Items) do
		Output = Output .. self:Expression(v.Item)

		if v.Separator then
			Output = Output .. self:Token(v.Separator)
		end
	end

	return Output .. self:Token(For.Do) .. self:Block(For.Body) .. self:Token(For.End)
end

function Base:If(If)
	local Output = self:Token(If.If)
		.. self:Expression(If.Condition)
		.. self:Token(If.Then)
		.. self:Block(If.Body)
	
	for _, v in ipairs(If.ElseIfs) do
		Output = Output
			.. self:Token(v.ElseIf)
			.. self:Expression(v.Condition)
			.. self:Token(v.Then)
			.. self:Block(v.Body)
	end

	if If.Else then
		Output = Output .. self:Token(If.Else) .. self:Block(If.ElseBody)
	end

	return Output .. self:Token(If.End)
end

function Base:Break(Break)
	return self:Token(Break.Break)
end

function Base:While(While)
	return self:Token(While.While)
		.. self:Expression(While.Condition)
		.. self:Token(While.Do)
		.. self:Block(While.Body)
		.. self:Token(While.End)
end

function Base:Repeat(Repeat)
	return self:Token(Repeat.Repeat)
		.. self:Block(Repeat.Body)
		.. self:Token(Repeat.Until)
		.. self:Expression(Repeat.Condition)
end

function Base:Return(Return)
	local Output = self:Token(Return.Return)
	
	for _, v in ipairs(Return.Expressions.Items) do
		Output = Output .. self:Expression(v.Item)

		if v.Separator then
			Output = Output .. self:Token(v.Separator)
		end
	end

	return Output
end

function Base:FunctionArgs(FunctionArgs)
	if FunctionArgs == BaseNodes.ParenFunctionArgs then
		local Output = self:Token(FunctionArgs.Parens.Left)

		for _, v in ipairs(FunctionArgs.Arguments.Items) do
			Output = Output .. self:Expression(v.Item)

			if v.Separator then
				Output = Output .. self:Token(v.Separator)
			end
		end

		return Output .. self:Token(FunctionArgs.Parens.Right)
	elseif FunctionArgs == BaseNodes.StringFunctionArgs then
		return self:Token(FunctionArgs.Value)
	elseif FunctionArgs == BaseNodes.TableFunctionArgs then
		return self:Table(FunctionArgs.Value)
	end

	error("No match")
end

function Base:MethodCall(MethodCall)
	return self:Token(MethodCall.Colon)
		.. self:Token(MethodCall.Name)
		.. self:FunctionArgs(MethodCall.Args)
end

function Base:Call(Call)
	if Call == BaseNodes.FunctionArgsCall then
		return self:FunctionArgs(Call.Value)
	elseif Call == BaseNodes.MethodCallCall then
		return self:MethodCall(Call.Value)
	end

	error("No match")
end

function Base:Prefix(Prefix)
	if Prefix == BaseNodes.ParenPrefix then
		return self:ParenExpression(Prefix.Value)
	elseif Prefix == BaseNodes.IdentifierPrefix then
		return self:Token(Prefix.Value)
	end

	error("No match")
end

function Base:Suffix(Suffix)
	if Suffix == BaseNodes.CallSuffix then
		return self:Call(Suffix.Value)
	elseif Suffix == BaseNodes.IndexSuffix then
		return self:Index(Suffix.Value)
	end

	error("No match")
end

function Base:FunctionBody(FunctionBody)
	local Output = self:Token(FunctionBody.Parens.Left)

	for _, v in ipairs(FunctionBody.Arguments.Items) do
		Output = Output .. self:Token(v.Item)

		if v.Separator then
			Output = Output .. self:Token(v.Separator)
		end
	end

	return Output
		.. self:Token(FunctionBody.Parens.Right)
		.. self:Block(FunctionBody.Body)
		.. self:Token(FunctionBody.End)
end

function Base:LocalFunction(LocalFunction)
	return self:Token(LocalFunction.Local)
		.. self:Token(LocalFunction.Function)
		.. self:Token(LocalFunction.Name)
		.. self:FunctionBody(LocalFunction.Body)
end

function Base:FunctionName(FunctionName)
	local Output = ""

	for _, v in ipairs(FunctionName.Names.Items) do
		Output = Output .. self:Token(v.Item)

		if v.Separator then
			Output = Output .. self:Token(v.Separator)
		end
	end

	if FunctionName.Colon then
		Output = Output
			.. self:Token(FunctionName.Colon)
			.. self:Token(FunctionName.Method)
	end

	return Output
end

function Base:FunctionDeclaration(FunctionDeclaration)
	return self:Token(FunctionDeclaration.Function)
		.. self:FunctionName(FunctionDeclaration.Name)
		.. self:FunctionBody(FunctionDeclaration.Body)
end

function Base:FunctionCall(FunctionCall)
	local Output = self:Prefix(FunctionCall.Prefix)

	for _, v in ipairs(FunctionCall.Suffixes) do
		Output = Output .. self:Suffix(v)
	end

	return Output
end

function Base:VarExpression(VarExpression)
	return self:FunctionCall(VarExpression)
end

function Base:Var(Var)
	if Var == BaseNodes.VarExpressionVar then
		return self:VarExpression(Var.Value)
	elseif Var == BaseNodes.IdentifierVar then
		return self:Token(Var.Value)
	end

	error("No match")
end

function Base:Assignment(Assignment)
	local Output = ""

	for _, v in ipairs(Assignment.Vars.Items) do
		Output = Output .. self:Var(v.Item)

		if v.Separator then
			Output = Output .. self:Token(v.Separator)
		end
	end

	Output = Output .. self:Token(Assignment.Equals)

	for _, v in ipairs(Assignment.Expressions.Items) do
		Output = Output .. self:Expression(v.Item)

		if v.Separator then
			Output = Output .. self:Token(v.Separator)
		end
	end

	return Output
end

function Base:LocalAssignment(LocalAssignment)
	local Output = self:Token(LocalAssignment.Local)

	for _, v in ipairs(LocalAssignment.Vars.Items) do
		Output = Output .. self:Var(v.Item)

		if v.Separator then
			Output = Output .. self:Token(v.Separator)
		end
	end

	if LocalAssignment.Equals then
		Output = Output .. self:Token(LocalAssignment.Equals)

		for _, v in ipairs(LocalAssignment.Expressions.Items) do
			Output = Output .. self:Expression(v.Item)

			if v.Separator then
				Output = Output .. self:Token(v.Separator)
			end
		end
	end

	return Output
end

function Base:Do(Do)
	return self:Token(Do.Do) .. self:Block(Do.Body) .. self:Token(Do.End)
end

function Base:Statement(Statement)
	local Output

	if Statement == BaseNodes.AssignmentStatement then
		Output = self:Assignment(Statement.Value)
	elseif Statement == BaseNodes.DoStatement then
		Output = self:Do(Statement.Value)
	elseif Statement == BaseNodes.FunctionCallStatement then
		Output = self:FunctionCall(Statement.Value)
	elseif Statement == BaseNodes.FunctionDeclarationStatement then
		Output = self:FunctionDeclaration(Statement.Value)
	elseif Statement == BaseNodes.GenericForStatement then
		Output = self:GenericFor(Statement.Value)
	elseif Statement == BaseNodes.IfStatement then
		Output = self:If(Statement.Value)
	elseif Statement == BaseNodes.LocalAssignmentStatement then
		Output = self:LocalAssignment(Statement.Value)
	elseif Statement == BaseNodes.LocalFunctionStatement then
		Output = self:LocalFunction(Statement.Value)
	elseif Statement == BaseNodes.NumericForStatement then
		Output = self:NumericFor(Statement.Value)
	elseif Statement == BaseNodes.RepeatStatement then
		Output = self:Repeat(Statement.Value)
	elseif Statement == BaseNodes.WhileStatement then
		Output = self:While(Statement.Value)
	elseif Statement == BaseNodes.ReturnStatement then
		Output = self:Return(Statement.Value)
	elseif Statement == BaseNodes.BreakStatement then
		Output = self:Break(Statement.Value)
	end

	assert(Output, "No match")

	if Statement.Semicolon then
		Output = Output .. self:Token(Statement.Semicolon)
	end

	return Output
end

return Base