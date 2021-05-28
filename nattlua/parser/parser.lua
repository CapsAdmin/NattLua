local syntax = require("nattlua.syntax.syntax")
local setmetatable = _G.setmetatable
local META = {}
META.__index = META
META.Emitter = require("nattlua.transpiler.emitter")
META.syntax = syntax
require("nattlua.parser.base_parser")(META)

function META:ResolvePath(path)
	return path
end

do -- statements
	local _break = require("nattlua.parser.statements.break")
	local _do = require("nattlua.parser.statements.do")
	local generic_for = require("nattlua.parser.statements.generic_for")
	local goto_label = require("nattlua.parser.statements.goto_label")
	local _goto = require("nattlua.parser.statements.goto")
	local _if = require("nattlua.parser.statements.if")
	local local_assignment = require("nattlua.parser.statements.local_assignment")
	local numeric_for = require("nattlua.parser.statements.numeric_for")
	local _repeat = require("nattlua.parser.statements.repeat")
	local semicolon = require("nattlua.parser.statements.semicolon")
	local _return = require("nattlua.parser.statements.return")
	local _while = require("nattlua.parser.statements.while")
	local _function = require("nattlua.parser.statements.function")
	local local_function = require("nattlua.parser.statements.local_function")
	local _continue = require("nattlua.parser.statements.extra.continue")
	local destructure_assignment = require("nattlua.parser.statements.extra.destructure_assignment")
	local local_destructure_assignment = require("nattlua.parser.statements.extra.local_destructure_assignment")
	local type_function = require("nattlua.parser.statements.typesystem.function")
	local local_type_function = require("nattlua.parser.statements.typesystem.local_function")
	local local_type_generics_function = require("nattlua.parser.statements.typesystem.local_generics_function")
	local debug_code = require("nattlua.parser.statements.typesystem.debug_code")
	local local_type_assignment = require("nattlua.parser.statements.typesystem.local_assignment")
	local type_assignment = require("nattlua.parser.statements.typesystem.assignment")
	local call_or_assignment = require("nattlua.parser.statements.call_or_assignment")

	function META:ReadNode()
		if self:IsCurrentType("end_of_file") then return end
		return
			debug_code(self) or
			_return(self) or
			_break(self) or
			_continue(self) or
			semicolon(self) or
			_goto(self) or
			goto_label(self) or
			_repeat(self) or
			type_function(self) or
			_function(self) or
			local_type_generics_function(self) or
			local_function(self) or
			local_type_function(self) or
			local_type_assignment(self) or
			local_destructure_assignment(self) or
			local_assignment(self) or
			type_assignment(self) or
			_do(self) or
			_if(self) or
			_while(self) or
			numeric_for(self) or
			generic_for(self) or
			destructure_assignment(self) or
			call_or_assignment(self)
	end
end

return function(config)
	return setmetatable(
		{
			config = config,
			nodes = {},
			name = "",
			code = "",
			current_statement = false,
			current_expression = false,
			root = false,
			i = 1,
			tokens = {},
			OnError = function() 
			end,
		},
		META
	)
end
