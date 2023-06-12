-- http://unixwiz.net/techtips/reading-cdecl.html
-- https://eli.thegreenplace.net/2007/11/24/the-context-sensitivity-of-cs-grammar/
local Lexer = require("nattlua.c_declarations.lexer").New
local Parser = require("nattlua.c_declarations.parser").New
local Emitter = require("nattlua.c_declarations.emitter").New
local Code = require("nattlua.code").New
local Compiler = require("nattlua.compiler")
local name_id = 0
local field_id = 0

do
	local blacklist = {
		code_start = true,
		code_stop = true,
		parent = true,
		environment = true,
		Buffer = true,
		Code = true,
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

	local function print_node_internal(state, node, k)
		if type(node) == "table" then
			-- token
			if node.is_whitespace == false then
				write(state, tostring(node))
				return
			end

			if k == "tokens" then
				local tokens = {}

				for i, v in pairs(node) do
					table.insert(tokens, tostring(v.value))
				end

				write(state, table.concat(tokens, " "))
				return
			end
		end

		for k, v in pairs(node) do
			if type(v) ~= "table" then print_field(state, node, k, v) end
		end

		for k, v in pairs(node) do
			if not blacklist[k] and not state.done[v] and type(v) == "table" and next(v) then
				write(state, k .. ": \n")
				state.level = state.level + 1
				state.done[v] = true
				print_node_internal(state, v, k)
				state.level = state.level - 1
				write(state, "\n")
			end
		end
	end

	_G.print_node = function(node)
		local state = {level = 0, buffer = {}, done = {}}
		print_node_internal(state, node)
		print(table.concat(state.buffer))
	end
end

local function test(c_code)
	do
		local ffi = require("ffi")
		c_code = c_code:gsub("NAME", function()
			name_id = name_id + 1
			return "foo" .. name_id
		end)
		c_code = c_code:gsub("FIELD", function()
			field_id = field_id + 1
			return "field" .. field_id
		end)
		ffi.cdef(c_code)
	end

	local code = Code(c_code, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	local parser = Parser(tokens, code)
	parser.OnError = function(parser, code, msg, start, stop, ...)
		return Compiler.OnDiagnostic({}, code, msg, "fatal", start, stop, nil, ...)
	end
	local ast = parser:ParseRootNode()

	do -- check if we stored all tokens into the ast
		local function find_all_tokens(tbl, out, done)
			done = done or {}

			for _, v in pairs(tbl) do
				if type(v) == "table" then
					if v.is_whitespace == false then
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
					2
				)
			end
		end
	end

	print_node(ast)

	do
		return
	end

	local emitter = Emitter({skip_translation = true})
	local res = emitter:BuildCode(ast)

	if res ~= c_code then
		print("expected\n", c_code)
		print("got\n", res)
		diff(c_code, res)
		error("UH OH")
	end
end

if false then
	-- array 2 of array 8 of pointer to pointer to function (pointer to char) returning pointer to array 1 of array 1 of pointer to unsigned long long
	-- unsigned long long *(*(**NAME [1][2])(char *))[3][4];
	--[[
        unsigned long long 
            * 
                (
                    * 
                        (
                            *
                            * 
                            NAME [1][2]
                        )
                        (char *)
                )
        [3][4];

    ]] local NAME = Array1(
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

do
	return
end

local function test_anon(code, ...)
	test([[
        void foo(
            ]] .. code .. [[
        );
    ]])
end

-- https://cdecl.org/
do -- functions
	do -- plain
		-- it's a normal function declaration if foo is directly followed by a ( or a )(
		do -- equvilent function returning void
			test([[void foo();]])
			test([[void (foo)();]])
		end

		-- attributes
		test([[long long foo();]])
		test([[void __attribute__((stdcall)) foo();]])
		test([[long long __attribute__((stdcall)) foo();]])
		test([[void __fastcall foo(); ]])

		do -- pointers
			test[[ void (*foo()) ;]]
			test[[ void (**foo()) ;]]
			test[[ void (** volatile foo()) ;]]
			test[[ void (* volatile * volatile foo()) ;]]
			test[[ void (__ptr32**foo()) ;]]
			test[[ void (__stdcall*foo()) ;]]
		end

		test[[ void foo(int (*lol)(int, long)) ;]] -- tricky
		test[[ void (*foo())() ;]] -- function returning pointer to function returning void
		test([[ int (*foo())[5] ;]]) -- function returning pointer to an array of 5 ints
		test([[ void (**foo())() ;]]) -- function returning pointer to pointer to function returning void
		test([[ void qsort(int (*compar)(const uint8_t *, const uint8_t *)); ]])
		test([[ void foo() asm("test"); ]])
	end

	do -- pointers
		-- it's a function pointer if foo is directly followed by a (* or (KEYWORD*
		do -- equivilent pointer to function returning void
			test([[ void (*foo)() ;]])
			test([[ void (*(foo))() ;]])
		end

		test([[ void (__stdcall*foo)(); ]])
		test([[ void (__cdecl*foo)(); ]])
		test([[ void (__attribute__((stdcall))*foo)(); ]])
		test([[ void (__attribute__((stdcall))__ptr32*foo)(); ]])
		test([[ void (__attribute__((__cdecl))*foo)(); ]])
		test([[ void (__stdcall*(foo))(); ]])
		test([[ void (__cdecl*(foo))(); ]])
		test([[ void (__attribute__((stdcall))*(foo))(); ]])
		test([[ void (__attribute__((__cdecl))*(foo))(); ]])

		do -- equivilent pointer to pointer to function returning void
			test([[ void (**foo)() ;]])
			test([[ void (*(*foo))() ;]])
		end

		test([[ void (* volatile foo)() ;]]) -- pointer to a volatile void function
		test([[ void (* volatile * foo)() ;]]) -- pointer to a volatile pointer to a void function
		test([[ void (__ptr32*__ptr32*foo)() ;]]) -- 32bit pointer to a 32bit pointer to a void function
		test([[ void (*(*foo)())() ;]]) -- pointer to function returning pointer to function returning void
		test([[ int (*(*foo)())[5] ;]]) -- pointer to function returning pointer to array 5 of int
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
	test[[ struct {int a;} const foo(); ]]
	test[[ struct {int a;} const static foo(); ]]
end

do -- function arguments
	test_anon([[ int ]])
	test_anon([[ int, int ]])
	test_anon([[ int a ]])
	test_anon([[ int a, int b ]])
	test_anon([[ int a, int ]])
	test_anon([[ void(*)(), void(*)() ]])
	test_anon([[ void(*)(int, int), void(*)(int, int) ]])
	test_anon([[ void(*)(int, int), void(*)(void(*)(int, int), void(*)(int, int)) ]])
	test_anon([[ int a, ... ]])
	test_anon([[ char *, short * ]])
-- test_anon([[ ..., void ]])
-- test_anon([[ void, void ]])
end

do -- arrays
	do -- http://unixwiz.net/techtips/reading-cdecl.html
		do
			-- long
			test([[ long foo; ]])
			-- array 7 of long
			test([[ long foo[7]; ]])
			-- array 7 of pointer to long
			test[[ long *var[7]; ]]
			-- array 7 of pointer to pointer to long
			test[[ long **var[7]; ]]
		end

		do
			-- char
			test([[ char foo; ]])
			-- array of char
			test([[ char foo[]; ]])
			-- array of array 8 of char
			test([[ char foo[][8]; ]])
			-- array of array 8 of pointer to char
			test([[ char *foo[][8]; ]])
			-- array of array 8 of pointer to pointer to char
			test([[ char **foo[][8]; ]])
			-- array of array 8 of pointer to pointer to function returning char
			test([[ char (**foo[][8])(); ]])
			-- array of array 8 of pointer to pointer to function returning pointer to char 
			test([[ char *(**foo[][8])(); ]])
			-- array of array 8 of pointer to pointer to function returning pointer to array of char 
			test([[ char (*(**foo[][8])())[]; ]])
			-- array of array 8 of pointer to pointer to function returning pointer to array of pointer to char 
			test([[ char *(*(**foo[][8])())[]; ]])
		end
	end

	-- pointer to array 5 of pointer to function returning void
	test([[ void (*(*foo)[5])() ;]])
	-- array of 5 pointers to void functions
	test([[ void (*foo[5])() ;]])
	-- array of 5 pointers to pointers to void functions
	test([[ void (**foo[5])() ;]])
	-- array of array 8 of pointer to function returning pointer to array of pointer to char
	test([[ char *(*(*foo[][8])())[]; ]])
	-- array of array 8 of pointer to function returning pointer to array of array of pointer to char
	test([[ char *(*(*foo[8][8])())[8][8]; ]])
	-- array of array 8 of pointer to function returning pointer to function returning char
	test([[ char (*(*foo[][8])())(); ]])
	-- array of array 8 of pointer to function returning pointer to function returning pointer to char
	test([[ char *(*(*foo[][8])())(); ]])
	-- array 2 of array 8 of pointer to pointer to function (pointer to char) returning pointer to array of pointer to long
	test([[ long int unsigned long *(*(**NAME [2][8])(char *))[]; ]])
	-- array 7 of pointer to pointer to long
	test([[ long int unsigned long **foo[7]; ]])
	test_anon[[ int a[1+2] ]]
	test_anon[[ int a[1+2*2] ]]
	test_anon[[ int a[1<<2] ]]
	test_anon[[ int a[sizeof(int)] ]]
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
	for _, TYPE in ipairs({"struct", "union"}) do
		local function test_field(code)
			test(TYPE .. [[ NAME { ]] .. code .. [[ }; ]])
		end

		test(TYPE .. [[ NAME; ]]) -- forward declaration
		test(TYPE .. [[ NAME { int FIELD; }; ]]) -- single field
		test(TYPE .. [[ NAME { int FIELD, FIELD; }; ]]) -- multiple fields of same type
		test(TYPE .. [[ NAME { int FIELD: 1, FIELD: 1; }; ]]) -- multiple fields of same type with bitfield
		test(TYPE .. [[ NAME { char FIELD, *FIELD, **FIELD, FIELD: 1; }; ]])

		do -- anonymous
			test(TYPE .. [[ NAME { ]] .. TYPE .. [[ { int FIELD; }; }; ]])
			test(TYPE .. [[ NAME { ]] .. TYPE .. [[ { int FIELD; }; int FIELD; }; ]]) -- anonymous
			test(TYPE .. [[ NAME { ]] .. TYPE .. [[ { int FIELD; } FIELD; }; ]]) -- anonymous in field foo
		end

		test(TYPE .. [[ NAME { ]] .. TYPE .. [[ NAME { int FIELD; } FIELD; };  ]]) -- declared in field foo
		do -- complex fields
			-- repeat the above maybe?
			test_field[[ char FIELD; ]]
			test_field[[ char FIELD: 1; ]]
			test_field[[ const int FIELD:8; ]]
			test_field[[ char FIELD: +1+1; ]]

			if TYPE ~= "union" then test_field[[ char *(*(**FIELD[][8])())[]; ]] end

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
		end

		test(TYPE .. [[ NAME(NAME)(]] .. TYPE .. [[ NAME);]])
	end
end

do -- enum
	local function test_field(code)
		test([[ enum NAME { ]] .. code .. [[ }; ]])
	end

	test[[ enum NAME; ]] -- forward declaration
	test[[ enum NAME { FIELD }; ]] -- single field
	test[[ enum NAME { FIELD, }; ]] -- single field with trailing comma
	test[[ enum NAME { FIELD, FIELD }; ]] -- multiple fields
	test[[ enum NAME { FIELD, FIELD, }; ]] -- multiple fields with trailing comma
	do -- complex fields
		test_field[[ FIELD = 17, FIELD = 37, FIELD = 42 ]]
		test_field[[ FIELD = 17, FIELD, FIELD ]]
		test_field[[ FIELD = 17, FIELD, FIELD = 42 ]]
		test_field[[ FIELD = 17, FIELD = 37, FIELD ]]
		test_field[[ FIELD = 17+1, FIELD = 37+2, FIELD=2*5 ]]
	end
end

do -- typedef
	test[[ typedef int NAME; ]] -- NAME becomes int
	test[[ typedef int NAME, NAME2; ]] -- NAME and NAME2 become int
	test[[ typedef int NAME, *NAME2; ]] -- NAME becomes int and NAME2 becomes int *
	test[[ typedef int (*NAME)(int); ]] -- NAME becomes int (*)(int)
	test[[ typedef int (*NAME)(int), NAME2; ]] -- NAME becomes int (*)(int) and NAME2 becomes int
	test[[ typedef struct NAME { int bar; } NAME; ]] -- struct declaration with typedef, NAME becomes struct NAME
	test[[ typedef struct NAME { int bar; } NAME, NAME2; ]] -- struct declaration with typedef, NAME and NAME2 become struct NAME
	test[[ typedef union NAME { int bar; } NAME; ]] -- union declaration with typedef, NAME becomes union NAME
	test[[ typedef union NAME { int bar; } NAME, NAME2; ]] -- union declaration with typedef, NAME and NAME2 become union NAME
	test[[ typedef enum NAME { FIELD } NAME; ]] -- enum declaration with typedef, NAME becomes enum NAME
	test[[ typedef enum NAME { FIELD } NAME, NAME2; ]] -- enum declaration with typedef, NAME and NAME2 become enum NAME
	test[[ typedef struct NAME NAME; ]] -- struct forward declaration with typedef, NAME becomes struct NAME
	test[[ typedef union NAME NAME; ]] -- union forward declaration with typedef, NAME becomes union NAME
	test[[ typedef enum NAME NAME; ]] -- enum forward declaration with typedef, NAME becomes enum NAME
	test[[ typedef struct NAME NAME, NAME2; ]] -- struct forward declaration with typedef, NAME and NAME2 become struct NAME
	test[[ typedef union NAME NAME, NAME2; ]] -- union forward declaration with typedef, NAME and NAME2 become union NAME
	test[[ typedef enum NAME NAME, NAME2; ]] -- enum forward declaration with typedef, NAME and NAME2 become enum NAME
end

do -- variable declarations
	test[[ struct NAME { int bar; } var; ]] -- struct declaration with variable
	test[[ struct NAME { int bar; } var1, var2; ]] -- struct declaration with multiple variables
	test[[ union NAME { int bar; } var; ]] -- union declaration with variable
	test[[ union NAME { int bar; } var1, var2; ]] -- union declaration with multiple variables
	test[[ enum NAME { FIELD } var; ]] -- enum declaration with variable
	test[[ enum NAME { FIELD } var1, var2; ]] -- enum declaration with multiple variables
	test[[ struct NAME var; ]] -- struct variable
	test[[ struct NAME var1, var2; ]] -- struct multiple variables
	test[[ union NAME var; ]] -- union variable
	test[[ union NAME var1, var2; ]] -- union multiple variables
	test[[ enum NAME var; ]] -- enum variable
	test[[ enum NAME var1, var2; ]] -- enum multiple variables
	test[[ struct NAME { int bar; } *var; ]] -- struct pointer variable
	test[[ struct NAME { int bar; } *var1, *var2; ]] -- struct pointer multiple variables
	test[[ union NAME { int bar; } *var; ]] -- union pointer variable
	test[[ union NAME { int bar; } *var1, *var2; ]] -- union pointer multiple variables
	test[[ enum NAME { FIELD } *var; ]] -- enum pointer variable
	test[[ enum NAME { FIELD } *var1, *var2; ]] -- enum pointer multiple variables
end

do
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