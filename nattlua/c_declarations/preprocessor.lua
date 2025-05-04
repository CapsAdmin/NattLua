local c = [==[/*
 * C Preprocessor Macros Test Suite
 * 
 * This file contains a comprehensive set of C preprocessor macro examples
 * to test all aspects of a C preprocessor implementation.
 */

#include <stdio.h>

/* ========== Basic Object-like Macros ========== */

// Simple replacement
#define PI 3.14159
#define MAX_BUFFER_SIZE 1024
#define PROGRAM_NAME "MacroTester"
#define TRUE 1
#define FALSE 0

// Empty macro
#define EMPTY

// Macro with spaces and special characters
#define COMPLEX_TEXT This is a (somewhat) "complex" macro \ with backslash!

/* ========== Function-like Macros ========== */

// Basic function-like macro
#define SQUARE(x) ((x) * (x))
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define MIN(a, b) ((a) < (b) ? (a) : (b))

// Nested macro usage
#define ABS(x) ((x) < 0 ? -(x) : (x))
#define CLAMP(x, min, max) (MIN(MAX((x), (min)), (max)))

// Multiple uses of same parameter
#define MULTIPLY_BY_ITSELF(x) ((x) * (x))

/* ========== Stringification (#) ========== */

// Basic stringification
#define STRINGIFY(x) #x

// Stringification with parameters containing commas and quotes
#define STRING_COMPLEX(x) #x

/* ========== Token Concatenation (##) ========== */

// Basic concatenation
#define CONCAT(a, b) a##b

// Concatenation in identifiers
#define MAKE_FUNCTION(name) void func_##name() { printf("Function: " #name "\n"); }

// Combine concatenation and stringification
#define DECLARE_VARIABLE(type, name) type g_##name; const char* name##_name = #name

/* ========== Variadic Macros ========== */

// Basic variadic macro
#define DEBUG_PRINT(fmt, ...) printf("DEBUG: " fmt, __VA_ARGS__)

// Variadic macro with empty __VA_ARGS__ handling
#define LOG(level, fmt, ...) printf("[%s] " fmt, level, ##__VA_ARGS__)

// Count the number of arguments
#define COUNT_ARGS(...) COUNT_ARGS_IMPL(__VA_ARGS__, 5, 4, 3, 2, 1, 0)
#define COUNT_ARGS_IMPL(_1, _2, _3, _4, _5, N, ...) N

/* ========== Recursive Macros ========== */

// Simple recursion through multiple definitions
#define A(x) B(x)
#define B(x) C(x)
#define C(x) (x + 3)

// Indirect self-recursion
#define FIRST(a, b) a
#define REST(a, b) b
#define EXPAND_1(x) x
#define EXPAND_2(x, y) EXPAND_1(x), EXPAND_1(y)
#define EXPAND_3(x, y, z) EXPAND_1(x), EXPAND_2(y, z)

/* ========== Conditional Compilation ========== */

// Define for conditional tests
#define TEST_FEATURE
#define VERSION 2
#define DEBUG_LEVEL 3

// Basic conditionals
#ifdef TEST_FEATURE
    #define FEATURE_ENABLED 1
#else
    #define FEATURE_ENABLED 0
#endif

// Nested conditionals
#if VERSION > 1
    #if DEBUG_LEVEL > 2
        #define LOG_LEVEL "VERBOSE"
    #else
        #define LOG_LEVEL "NORMAL"
    #endif
#else
    #define LOG_LEVEL "MINIMAL"
#endif

// Complex expressions
#if defined(TEST_FEATURE) && (VERSION > 1 || DEBUG_LEVEL > 0)
    #define COMPLEX_CONDITION 1
#else
    #define COMPLEX_CONDITION 0
#endif

// Undef and redefine test
#undef VERSION
#define VERSION 3

#if VERSION == 3
    #define VERSION_STRING "Version 3"
#endif

/* ========== Multi-line Macros ========== */

// Multi-line macro with continuation character
#define MULTI_LINE_FUNC(x, y) \
    do { \
        int temp = (x) + (y); \
        printf("Sum: %d\n", temp); \
        temp = (x) * (y); \
        printf("Product: %d\n", temp); \
    } while(0)

/* ========== Advanced Examples ========== */

// Macro that expands to a compile-time error message
#define STATIC_ASSERT(condition, message) \
    typedef char static_assertion_##message[(condition) ? 1 : -1]

// Macro to generate a unique identifier (using __LINE__)
#define UNIQUE_ID(prefix) prefix##_##__LINE__

// Function overloading through macros
#define OVERLOAD_1_ARG(func, x) func##_1(x)
#define OVERLOAD_2_ARGS(func, x, y) func##_2(x, y)
#define OVERLOAD_3_ARGS(func, x, y, z) func##_3(x, y, z)

#define GET_MACRO(_1, _2, _3, NAME, ...) NAME
#define OVERLOAD(func, ...) \
    GET_MACRO(__VA_ARGS__, OVERLOAD_3_ARGS, OVERLOAD_2_ARGS, OVERLOAD_1_ARG)(func, __VA_ARGS__)

// X-Macros pattern
#define LIST_OF_COLORS \
    X(red, 0xFF0000) \
    X(green, 0x00FF00) \
    X(blue, 0x0000FF) \

#define X(name, value) COLOR_##name = value,
enum Colors {
    LIST_OF_COLORS
};
#undef X

#define X(name, value) #name,
const char* color_names[] = {
    LIST_OF_COLORS
};
#undef X

/* ========== Edge Cases ========== */

// Empty macro arguments
#define HANDLE_EMPTY() "Empty args handled"
#define HANDLE_COMMAS(a, b, c) "Got arguments with commas"

// Space between macro name and parentheses
#define SPACED_MACRO (x) "Should not be treated as function-like macro"

// Comments inside macro definition
#define COMMENTED_MACRO(x) /* Comment in the middle */ (x) * 2

// Multiple adjacent stringifications and concatenations
#define COMPLEX_OP(a, b, c) a##b##c #a#b#c

// Macro with non-identifier character in name (implementation-defined)
#define $SPECIAL_MACRO 123

/* ========== Usage Examples for Testing ========== */

// Temporary macro for the test function
#define TEST(name, expr) printf("Test %-30s: %s\n", name, (expr) ? "PASS" : "FAIL");

int main() {
    printf("===== C Preprocessor Macro Test Suite =====\n\n");
    
    // Basic macros
    printf("PI: %f\n", PI);
    printf("MAX_BUFFER_SIZE: %d\n", MAX_BUFFER_SIZE);
    printf("PROGRAM_NAME: %s\n", PROGRAM_NAME);
    
    // Function-like macros
    int a = 5, b = 10;
    printf("SQUARE(5): %d\n", SQUARE(5));
    printf("SQUARE(a+1): %d\n", SQUARE(a+1));  // Tests proper parenthesization
    printf("MAX(a,b): %d\n", MAX(a, b));
    printf("CLAMP(15, 0, 10): %d\n", CLAMP(15, 0, 10));
    
    // Stringification
    printf("STRINGIFY(Hello World): %s\n", STRINGIFY(Hello World));
    //printf("STRING_COMPLEX(a,b,c): %s\n", STRING_COMPLEX(a,b,c));
    printf("STRING_COMPLEX(\"quoted\"): %s\n", STRING_COMPLEX("quoted"));
    
    // Concatenation
    printf("CONCAT(abc, 123): %s\n", CONCAT(abc, 123));
    MAKE_FUNCTION(test);
    func_test();
    
    // Variadic macros
    DEBUG_PRINT("Value: %d\n", 42);
    LOG("INFO", "Simple message\n");
    LOG("DEBUG", "Message with args: %d %s\n", 123, "test");
    
    // Recursive macros
    printf("A(10): %d\n", A(10));
    
    // Conditional compilation results
    printf("FEATURE_ENABLED: %d\n", FEATURE_ENABLED);
    printf("LOG_LEVEL: %s\n", LOG_LEVEL);
    printf("COMPLEX_CONDITION: %d\n", COMPLEX_CONDITION);
    printf("VERSION_STRING: %s\n", VERSION_STRING);
    
    // Multi-line macros
    MULTI_LINE_FUNC(5, 7);
    
    // Unique identifiers
    int UNIQUE_ID(counter) = 0;
    printf("Unique ID created\n");
    
    // X-Macros
    printf("COLOR_red: 0x%06X\n", COLOR_red);
    printf("color_names[0]: %s\n", color_names[0]);
    
    return 0;
}

/* 
 * Expected preprocessor output would expand all macros,
 * resolve all conditionals, and remove all preprocessor directives,
 * resulting in standard C code ready for compilation.
 */
]==]

local function gcc_preprocess(code)
	local temp_filename = os.tmpname() .. ".c"
	local output_filename = os.tmpname() .. ".i"
	local file = assert(io.open(temp_filename, "w"))
	file:write(code)
	file:close()
	os.execute("gcc -E -v " .. temp_filename .. " -o " .. output_filename .. " 2>&1")
	local file = assert(io.open(output_filename, "r"))
	local output = file:read("*all")
	file:close()
	os.remove(temp_filename)
	os.remove(output_filename)
	return output
end

print(gcc_preprocess(c))
