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
	local _break = require("nattlua.parser.statements.break").ReadBreak
	local _do = require("nattlua.parser.statements.do").ReadDo
	local generic_for = require("nattlua.parser.statements.generic_for").ReadGenericFor
	local goto_label = require("nattlua.parser.statements.goto_label").ReadGotoLabel
	local _goto = require("nattlua.parser.statements.goto").ReadGoto
	local _if = require("nattlua.parser.statements.if").ReadIf
	local local_assignment = require("nattlua.parser.statements.local_assignment").ReadLocalAssignment
	local numeric_for = require("nattlua.parser.statements.numeric_for").ReadNumericFor
	local _repeat = require("nattlua.parser.statements.repeat").ReadRepeat
	local semicolon = require("nattlua.parser.statements.semicolon").ReadSemicolon
	local _return = require("nattlua.parser.statements.return").ReadReturn
	local _while = require("nattlua.parser.statements.while").ReadWhile
	local _function = require("nattlua.parser.statements.function").ReadFunction
	local local_function = require("nattlua.parser.statements.local_function").ReadLocalFuncfunction
	local _continue = require("nattlua.parser.statements.extra.continue").ReadContinue
	local destructure_assignment = require("nattlua.parser.statements.extra.destructure_assignment").ReadDestructureAssignment
	local local_destructure_assignment = require("nattlua.parser.statements.extra.local_destructure_assignment")
		.ReadLocalDestructureAssignment
	local type_function = require("nattlua.parser.statements.typesystem.function").ReadFunction
	local local_type_function = require("nattlua.parser.statements.typesystem.local_function").ReadLocalFunction
	local local_type_generics_function = require("nattlua.parser.statements.typesystem.local_generics_function").ReadLocalGenericsFunction
	local debug_code = require("nattlua.parser.statements.typesystem.debug_code").ReadDebugCode
	local local_type_assignment = require("nattlua.parser.statements.typesystem.local_assignment").ReadLocalAssignment
	local type_assignment = require("nattlua.parser.statements.typesystem.assignment").ReadAssignment
	local call_or_assignment = require("nattlua.parser.statements.call_or_assignment").ReadCallOrAssignment

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
