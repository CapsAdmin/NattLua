local class = require("nattlua.other.class")
local META = class.CreateTemplate("analyzer_context")
require("nattlua.other.context_mixin")(META)

function META:GetCurrentAnalyzer()
	return self:GetContextValue("analyzer")
end

function META:PushCurrentAnalyzer(a)
	self:PushContextValue("analyzer", a)
end

function META:PopCurrentAnalyzer()
	self:PopContextValue("analyzer")
end

return META.NewObject({context_values = {}, context_ref = {}}, true)
