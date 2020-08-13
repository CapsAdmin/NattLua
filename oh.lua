local oh = {}

if not table.unpack and _G.unpack then
	table.unpack = _G.unpack
end

local helpers = require("oh.helpers")

oh.current_analyzer = {}
function oh.PushAnalyzer(a)
    table.insert(oh.current_analyzer, 1, a)
end

function oh.PopAnalyzer()
	table.remove(oh.current_analyzer, 1)
end

function oh.GetCurrentAnalyzer()
	return oh.current_analyzer[1]
end

function oh.GetBaseAnalyzer()

    if not oh.base_analyzer then
        local base = require("oh.lua.analyzer")()
		base.IndexNotFound = nil

		local ret, root, code_data = base:AnalyzeFile("oh/lua/base_typesystem.oh")

		local g = base:TypeFromImplicitNode(root, "table")

		for k, v in pairs(base.env.typesystem) do
			g:Set(k, v)
		end

		-- TODO: string library isn't in base.env.typesystem
		g:Set("string", base:GetValue("string", "typesystem"))
		base:SetValue("_G", g, "typesystem")
		base:GetValue("_G", "typesystem"):Set("_G", g)

        oh.base_analyzer = base
    end

    return oh.base_analyzer
end


function oh.load(code, name, config)
	local obj = oh.Code(code, name, config)
	local code, err = obj:Emit()
	if not code then return nil, err end
    return load(code, name)
end

function oh.loadfile(path, config)
	local obj = oh.File(path, config)
	local code, err = obj:Emit()
	if not code then return nil, err end
    return load(code, path)
end

function oh.on_editor_save(path)
	if path:sub(-4) ~= ".lua" and path:sub(-3) ~= ".oh" then
		return
	end

	if path:find("test/") then
		os.execute("luajit test/run.lua " .. path)
		return
	end

	if path:find("javascript_emitter") then
		path = "./examples/lua_to_js.lua"
	end

	if path:find("oh/oh", nil, true) and not path:find("helpers") then
		local f = io.open("test_focus.lua")
		if f and #f:read("*all") == 0 then
			f:close()
			if path:find("/lua/") then
				os.execute("luajit test/run.lua lua")
			elseif path:find("/c_preprocessor/") then
				os.execute("luajit test/run.lua c_preprocessor")
			elseif path:find("/c/") then
				os.execute("luajit test/run.lua c")
			else
				os.execute("luajit test/run.lua")
			end
			return
		else
			path = "./test_focus.lua"
		end
	end

	if path:find("examples/") then
		os.execute("luajit " .. path)
		return
	end

	local c = oh.File(path, {annotate = true})
	if c.code:find("--DISABLE_BASE_TYPES", nil, true) then
		_G.DISABLE_BASE_TYPES = true
	end
	local ok, err = c:Analyze()
	if c.code:find("--DISABLE_BASE_TYPES", nil, true) then
		_G.DISABLE_BASE_TYPES = nil
	end
	if not ok then
		io.write(err, "\n")
		return
	end
	local res = assert(c:Emit())
	require("oh.lua.base_runtime")
	io.write(res, "\n")
	--assert(load(res))()
end

function oh.ParseFile(path, root)
	local code = assert(oh.File(path, {path = path, root = root}))
	return assert(code:Parse()), code
end

do
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

	function META:OnError(msg, start, stop, ...)
		local self = self.code_data
		local msg = helpers.FormatError(self.code, self.name, msg, start, stop, ...)
		if self.NoThrow then
			io.write(msg)
		else
			error(msg)
		end
	end

	local function traceback_(msg)
		msg = msg or "no error"

		local s = ""
		s = msg .. "\n" .. s
		for i = 2, math.huge do
			local info = debug.getinfo(i)
			if not info then
				break
			end

			if info.source:find("/busted/") then
				break
			end

			if info.source:sub(1,1) == "@" then
				if info.name == "Error" or info.name == "OnError" then

				else
					s = s .. info.source:sub(2) .. ":" .. info.currentline .. " - " .. (info.name or "?") .. "\n"
				end
			end
		end

		if oh.GetCurrentAnalyzer() then
			local analyzer = oh.GetCurrentAnalyzer()

			if analyzer.current_statement and analyzer.current_statement.Render then
				s = s .. "======== statement =======\n"
				s = s .. analyzer.current_statement:Render()
				s = s .. "\n===============\n"
			end

			if analyzer.current_expression and analyzer.current_expression.Render then
				s = s .. "======== expression =======\n"
				s = s .. analyzer.current_expression:Render()
				s = s .. "\n===============\n"
			end

			if analyzer.callstack then
				s = s .. "======== callstack =======\n"

				for _, obj in ipairs(analyzer.callstack) do
					s = s .. helpers.FormatError(analyzer.code_data.code, analyzer.code_data.name, tostring(obj), helpers.LazyFindStartStop(obj))
				end

				s = s .. "\n===============\n"
			end

			if analyzer.error_stack then
				s = s .. "======== error_stack =======\n"

				for _, data in ipairs(analyzer.error_stack) do
					s = s .. tostring(data.statement:Render())
					s = s .. tostring(data.expression:Render())
				end

				s = s .. "\n===============\n"
			end
		end

		return s
	end

	local traceback = function(...)
		local ret = {pcall(traceback_, ...)}
		if not ret[1] then
			return "error in error handling: " .. ret[2]
		end
		return table.unpack(ret, 2)
	end

	function META:Lex()
		local lexer = self.Lexer(self.code)
		lexer.code_data = self
		lexer.OnError = self.OnError

		local ok, tokens = xpcall(lexer.GetTokens, traceback, lexer)

		if not ok then
			return nil, tokens
		end

		self.Tokens = tokens

		return self, lexer
	end

	function META:Parse(cb)
		if not self.Tokens then
			local ok, err = self:Lex()
			if not ok then
				return ok, err
			end
		end

		local parser = self.Parser(self.config)
		parser.code_data = self
		parser.OnError = self.OnError

		if cb then
			parser.OnNode = function(self, node) cb(self, node) end
		end

		local ok, ast = xpcall(parser.BuildAST, traceback, parser, self.Tokens)

		if not ok then
			return nil, ast
		end

		self.SyntaxTree = ast


		return self
	end

	function META:Analyze(dump_events)
		if not self.SyntaxTree then
			local ok, err = self:Parse()
			if not ok then
				return ok, err
			end
		end

		local analyzer = self.Analyzer()
		if dump_events or self.config and self.config.dump_analyzer_events then
			analyzer.OnEvent = analyzer.DumpEvent
		end
		analyzer.code_data = self
		analyzer.OnError = self.OnError

		oh.PushAnalyzer(analyzer)
		local ok, ast = xpcall(analyzer.AnalyzeStatement, traceback, analyzer, self.SyntaxTree)
		oh.PopAnalyzer()
		self.Analyzer = analyzer

		if not ok then
			return nil, ast
		end

		self.Analyzed = true

		return self
	end

	function META:Emit()
		if not self.SyntaxTree then
			local ok, err = self:Parse()
			if not ok then
				return ok, err
			end
		end

		local em = self.Emitter(self.config)
    	return em:BuildCode(self.SyntaxTree), em
	end

	function oh.Code(code, name, config, level)
		local info = debug.getinfo(level or 2)

		local parent_line = info and info.currentline or nil
		local parent_name = info and info.source:sub(2) or nil

		name = name or (parent_name .. ":" .. parent_line)

		return setmetatable({
			code = code,
			parent_line = parent_line,
			parent_name = parent_name,
			name = name,
			config = config,
			Lexer = require("oh.lua.lexer"),
			Parser = require("oh.lua.parser"),
			Analyzer = require("oh.lua.analyzer"),
			Emitter = config and config.js and require("oh.lua.javascript_emitter") or require("oh.lua.emitter"),

		}, META)
	end

	function oh.File(path, config)

		config = config or {}
		config.path = config.path or path
		config.name = config.name or path

		local f, err = io.open(path, "rb")
		if not f then
			return nil, err
		end
		local code = f:read("*all")
		f:close()
		return oh.Code(code, "@" .. path, config)
	end
end

return oh