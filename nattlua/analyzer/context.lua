local class = require("nattlua.other.class")
local META = class.CreateTemplate("analyzer_context")
require("nattlua.other.context_mixin")(META)
local push, get, get_offset, pop = META:SetupContextValue("analyzer")

function META:GetCurrentAnalyzer()
	return get(self)
end

function META:PushCurrentAnalyzer(a)
	push(self, a)
end

function META:PopCurrentAnalyzer()
	pop(self)
end

return META.NewObject({context_values = {}, context_ref = {}}, true)
