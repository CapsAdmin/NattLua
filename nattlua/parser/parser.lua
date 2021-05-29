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
	local ReadBreak = require("nattlua.parser.statements.break").ReadBreak
	local ReadDo = require("nattlua.parser.statements.do").ReadDo
	local ReadGenericFor = require("nattlua.parser.statements.generic_for").ReadGenericFor
	local ReadGotoLabel = require("nattlua.parser.statements.goto_label").ReadGotoLabel
	local ReadGoto = require("nattlua.parser.statements.goto").ReadGoto
	local ReadIf = require("nattlua.parser.statements.if").ReadIf
	local ReadLocalAssignment = require("nattlua.parser.statements.local_assignment").ReadLocalAssignment
	local ReadNumericFor = require("nattlua.parser.statements.numeric_for").ReadNumericFor
	local ReadRepeat = require("nattlua.parser.statements.repeat").ReadRepeat
	local ReadSemicolon = require("nattlua.parser.statements.semicolon").ReadSemicolon
	local ReadReturn = require("nattlua.parser.statements.return").ReadReturn
	local ReadWhile = require("nattlua.parser.statements.while").ReadWhile
	local ReadFunction = require("nattlua.parser.statements.function").ReadFunction
	local ReadLocalFunction = require("nattlua.parser.statements.local_function").ReadLocalFunction
	local ReadContinue = require("nattlua.parser.statements.extra.continue").ReadContinue
	local ReadDestructureAssignment = require("nattlua.parser.statements.extra.destructure_assignment").ReadDestructureAssignment
	local ReadLocalDestructureAssignment = require("nattlua.parser.statements.extra.local_destructure_assignment")
		.ReadLocalDestructureAssignment
	local ReadTypeFunction = require("nattlua.parser.statements.typesystem.function").ReadFunction
	local ReadLocalTypeFunction = require("nattlua.parser.statements.typesystem.local_function").ReadLocalFunction
	local ReadLocalGenericsFunction = require("nattlua.parser.statements.typesystem.local_generics_function").ReadLocalGenericsFunction
	local ReadDebugCode = require("nattlua.parser.statements.typesystem.debug_code").ReadDebugCode
	local ReadLocalTypeAssignment = require("nattlua.parser.statements.typesystem.local_assignment").ReadLocalAssignment
	local ReadTypeAssignment = require("nattlua.parser.statements.typesystem.assignment").ReadAssignment
	local ReadCallOrAssignment = require("nattlua.parser.statements.call_or_assignment").ReadCallOrAssignment

	function META:ReadNode()
		if self:IsCurrentType("end_of_file") then return end
		return
			ReadDebugCode(self) or
			ReadReturn(self) or
			ReadBreak(self) or
			ReadContinue(self) or
			ReadSemicolon(self) or
			ReadGoto(self) or
			ReadGotoLabel(self) or
			ReadRepeat(self) or
			ReadTypeFunction(self) or
			ReadFunction(self) or
			ReadLocalGenericsFunction(self) or
			ReadLocalFunction(self) or
			ReadLocalTypeFunction(self) or
			ReadLocalTypeAssignment(self) or
			ReadLocalDestructureAssignment(self) or
			ReadLocalAssignment(self) or
			ReadTypeAssignment(self) or
			ReadDo(self) or
			ReadIf(self) or
			ReadWhile(self) or
			ReadNumericFor(self) or
			ReadGenericFor(self) or
			ReadDestructureAssignment(self) or
			ReadCallOrAssignment(self)
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
