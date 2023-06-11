-- http://unixwiz.net/techtips/reading-cdecl.html
-- https://eli.thegreenplace.net/2007/11/24/the-context-sensitivity-of-cs-grammar/
local Lexer = require("nattlua.c_declarations.lexer").New
local Parser = require("nattlua.c_declarations.parser").New
local Emitter = require("nattlua.c_declarations.emitter").New
local Code = require("nattlua.code").New
local Compiler = require("nattlua.compiler")
local name_id = 0
local field_id = 0

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

	do
		return
	end

	local code = Code(c_code, "test.c")
	local lex = Lexer(code)
	local tokens = lex:GetTokens()
	local parser = Parser(tokens, code)
	parser.OnError = function(parser, code, msg, start, stop, ...)
		return Compiler.OnDiagnostic({}, code, msg, "fatal", start, stop, nil, ...)
	end
	local ast = parser:ParseRootNode()
	local emitter = Emitter({skip_translation = true})
	local res = emitter:BuildCode(ast)

	if res ~= c_code then
		print("expected\n", c_code)
		print("got\n", res)
		diff(c_code, res)
		error("UH OH")
	end
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
			test([[void foo() ;]])
			test([[void (foo)() ;]])
		end

		test[[ void (*foo()) ;]] -- function returning pointer to void
		test[[ void (*foo())() ;]] -- function returning pointer to function returning void
		test([[ int (*foo())[5] ;]]) -- function returning pointer to an array of 5 ints
		test([[ void (**foo())() ;]]) -- function returning pointer to pointer to function returning void
		test([[ void foo() asm("test"); ]])
		test([[ void qsort(int (*compar)(const uint8_t *, const uint8_t *)); ]])
		test([[ void __fastcall foo(); ]])
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
		test([[ void (__attribute__((__cdecl))*foo)(); ]])
		test([[ void (__stdcall*(foo))(); ]])
		test([[ void (__cdecl*(foo))(); ]])
		test([[ void (__attribute__((stdcall))*(foo))(); ]])
		test([[ void (__attribute__((__cdecl))*(foo))(); ]])
		test([[ long static volatile int unsigned long *(*(**foo [2][8])(char *))[]; ]])
		test([[ long static volatile int unsigned long long **foo[7]; ]])

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
			do -- function returning pointer to function returning void
				test_anon([[ void (*())() ]])
				test_anon([[ void ((*()))() ]])
			end

			-- pointer to function returning pointer to function returning void
			test_anon([[ void (*(*)())() ]])
		end
	end
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
	test([[void (*foo[5])() ;]])
	-- array of 5 pointers to pointers to void functions
	test([[void (**foo[5])() ;]])
	-- array of array 8 of pointer to function returning pointer to array of pointer to char
	test([[ char *(*(*foo[][8])())[]; ]])
	-- array of array 8 of pointer to function returning pointer to array of array of pointer to char
	test([[ char *(*(*foo[8][8])())[8][8]; ]])
	-- array of array 8 of pointer to function returning pointer to function returning char
	test([[ char (*(*foo[][8])())(); ]])
	-- array of array 8 of pointer to function returning pointer to function returning pointer to char
	test([[ char *(*(*foo[][8])())(); ]])
	test_anon[[ int a[1+2] ]]
	test_anon[[ int a[1+2*2] ]]
	test_anon[[ int a[1<<2] ]]
	test_anon[[ int a[sizeof(int)] ]]
	test_anon[[ int a[1?2:3] ]]
end

do -- struct and union declarations
	for _, TYPE in ipairs({"struct", "union"}) do
		local function test_field(code)
			test(TYPE .. [[ NAME { ]] .. code .. [[ } ]])
		end

		test(TYPE .. [[ NAME; ]]) -- forward declaration
		test(TYPE .. [[ NAME { int FIELD; }; ]]) -- single field
		test(TYPE .. [[ NAME { int FIELD, FIELD; }; ]]) -- multiple fields of same type
		test(TYPE .. [[ NAME { int FIELD: 1, FIELD: 1; }; ]]) -- multiple fields of same type with bitfield
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
		test([[ enum NAME { ]] .. code .. [[ } ]])
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