local io = require("io")
local diff = require("nattlua.other.diff")
local Table = require("nattlua.types.table").Table
local debug = require("debug")
local pcall = _G.pcall
local type = _G.type
local ipairs = _G.ipairs
local xpcall = _G.xpcall

function _G.test(name, cb, start, stop)
	if start and stop then
		local ok_start, err_start = xpcall(start, debug.traceback)
		local ok_cb, err_cb = xpcall(cb, debug.traceback)
		local ok_stop, err_stop = xpcall(stop, debug.traceback)

		-- Report errors in priority order, but only after all functions have run
		if not ok_start then
			error(string.format("Test '%s' setup failed: %s", name, err_start), 2)
		elseif not ok_cb then
			error(string.format("Test '%s' failed: %s", name, err_cb), 2)
		elseif not ok_stop then
			error(string.format("Test '%s' teardown failed: %s", name, err_stop), 2)
		end
	else
		-- If setup/teardown not provided, just run the test
		local ok_cb, err_cb = xpcall(cb, debug.traceback)

		if not ok_cb then
			error(string.format("Test '%s' failed: %s", name, err_cb), 2)
		end
	end
end

function _G.pending(...) end

function _G.equal(a, b, level)
	level = level or 1

	if a ~= b then
		if type(a) == "string" then a = string.format("%q", a) end

		if type(b) == "string" then b = string.format("%q", b) end

		error("\n" .. tostring(a) .. "\n~=\n" .. tostring(b), level + 1)
	end
end

function _G.diff(input, expect)
	print(diff.diff(input, expect))
end

do
	-- reuse an existing environment to speed up tests
	local BuildBaseEnvironment = require("nattlua.base_environment").BuildBaseEnvironment
	local runtime_env, typesystem_env = BuildBaseEnvironment()
	local nl = require("nattlua")

	function _G.analyze(code, expect_error, expect_warning)
		local info = debug.getinfo(2)
		local name = info.source:match("(test/tests/.+)") or info.source

		if not _G.HOTRELOAD then
			io.write(".")
			io.flush()
		end

		_G.TEST = true
		local compiler = nl.Compiler(code, nil, nil, 3)
		compiler:SetEnvironments(Table({}), typesystem_env)
		_G.TEST_GARBAGE = {}
		local ok, err = compiler:Analyze()
		do
			local tbl = {}
			for k,v in pairs(_G.TEST_GARBAGE) do
				tbl[k:GetHash()] = v
			end
			
			for hash, v in pairs(tbl) do
				if v and v.Type == "symbol" and v:IsNil() then
					tbl[hash] = nil
				end
			end

			if next(tbl) then
				table.print(tbl)
				error("garbage not collected", 2)
			end
		end


		_G.TEST = false

		if expect_warning then
			local str = ""

			for _, diagnostic in ipairs(compiler.analyzer:GetDiagnostics()) do
				if diagnostic.msg:find(expect_warning) then return compiler end

				str = str .. diagnostic.msg .. "\n"
			end

			if str == "" then error("expected warning, got\n\n\n" .. str, 2) end

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

		return compiler.analyzer, compiler.SyntaxTree, compiler.AnalyzedResult
	end
end
