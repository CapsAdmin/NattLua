local Union = require("nattlua.types.union").Union
local Nil = require("nattlua.types.symbol").Nil
local Any = require("nattlua.types.any").Any

local function AnalyzeTernary(self, node)
	-- Analyze condition
	local condition = self:Assert(self:AnalyzeExpression(node.condition))

	-- Track union for condition (if it's a union, narrow based on truthy/falsy)
	if condition.Type == "union" then
		self.narrowing_store:TrackUpvalueUnion(condition, condition:GetTruthy(), condition:GetFalsy(), nil, self)
	end

	-- Handle constant conditions
	if condition:IsCertainlyTrue() then
		-- Condition is always true, result is then-expression
		self.narrowing_store:PushTruthyExpressionContext()
		local then_expr = self:Assert(self:AnalyzeExpression(node.then_expr))
		self.narrowing_store:PopTruthyExpressionContext()

		if then_expr.Type == "union" then
			self.narrowing_store:TrackUpvalueUnion(then_expr, then_expr:GetTruthy(), then_expr:GetFalsy(), nil, self)
		end

		return then_expr
	elseif condition:IsCertainlyFalse() then
		-- Condition is always false, result is else-expression
		self.narrowing_store:PushFalsyExpressionContext()
		local else_expr = self:Assert(self:AnalyzeExpression(node.else_expr))
		self.narrowing_store:PopFalsyExpressionContext()

		if else_expr.Type == "union" then
			self.narrowing_store:TrackUpvalueUnion(else_expr, else_expr:GetTruthy(), else_expr:GetFalsy(), nil, self)
		end

		return else_expr
	end

	-- Analyze then-expression (truthy branch)
	self.narrowing_store:PushTruthyExpressionContext()
	local then_expr = self:Assert(self:AnalyzeExpression(node.then_expr))
	self.narrowing_store:PopTruthyExpressionContext()

	-- Track union for then-expression
	if then_expr.Type == "union" then
		self.narrowing_store:TrackUpvalueUnion(then_expr, then_expr:GetTruthy(), then_expr:GetFalsy(), nil, self)
	end

	-- Analyze else-expression (falsy branch)
	self.narrowing_store:PushFalsyExpressionContext()
	local else_expr = self:Assert(self:AnalyzeExpression(node.else_expr))
	self.narrowing_store:PopFalsyExpressionContext()

	-- Track union for else-expression
	if else_expr.Type == "union" then
		self.narrowing_store:TrackUpvalueUnion(else_expr, else_expr:GetTruthy(), else_expr:GetFalsy(), nil, self)
	end

	-- The result type is the union of both branches
	-- This correctly handles the case where then_expr is false/nil
	local result = Union({then_expr, else_expr}):Simplify()
	return result
end

return {
	AnalyzeTernary = AnalyzeTernary,
}
