local META = dofile("nattlua/lexer/lexer.lua")
--[[#type META.comment_escape = boolean]]
--[[#type Lexer = typeof META]]
META.comment_escape = false

do
	local space = require("nattlua.lexer.readers.space")
	local letter = require("nattlua.lexer.readers.letter")
	local c_multiline_comment = require("nattlua.lexer.readers.c_multiline_comment")
	local c_line_comment = require("nattlua.lexer.readers.c_line_comment")
	local multiline_comment = require("nattlua.lexer.readers.multiline_comment")
	local line_comment = require("nattlua.lexer.readers.line_comment")
	local inline_type_code = require("nattlua.lexer.readers.inline_type_code")
	local number = require("nattlua.lexer.readers.number")
	local multiline_string = require("nattlua.lexer.readers.multiline_string")
	local single_quote_string = require("nattlua.lexer.readers.string").read_single_quote
	local double_quote_string = require("nattlua.lexer.readers.string").read_double_quote
	local symbol = require("nattlua.lexer.readers.symbol")
	local comment_escape = require("nattlua.lexer.readers.comment_escape").read
	local remaining_comment_escape = require("nattlua.lexer.readers.comment_escape").read_remaining

	function META:Read()
		if remaining_comment_escape(self) then return "discard", false end

		do
			local name = space(self) or
				comment_escape(self) or
				c_multiline_comment(self) or
				c_line_comment(self) or
				multiline_comment(self) or
				line_comment(self)
			if name then return name, true end
		end

		do
			local name = inline_type_code(self) or
				number(self) or
				multiline_string(self) or
				single_quote_string(self) or
				double_quote_string(self) or
				letter(self) or
				symbol(self)
			if name then return name, false end
		end
	end
end

return function(code--[[#: string]])
	return META:New(code)
end
