if not table.unpack and _G.unpack then
	table.unpack = _G.unpack
end

local helpers = require("nattlua.other.helpers")

local nl = {}

function nl.load(code, name, config)
	local obj = nl.Code(code, name, config)
	local code, err = obj:Emit()
	if not code then return nil, err end
    return load(code, name)
end

function nl.loadfile(path, config)
	local obj = nl.File(path, config)
	local code, err = obj:Emit()
	if not code then return nil, err end
    return load(code, path)
end

function nl.ParseFile(path, root)
	local code = assert(nl.File(path, {path = path, root = root}))
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


	function META:OnDiagnostic(code, name, msg, severity, start, stop, ...)
		local level = 0

		if self.analyzer and self.analyzer.processing_deferred_calls then
			msg = "DEFERRED CALL: " .. msg 
		end

		local msg = helpers.FormatError(code, name, msg, start, stop, nil, ...)

		local msg2 = ""
		for line in (msg .. "\n"):gmatch("(.-)\n") do
			msg2 = msg2 .. (" "):rep(4-level*2) .. line .. "\n"
		end
		msg = msg2
		
        if severity == "error" then
            if self.NoThrow then
                io.write(msg)
            else
                error(msg)
            end
        else
            if not _G.test then
                io.write(msg)
            end
        end
    end

    
    local function stack_trace()
        local s = ""
        for i = 2, 50 do
			local info = debug.getinfo(i)
			if not info then
				break
			end

			if info.source:sub(1,1) == "@" then
				if info.name == "Error" or info.name == "OnDiagnostic" then
				else
					s = s .. info.source:sub(2) .. ":" .. info.currentline .. " - " .. (info.name or "?") .. "\n"
				end
			end
        end
        return s
    end

	local function traceback_(self, obj, msg)
		msg = msg or "no error"

        local s = msg .. "\n" .. stack_trace()

        if self.analyzer then
            s = s .. self.analyzer:DebugStateToString()
		end

		return s
	end

	local traceback = function(self, obj, msg)
		local ret = {xpcall(traceback_, function(msg) return debug.traceback(tostring(msg)) end, self, obj, msg)}
        if not ret[1] then
			return "error in error handling: " .. tostring(ret[2])
		end
		return table.unpack(ret, 2)
	end

	function META:Lex()
		local lexer = self.Lexer(self.code)
		lexer.name = self.name
		self.lexer = lexer
        lexer.OnError = function(lexer, code, name, msg, start, stop, ...) 
            self:OnDiagnostic(code, name, msg, "error", start, stop, ...) 
        end
		
		local ok, tokens = xpcall(
			lexer.GetTokens, 
			function(msg) return traceback(self, lexer, msg) end, 
			lexer
		)

		if not ok then
			return nil, tokens
		end

		self.Tokens = tokens

		return self
	end

	function META:Parse()
		if not self.Tokens then
			local ok, err = self:Lex()
			if not ok then
				return ok, err
			end
		end

		local parser = self.Parser(self.config)
		parser.code = self.code
		parser.name = self.name
		self.parser = parser
        parser.OnError = function(parser, code, name, msg, start, stop, ...) 
            self:OnDiagnostic(code, name, msg, "error", start, stop, ...) 
        end

		if self.OnNode then
			parser.OnNode = function(_, node) self:OnNode(node) end
		end

		local ok, res = xpcall(
			parser.BuildAST, 
			function(msg) return traceback(self, parser, msg) end, 
			parser, 
			self.Tokens
		)

		if not ok then
			return nil, res
		end

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
		analyzer.code_data = self
		analyzer.OnDiagnostic = function(analyzer, ...) self:OnDiagnostic(...) end

		if self.default_environment then
			analyzer:SetDefaultEnvironment(self.default_environment, "typesystem")
		elseif self.default_environment ~= false then
			-- this is studid, trying to stop the base analyzer from causing a require() loop
			analyzer:SetDefaultEnvironment(require("nattlua.runtime.base_environment"), "typesystem")
		end

		if self.dump_events or self.config and self.config.dump_analyzer_events then
			analyzer.OnEvent = analyzer.DumpEvent
		end

		local ok, res = xpcall(function(...) 
				local res = analyzer:AnalyzeRootStatement(self.SyntaxTree, ...)
				analyzer:AnalyzeUnreachableCode()
				return res
			end,
			function(msg) return traceback(self, analyzer, msg) end,
			...
		)		
		self.AnalyzedResult = res

		if not ok then
			return nil, res
		end

		return self
	end

	function META:Emit(cfg)
		if not self.SyntaxTree then
			local ok, err = self:Parse()
			if not ok then
				return ok, err
			end
		end

		local emitter = self.Emitter(cfg or self.config)
		self.emitter = emitter
    	return emitter:BuildCode(self.SyntaxTree)
	end

	function nl.Code(code--[[#: string]], name--[[#: string]], config--[[#: {[any] = any}]], level--[[#: number | nil]])
        local info = debug.getinfo(level or 2)

		local parent_line = info and info.currentline or "unknown line"
		local parent_name = info and info.source:sub(2) or "unknown name"

		name = name or (parent_name .. ":" .. parent_line)

		return setmetatable({
			code = code,
			parent_line = parent_line,
			parent_name = parent_name,
			name = name,
			config = config,
			Lexer = require("nattlua.lexer.lexer"),
			Parser = require("nattlua.parser.parser"),
			Analyzer = require("nattlua.analyzer.analyzer"),
			Emitter = config and config.js and require("nattlua.transpiler.javascript_emitter") or require("nattlua.transpiler.emitter"),

		}, META)
	end

	function nl.File(path, config)
		config = config or {}
		
		config.path = config.path or path
		config.name = config.name or path

		local f, err = io.open(path, "rb")
		if not f then
			return nil, err
		end
		local code = f:read("*all")
		f:close()
		return nl.Code(code, "@" .. path, config)
	end
end

return nl