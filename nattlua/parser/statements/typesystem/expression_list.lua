local multiple_values = require("nattlua.parser.statements.multiple_values")
return function(parser, max)
	return multiple_values(parser, max, parser.ReadTypeExpression)
end
