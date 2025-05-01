import { LuaEngine, LuaFactory } from "wasmoon"
import { loadLuaModule } from "./util"

export const loadLua = async () => {
	const factory = new LuaFactory()
	const lua = await factory.createEngine({
		openStandardLibs: true,
	})

	await loadLuaModule((str) => lua.doStringSync(str), import("./../../build_output.lua"), "nattlua")
	await lua.doString("for k, v in pairs(package.preload) do print(k,v) end require('nattlua') for k,v in pairs(IMPORTS) do package.preload[k] = v end")
	await loadLuaModule((str) => lua.doStringSync(str), import("./../../language_server/lsp.lua"), "lsp", "@language_server/lsp.lua")

	await lua.doString(`
		local lsp = require("lsp")

		local listeners = {}

		function lsp.Call(data)
			assert(data.method, "missing method")
			listeners[data.method](data.params)
		end

		function lsp.On(method, callback)
			listeners[method] = callback
		end

		for k,v in pairs(lsp.methods) do
			lsp.methods[k] = function(params)
				print("calling on server", k)
				local ok, res = xpcall(function()
					return v(params)
				end, debug.traceback)
				if not ok then
					error(res, 2)
				end
				return res
			end
		end

		_G.lsp = lsp`)

	console.log("OK")

	return lua
}

export const prettyPrint = (lua: LuaEngine, code: string) => {
	lua.doStringSync(`
		function _G.prettyPrint(code)
			local nl = require("nattlua")
			local compiler = nl.Compiler(code, "temp", {
				emitter = {
					preserve_whitespace = false,
					string_quote = "\\"",
					no_semicolon = true,
					type_annotations = "explicit",
					force_parenthesis = true,
					comment_type_annotations = false,
				},
				parser = {
					skip_import = true,
				}
			})
			return assert(compiler:Emit())
		end    
	`)

	return lua.global.get("prettyPrint")(code) as string
}
