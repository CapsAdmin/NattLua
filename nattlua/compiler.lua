local io = io
local error = error
local xpcall = xpcall
local tostring = tostring
local table = require("table")
local assert = assert
local helpers = require("nattlua.other.helpers")
local debug = require("debug")
local BuildBaseEnvironment = require("nattlua.runtime.base_environment").BuildBaseEnvironment
local setmetatable = _G.setmetatable
local META = {}
META.__index = META

function META:__tostring()
	local str = ""

	if self.parent_name then
		str = str .. "[" .. self.parent_name .. ":" .. self.parent_line .. "] "
	end

	local line = self.code:match("(.-)\n")

	if line then
		str = str .. line .. "..."
	else
		str = str .. self.code
	end

	return str
end

local repl = function()
	return "\nbecause "
end

function META:OnDiagnostic(code, name, msg, severity, start, stop, ...)
	local level = 0
	local t = 0
	msg = msg:gsub(" because ", repl)

	if t > 0 then
		msg = "\n" .. msg
	end

	if self.analyzer and self.analyzer.processing_deferred_calls then
		msg = "DEFERRED CALL: " .. msg
	end

	local msg = helpers.FormatError(
		code,
		name,
		msg,
		start,
		stop,
		nil,
		...
	)
	local msg2 = ""

	for line in (msg .. "\n"):gmatch("(.-)\n") do
		msg2 = msg2 .. (" "):rep(4 - level * 2) .. line .. "\n"
	end

	msg = msg2

	if not _G.TEST then
		io.write(msg)
	end

	if
		severity == "fatal" or
		(_G.TEST and severity == "error" and not _G.TEST_DISABLE_ERROR_PRINT) or
		self.debug
	then
		local level = 2

		if _G.TEST then
			for i = 1, math.huge do
				local info = debug.getinfo(i)
				if not info then break end

				if info.source:find("@test/nattlua", nil, true) then
					level = i

					break
				end
			end
		end

		error(msg, level)
	end
end

local function stack_trace()
	local s = ""

	for i = 2, 50 do
		local info = debug.getinfo(i)
		if not info then break end

		if info.source:sub(1, 1) == "@" then
			if info.name == "Error" or info.name == "OnDiagnostic" then

			else
				s = s .. info.source:sub(2) .. ":" .. info.currentline .. " - " .. (info.name or "?") .. "\n"
			end
		end
	end

	return s
end

local traceback = function(self, obj, msg)
	if self.debug or _G.TEST then
		local ret = {
				xpcall(function()
					msg = msg or "no error"
					local s = msg .. "\n" .. stack_trace()

					if self.analyzer then
						s = s .. self.analyzer:DebugStateToString()
					end

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
	local lexer = self.Lexer(self.code)
	lexer.name = self.name
	self.lexer = lexer
	lexer.OnError = function(lexer, code, name, msg, start, stop, ...)
		self:OnDiagnostic(
			code,
			name,
			msg,
			"fatal",
			start,
			stop,
			...
		)
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

	local parser = self.Parser(self.Tokens, self.config)
	parser.code = self.code
	parser.name = self.name
	self.parser = parser
	parser.OnError = function(parser, code, name, msg, start, stop, ...)
		self:OnDiagnostic(
			code,
			name,
			msg,
			"fatal",
			start,
			stop,
			...
		)
	end

	if self.OnNode then
		parser.OnNode = function(_, node)
			self:OnNode(node)
		end
	end

	local ok, res = xpcall(function()
		return parser:ReadRootNode()
	end, function(msg)
		return traceback(self, parser, msg)
	end)
	if not ok then return nil, res end
	self.SyntaxTree = res
	return self
end

function META:EnableEventDump(b)
	self.dump_events = b
end

function META:SetDefaultEnvironment(obj)
	self.default_environment = obj
end

function META:Analyze(analyzer, ...)
	if not self.SyntaxTree then
		local ok, err = self:Parse()

		if not ok then
			assert(err)
			return ok, err
		end
	end

	local analyzer = analyzer or self.Analyzer()
	self.analyzer = analyzer
	analyzer.compiler = self
	analyzer.OnDiagnostic = function(analyzer, ...)
		self:OnDiagnostic(...)
	end

	if self.default_environment then
		analyzer:SetDefaultEnvironment(self.default_environment, "typesystem")
	elseif self.default_environment ~= false then
        analyzer:SetDefaultEnvironment(BuildBaseEnvironment(), "typesystem")
	end

	if self.dump_events or self.config and self.config.dump_analyzer_events then
		analyzer.OnEvent = analyzer.DumpEvent
	end

	analyzer.ResolvePath = self.OnResolvePath
	local args = {...}
	local ok, res = xpcall(function()
		local res = analyzer:AnalyzeRootStatement(self.SyntaxTree, table.unpack(args))
		analyzer:AnalyzeUnreachableCode()

		if analyzer.OnFinish then
			analyzer:OnFinish()
		end

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

return function(code--[[#: string]], name--[[#: string]], config--[[#: {[any] = any}]], level--[[#: number | nil]])
	local info = debug.getinfo(level or 2)
	local parent_line = info and info.currentline or "unknown line"
	local parent_name = info and info.source:sub(2) or "unknown name"
	name = name or (parent_name .. ":" .. parent_line)
	return setmetatable(
		{
			code = code,
			parent_line = parent_line,
			parent_name = parent_name,
			name = name,
			config = config,
			Lexer = require("nattlua.lexer.lexer"),
			Parser = require("nattlua.parser.parser"),
			Analyzer = require("nattlua.analyzer.analyzer"),
			Emitter = config and
			config.js and
			require("nattlua.transpiler.javascript_emitter") or
			require("nattlua.transpiler.emitter"),
		},
		META
	)
end
