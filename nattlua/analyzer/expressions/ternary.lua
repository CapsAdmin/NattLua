local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any

local function AnalyzeTernary(self, node)
	-- Analyze condition
	local condition = self:Assert(self:AnalyzeExpression(node.condition))

	-- Track union for condition (if it's a union, narrow based on truthy/falsy)
	if condition.Type == "union" then
		self:TrackUpvalueUnion(condition, condition:GetTruthy(), condition:GetFalsy())
	end

	-- Handle constant conditions
	if condition:IsCertainlyTrue() then
		-- Condition is always true, result is then-expression
		self:PushTruthyExpressionContext()
		local then_expr = self:Assert(self:AnalyzeExpression(node.then_expr))
		self:PopTruthyExpressionContext()

		if then_expr.Type == "union" then
			self:TrackUpvalueUnion(then_expr, then_expr:GetTruthy(), then_expr:GetFalsy())
		end

		return then_expr
	elseif condition:IsCertainlyFalse() then
		-- Condition is always false, result is else-expression
		self:PushFalsyExpressionContext()
		local else_expr = self:Assert(self:AnalyzeExpression(node.else_expr))
		self:PopFalsyExpressionContext()

		if else_expr.Type == "union" then
			self:TrackUpvalueUnion(else_expr, else_expr:GetTruthy(), else_expr:GetFalsy())
		end

		return else_expr
	end

	-- Analyze then-expression (truthy branch)
	self:PushTruthyExpressionContext()
	local then_expr = self:Assert(self:AnalyzeExpression(node.then_expr))
	self:PopTruthyExpressionContext()

	-- Track union for then-expression
	if then_expr.Type == "union" then
		self:TrackUpvalueUnion(then_expr, then_expr:GetTruthy(), then_expr:GetFalsy())
	end

	-- Analyze else-expression (falsy branch)
	self:PushFalsyExpressionContext()
	local else_expr = self:Assert(self:AnalyzeExpression(node.else_expr))
	self:PopFalsyExpressionContext()

	-- Track union for else-expression
	if else_expr.Type == "union" then
		self:TrackUpvalueUnion(else_expr, else_expr:GetTruthy(), else_expr:GetFalsy())
	end

	-- The result type is the union of both branches
	-- This correctly handles the case where then_expr is false/nil
	local result = Union({then_expr, else_expr}):Simplify()
	return result
end

return {
	AnalyzeTernary = AnalyzeTernary,
}
