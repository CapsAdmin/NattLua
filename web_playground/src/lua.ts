interface LuaInterop {
	newState: () => void;
	doString: (s: string, ...any) => any;
}

type NewLuaFunc = (args?: Record<string, any>) => Promise<LuaInterop>;

let newLuaPromise: Promise<{ newLua: NewLuaFunc }> | null = null;

async function getLuaInterop(): Promise<{ newLua: NewLuaFunc }> {
	if (!newLuaPromise) {
		newLuaPromise = new Promise((resolve, reject) => {
			const script = document.createElement('script');
			script.src = window.location.href + '/lua-interop.js';
			script.type = 'module';

			script.onload = () => {
				if (window.newLua) {
					resolve({ newLua: window.newLua });
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
	}

	return newLuaPromise;
}

declare global {
	interface Window {
		newLua?: NewLuaFunc;
	}
}


const loadLuaModule = async (lua: LuaInterop, p: Promise<{ default: string }>, moduleName: string, chunkName?: string) => {
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

export const loadLuaInterop = async () => {
	const { newLua } = await getLuaInterop();
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

	globalThis.lua = lua

	await loadLuaModule(lua, import("./../../build_output.lua"), "nattlua")
	await lua.doString("for k, v in pairs(package.preload) do print(k,v) end require('nattlua') for k,v in pairs(IMPORTS) do package.preload[k] = v end")
	await loadLuaModule(lua, import("./../../language_server/lsp.lua"), "lsp", "@language_server/lsp.lua")
	await loadLuaModule(lua, import("./../../language_server/json.lua"), "json", "@language_server/json.lua")

	const [lsp] = await lua.doString(`
		local lsp = require("lsp")
		local json = require("json")

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


	const [syntax_runtime_json] = await lua.doString(`return require("json").encode(require("nattlua.syntax.runtime"))`)
	const [syntax_typesystem_json] = await lua.doString(`return require("json").encode(require("nattlua.syntax.typesystem"))`)
	const syntax_runtime = JSON.parse(syntax_runtime_json)
	const syntax_typesystem = JSON.parse(syntax_typesystem_json)
	const [prettyPrintFunc] = await lua.doString(`
		return function(code)
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
	console.log("Lua interop initialized successfully")
	return {
		syntax_typesystem,
		syntax_runtime,
		lsp,
		prettyPrint: (code: string) => prettyPrintFunc(code)[0] as string,

	}

}