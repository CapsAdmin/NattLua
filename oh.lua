local oh = {}

local Lexer = require("oh.lexer")
local Parser = require("oh.parser")
local LuaEmitter = require("oh.lua_emitter")
local print_util = require("oh.print_util")
local Analyzer = require("oh.analyzer")


function oh.GetBaseAnalyzeer()

    if not oh.base_analyzer then
        local base = Analyzer()
        base.Index = nil
        base:AnalyzeStatement(assert(oh.FileToAST("oh/base_lib.oh")))
        oh.base_analyzer = base
    end

    return oh.base_analyzer
end


function oh.loadstring(code, name, config)
	local code = oh.Code(code, name, config)
	local ok, code = pcall(code.BuildLua, code)
	if not ok then return nil, code end
    return loadstring(code, name)
end

function oh.loadfile(path, config)
	local code = oh.File(path, config)
	local ok, code = pcall(code.BuildLua, code)
	if not ok then return nil, code end
    return loadstring(code, name)
end

function oh.FileToAST(path, root)
	local code, err = assert(oh.File(path, {path = path, root = root}))

	if not code then
		return err
	end

	return assert(code:Parse()).SyntaxTree
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

	function META:OnError(obj, msg, start, stop, ...)
		error(print_util.FormatError(self.code, self.name, msg, start, stop, ...))
	end

	function META:Lex()
		local lexer = Lexer(self.code)
		lexer.code_data = self
		lexer.OnError = function(obj, ...) self:OnError(obj, ...) end
	
		local ok, tokens = pcall(lexer.GetTokens, lexer)
	
		if not ok then
			return nil, tokens:match("^.-:%s+(.+)")
		end

		self.Tokens = tokens

		return self
	end

	function META:Parse()
		if not self.Tokens then
			assert(self:Lex())
		end

		local parser = Parser(self.config)
		parser.code_data = self
		parser.OnError = function(obj, ...) self:OnError(obj, ...) end
		
		local ok, ast = pcall(parser.BuildAST, parser, self.Tokens)

		if not ok then
			return nil, ast:match("^.-:%s+(.+)")
		end

		self.SyntaxTree = ast

		return self
	end

	function META:Analyze()
		if not self.SyntaxTree then
			assert(self:Parse())
		end

		local analyzer = Analyzer()
		analyzer.code_data = self
		analyzer.OnError = function(obj, ...) self:OnError(obj, ...) end

		oh.current_analyzer = analyzer
		local ok, ast = pcall(analyzer.AnalyzeStatement, analyzer, self.SyntaxTree)
		oh.current_analyzer = nil
	
		if not ok then
			return nil, ast:match("^.-:%s+(.+)")
		end
	
		self.Analyzed = true
	
		return self
	end

	function META:BuildLua()
		if not self.SyntaxTree then
			assert(self:Parse())
		end

		local em = LuaEmitter(self.config)
    	return em:BuildCode(self.SyntaxTree), em
	end

	function oh.Code(code, name, config)
		local info = debug.getinfo(2)

		local parent_line = info and info.currentline or nil
		local parent_name = info and info.source:sub(2) or nil
		
		name = name or (parent_name .. ":" .. parent_line)

		return setmetatable({
			code = code, 
			parent_line = parent_line,
			parent_name = parent_name,
			name = name,
			config = config,
		}, META)
	end

	function oh.File(path, config)
		
		config = config or {}
		config.path = config.path or path

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