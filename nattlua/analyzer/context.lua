local class = require("nattlua.other.class")
local META = class.CreateTemplate("analyzer_context")
META.OnInitialize = {}
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

local self = setmetatable({context_values = {}, context_ref = {}}, META)

for i, v in ipairs(META.OnInitialize) do
	v(self)
end

return self