local lsx = require("nattlua.parser.expressions.extra.lsx")
return function(parser)
	return lsx(parser, true)
end
