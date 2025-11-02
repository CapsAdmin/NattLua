--[[HOTRELOAD
	run_lua("test/tests/nattlua/c_declarations/preprocessor.lua")
]]
local Lexer = require("nattlua.definitions.lua.ffi.preprocessor.lexer").New
local Parser = require("nattlua.definitions.lua.ffi.preprocessor.parser").New
local Code = require("nattlua.code").New

-- Get GCC/C standard predefined macros
local function get_standard_defines()
	return {
		-- Standard C macros
		__STDC__ = 1,
		__STDC_VERSION__ = "201710L", -- C17
		__STDC_HOSTED__ = 1,
		-- GCC version (simulating GCC 4.2.1 for compatibility)
		__GNUC__ = 4,
		__GNUC_MINOR__ = 2,
		__GNUC_PATCHLEVEL__ = 1,
	-- Common architecture/platform detection
	-- Note: Users should override these based on their target platform
	-- __linux__ = 1,
	-- __unix__ = 1,
	-- __x86_64__ = 1,
	-- __LP64__ = 1,
	}
end

-- Main preprocessor function with options support
return function(code_or_options, options)
	local code, opts

	-- Handle both old and new calling conventions
	if type(code_or_options) == "string" then
		code = code_or_options
		opts = options or {}
	else
		opts = code_or_options or {}
		code = opts.code
	end

	-- Default options
	opts.working_directory = opts.working_directory or os.getenv("PWD") or "."
	opts.defines = opts.defines or {}
	opts.include_paths = opts.include_paths or {}
	opts.max_include_depth = opts.max_include_depth or 100
	opts.on_include = opts.on_include -- Optional callback for includes
	opts.system_include_paths = opts.system_include_paths or {}

	-- Merge standard defines with user defines (user defines take precedence)
	if opts.add_standard_defines ~= false then
		local standard_defines = get_standard_defines()

		for name, value in pairs(standard_defines) do
			if opts.defines[name] == nil then opts.defines[name] = value end
		end
	end

	-- Create Code and Lexer instances
	-- Create code object
	local code_obj = Code(code, opts.filename or "input.c")
	local tokens = Lexer(code_obj):GetTokens()
	local parser = Parser(tokens, code_obj)

	-- Add predefined macros
	for name, value in pairs(opts.defines) do
		if type(value) == "string" then
			-- Parse the value as tokens
			local value_tokens = Lexer(Code(value, "define")):GetTokens()

			-- Remove EOF token
			if value_tokens[#value_tokens] and value_tokens[#value_tokens].type == "end_of_file" then
				table.remove(value_tokens)
			end

			parser:Define(name, nil, value_tokens)
		elseif type(value) == "boolean" then
			if value then
				parser:Define(name, nil, {parser:NewToken("number", "1")})
			end
		else
			parser:Define(name, nil, {parser:NewToken("number", tostring(value))})
		end
	end

	-- Store options in parser for include handling
	parser.preprocess_options = opts
	parser.include_depth = 0
	-- Parse/preprocess
	parser:Parse()
	-- Return processed code
	return parser:ToString()
end
