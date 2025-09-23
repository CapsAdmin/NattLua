--[[HOTRELOAD
	run_test("test/tests/line_hook.lua")
]]
local line_hook = {}
line_hook.collected = {}
local nl = require("nattlua")
local loadstring = require("nattlua.other.loadstring")
local diff = require("nattlua.other.diff")
local Emitter = require("nattlua.emitter.emitter").New

function line_hook.Preprocess(code, key, path)
	local compiler = nl.Compiler(code, key, {
		parser = {
			skip_import = true,
		},
	})
	assert(compiler:Parse())
	local em = Emitter(compiler.Config.emitter)
	local old = em.EmitStatement
	local id_stack = {} -- Stack to track currently open statement IDs
	local function open_statement(self, node) end

	local function close_statement(self, node)
		local start, stop = node:GetStartStop()
	end

	local function open_expression(self, node, how) end

	local function close_expression(self)
		self:Emit(")")
		table.remove(id_stack)
	end

	function em:EmitStatement(node)
		if
			node.Type == "statement_break" or
			node.Type == "statement_continue" or
			node.Type == "statement_semicolon" or
			node.Type == "statement_do" or
			node.Type == "statement_root" or
			node.Type == "statement_end_of_file"
		then
			old(self, node)
			return
		end

		local start, stop = node:GetStartStop()

		if node.Type == "statement_return" and node.expressions[1] then
			self:Emit(" LINE_OPEN(LINE_PATH, " .. start .. ", " .. stop .. ");")
			self:Emit("return LINE_RETURN(LINE_PATH, " .. start .. ", " .. stop .. ", ")
			node.tokens["return"].value = ""
			old(self, node)
			self:Emit(");")
		else
			self:Emit(" LINE_OPEN(LINE_PATH, " .. start .. ", " .. stop .. ");")
			old(self, node)
			self:Emit(" LINE_CLOSE(LINE_PATH, " .. start .. ", " .. stop .. ");")
		end
	end

	local gen = em:BuildCode(compiler.SyntaxTree)
	local header = "local LINE_OPEN = _G.LINE_OPEN \z
			local LINE_CLOSE = _G.LINE_CLOSE \z
			local LINE_PATH = [==[" .. (
			path or
			key
		) .. "]==] \z
			local LINE_RETURN = function(path, start, stop, ...) \z
				LINE_CLOSE(path, start, stop) \z
				return ... \z
			end"
	local lua = header .. " " .. gen

	if false then
		local ok, err = loadstring(lua)

		if not ok then
			print(lua)
			error(err)
		end
	end

	return lua
end

return line_hook
