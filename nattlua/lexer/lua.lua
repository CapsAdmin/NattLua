local META = dofile("nattlua/lexer/lexer.lua")


--[[#	
	type META.comment_escape = boolean
	type Lexer = typeof META
]]

do
	local read_space = require("nattlua.lexer.readers.space")
	local read_letter = require("nattlua.lexer.readers.letter")
	local read_multiline_c_comment = require("nattlua.lexer.readers.c_multiline_comment")
	local read_line_c_comment = require("nattlua.lexer.readers.c_line_comment")
	local read_multiline_comment = require("nattlua.lexer.readers.multiline_comment")
	local read_line_comment = require("nattlua.lexer.readers.line_comment")
	local read_inline_type_code = require("nattlua.lexer.readers.inline_type_code")
	local read_number = require("nattlua.lexer.readers.number")
	local read_multiline_string = require("nattlua.lexer.readers.multiline_string")
	local read_single_quote_string = require("nattlua.lexer.readers.string").read_single_quote
	local read_double_quote_string = require("nattlua.lexer.readers.string").read_double_quote
	local read_symbol = require("nattlua.lexer.readers.symbol")
	local read_comment_escape = require("nattlua.lexer.readers.comment_escape").read
	local read_remaining_comment_escape = require("nattlua.lexer.readers.comment_escape").read_remaining

	function META:Read()
		if read_remaining_comment_escape(self) then return "discard", false end

		do
			local name = read_space(self) or
				read_comment_escape(self) or
				read_multiline_c_comment(self) or
				read_line_c_comment(self) or
				read_multiline_comment(self) or
				read_line_comment(self)
			if name then return name, true end
		end
		
		do
			local name = read_inline_type_code(self) or
				read_number(self) or
				read_multiline_string(self) or
				read_single_quote_string(self) or
				read_double_quote_string(self) or
				read_letter(self) or
				read_symbol(self)
			if name then return name, false end
		end
	end
end

return function(code--[[#: string]])
	local self = setmetatable({}, META)
	self.comment_escape = false
	self:Initialize(code)
	return self
end
