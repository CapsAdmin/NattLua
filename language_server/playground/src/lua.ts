import { LuaFactory } from "wasmoon";
import { registerSyntax } from "./syntax";
import { loadLuaModule } from "./util";

export const loadLua = async () => {
  const factory = new LuaFactory();
  const lua = await factory.createEngine({
    openStandardLibs: true,
  });

  await loadLuaModule(lua, import("../../../build_output.lua"), "nattlua");
  await lua.doString(
    "for k, v in pairs(package.preload) do print(k,v) end require('nattlua') for k,v in pairs(IMPORTS) do package.preload[k] = v end"
  );
  await loadLuaModule(lua, import("./../../server/lsp.lua"), "lsp");

  await lua.doString(`
    local lsp = require("lsp")

    local calls = {}
    function lsp.Call(params)
      table.insert(calls, params)
    end

    function lsp.ReadCall()
      return table.remove(calls)
    end

    _G.lsp = lsp`);

  return lua;
};
