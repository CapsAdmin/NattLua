-- http://unixwiz.net/techtips/reading-cdecl.html
-- https://eli.thegreenplace.net/2007/11/24/the-context-sensitivity-of-cs-grammar/
-- http://benno.id.au/blog/2011/03/10/c-declarations
-- https://c-faq.com/decl/spiral.anderson.html
-- https://cdecl.org/
--[[
	
lj_cparse.c order of parsing

	read attributes:
		const, volatile, restrict, extension, attribute, asm, declspec, ccdecl
		if first, goto end_decl

	try read struct
	try read union
	try read enum
	try read identifier
	try read $

	cp_declarator:
		try *
			read attributes:
		
		try (
			if abstract read function

			cp_declarator
			expect )
		
		try identifier -- direct declarator
		try 
		

]]
if false then
	--[=[
            unsigned long long * (* (* *NAME [1][2])(char *))[3][4];
			|                  | \| \| |NAME is               |  |
			|                  |  |  | |     [1] array1       |  |      
			|                  |  |  | |        [2] of array2 |  | 
			|				   |  |  | * pointer to           |  | 
			|			       |  |  (* pointer to function(char *) returning
			|				   | (* a pointer to              |  |
			|				   |                             [3] array3 of
			|		           |                                [4] array4 of
			|				   * pointing to
			unsigned long long
									
			array1 of array2 of pointer to pointer to function (pointer to char) returning pointer to array3 of array4 of pointer to unsigned long long

											

			unsigned long long * (* (* *NAME |[1][2])(char *))[3][4];
											 |array1
		it's read in the following order:

			#                                                           unsigned long long  #                                   
			#                                                        *  |                   #                 
			#                                                        |  |                   #                 
			#                                       (*               |  |                   #                 
			#                                        |               |  |                   #                 
			#                        (*              |               |  |                   #                 
			#                     *   |              |               |  |                   #                 
			# 1 NAME  2    3      4   5  6           7  8     9     10  11                  #                  
			#         [1]  |             |              |     |                             #       
			#              [2]           |              |     |                             #       
			#                            |              |     |                             #       
			#                            (char *)))     |     |                             #       
			#                                           |     |                             #       
			#                                           [3]   |                             #       
			#                                                 [4]                           #          
		-------
        the above but collapsed in lines:
            NAME = [1][2]**( function( *char )( *[3][4]* unsigned long long ) )
		
		-------
		array1 of array2 of pointer to pointer to function (pointer to char) returning pointer to array3 of array4 of pointer to unsigned long long
		human description:
			array1 of			
				array2 of 
					pointer to 
						pointer to 
							(function(pointer to char)  
								pointer to
									array3 of 
										array4 of 
										pointer to 
										unsigned long long
							)

		
    ]=]
	local NAME = Array1(
		Array2(
			Pointer(
				Pointer(Function({Pointer(char)}, Pointer(Array3(Array4(Pointer("unsigned long long"))))))
			)
		)
	)
	local NAME = Array1(
		Array2(
			Pointer(
				Pointer(
					Function(
						-- arguments
						{Pointer(char)},
						-- return type
						Pointer(Array3(Array4(Pointer("unsigned long long"))))
					)
				)
			)
		)
	)
end

local Lexer = require("nattlua.c_declarations.lexer").New
local Parser = require("nattlua.c_declarations.parser").New
local Emitter = require("nattlua.c_declarations.emitter").New
local Code = require("nattlua.code").New
local Compiler = require("nattlua.compiler")
local type = _G.type
local pairs = _G.pairs

do
	local blacklist = {
		code_start = true,
		code_stop = true,
		parent = true,
		environment = true,
		Buffer = true,
		Code = true,
	}
	local priority = {
		"tokens",
		"modifiers",
		"pointers",
	}

	local function write(state, str, index)
		str = ("\t"):rep(state.level) .. str

		if index then
			table.insert(state.buffer, index, str)
		else
			table.insert(state.buffer, str)
		end
	end

	local function print_field(state, tbl, k, v)
		if blacklist[k] then return end

		write(state, k .. " = " .. tostring(v) .. "\n")
	end

	local print_node_internal

	local function print_kv(state, k, v)
		if not blacklist[k] and not state.done[v] and type(v) == "table" and next(v) then
			write(state, k .. ": \n")
			state.level = state.level + 1
			state.done[v] = true
			print_node_internal(state, v, k)
			state.level = state.level - 1
			write(state, "\n")
		end
	end

	function print_node_internal(state, node, k)
		if type(node) == "table" then
			-- token
			if node.is_whitespace == false then
				write(state, tostring(node))
				return
			end

			if k == "tokens" then
				local tokens = {}

				for i, v in pairs(node) do
					table.insert(tokens, i .. "=" .. tostring(v.value))
				end

				write(state, table.concat(tokens, " "))
				return
			end
		end

		for k, v in pairs(node) do
			if type(v) ~= "table" then print_field(state, node, k, v) end
		end

		for _, key in ipairs(priority) do
			if node[key] ~= nil then print_kv(state, key, node[key]) end
		end

		for k, v in pairs(node) do
			print_kv(state, k, v)
		end
	end

	_G.print_node = function(node)
		local state = {level = 0, buffer = {}, done = {}}
		print_node_internal(state, node)
		print(table.concat(state.buffer))
	end
end

local name_id = 0
local field_id = 0
local var_id = 0

local function test(c_code, error_level)
	error_level = error_level or 2
	local start, stop = c_code:find("%%%b{}")

	if start then
		local pattern = c_code:sub(start, stop):sub(3, -2)

		for what in (pattern .. "|"):gmatch("([^|]-)%|") do
			test(c_code:sub(1, start - 1) .. what .. c_code:sub(stop + 1), error_level + 1)
		end

		return
	end

	local using_name = false
	local using_field = false
	local using_var = false
	c_code = c_code:gsub("NAME", function()
		name_id = name_id + 1
		using_name = true
		return "NAME" .. name_id
	end)
	c_code = c_code:gsub("FIELD", function()
		field_id = field_id + 1
		using_field = true
		return "FIELD" .. field_id
	end)
	c_code = c_code:gsub("TYPE", function()
		var_id = var_id + 1
		using_var = true
		return "TYPE" .. var_id
	end)

	if jit then
		local ffi = require("ffi")
		ffi.cdef(c_code)
	end

	local code = Code(c_code, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	local parser = Parser(tokens, code)
	parser.OnError = function(parser, code, msg, start, stop, ...)
		_G.TEST = true
		Compiler.OnDiagnostic({}, code, msg, "fatal", start, stop, nil, ...)
		_G.TEST = false
	end
	local ast = parser:ParseRootNode()

	if ast.statements[2].kind == "end_of_file" then
		local node = ast.statements[1]

		if using_name then
			if not node.tokens["potential_identifier"] then
				print_node(node)
				print(c_code)
				error("unable to find name", error_level)
			end

			if not node.tokens["potential_identifier"].value:find("NAME") then
				print_node(node)
				print(c_code)
				error("name is not right " .. node.tokens["potential_identifier"].value, error_level)
			end
		end
	end

	do -- check if we stored all tokens into the ast
		local function find_all_tokens(tbl, out, done)
			done = done or {}

			for _, v in pairs(tbl) do
				if type(v) == "table" then
					if v.type ~= "statement" and v.type ~= "expression" and v.value then
						out[v] = v
					else
						if not done[v] then
							done[v] = true
							find_all_tokens(v, out, done)
						end
					end
				end
			end
		end

		local found = {}
		find_all_tokens(ast, found)

		for _, token in ipairs(tokens) do
			if not found[token] then
				error(
					code:BuildSourceCodePointMessage(
						"token " .. tostring(token) .. " was not consumed anywhere",
						token.start,
						token.stop
					),
					error_level
				)
			end
		end
	end

	local emitter = Emitter({skip_translation = true})
	local res = emitter:BuildCode(ast)

	if res ~= c_code then
		print_node(ast)
		print("expected\n", c_code)
		print("got\n", res)
		diff(c_code, res)
		error("UH OH", error_level)
	end

	if ast.statements[2].kind == "end_of_file" then return ast.statements[1] end

	return ast
end

local function test_field(code)
	test([[ %{struct|union} TYPE { ]] .. code .. [[ }; ]])
end

local function test_anon(code)
	test([[
        void NAME(
            ]] .. code .. [[
        );
    ]], 3)
end

local function check_error(func, c_code, expect)
	local ok, err = pcall(func, c_code)

	if not ok then if not expect or err:find(expect) then return end end

	error("expected error", 2)
end

do -- functions
	do -- plain
		-- it's a normal function declaration if NAME is directly followed by a ( or a )(
		do -- equvilent function returning void
			test([[void NAME();]])
			test([[void (NAME)();]])
		end

		-- attributes
		test([[ long long NAME(); ]])
		test([[ void __attribute__((stdcall)) NAME(); ]])
		test([[ long long __attribute__((stdcall)) NAME(); ]])
		test([[ void __fastcall NAME(); ]])

		do -- pointers
			test[[ void (*NAME()) ;]]
			test[[ void (**NAME()) ;]]
			test[[ void (** volatile NAME()) ;]]
			test[[ void (* volatile * volatile NAME()) ;]]
			test[[ void __ptr32**NAME() ;]]
			test[[ void (__ptr32**NAME()) ;]]
			test[[ void (__stdcall*NAME()) ;]]
		end

		test[[ void NAME(int (*ARG)(int, long)) ;]] -- tricky
		test[[ void (*NAME())() ;]] -- function returning pointer to function returning void
		test([[ int (*NAME())[5] ;]]) -- function returning pointer to an array of 5 ints
		test([[ void (**NAME())() ;]]) -- function returning pointer to pointer to function returning void
		test([[ void NAME(int (*ARG)(const uint8_t *, const uint8_t *)); ]])
		test([[ void NAME() asm("test"); ]])
	end

	do -- pointers
		-- it's a function pointer if NAME is directly followed by a (* or (KEYWORD*
		do -- equivilent pointer to function returning void
			test([[ void (*NAME)() ;]])
			test([[ void (*(NAME))() ;]])
		end

		test([[ void (__stdcall*NAME)(); ]])
		test([[ void (__cdecl*NAME)(); ]])
		test([[ void (__attribute__((stdcall))*NAME)(); ]])
		test([[ void (__attribute__((stdcall))__ptr32*NAME)(); ]])
		test([[ void (__attribute__((__cdecl))*NAME)(); ]])
		test([[ void (__stdcall*(NAME))(); ]])
		test([[ void (__cdecl*(NAME))(); ]])
		test([[ void (__attribute__((stdcall))*(NAME))(); ]])
		test([[ void (__attribute__((__cdecl))*(NAME))(); ]])

		do -- equivilent pointer to pointer to function returning void
			test([[ void (**NAME)(); ]])
			test([[ void (*(*NAME))(); ]])
		end

		test([[ void (* volatile NAME)(); ]]) -- pointer to a volatile void function
		test([[ void (* volatile * NAME)(); ]]) -- pointer to a volatile pointer to a void function
		test([[ void (__ptr32*__ptr32*NAME)(); ]]) -- 32bit pointer to a 32bit pointer to a void function
		test([[ void (*(*NAME)())(); ]]) -- pointer to function returning pointer to function returning void
		test([[ int (*(*NAME)())[5]; ]]) -- pointer to function returning pointer to array 5 of int
		do -- abstract
			test_anon([[ void (*)() ]])

			do -- function returning pointer to function returning void
				test_anon([[ void (*())() ]])
				test_anon([[ void ((*()))() ]])
			end

			-- pointer to function returning pointer to function returning void
			test_anon([[ void (*(*)())() ]])
		end
	end
end

do -- return types
	test[[ struct {int FIELD;} const NAME(); ]]
	test[[ struct {int FIELD;} const static NAME(); ]]
end

do -- function arguments
	test_anon([[ int ]])
	test_anon([[ int, int ]])
	test_anon([[ int ARG ]])
	test_anon([[ int ARG, int ARG ]])
	test_anon([[ int ARG, int ]])
	test_anon([[ void(*)(), void(*)() ]])
	test_anon([[ void(*)(int, int), void(*)(int, int) ]])
	test_anon([[ void(*)(int, int), void(*)(void(*)(int, int), void(*)(int, int)) ]])
	test_anon([[ int ARG, ... ]])
	test_anon([[ char *, short * ]])
-- test_anon([[ ..., void ]])
-- test_anon([[ void, void ]])
end

do -- arrays
	do -- http://unixwiz.net/techtips/reading-cdecl.html
		do
			-- long
			test([[ long NAME; ]])
			-- array 7 of long
			test([[ long NAME[7]; ]])
			-- array 7 of pointer to long
			test[[ long *NAME[7]; ]]
			-- array 7 of pointer to pointer to long
			test[[ long **NAME[7]; ]]
		end

		do
			-- char
			test([[ char NAME; ]])
			-- array of char
			test([[ char NAME[]; ]])
			-- array of array 8 of char
			test([[ char NAME[][8]; ]])
			-- array of array 8 of pointer to char
			test([[ char *NAME[][8]; ]])
			-- array of array 8 of pointer to pointer to char
			test([[ char **NAME[][8]; ]])
			-- array of array 8 of pointer to pointer to function returning char
			test([[ char (**NAME[][8])(); ]])
			-- array of array 8 of pointer to pointer to function returning pointer to char 
			test([[ char *(**NAME[][8])(); ]])
			-- array of array 8 of pointer to pointer to function returning pointer to array of char 
			test([[ char (*(**NAME[][8])())[]; ]])
			-- array of array 8 of pointer to pointer to function returning pointer to array of pointer to char 
			test([[ char *(*(**NAME[][8])())[]; ]])
		end
	end

	-- pointer to array 5 of pointer to function returning void
	test([[ void (*(*NAME)[5])() ;]])
	-- array of 5 pointers to void functions
	test([[ void (*NAME[5])() ;]])
	-- array of 5 pointers to pointers to void functions
	test([[ void (**NAME[5])() ;]])
	-- array of array 8 of pointer to function returning pointer to array of pointer to char
	test([[ char *(*(*NAME[][8])())[]; ]])
	-- array of array 8 of pointer to function returning pointer to array of array of pointer to char
	test([[ char *(*(*NAME[][8])())[][8]; ]])
	-- array of array 8 of pointer to function returning pointer to function returning char
	test([[ char (*(*NAME[][8])())(); ]])
	-- array of array 8 of pointer to function returning pointer to function returning pointer to char
	test([[ char *(*(*NAME[][8])())(); ]])
	-- array 2 of array 8 of pointer to pointer to function (pointer to char) returning pointer to array of pointer to long
	test([[ long int unsigned long *(*(**NAME [2][8])(char *))[]; ]])
	-- array 7 of pointer to pointer to long
	test([[ long int unsigned long **NAME[7]; ]])
	test_anon[[ int ARG[1+2] ]]
	test_anon[[ int ARG[1+2*2] ]]
	test_anon[[ int ARG[1<<2] ]]
	test_anon[[ int ARG[sizeof(int)] ]]
	test_anon(" int [10][5] ")
	test_anon(" int [10][5][3][2][7] ")
	test_anon(" int ([10])[5] ")
	test_anon(" int *[10] ")
	test_anon(" int (*)[10] ")
	test_anon(" int (*[5])[10] ")
	test_anon(" struct { int x; char y; } [10] ")
	test_anon(" volatile int *(* const *[5][10])(void) ")
	test_anon(" int [] ")
	test_anon(" int __attribute__((aligned(8))) [10] ")
	test_anon(" __attribute__((aligned(8))) int [10] ")
	test_anon(" int [10] __attribute__((aligned(8))) ")
	test_anon(" char ['a'] ")
	test_anon(" char ['\\123'] ")
	test_anon(" char ['\x4F'] ")
	test_anon(" char [sizeof(\"aa\" \"bb\")] ")
	test_anon(" char [15 * sizeof(int) - 4 * sizeof(void * ) - sizeof(size_t)] ")
--test_anon[[ int a[1?2:3] ]] -- TODO
end

do -- struct and union declarations
	test([[ %{struct|union} TYPE; ]]) -- forward declaration
	test([[ %{struct|union} TYPE { int FIELD; }; ]]) -- single field
	test([[ %{struct|union} TYPE { int FIELD, FIELD; }; ]]) -- multiple fields of same type
	test([[ %{struct|union} TYPE { int FIELD: 1, FIELD: 1; }; ]]) -- multiple fields of same type with bitfield
	test([[ %{struct|union} TYPE { char FIELD, *FIELD, **FIELD, FIELD: 1; }; ]])

	do -- anonymous
		test([[ %{struct|union} TYPE { %{struct|union} { int FIELD; }; }; ]])
		test([[ %{struct|union} TYPE { %{struct|union} { int FIELD; }; int FIELD; }; ]]) -- anonymous
		test([[ %{struct|union} TYPE { %{struct|union} { int FIELD; } FIELD; }; ]]) -- anonymous in field
	end

	test([[ %{struct|union} TYPE { %{struct|union} TYPE { int FIELD; } FIELD; }; ]]) -- declared in field
	do -- complex fields
		-- repeat the above maybe?
		test_field[[ char FIELD; ]]
		test_field[[ char FIELD: 1; ]]
		test_field[[ const int FIELD:8; ]]
		test_field[[ char FIELD: +1+1; ]]
		test_field[[ long **FIELD[7]; ]]
		test_field[[ uint8_t __attribute__((mode(__V16QI__))) FIELD; ]]
		test_field[[ uint8_t __attribute__((mode(__V16QI__))) FIELD[2]; ]]
		test_field[[ static const int FIELD = 17; ]]
		test_field[[ enum { FIELD = -37 }; ]] -- doesn't have a meaning
		test_field[[ enum { FIELD = -37 } FIELD; ]] -- doesn't have a meaning
		test_field[[ int FIELD[10]; ]]
		test_field[[ const int FIELD[10]; ]]
		test_field[[ int FIELD, FIELD; ]]
		test_field[[ uint8_t __attribute__((mode(__V16QI__))) FIELD; ]]
		test_field[[ int __attribute__((mode(__V4SI__))) FIELD; ]]
		test_field[[ double __attribute__((mode(__V2DF__))) FIELD; ]]
		test_field[[ const int **FIELD; ]]
		test_field[[ void **FIELD; ]]
		test_field[[ char *(*FIELD)(char *, const char *); ]]
		test_field[[ int *__ptr32 FIELD; ]]
		test_field[[ volatile int *FIELD; ]]
		test_field[[ int **FIELD; ]]
		check_error(test_field, [[ int FIELD ]], ";")
	end

	test[[ struct TYPE { char *(*(**FIELD[][8])())[]; }; ]]
	test([[ %{struct|union} NAME(NAME)( %{struct|union} NAME);]])
	test[[ int foo ]] -- a single statement is allowed not to have a semicolon
	check_error(test, [[ int foo; int foo ]], ";") -- but 2 statements and above must all have semicolons 
end

do -- enum
	local function test_field(code)
		test([[ enum TYPE { ]] .. code .. [[ }; ]])
	end

	test[[ enum TYPE; ]] -- forward declaration
	test[[ enum TYPE { FIELD }; ]] -- single field
	test[[ enum TYPE { FIELD, }; ]] -- single field with trailing comma
	test[[ enum TYPE { FIELD, FIELD }; ]] -- multiple fields
	test[[ enum TYPE { FIELD, FIELD, }; ]] -- multiple fields with trailing comma
	do -- complex fields
		test_field[[ FIELD = 17  , FIELD = 37,   FIELD = 42  ]]
		test_field[[ FIELD = 17  , FIELD, 		 FIELD       ]]
		test_field[[ FIELD = 17  , FIELD, 		 FIELD = 42  ]]
		test_field[[ FIELD = 17  , FIELD = 37,   FIELD 		 ]]
		test_field[[ FIELD = 17+1, FIELD = 37+2, FIELD = 2*5 ]]
	end
end

do -- typedef and variable declarations
	test[[ %{typedef|} %{struct|union|enum} TYPE NAME; ]]
	test[[ %{typedef|} %{struct|union|enum} TYPE NAME, NAME; ]]
	test[[ %{typedef|} enum TYPE { FIELD } NAME; ]]
	test[[ %{typedef|} enum TYPE { FIELD } NAME, NAME; ]]
	test[[ %{typedef|} enum TYPE { FIELD } *NAME; ]]
	test[[ %{typedef|} enum TYPE { FIELD } *NAME, *NAME; ]]
	test[[ %{typedef|} %{struct|union} TYPE { int FIELD; } NAME; ]]
	test[[ %{typedef|} %{struct|union} TYPE { int FIELD; } NAME, NAME; ]]
	test[[ %{typedef|} %{struct|union} TYPE { int FIELD; } *NAME; ]]
	test[[ %{typedef|} %{struct|union} TYPE { int FIELD; } *NAME, *NAME; ]]
	test[[ %{typedef|} int NAME; ]] -- NAME becomes int
	test[[ %{typedef|} int NAME, NAME; ]] -- NAME and NAME become int
	test[[ %{typedef|} int NAME, *NAME; ]] -- NAME becomes int and NAME becomes int *
	test[[ %{typedef|} int (*NAME)(int); ]] -- NAME becomes int (*)(int)
	test[[ %{typedef|} int (*NAME)(int), NAME; ]] -- NAME becomes int (*)(int) and NAME becomes int
	test[[ %{typedef|} int * const NAME; ]]
	test[[ %{typedef|} const int * NAME; ]]
	test[[ int *NAME, NAME, NAME[1], (*NAME)(void), NAME(void); ]]
	test[[ static const int NAME = 1; ]]
	test[[ static const int NAME = 1, NAME = 2; ]]
end

if jit then
	-- TODO: cast and struct lookup, not standard C
	local ffi = require("ffi")
	ffi.cdef[[
        struct STRUCT {
            enum { K_99 = 99 };
            static const int K_55 = 55;
        } VAR;
        char a[K_99];
        char b[VAR.K_99];
        char c[((struct STRUCT)0).K_99];
        char d[((struct STRUCT *)0)->K_99];
        char e[VAR.K_55];
    ]]
end
