import { LuaEngine, LuaFactory } from "wasmoon"
import { getLuaInterop } from "./lua-utils/luaInterop"

const loadLuaModule = async (doString: (luaCode: string) => void, p: Promise<{ default: string }>, moduleName: string, chunkName?: string) => {
	let { default: code } = await p

	if (code.startsWith("#")) {
		// remove shebang
		const index = code.indexOf("\n")
		if (index !== -1) {
			code = code.substring(index)
		}
	}

	// I think something broke with moonwasm. There seems to be a limit on how large the string can be.
	// This may be taking it too far but I've spent too much time on this already..

	const bytes = (new TextEncoder()).encode(code)
	let bytesString: string[] = []
	let bytesStringIndex = 0
	for (let i = 0; i < bytes.length; i++) {
		let code = bytes[i]
		bytesString[bytesStringIndex] = `\\${code}`
		bytesStringIndex++
		if (bytesStringIndex > 8000) {
			let str = `CHUNKS = CHUNKS or {};CHUNKS[#CHUNKS + 1] = "${bytesString.join("")}"`
			doString(str)
			bytesString = []
			bytesStringIndex = 0
		}
	}
	{
		let str = `CHUNKS = CHUNKS or {};CHUNKS[#CHUNKS + 1] = "${bytesString.join("")}"`
		doString(str)
	}

	let str = `
	local code = "package.preload['${moduleName}'] = function(...) " .. table.concat(CHUNKS) .. " end"
	assert(load(code, "${chunkName}"))(...); CHUNKS = nil
	`
	doString(str)
}

export const loadLuaWasmoon = async () => {


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


	await lua.doString(`
	_G.syntax_typesystem = require("nattlua.syntax.typesystem")
	_G.syntax_runtime = require("nattlua.syntax.runtime")
  `)

	const syntax_typesystem = lua.global.get("syntax_typesystem")
	const syntax_runtime = lua.global.get("syntax_runtime")
	const lsp = lua.global.get("lsp")
	console.log("Lua engine initialized successfully")
	return {
		syntax_typesystem,
		syntax_runtime,
		lsp,
		prettyPrint: (lua: LuaEngine, code: string) => {
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

	}
}

export const loadLuaInterop = async () => {
	const { newLua } = await getLuaInterop();
	let lua = await newLua({
		print: s => {
			console.log('>', s);
		},
		printErr: s => {
			console.log('1>', s);
			console.log(new Error().stack);
		},
	});
	lua.newState();

	globalThis.lua = lua

	let lsp: any
	globalThis.loadLSP = (obj) => lsp = obj

	let syntax_runtime: any
	globalThis.loadSyntaxRuntime = (obj) => syntax_runtime = obj

	let syntax_typesystem: any
	globalThis.loadSyntaxTypesystem = (obj) => syntax_typesystem = obj

	await loadLuaModule((str) => lua.doString(str), import("./../../build_output.lua"), "nattlua")
	await lua.doString("for k, v in pairs(package.preload) do print(k,v) end require('nattlua') for k,v in pairs(IMPORTS) do package.preload[k] = v end")
	await loadLuaModule((str) => lua.doString(str), import("./../../language_server/lsp.lua"), "lsp", "@language_server/lsp.lua")

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

		jsToLua[0].loadLSP(lsp)`)


	await lua.doString(`
		jsToLua[0].loadSyntaxRuntime(require("nattlua.syntax.typesystem"))
		jsToLua[0].loadSyntaxTypesystem(require("nattlua.syntax.runtime"))
  `)

	globalThis.syntax_typesystem = syntax_typesystem
	globalThis.syntax_runtime = syntax_runtime
	globalThis.lsp = lsp

	console.log("Lua interop initialized successfully")
	return {
		syntax_typesystem,
		syntax_runtime,
		lsp,
		prettyPrint: (lua: LuaEngine, code: string) => {
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

	}

}