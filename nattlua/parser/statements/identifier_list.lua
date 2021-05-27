local identifier = require("nattlua.parser.expressions.identifier")
return function(parser, max)
	local out = {}

	for i = 1, max or parser:GetLength() do
		if
			(not parser:IsCurrentType("letter") and not parser:IsCurrentValue("...")) or
			parser:HandleListSeparator(out, i, identifier(parser))
		then
			break
		end
	end

	return out
end
