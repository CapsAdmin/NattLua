import { mapsToArray } from "./util";

interface LuaInterop {
	newState: () => void;
	doString: (s: string, ...any) => any;
}

interface Syntax {
	Keywords: { [key: string]: string }
	NonStandardKeywords: { [key: string]: string }
	PrefixOperators: { [key: string]: string }
	BinaryOperators: { [key: string]: string }
	PostfixOperators: { [key: string]: string }
	PrimaryBinaryOperators: { [key: string]: string }
	SymbolPairs: { [key: string]: string }
}

const loadModule = async (lua: LuaInterop, p: Promise<{ default: string }>, moduleName: string, chunkName?: string) => {
	let { default: code } = await p

	if (code.startsWith("#")) {
		// remove shebang
		const index = code.indexOf("\n")
		if (index !== -1) {
			code = code.substring(index)
		}
	}

	// There seems to be a limit on how large the string can be somewhere.

	const bytes = (new TextEncoder()).encode(code)
	let bytesString: string[] = []
	let bytesStringIndex = 0
	for (let i = 0; i < bytes.length; i++) {
		let code = bytes[i]
		bytesString[bytesStringIndex] = `\\${code}`
		bytesStringIndex++
		if (bytesStringIndex > 8000) {
			lua.doString(`CHUNKS = CHUNKS or {};CHUNKS[#CHUNKS + 1] = "${bytesString.join("")}"`)
			bytesString = []
			bytesStringIndex = 0
		}
	}
	{
		lua.doString(`CHUNKS = CHUNKS or {};CHUNKS[#CHUNKS + 1] = "${bytesString.join("")}"`)
	}

	lua.doString(`
		local code = "package.preload['${moduleName}'] = function(...) " .. table.concat(CHUNKS) .. " end"
		assert(load(code, "${chunkName}"))(...)
		CHUNKS = nil
	`)
}

const initLanguageServer = async () => {
	const { newLua } = await new Promise<{ newLua: (args?: Record<string, any>) => Promise<LuaInterop> }>((resolve, reject) => {
		const script = document.createElement('script');
		script.src = window.location.href + '/lua-interop.js';
		script.type = 'module';

		script.onload = () => {
			let g = window as any;
			if (g.newLua) {
				resolve({ newLua: g.newLua });
			} else {
				import(window.location.href + '/lua-interop.js' as string)
					.then(module => {
						resolve(module);
					})
					.catch(error => {
						reject(new Error(`Failed to import lua-interop.js: ${error.message}`));
					});
			}
		};

		script.onerror = () => {
			reject(new Error('Failed to load lua-interop.js'));
		};

		document.head.appendChild(script);
	});

	let lua = await newLua({
		luaJSPath: window.location.href + "/lua-5.4.7-with-ffi.js",
		locateFile: () => window.location.href + "/lua-5.4.7-with-ffi.wasm",
		print: s => {
			console.log('>', s);
		},
		printErr: s => {
			console.log('1>', s);
			console.log(new Error().stack);
		},
	});
	lua.newState();

	return lua
}

export const startLanguageServer = async () => {

	const lua = await initLanguageServer()
	globalThis.lua = lua

	const dostring = (code: string, ...args: any[]) => {
		const ret = lua.doString(code, ...args)
		if (Array.isArray(ret)) {
			return ret[0]
		}
		return undefined
	}


	await loadModule(lua, import("./../../build_output.lua"), "nattlua")

	dostring(`require('nattlua')`)

	const lsp = dostring(`
		local lsp = require("language_server.lsp")
		local json = require("language_server.json")

		local listeners = {}

		function lsp.Call(data)
			assert(data.method, "missing method")
			listeners[data.method](data.params)
		end

		function lsp.On(method, callback)
			-- callback is js function, first argument is "this"
			listeners[method] = function(params) 
				params = json.encode(params)
 				return callback(nil, params) 
			end 

			return function()
				listeners[method] = nil
			end
		end

		for k,v in pairs(lsp.methods) do
			lsp.methods[k] = function(params)
				params = json.decode(params)
				print("calling on server", k, params)
				local ok, res = xpcall(function()
					return v(params)
				end, debug.traceback)
				if not ok then
					error(res, 2)
				end
				return res
			end
		end
		return lsp
	`)

	const syntax_runtime = JSON.parse(dostring(`return require("language_server.json").encode(require("nattlua.syntax.runtime"))`)) as Syntax
	const syntax_typesystem = JSON.parse(dostring(`return require("language_server.json").encode(require("nattlua.syntax.typesystem"))`)) as Syntax

	const syntax = {
		keywords: mapsToArray([syntax_runtime.Keywords, syntax_runtime.NonStandardKeywords]),
		typeKeywords: mapsToArray([syntax_typesystem.Keywords, syntax_typesystem.NonStandardKeywords]).concat(["string", "any", "nil", "boolean", "number"]),
		operators: mapsToArray([
			syntax_runtime.PrefixOperators,
			syntax_runtime.BinaryOperators,
			syntax_runtime.PostfixOperators,
			syntax_runtime.PrimaryBinaryOperators,
			syntax_typesystem.PrefixOperators,
			syntax_typesystem.BinaryOperators,
			syntax_typesystem.PostfixOperators,
			syntax_typesystem.PrimaryBinaryOperators,
		]),

		brackets: [] as [string, string][],
		autoClosingPairs: [] as { open: string, close: string }[],
		surroundingPairs: [] as { open: string, close: string }[],
	}

	for (let [l, r] of Object.entries(syntax_runtime.SymbolPairs as { [key: string]: string })) {
		syntax.brackets.push([l, r])
		syntax.autoClosingPairs.push({ open: l, close: r })
		syntax.surroundingPairs.push({ open: l, close: r })
	}


	const prettyPrintFunc = dostring(`
		local nl = require("nattlua")
		return function(code)
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
	const formatLuaCode = (code: string) => {
		return prettyPrintFunc(code)[0] as string;
	}

	const callFunction = (method: string, params: any) => {
		console.log("lsp.methods['", method, "'](", params, ")")
		let [response] = lsp.methods[method](JSON.stringify(params))
		console.log("\tgot", response)
		return response
	}

	const onMessage = (method: string, callback: (params: any) => void) => {
		return lsp.On(method, (params) => {
			params = JSON.parse(params)
			console.log("received", method, params)
			callback(params)
		}) as () => void;
	}

	return {
		syntax,
		callFunction,
		onMessage,
		formatLuaCode,

	}

}