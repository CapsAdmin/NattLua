local nl = require("nattlua")
local Union = require("nattlua.types.union").Union
local Tuple = require("nattlua.types.tuple").Tuple
local Number = require("nattlua.types.number").Number
local LNumber = require("nattlua.types.number").LNumber
local LString = require("nattlua.types.string").LString
local String = require("nattlua.types.string").String
local Symbol = require("nattlua.types.symbol").Symbol

local helpers = {}

do
	local function cast(...)
		local ret = {}

		for i = 1, select("#", ...) do
			local v = select(i, ...)
			local t = type(v)

			if t == "number" then
				ret[i] = LNumber(v)
			elseif t == "string" then
				ret[i] = LString(v)
			elseif t == "boolean" then
				ret[i] = Symbol(v)
			else
				ret[i] = v
			end
		end

		return ret
	end

	function helpers.Union(...)
		return Union(cast(...))
	end

	function helpers.Tuple(...)
		return Tuple(cast(...))
	end
end

do
	-- reuse an existing environment to speed up tests
	local BuildBaseEnvironment = require("nattlua.runtime.base_environment").BuildBaseEnvironment
	local runtime_env, typesystem_env = BuildBaseEnvironment()

	function helpers.RunCode(code, expect_error, expect_warning)
		local info = debug.getinfo(2)
		local name = info.source:match("(test/nattlua/.+)") or info.source

		if not _G.ON_EDITOR_SAVE then
			io.write(".")
			io.flush()
		end

		_G.TEST = true
		local compiler = nl.Compiler(code, nil, nil, 3)
		compiler:SetEnvironments(runtime_env:Copy(), typesystem_env)
		local ok, err = compiler:Analyze()
		_G.TEST = false

		if expect_warning then
			local str = ""

			for _, diagnostic in ipairs(compiler.analyzer:GetDiagnostics()) do
				if diagnostic.msg:find(expect_warning) then return compiler end

				str = str .. diagnostic.msg .. "\n"
			end

			if str == "" then error("expected warning, got\n\n\n" .. str, 3) end

			error("expected warning '" .. expect_warning .. "' got:\n>>\n" .. str .. "\n<<", 3)
		end

		if expect_error then
			if not err or err == "" then
				error(
					"expected error, got nothing\n\n\n[" .. tostring(ok) .. ", " .. tostring(err) .. "]",
					3
				)
			elseif type(expect_error) == "string" then
				if not err:find(expect_error) then
					error("expected error '" .. expect_error .. "' got:\n>>\n" .. err .. "\n<<", 3)
				end
			elseif type(expect_error) == "function" then
				local ok, msg = pcall(expect_error, err)

				if not ok then
					error("error did not pass: " .. msg .. "\n\nthe error message was:\n" .. err, 3)
				end
			else
				error("invalid expect_error argument", 3)
			end
		else
			if not ok then error(err, 3) end
		end

		return compiler.analyzer, compiler.SyntaxTree
	end
end

function helpers.Transpile(code)
	return helpers.RunCode(code):Emit({type_annotations = true})
end



return helpers