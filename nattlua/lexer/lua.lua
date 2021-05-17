local META = dofile("nattlua/lexer/lexer.lua")
--[[#type Lexer = META.@Self]]

do
	local space = require("nattlua.lexer.readers.space").space
	local letter = require("nattlua.lexer.readers.letter").letter
	local c_multiline_comment = require("nattlua.lexer.readers.c_multiline_comment").c_multiline_comment
	local c_line_comment = require("nattlua.lexer.readers.c_line_comment").c_line_comment
	local multiline_comment = require("nattlua.lexer.readers.multiline_comment").multiline_comment
	local line_comment = require("nattlua.lexer.readers.line_comment").line_comment
	local inline_type_code = require("nattlua.lexer.readers.inline_type_code").inline_type_code
	local number = require("nattlua.lexer.readers.number").number
	local multiline_string = require("nattlua.lexer.readers.multiline_string").multiline_string
	local single_quote_string = require("nattlua.lexer.readers.string").single_quote_string
	local double_quote_string = require("nattlua.lexer.readers.string").double_quote_string
	local symbol = require("nattlua.lexer.readers.symbol").symbol
	local comment_escape = require("nattlua.lexer.readers.comment_escape").comment_escape
	local remaining_comment_escape = require("nattlua.lexer.readers.comment_escape").remaining_comment_escape

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

return META.New
