local io = _G.io
local error = _G.error
local xpcall = _G.xpcall
local tostring = _G.tostring
local ipairs = _G.ipairs
local table = _G.table
local assert = _G.assert
local math_huge = _G.math.huge
local formating = require("nattlua.other.formating")
local stack_trace = require("nattlua.other.stack_trace")
local debug = _G.debug
local BuildBaseEnvironment = require("nattlua.base_environment").BuildBaseEnvironment
local setmetatable = _G.setmetatable
local Code = require("nattlua.code").New
local class = require("nattlua.other.class")
local Lexer = require("nattlua.lexer.lexer").New
local Parser = require("nattlua.parser.parser").New
local Analyzer = require("nattlua.analyzer.analyzer").New
local Emitter = require("nattlua.emitter.emitter").New
local loadstring = require("nattlua.other.loadstring")
local stringx = require("nattlua.other.string")
local callstack = require("nattlua.other.callstack")
local META = class.CreateTemplate("compiler")
local NATTLUA_MARKDOWN_OUTPUT = _G.NATTLUA_MARKDOWN_OUTPUT
--[[#local type CompilerConfig = Partial<|
	{
		file_path = string | nil,
		file_name = string | nil,
		parser = Partial<|import("~/nattlua/parser/config.nlua")|>,
		analyzer = Partial<|import("~/nattlua/analyzer/config.nlua")|>,
		emitter = Partial<|import("~/nattlua/emitter/config.nlua")|>,
	}
|>]]
--[[#type META.@Self = {
	Code = any,
	ParentSourceLine = string,
	ParentSourceName = string,
	Config = CompilerConfig | false,
	Tokens = any,
	SyntaxTree = any,
	default_environment = any,
	analyzer = any,
	AnalyzedResult = any,
	debug = any,
	errors = List<|string|>,
}]]

function META:GetCode()
	return self.Code
end

function META:__tostring()
	local str = ""

	if self.ParentSourceName then
		str = str .. "[" .. self.ParentSourceName .. ":" .. self.ParentSourceLine .. "] "
	end

	local lua_code = self.Code:GetString()
	local line = lua_code:match("(.-)\n")

	if line then str = str .. line .. "..." else str = str .. lua_code end

	return str
end

function META:OnDiagnostic(code, msg, severity, start, stop, node, level, ...)
	local t = #self.errors + 1
	msg = stringx.replace(msg, " because ", "\nbecause ")
	msg = formating.FormatMessage(msg, ...)
	local messages = {}

	if self.analyzer then
		local stack = self.analyzer:GetCallStack()

		for i = #stack, 1, -1 do
			local v = stack[i]

			if i > 1 then
				local node = v.call_node or v.obj:GetFunctionBodyNode()

				if node then
					local info = node.Code:SubPosToLineChar(node:GetStartStop())
					local path = node.Code:GetName()

					if path:sub(1, 1) == "@" then path = path:sub(2) end

					table.insert(messages, path .. ":" .. info.line_start .. ":" .. info.character_start)
				else
					for k, v in pairs(v.obj) do

					-- print(k, v)
					end
				end
			end
		end
	end

	local title = severity

	if
		level and
		self.Config and
		self.Config.analyzer and
		self.Config.analyzer.show_severity
	then
		title = severity .. "(" .. level .. ")"
	end

	table.insert(messages, msg)
	local str_code = "unknown code"
	local path = "unknown path"

	if code then
		str_code = code:GetString()
		path = code:GetName()
	end

	msg = formating.BuildSourceCodePointMessage2(
			str_code,
			start,
			stop,
			{
				path = path,
				messages = messages,
				surrounding_line_count = 1,
				title = title,
			}
		) .. "\n"

	if not NATTLUA_MARKDOWN_OUTPUT then
		if severity == "error" then
			msg = "\x1b[0;31m" .. msg .. "\x1b[0m"
		elseif severity == "warning" then
			msg = "\x1b[0;33m" .. msg .. "\x1b[0m"
		elseif severity == "fatal" then
			msg = "\x1b[0;35m" .. msg .. "\x1b[0m"
		end
	end

	if not _G.TEST then
		io.write(msg)
		io.flush()
	end

	if
		severity == "fatal" or
		(
			_G.TEST and
			severity == "error" and
			not _G.TEST_DISABLE_ERROR_PRINT
		)
		or
		self.debug
	then
		local level = 2

		if _G.TEST then
			for i = 1, math_huge do
				local path = callstack.get_line(i)

				if not path then break end

				if path:find("test/tests", nil, true) then
					level = i

					break
				end
			end
		end

		if not _G.TEST and not NATTLUA_MARKDOWN_OUTPUT then print(msg) end

		table.insert(self.errors, msg)
	end
end

local traceback = function(self, obj, msg)
	if self.debug or _G.TEST or NATTLUA_MARKDOWN_OUTPUT then
		local ret = {
			xpcall(function()
				msg = msg or "no error"
				local s = msg .. "\n" .. callstack.traceback(nil, 2)

				if self.analyzer then s = s .. self.analyzer:DebugStateToString() end

				return s
			end, function(msg)
				return callstack.traceback(tostring(msg), 2)
			end),
		}

		if not ret[1] then return "error in error handling: " .. tostring(ret[2]) end

		return table.unpack(ret, 2)
	end

	return msg
end

function META:Lex()
	local lexer = Lexer(self.Code, self.Config and self.Config.lexer)
	lexer.OnError = function(lexer, code, msg, start, stop, ...)
		self:OnDiagnostic(code, msg, "fatal", start, stop, nil, nil, ...)
	end
	local ok, tokens = xpcall(function()
		return lexer:GetTokens()
	end, function(msg)
		return traceback(self, lexer, msg)
	end)

	if not ok then return nil, tokens end

	self.Tokens = tokens
	return self
end

function META:Parse()
	if not self.Tokens then
		local ok, err = self:Lex()

		if not ok then return ok, err end
	end

	local parser = Parser(self.Tokens, self.Code, self.Config and self.Config.parser)
	parser.OnError = function(parser, code, msg, start, stop, ...)
		self:OnDiagnostic(code, msg, "fatal", start, stop, nil, nil, ...)
	end
	parser.OnPreCreateNode = function(_, node)
		self:OnPreCreateNode(node)
	end
	local ok, res = xpcall(function()
		return parser:ParseRootNode()
	end, function(msg)
		return traceback(self, parser, msg)
	end)

	if not ok then return nil, res end

	if self.errors[1] then return nil, table.concat(self.errors, "\n") end

	self.SyntaxTree = res
	return self
end

function META:SetEnvironments(runtime, typesystem)
	self.default_environment = {}
	self.default_environment.runtime = runtime
	self.default_environment.typesystem = typesystem
end

function META:Analyze(analyzer, ...)
	if not self.SyntaxTree then
		local ok, err = self:Parse()

		if not ok then
			assert(err)
			return ok, err
		end
	end

	analyzer = analyzer or Analyzer(self.Config and self.Config.analyzer)
	analyzer.compiler = self
	self.analyzer = analyzer
	analyzer.OnDiagnostic = function(analyzer, code, msg, severity, start, stop, node, level)
		self:OnDiagnostic(code, msg, severity, start, stop, node, level)
	end

	if self.default_environment then
		analyzer:SetDefaultEnvironment(self.default_environment["runtime"], "runtime")
		analyzer:SetDefaultEnvironment(self.default_environment["typesystem"], "typesystem")
	else
		local runtime_env, typesystem_env = BuildBaseEnvironment(self.SyntaxTree, analyzer)
		analyzer:SetDefaultEnvironment(runtime_env, "runtime")
		analyzer:SetDefaultEnvironment(typesystem_env, "typesystem")
	end

	local args = {...}
	local ok, res = xpcall(function()
		local res = analyzer:AnalyzeRootStatement(self.SyntaxTree, table.unpack(args))
		analyzer:AnalyzeUnreachableCode()
		return res
	end, function(msg)
		return traceback(self, analyzer, msg)
	end)
	self.AnalyzedResult = res

	if not ok then return nil, res end

	if self.errors[1] then return nil, table.concat(self.errors, "\n") end

	return self
end

function META:Emit(cfg)
	if not self.SyntaxTree then
		local ok, err = self:Parse()

		if not ok then return ok, err end
	end

	local emitter = Emitter(cfg or self.Config and self.Config.emitter)
	return emitter:BuildCode(self.SyntaxTree)
end

function META:OnPreCreateNode(node) end

function META.New(
	lua_code--[[#: string]],
	name--[[#: string]],
	config--[[#: CompilerConfig]],
	level--[[#: number | nil]]
)
	local path, line, parent_name = callstack.get_path_line(level or 2)
	path = path or "unknown name"
	line = line or "unknown line"
	name = name or path .. ":" .. line

	if config then
		for _, v in ipairs({"emitter", "parser", "analyzer"}) do
			config[v] = config[v] or {}
			config[v].file_path = config[v].file_path or config.file_path
			config[v].file_name = config[v].file_name or config.file_name
			config[v].root_directory = config[v].root_directory or config.root_directory
		end
	end

	return META.NewObject(
		{
			Code = Code(lua_code, name),
			ParentSourceLine = line,
			ParentSourceName = parent_name,
			Config = config or false,
			Tokens = false,
			SyntaxTree = false,
			default_environment = false,
			analyzer = false,
			AnalyzedResult = false,
			debug = false,
			is_base_environment = false,
			errors = {},
		},
		true
	)
end

function META.FromFile(path, config)
	config = config or {}
	config.file_path = config.file_path or path
	config.file_name = config.file_name or "@" .. path
	local f, err = io.open(path, "rb")

	if not f then return nil, err end

	local code = f:read("*a")
	f:close()

	if not code then return nil, path .. " empty file" end

	return META.New(code, config.file_name, config)
end

function META.Load(code, name, config)
	config = config or {}
	config.file_name = config.file_name or name
	local obj = META.New(code, config.file_name, config)
	local code, err = obj:Emit()

	if not code then return nil, err end

	return loadstring(code, config.file_name)
end

function META.LoadFile(path, config)
	local obj, err = META.FromFile(path, config)

	if not obj then return nil, err end

	local code, err = obj:Emit()

	if not code then return nil, err end

	return loadstring(code, obj.Config.file_name)
end

return META
