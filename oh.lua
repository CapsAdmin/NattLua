local oh = {}

local Lexer = require("oh.lexer")
local Parser = require("oh.parser")
local LuaEmitter = require("oh.lua_emitter")
local print_util = require("oh.print_util")
local Crawler = require("oh.crawler")

function oh.ASTToCode(ast, config)
    local self = LuaEmitter(config)
    return self:BuildCode(ast)
end

local function on_error(self, msg, start, stop, ...)
	self.errors = self.errors or {}
    table.insert(self.errors, {msg = msg, start = start, stop = stop, args = {...}})
end

function oh.CodeToTokens(code, name)
	name = name or "unknown"

	local lexer = Lexer(code)
    lexer.OnError = on_error
    local tokens = lexer:GetTokens()
    if lexer.errors then
        local str = ""
        for _, err in ipairs(lexer.errors) do
            str = str .. print_util.FormatError(code, name, err.msg, err.start, err.stop, unpack(err.args)) .. "\n"
        end
        return nil, str
	end

	return tokens, lexer
end

function oh.DefaultErrorHandler(self, msg, start, stop, ...)
	self.errors = self.errors or {}
	table.insert(self.errors, {msg = msg, start = start, stop = stop, args = {...}})
	error(print_util.FormatMessage(msg, ...))
end

function oh.TokensToAST(tokens, name, code, config)
	name = name or "unknown"

	local parser = Parser(config)
    parser.OnError = oh.DefaultErrorHandler
    local ok, ast = pcall(parser.BuildAST, parser, tokens)
	if not ok then
		if parser.errors then
			local str = ""
			for _, err in ipairs(parser.errors) do
				if code then
					str = str .. print_util.FormatError(code, name, err.msg, err.start, err.stop, unpack(err.args)) .. "\n"
				else
					str = str .. err.msg .. "\n"
				end
			end
			return nil, str
		else
			return nil, ast
		end
	end

	return ast, parser
end

function oh.Transpile(code, name, config)
    name = name or "unknown"

	local tokens, err = oh.CodeToTokens(code, name)
	if not tokens then return nil, err end

	local ast, err = oh.TokensToAST(tokens, name, code, config)
	if not ast then return nil, err end

	return oh.ASTToCode(ast, config)
end

function oh.loadstring(code, name, config)
	local code, err = oh.Transpile(code, name, config)
	if not code then return nil, err end

    return loadstring(code, name)
end

function oh.loadfile(path)
	local code, err = oh.TranspileFile(path)
	if not code then return nil, err end
	print(code)
    return loadstring(code, name)
end


function oh.GetBaseCrawler()

    if not oh.base_crawler then
        local base_lib = io.open("oh/base_lib.oh"):read("*all")
        local base = Crawler()
        base.Index = nil
        base:CrawlStatement(assert(oh.TokensToAST(assert(oh.CodeToTokens(base_lib, "test")), "test", base_lib)))
        oh.base_crawler = base
    end

    return oh.base_crawler
end


function oh.FileToAST(path, root)
	local f, err = io.open(path, "rb")

	if not f then
		return nil, err
	end

	local code = f:read("*all")
	f:close()

	local name = "@" .. path
	local tokens, err = oh.CodeToTokens(code, name)
	if not tokens then return nil, err end

	local ast, err = oh.TokensToAST(tokens, name, code, {path = path, root = root})
	if not ast then return nil, err end

	return ast
end

function oh.TranspileFile(path)
	local f, err = io.open(path, "rb")
	if not f then return nil, err end
	local code = f:read("*all")
	f:close()
	local code, err = oh.Transpile(code, "@" .. path, {path = path})
	if not code then return nil, err end

	return code
end

return oh