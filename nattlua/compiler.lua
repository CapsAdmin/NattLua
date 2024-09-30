local io = io
local error = error
local xpcall = xpcall
local tostring = tostring
local table = _G.table
local assert = assert
local formating = require("nattlua.other.formating")
local stack_trace = require("nattlua.other.stack_trace")
local debug = _G.debug
local BuildBaseEnvironment = require("nattlua.base_environment").BuildBaseEnvironment
local setmetatable = _G.setmetatable
local Code = require("nattlua.code").New
local class = require("nattlua.other.class")
local Lexer = require("nattlua.lexer").New
local Parser = require("nattlua.parser").New
local Analyzer = require("nattlua.analyzer").New
local Emitter = require("nattlua.emitter").New
local loadstring = require("nattlua.other.loadstring")
local stringx = require("nattlua.other.string")
local META = class.CreateTemplate("compiler")

--[[#local type { CompilerConfig } = import("~/nattlua/config.nlua")]]

function META:GetCode()
	return self.Code
end

function META:__tostring()
	local str = ""

	if self.parent_name then
		str = str .. "[" .. self.parent_name .. ":" .. self.parent_line .. "] "
	end

	local lua_code = self.Code:GetString()
	local line = lua_code:match("(.-)\n")

	if line then str = str .. line .. "..." else str = str .. lua_code end

	return str
end

function META:OnDiagnostic(code, msg, severity, start, stop, node, ...)
	local level = 0
	local t = 0
	msg = stringx.replace(msg, " because ", "\nbecause ")

	if t > 0 then msg = "\n" .. msg end

	local msg = code:BuildSourceCodePointMessage(formating.FormatMessage(msg, ...), start, stop)
	local msg2 = ""

	for _, line in ipairs(stringx.split(msg, "\n")) do
		msg2 = msg2 .. (" "):rep(4 - level * 2) .. line .. "\n"
	end

	msg = msg2

	if severity == "error" then
		msg = "\x1b[0;31m" .. msg .. "\x1b[0m"
	elseif severity == "warning" then
		msg = "\x1b[0;33m" .. msg .. "\x1b[0m"
	end

	if not _G.TEST then io.write(msg) end

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
			for i = 1, math.huge do
				local info = debug.getinfo(i)

				if not info then break end

				if info.source:find("@test/tests", nil, true) then
					level = i

					break
				end
			end
		end

		error(msg, level)
	end
end

local function check_info(info, level)
	if info.source:sub(1, 1) == "@" then
		if info.name == "Error" or info.name == "OnDiagnostic" then return false end
	end

	return true
end

local function stack_trace_simple(level, check_info)
	local s = ""

	for i = level, 50 do
		local info = debug.getinfo(i)

		if not info then break end

		if check_info(info, level) then
			s = s .. info.source:sub(2) .. ":" .. info.currentline .. " - " .. (
					info.name or
					"?"
				) .. "\n"
		end
	end

	return s
end

local traceback = function(self, obj, msg)
	if self.debug or _G.TEST then
		local ret = {
			xpcall(function()
				msg = msg or "no error"
				local s = msg .. "\n" .. stack_trace_simple(2, check_info)

				if self.analyzer then s = s .. self.analyzer:DebugStateToString() end

				return s
			end, function(msg)
				return debug.traceback(tostring(msg))
			end),
		}

		if not ret[1] then return "error in error handling: " .. tostring(ret[2]) end

		return table.unpack(ret, 2)
	end

	return msg
end

function META:Lex()
	local lexer = self.Lexer(self:GetCode())
	lexer.name = self.name
	self.lexer = lexer
	lexer.OnError = function(lexer, code, msg, start, stop, ...)
		self:OnDiagnostic(code, msg, "fatal", start, stop, nil, ...)
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

	local parser = self.Parser(self.Tokens, self.Code, self.config)
	self.parser = parser
	parser.OnError = function(parser, code, msg, start, stop, ...)
		self:OnDiagnostic(code, msg, "fatal", start, stop, nil, ...)
	end

	if self.OnPreCreateNode then
		parser.OnPreCreateNode = function(_, node)
			self:OnPreCreateNode(node)
		end
	end

	local ok, res = xpcall(function()
		return parser:ParseRootNode()
	end, function(msg)
		return traceback(self, parser, msg)
	end)

	if not ok then return nil, res end

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

	local analyzer = analyzer or self.Analyzer(self.config)
	self.analyzer = analyzer
	analyzer.compiler = self
	analyzer.OnDiagnostic = function(analyzer, ...)
		self:OnDiagnostic(...)
	end

	if self.default_environment then
		analyzer:SetDefaultEnvironment(self.default_environment["runtime"], "runtime")
		analyzer:SetDefaultEnvironment(self.default_environment["typesystem"], "typesystem")
	elseif self.default_environment ~= false then
		local runtime_env, typesystem_env = BuildBaseEnvironment()
		analyzer:SetDefaultEnvironment(runtime_env, "runtime")
		analyzer:SetDefaultEnvironment(typesystem_env, "typesystem")
	end

	local args = {...}
	local ok, res = xpcall(function()
		local res = analyzer:AnalyzeRootStatement(self.SyntaxTree, table.unpack(args))
		analyzer:AnalyzeUnreachableCode()

		if analyzer.OnFinish then analyzer:OnFinish() end

		return res
	end, function(msg)
		return traceback(self, analyzer, msg)
	end)
	self.AnalyzedResult = res

	if not ok then return nil, res end

	return self
end

function META:Emit(cfg)
	if not self.SyntaxTree then
		local ok, err = self:Parse()

		if not ok then return ok, err end
	end

	local emitter = self.Emitter(cfg or self.config)
	self.emitter = emitter
	return emitter:BuildCode(self.SyntaxTree)
end

function META.New(
	lua_code--[[#: string]],
	name--[[#: string]],
	config--[[#: CompilerConfig]],
	level--[[#: number | nil]]
)
	local info = debug.getinfo(level or 2)
	local parent_line = info and info.currentline or "unknown line"
	local parent_name = info and info.source:sub(2) or "unknown name"
	name = name or (parent_name .. ":" .. parent_line)
	return setmetatable(
		{
			Code = Code(lua_code, name),
			parent_line = parent_line,
			parent_name = parent_name,
			config = config,
			Lexer = Lexer,
			Parser = Parser,
			Analyzer = Analyzer,
			Emitter = Emitter,
		},
		META
	)
end

function META.FromFile(path, config)
	config = config or {}
	config.file_path = config.file_path or path
	config.file_name = config.file_name or "@" .. path
	local f, err = io.open(path, "rb")

	if not f then return nil, err end

	local code = f:read("*all")
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
	local obj = META.FromFile(path, config)
	local code, err = obj:Emit()

	if not code then return nil, err end

	return loadstring(code, obj.config.file_name)
end

return META
