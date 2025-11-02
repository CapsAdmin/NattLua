local preprocess = require("nattlua.definitions.lua.ffi.preprocessor.preprocessor")
local SKIP_GCC = true

local function preprocess_gcc(code)
	local tmp_file = os.tmpname() .. ".c"
	local f = assert(io.open(tmp_file, "w"))
	f:write(code)
	f:close()
	local p = assert(io.popen("gcc -E -P -w -x c -nostdinc -undef " .. tmp_file .. " 2>&1", "r"))
	local res = p:read("*all")
	p:close()
	os.remove(tmp_file)
	return res
end

local function test(code, find)
	if not code:find(">.-<") then error("must define a macro with > and <", 2) end

	if find:find(">.-<") then error("must not contain > and <", 2) end

	local test_name = code:match("#define%s+(%w+)")
	local gcc_ok = true
	local gcc_error = nil

	if not SKIP_GCC then
		local gcc_code = preprocess_gcc(code)
		print(gcc_code)
		local captured = gcc_code:match(">(.-)<")

		if find ~= captured then
			gcc_ok = false
			gcc_error = "gcc -E: expected '" .. find .. "', got '" .. (captured or "nil") .. "'"
		end
	end

	do
		local success, code_result = pcall(function()
			return preprocess(code)
		end)

		if not success then
			local err = ""
			err = err .. string.format("  Expected: %s", find) .. "\n"
			err = err .. string.format("  Got:      ERROR: %s", tostring(code_result)) .. "\n"

			if gcc_error then
				err = err .. string.format("  GCC:      %s", gcc_error) .. "\n"
			end

			error(err)
		end

		local captured = code_result:match(">(.-)<")

		if find ~= captured then
			local err = ""
			err = err .. string.format("  Expected: %s", find) .. "\n"
			err = err .. string.format("  Got:      %s", captured or "nil") .. "\n"

			if gcc_error then
				err = err .. string.format("  GCC:      %s", gcc_error) .. "\n"
			end

			error(err)
		end
	end
end

local function test_error(code, error_msg)
	local test_name = code:match("#define%s+(%w+)") or "error_test"
	local success, err = pcall(function()
		preprocess(code)
	end)

	if success then
		local err = ""
		err = err .. string.format("  Expected: ERROR: %s", error_msg) .. "\n"
		err = err .. string.format("  Got:      No error was thrown") .. "\n"
		error(err)
	elseif not err:find(error_msg, nil, true) then
		local err = ""
		err = err .. string.format("  Expected: ERROR: %s", error_msg) .. "\n"
		err = err .. string.format("  Got:      ERROR: %s", tostring(err)) .. "\n"
		error(err)
	end
end

do -- whitespace
	test("#define M 1 \n >x=M<", "x=1")
	test("#define M z \n >x=\nM<", "x=\nz")
	test("#define M 1 \n >x=M<", "x=1")
	test("#define M \\\n z \n >x=M<", "x=z")
	test("#define S(a) a \n >S(x-y)<", "x-y")
	test("#define S(a) a \n >S(x - y)<", "x - y")
	test("#define S(a) a \n >S( x - y )<", "x - y")
	test("#define S(a) a \n >S( x-    y )<", "x- y")
	test("#define S(a) a \n >S( x -y )<", "x -y")
end

do -- basic macro expansion
	test("#define REPEAT(x) x \n >REPEAT(1)<", "1")
	test("#define REPEAT(x) x x \n >REPEAT(1)<", "1 1")
	test("#define REPEAT(x) x x x \n >REPEAT(1)<", "1 1 1")
	test("#define REPEAT(x) x x x x \n >REPEAT(1)<", "1 1 1 1")
	test("#define TEST 1 \n #define TEST2 2 \n >TEST + TEST2<", "1 + 2")
	test("#define TEST(x) x*x \n >TEST(2)<", "2*2")
	test("#define TEST(x,y) x*y \n >TEST(2,4)<", "2*4")
	test("#define X 1 \n #define X 2 \n >X<", "2")
	test("#define A 1 \n #define B 2 \n >A + B + A<", "1 + 2 + 1")
	test("#define TRIPLE(x) x x x \n >TRIPLE(abc)<", "abc abc abc")
	test("#define PLUS(a, b) a + b \n >PLUS(1, 2)<", "1 + 2")
	test("#define MULT(a, b) a * b \n >MULT(3, 4)<", "3 * 4")
	test("#define EMPTY \n >EMPTY<", "")
	test("#define EMPTY() nothing \n >EMPTY()<", "nothing")
	test("#define TEST 1 \n #undef TEST \n >TEST<", "TEST")
end

do -- string operations (#)
	test("#define STR(a) #a \n >STR(hello world)<", "\"hello world\"")
	test("#define STR(x) #x \n >STR(  hello  world  )<", "\"hello world\"")
	test(
		"#define STRINGIFY(a,b,c,d) #a #b #c #d  \n >STRINGIFY(1,2,3,4)<",
		"\"1\" \"2\" \"3\" \"4\""
	)
	test("#define STRINGIFY(a) #a  \n >STRINGIFY(1)<", "\"1\"")
	test("#define STRINGIFY(a) #a  \n >STRINGIFY((a,b,c))<", "\"(a,b,c)\"")
	test("#define STR(x) #x \n >STR(a + b)<", "\"a + b\"")
	test("#define A value \n #define STR(x) #x \n >STR(A)<", "\"A\"")
end

do -- token concatenation (##)
	test(
		"#define PREFIX(x) pre_##x \n #define SUFFIX(x) x##_post \n >PREFIX(fix) SUFFIX(fix)<",
		"pre_fix fix_post"
	)
	test("#define F(a, b) a##b \n >F(1,2)<", "12")
	test("#define EMPTY_ARG(a, b) a##b \n >EMPTY_ARG(test, )<", "test")
	test("#define EMPTY_ARG(a, b) a##b \n >EMPTY_ARG(, test)<", "test")
	test("#define JOIN(a, b) a##b \n >JOIN(pre, post)<", "prepost")
	test(
		[[
		#define VK_DEFINE_HANDLE(object) typedef struct object##_T* object;
		VK_DEFINE_HANDLE(VkInstance)

		int foo(void *>object<); 
	]],
		"object"
	)
end

do -- empty arguments
	-- Empty parameters should preserve surrounding whitespace
	test("#define F(x,y) x and y \n >F(,)<", " and ")
end

do -- variadic macros and VA_ARGS
	test("#define F(...) __VA_ARGS__ \n >F(0)<", "0")
	test("#define F(...) __VA_ARGS__ \n >F()<", "")
	test("#define F(...) __VA_ARGS__ \n >F(1,2,3)<", "1,2,3")
	test("#define F(...) f(0 __VA_OPT__(,) __VA_ARGS__) \n >F(1)<", "f(0 , 1)")
	test("#define F(...) f(0 __VA_OPT__(,) __VA_ARGS__) \n >F()<", "f(0 )")
	test(
		"#define VARIADIC(a, ...) a __VA_ARGS__ \n >VARIADIC(first, second, third)<",
		"first second, third"
	)
	test("#define VARIADIC(a, ...) a __VA_ARGS__ \n >VARIADIC(only)<", "only ")
	test(
		"#define DEBUG(...) printf(\"Debug: \" __VA_ARGS__) \n >DEBUG(\"Value: %d\", x)<",
		"printf(\"Debug: \" \"Value: %d\", x)"
	)
	test(
		"#define LOG(fmt, ...) printf(fmt __VA_OPT__(,) __VA_ARGS__) \n >LOG(\"Hello\")<",
		"printf(\"Hello\" )"
	)
	test(
		"#define LOG(fmt, ...) printf(fmt __VA_OPT__(,) __VA_ARGS__) \n >LOG(\"Hello\", \"World\")<",
		"printf(\"Hello\" , \"World\")"
	)
	test("#define COMMA(...) __VA_OPT__(,)__VA_ARGS__ \n >COMMA()<", "")
	test("#define COMMA(...) __VA_OPT__(,)__VA_ARGS__ \n >COMMA(x)<", ",x")
end

do -- nested and recursive macros
	local function ones(count)
		local str = {}

		for i = 1, count do
			str[i] = "1"
		end

		return table.concat(str, " ")
	end

	test("#define X(x) x \n #define Y X(1) \n >Y<", "1")
	test("#define X(x) x \n #define Y(x) X(x) \n >Y(1)<", "1")
	test(
		"#define REPEAT_5(x) x x x x x \n #define REPEAT_25(x) REPEAT_5(x) \n >REPEAT_25(1)<",
		ones(5)
	)
	test(
		"#define REPEAT_5(x) x x x x x \n #define REPEAT_25(x) REPEAT_5(x) REPEAT_5(x) \n >REPEAT_25(1)<",
		ones(10)
	)
	test(
		"#define REPEAT_5(x) x x x x x \n #define REPEAT_25(x) REPEAT_5(REPEAT_5(x)) \n >REPEAT_25(1)<",
		ones(25)
	)
	test(
		"#define REPEAT_5(x) x x x x x \n #define REPEAT_25(x) REPEAT_5(x) \n >REPEAT_25(1)<",
		"1 1 1 1 1"
	)
	test("#define F(x) (2*x) \n #define G(y) F(y+1) \n >G(5)<", "(2*5+1)")
	test("#define INNER(x) x+x \n #define OUTER(y) INNER(y) \n >OUTER(5)<", "5+5")
	test(
		"#define A(x) x+1 \n #define B(y) A(y*2) \n #define C(z) B(z-1) \n >C(5)<",
		"5-1*2+1"
	)
end

do -- complex expressions and ternary operators
	test(
		"#define max(a,b) ((a)^(b)?(a):(b))  \n int x = >max(1,2)<",
		"((1)^(2)?(1):(2))"
	)
	test(
		"#define MAX(a,b) ((a)^(b)?(a):(b)) \n >MAX(1+2,3*4)<",
		"((1+2)^(3*4)?(1+2):(3*4))"
	)
	test("#define COMPLEX(a) a*a \n >COMPLEX(1+2)<", "1+2*1+2")
	test("#define PAREN(a) (a) \n >PAREN(1+2*3)<", "(1+2*3)")
	test("#define FUNC(a) a \n >FUNC((1+2))<", "(1+2)")
	test("#define X 10 \n #define EXPAND(a) a \n >EXPAND(X)<", "10")
end

do -- multi-line macros
	test(
		[[
#define MY_LIST \
X(Item1, "This is a description of item 1") \
X(Item2, "This is a description of item 2") \
X(Item3, "This is a description of item 3")

#define X(name, desc) name,
>enum ListItemType { MY_LIST }<
#undef X]],
		"enum ListItemType { Item1,Item2,Item3, }"
	)
end

do -- error handling
	test_error("#define FUNC(a, b) a + b \n FUNC(1)", "Argument count mismatch")
	test_error("#define FUNC(a, b, c) a + b + c \n FUNC(1, 2)", "Argument count mismatch")
	test_error("#define FUNC(a, b) a + b \n FUNC(1, 2, 3)", "Argument count mismatch")
end

do -- self-referential macros (should not expand infinitely)
	test("#define FOO FOO \n >FOO<", "FOO")
	test("#define X X+1 \n >X<", "X+1")
	test("#define INDIRECT INDIRECT \n >INDIRECT<", "INDIRECT")
end

do -- advanced token concatenation
	test("#define CONCAT3(a,b,c) a##b##c \n >CONCAT3(x,y,z)<", "xyz")
	test("#define VAR(n) var##n \n >VAR(1) VAR(2)<", "var1 var2")
	test(
		"#define GLUE(a,b) a##b \n #define XGLUE(a,b) GLUE(a,b) \n #define X 1 \n >XGLUE(X,2)<",
		"12"
	)
end

do -- stringification edge cases
	test("#define STR(x) #x \n >STR()<", "\"\"")
	test("#define STR(x) #x \n >STR(   )<", "\"\"")
	test(
		"#define STR(x) #x \n #define XSTR(x) STR(x) \n #define NUM 42 \n >XSTR(NUM)<",
		"\"42\""
	)
end

do -- complex variadic patterns
	test(
		"#define LOG(level, ...) level: __VA_ARGS__ \n >LOG(ERROR, msg, code)<",
		"ERROR: msg, code"
	)
	test("#define CALL(fn, ...) fn(__VA_ARGS__) \n >CALL(printf, x, y)<", "printf(x, y)")
	test("#define WRAP(...) (__VA_ARGS__) \n >WRAP(1,2,3)<", "(1,2,3)")
	test("#define FIRST(a, ...) a \n >FIRST(x, y, z)<", "x")
end

do -- nested __VA_OPT__
	test("#define F(...) a __VA_OPT__(b __VA_OPT__(c)) \n >F(x)<", "a b c") -- May not work, skip gcc
	test("#define COMMA_IF(x, ...) x __VA_OPT__(,) __VA_ARGS__ \n >COMMA_IF(a)<", "a ")
	test(
		"#define COMMA_IF(x, ...) x __VA_OPT__(,) __VA_ARGS__ \n >COMMA_IF(a, b)<",
		"a , b"
	)
end

do -- macro redefinition
	test("#define X 1 \n #define X 1 \n >X<", "1") -- Identical redefinition (should be ok)
-- Different redefinition tested earlier with X=1 then X=2
end

do -- mixed operators
	-- Combining # and ## operators in the same macro
	test("#define M(x) #x##_suffix \n >M(test)<", "\"test\"_suffix")
	test("#define M2(x) prefix_##x#x \n >M2(val)<", "prefix_val\"val\"")
	test("#define M3(x,y) #x##y##_end \n >M3(foo,bar)<", "\"foo\"bar_end")
	test(
		"#define PREFIX(x) PRE_##x \n #define SUFFIX(x) x##_POST \n >PREFIX(SUFFIX(mid))<",
		"PRE_mid_POST"
	)
end

do -- whitespace preservation
	test("#define SPACE(a,b) a b \n >SPACE(x,y)<", "x y")
	test("#define NOSPACE(a,b) a##b \n >NOSPACE(x,y)<", "xy")
end

do -- parentheses in arguments
	test("#define F(x) [x] \n >F((a,b))<", "[(a,b)]")
	test("#define G(x,y) x+y \n >G((1,2),(3,4))<", "(1,2)+(3,4)")
end

do -- multiple levels of indirection
	test("#define A B \n #define B C \n #define C D \n #define D 42 \n >A<", "42")
	test("#define EVAL(x) x \n #define INDIRECT EVAL \n >INDIRECT(5)<", "5")
end

do -- #include directive
	local tmp_header = "/tmp/nattlua_test_include.h"
	local f = io.open(tmp_header, "w")
	f:write("#ifndef TEST_H\n#define TEST_H\n#define INCLUDED_VALUE 42\n#endif\n")
	f:close()
	local code_with_include = string.format("#include \"%s\"\n>INCLUDED_VALUE<", tmp_header)
	test(code_with_include, "42")
	os.remove(tmp_header)

	do
		local res = preprocess("#include \"non_existent_file.h\"\nsome other code")
		assert(
			res:find("some other code"),
			"Expected preprocessing to continue after failed #include"
		)
		assert(
			not res:find("non_existent_file"),
			"Expected non-existent include to be skipped"
		)
	end
end

do -- conditional compilation
	-- Basic #ifdef / #ifndef
	test("#define FOO 1\n#ifdef FOO\n>x=FOO<\n#endif", "x=1")
	test("#ifdef UNDEFINED\n>x=1<\n#endif\n>y=2<", "y=2")
	test("#ifndef UNDEFINED\n>x=1<\n#endif", "x=1")
	test("#define FOO 1\n#ifndef FOO\n>x=2<\n#endif\n>y=3<", "y=3")
	-- #ifdef with #else
	test("#define FOO 1\n#ifdef FOO\n>x=1<\n#else\n>x=2<\n#endif", "x=1")
	test("#ifdef UNDEFINED\n>x=1<\n#else\n>x=2<\n#endif", "x=2")
	-- #ifndef with #else
	test("#ifndef UNDEFINED\n>x=1<\n#else\n>x=2<\n#endif", "x=1")
	test("#define FOO 1\n#ifndef FOO\n>x=1<\n#else\n>x=2<\n#endif", "x=2")
	-- #if with constant expressions
	test("#if 1\n>x=1<\n#endif", "x=1")
	test("#if 0\n>x=1<\n#endif\n>y=2<", "y=2")
	test("#if 1 + 1\n>x=1<\n#endif", "x=1")
	test("#if 2 - 2\n>x=1<\n#endif\n>y=2<", "y=2")
	-- #if with defined() operator
	test("#define FOO 1\n#if defined(FOO)\n>x=1<\n#endif", "x=1")
	test("#if defined(UNDEFINED)\n>x=1<\n#endif\n>y=2<", "y=2")
	test("#define BAR 2\n#if defined BAR\n>x=1<\n#endif", "x=1")
	-- #if with macro expansion in condition
	test("#define VAL 5\n#if VAL > 3\n>x=1<\n#endif", "x=1")
	test("#define VAL 2\n#if VAL > 3\n>x=1<\n#endif\n>y=2<", "y=2")
	-- #if with #else
	test("#if 1\n>x=1<\n#else\n>x=2<\n#endif", "x=1")
	test("#if 0\n>x=1<\n#else\n>x=2<\n#endif", "x=2")
	-- #if with #elif
	test("#if 0\n>x=1<\n#elif 1\n>x=2<\n#endif", "x=2")
	test("#if 1\n>x=1<\n#elif 1\n>x=2<\n#endif", "x=1")
	test("#if 0\n>x=1<\n#elif 0\n>x=2<\n#else\n>x=3<\n#endif", "x=3")
	-- Multiple #elif
	test("#if 0\n>x=1<\n#elif 0\n>x=2<\n#elif 1\n>x=3<\n#endif", "x=3")
	test(
		"#define A 2\n#if A == 1\n>x=1<\n#elif A == 2\n>x=2<\n#elif A == 3\n>x=3<\n#endif",
		"x=2"
	)
	-- Nested conditionals
	test("#ifdef FOO\n#ifdef BAR\n>x=1<\n#endif\n#endif\n>y=2<", "y=2")
	test(
		"#define FOO 1\n#ifdef FOO\n#ifdef BAR\n>x=1<\n#else\n>x=2<\n#endif\n#endif",
		"x=2"
	)
	test(
		"#define FOO 1\n#define BAR 2\n#ifdef FOO\n#ifdef BAR\n>x=1<\n#endif\n#endif",
		"x=1"
	)
	-- Conditional with macro definitions
	test("#define ENABLE 1\n#if ENABLE\n#define VAL 42\n#endif\n>x=VAL<", "x=42")
	test("#if 0\n#define VAL 42\n#endif\n>x=VAL<", "x=VAL")
	-- Complex expressions
	test("#if (1 + 2) * 3 == 9\n>x=1<\n#endif", "x=1")
	test("#if 10 / 2 > 4\n>x=1<\n#endif", "x=1")
	test("#if 1 && 1\n>x=1<\n#endif", "x=1")
	test("#if 1 || 0\n>x=1<\n#endif", "x=1")
	test("#if 0 && 1\n>x=1<\n#endif\n>y=2<", "y=2")
	test("#if !0\n>x=1<\n#endif", "x=1")
	test("#if !1\n>x=1<\n#endif\n>y=2<", "y=2")
	-- Logical operators
	test("#define A 1\n#define B 0\n#if A && !B\n>x=1<\n#endif", "x=1")
	test("#if defined(FOO) || defined(BAR)\n>x=1<\n#endif\n>y=2<", "y=2")
	test("#define FOO 1\n#if defined(FOO) || defined(BAR)\n>x=1<\n#endif", "x=1")
	-- Comparison operators
	test("#if 5 > 3\n>x=1<\n#endif", "x=1")
	test("#if 5 < 3\n>x=1<\n#endif\n>y=2<", "y=2")
	test("#if 5 >= 5\n>x=1<\n#endif", "x=1")
	test("#if 5 <= 5\n>x=1<\n#endif", "x=1")
	test("#if 5 == 5\n>x=1<\n#endif", "x=1")
	test("#if 5 != 3\n>x=1<\n#endif", "x=1")
	-- Undefined identifiers evaluate to 0
	test("#if UNDEFINED\n>x=1<\n#endif\n>y=2<", "y=2")
	test("#if !UNDEFINED\n>x=1<\n#endif", "x=1")
	-- Additional comprehensive tests for new parser
	test("#if 3 > 2 && 5 < 10\n>x=1<\n#endif", "x=1")
	test("#if (5 + 3) >= 8\n>x=1<\n#endif", "x=1")
	test("#define X 10\n#define Y 20\n#if X < Y\n>x=1<\n#endif", "x=1")
	test("#define X 10\n#if X * 2 > 15\n>x=1<\n#endif", "x=1")
	test("#if (10 - 5) == 5\n>x=1<\n#endif", "x=1")
	test("#if !(5 > 10)\n>x=1<\n#endif", "x=1")
	test("#define A 5\n#define B 10\n#if A + B > 10\n>x=1<\n#endif", "x=1")
end

do -- #pragma directive
	test("#pragma once\n>x=1<", "x=1")
	test("#pragma pack(push, 1)\n>x=1<", "x=1")
	test("#define X 42\n#pragma GCC diagnostic ignored \"-Wunused\"\n>X<", "42")
end

do -- #error directive
	test_error("#error This is an error message", "#error: This is an error message")
	test_error(
		"#define ERR 1\n#if ERR\n#error Compilation stopped\n#endif",
		"#error: Compilation stopped"
	)
	test_error("#error", "#error: ")
end

do -- #warning directive (warnings should not stop preprocessing)
	local old = print
	local called = false
	print = function()
		called = true
	end -- suppress output
	test("#warning This is a warning\n>x=1<", "x=1")
	print = old
	assert(called, "Expected warning to be printed")
end

do -- __DATE__ and __TIME__ macros
	local result = preprocess(">__DATE__<")
	assert(
		result:match(">\".-\"<"),
		"Expected __DATE__ to expand to a quoted string, got: " .. result
	)
	result = preprocess(">__TIME__<")
	assert(
		result:match(">\".-\"<"),
		"Expected __TIME__ to expand to a quoted string, got: " .. result
	)
	local date_value = preprocess("__DATE__")
	local result2 = preprocess("#define BUILD_DATE __DATE__\n>BUILD_DATE<")
	assert(result2:match("\""), "Expected BUILD_DATE to expand to a date string")
end

do -- __LINE__ and __FILE__ macros
	-- __LINE__ uses a simple counter that increments on newlines
	test(">__LINE__<", "1")
	test("\n>__LINE__<", "2")
	test("\n\n>__LINE__<", "3")
	test("#define X __LINE__\n>X<", "2") -- __LINE__ expands at use time, line 2
	local result = preprocess(">__FILE__<")
	assert(
		result:match(">\".-\"<"),
		"Expected __FILE__ to expand to a quoted string, got: " .. result
	)
	assert(
		result:match("cpreprocessor"),
		"Expected __FILE__ to contain 'cpreprocessor', got: " .. result
	)
end

do -- combined predefined macros
	test(">__STDC__<", "1")
	test("#if __STDC__\n>x=1<\n#endif", "x=1")
	test("#if __GNUC__ >= 4\n>x=1<\n#endif", "x=1")
end

do -- bitwise operators in #if expressions
	test("#if (1 << 3) == 8\n>x=1<\n#endif", "x=1")
	test("#if (16 >> 2) == 4\n>x=1<\n#endif", "x=1")
	test("#if (5 & 3) == 1\n>x=1<\n#endif", "x=1")
	test("#if (5 | 3) == 7\n>x=1<\n#endif", "x=1")
	test("#if (5 ^ 3) == 6\n>x=1<\n#endif", "x=1")
	test("#if (~0) == -1\n>x=1<\n#endif", "x=1")
	test("#if (0xFF & 0x0F) == 0x0F\n>x=1<\n#endif", "x=1")
	test("#define MASK 0xF0\n#if (MASK >> 4) == 0x0F\n>x=1<\n#endif", "x=1")
	test("#if ((1 << 4) | (1 << 2)) == 20\n>x=1<\n#endif", "x=1")
	test("#if (0xAA & 0x55) == 0\n>x=1<\n#endif", "x=1")
end

do -- __COUNTER__ macro
	local result = preprocess(">__COUNTER__ __COUNTER__ __COUNTER__<")
	assert(result:match(">0 1 2<"), "Expected __COUNTER__ to increment, got: " .. result)
	-- Test __COUNTER__ in macro definitions
	result = preprocess("#define A __COUNTER__\n#define B __COUNTER__\n>A B<")
	assert(
		result:match(">0 1<"),
		"Expected __COUNTER__ in defines to increment, got: " .. result
	)
	-- Test __COUNTER__ expands each time it's used
	result = preprocess("#define UNIQUE_ID __COUNTER__\n>UNIQUE_ID UNIQUE_ID UNIQUE_ID<")
	assert(
		result:match(">0 1 2<"),
		"Expected UNIQUE_ID to expand __COUNTER__ each time, got: " .. result
	)
end

do -- indirect stringification (XSTR pattern)
	test(
		"#define STR(x) #x\n#define XSTR(x) STR(x)\n#define VALUE 42\n>XSTR(VALUE)<",
		"\"42\""
	)
	test(
		"#define STR(x) #x\n#define XSTR(x) STR(x)\n#define CONCAT(a,b) a##b\n>XSTR(CONCAT(12,34))<",
		"\"1234\""
	)
	test(
		"#define STR(x) #x\n#define XSTR(x) STR(x)\n#define PI 314\n>STR(PI) XSTR(PI)<",
		"\"PI\" \"314\""
	)
end

do -- token rescan after concatenation
	test("#define AB 99\n#define CONCAT(a,b) a##b\n>CONCAT(A,B)<", "99")
	test("#define x123 999\n#define GLUE(a,b) a##b\n>GLUE(x,123)<", "999")
	test("#define foo bar\n#define bar 42\n#define CONCAT(a,b) a##b\n>CONCAT(f,oo)<", "42")
end

do -- complex bitwise expressions
	test("#if ((1 << 8) - 1) == 255\n>x=1<\n#endif", "x=1")
	test("#if (0xFF00 >> 8) == 0xFF\n>x=1<\n#endif", "x=1")
	test("#define BIT(n) (1 << (n))\n#if BIT(3) == 8\n>x=1<\n#endif", "x=1")
	test(
		"#define FLAGS (0x01 | 0x04 | 0x10)\n#if (FLAGS & 0x04) != 0\n>x=1<\n#endif",
		"x=1"
	)
end

do -- edge cases for concatenation with rescan
	test("#define ABC 777\n#define CONCAT3(a,b,c) a##b##c\n>CONCAT3(A,B,C)<", "777")
	test("#define JOIN(a,b) a##b\n>JOIN(12,34)<", "1234")
end

do -- edge cases for __COUNTER__
	result = preprocess([[
#define NEXT __COUNTER__
#define ARRAY_SIZE NEXT
>ARRAY_SIZE NEXT NEXT<
]])
	assert(result:match(">0 1 2<"), "Expected __COUNTER__ to persist, got: " .. result)
end

do -- combined features: bitwise + macros + conditionals
	test([[
#define ALL_FLAGS 7
#if ALL_FLAGS == 7
>x=1<
#endif
]], "x=1")
	test(
		[[
#define MASK 0xF0
#define SHIFT 4
#if (MASK >> SHIFT) == 0x0F
>x=1<
#endif
]],
		"x=1"
	)
end

do -- function-like macros in #if conditions
	test(
		"#define GET_VALUE(x) x\n#define VALUE 5\n#if GET_VALUE(VALUE) > 3\n>x=1<\n#endif",
		"x=1"
	)
	test("#define ADD(a,b) a+b\n#if ADD(2,3) == 5\n>x=1<\n#endif", "x=1")
	test("#define MUL(a,b) (a*b)\n#if MUL(2,3) == 6\n>x=1<\n#endif", "x=1")
	test(
		"#define INNER(x) (x*2)\n#define OUTER(y) INNER(y)\n#if OUTER(5) == 10\n>x=1<\n#endif",
		"x=1"
	)
	test("#define MAX(a,b) ((a)>(b)?(a):(b))\n#if MAX(5,3) > 0\n>x=1<\n#endif", "x=1")
	test(
		"#define VALUE 10\n#define DOUBLE(x) (x*2)\n#if DOUBLE(VALUE) == 20\n>x=1<\n#endif",
		"x=1"
	)
	test(
		"#define A(x) (x+1)\n#define B(x) (x*2)\n#if A(5) + B(3) == 12\n>x=1<\n#endif",
		"x=1"
	)
end

do -- defined() operator behavior
	-- Basic defined() usage
	test("#define FOO 1\n#if defined(FOO)\n>x=1<\n#endif", "x=1")
	test("#if defined(UNDEFINED)\n>x=1<\n#else\n>x=2<\n#endif", "x=2")
	test("#define BAR 1\n#if defined BAR\n>x=1<\n#endif", "x=1")
	-- defined() should NOT expand its argument
	test("#define ALIAS REAL\n#define REAL 1\n#if defined(ALIAS)\n>x=1<\n#endif", "x=1")
	test("#define ALIAS REAL\n#if defined(REAL)\n>x=1<\n#else\n>x=2<\n#endif", "x=2")
	-- defined() in complex expressions
	test("#define A 1\n#define B 2\n#if defined(A) && defined(B)\n>x=1<\n#endif", "x=1")
	test("#if defined(X) || defined(Y)\n>x=1<\n#else\n>x=2<\n#endif", "x=2")
	test("#define X 1\n#if !defined(Y) && defined(X)\n>x=1<\n#endif", "x=1")
end
