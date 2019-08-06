local lib = {
    -- Basic library
    _ENV = {
      type = "value",
      description = "VALUE ADDED IN Lua 5.2.",
    },
    _G = {
      type = "value",
      description = "A global variable (not a function) that holds the global environment.\nLua itself does not use this variable; changing its value does not affect any environment, nor vice-versa.",
    },
    _VERSION = {
      type = "value",
      description = "A global variable (not a function) that holds a string containing the current interpreter version.",
    },
    assert = {
      type = "function",
      description = "Issues an error when the value of its argument v is false (i.e., nil or false); otherwise, returns all its arguments.\nmessage is an error message; when absent, it defaults to \"assertion failed!\"",
      args = "(v: any [, message: string])",
      returns = "(...)",
    },
    collectgarbage = {
      type = "function",
      description = "This function is a generic interface to the garbage collector.\nIt performs different functions according to its first argument, opt:\n* \"collect\": performs a full garbage-collection cycle. This is the default option.\n* \"stop\": stops automatic execution of the garbage collector. The collector will run only when explicitly invoked, until a call to restart it.\n* \"restart\": restarts automatic execution of the garbage collector.\n* \"count\": returns the total memory in use by Lua (in Kbytes) and a second value with the total memory in bytes modulo 1024 (SECOND RETURN ADDED IN Lua 5.2). The first value has a fractional part, so the following equality is always true:\nk, b = collectgarbage(\"count\")\nassert(k*1024 == math.floor(k)*1024 + b)\n(The second result is useful when Lua is compiled with a non floating-point type for numbers.)\n* \"step\": performs a garbage-collection step. The step \"size\" is controlled by arg (larger values mean more steps) in a non-specified way. If you want to control the step size you must experimentally tune the value of arg. Returns true if the step finished a collection cycle.\n* \"setpause\": sets arg as the new value for the pause of the collector. Returns the previous value for pause.\n* \"setstepmul\": sets arg as the new value for the step multiplier of the collector. Returns the previous value for step.\n* \"isrunning\": returns a boolean that tells whether the collector is running (i.e., not stopped). VALUE ADDED IN Lua 5.2.\n* \"generational\": changes the collector to generational mode. This is an experimental feature. VALUE ADDED IN Lua 5.2.\n* \"incremental\": changes the collector to incremental mode. This is the default mode. VALUE ADDED IN Lua 5.2.",
      args = "([opt: string [, arg: number]])",
      returns = "(...)",
    },
    dofile = {
      type = "function",
      description = "Opens the named file and executes its contents as a Lua chunk.\nWhen called without arguments, dofile executes the contents of the standard input (stdin). Returns all values returned by the chunk. In case of errors, dofile propagates the error to its caller (that is, dofile does not run in protected mode).",
      args = "([filename: string])",
      returns = "(...)",
    },
    error = {
      type = "function",
      description = "Terminates the last protected function called and returns message as the error message.\nFunction error never returns.\nUsually, error adds some information about the error position at the beginning of the message, if the message is a string. The level argument specifies how to get the error position. With level 1 (the default), the error position is where the error function was called. Level 2 points the error to where the function that called error was called; and so on. Passing a level 0 avoids the addition of error position information to the message.",
      args = "(message: string [, level: number])",
      returns = "()",
    },
    getfenv = {
      type = "function",
      description = "Returns the current environment in use by the function.\n\nf can be a Lua function or a number that specifies the function at that stack level: Level 1 is the function calling getfenv. If the given function is not a Lua function, or if f is 0, getfenv returns the global environment. The default for f is 1.\n\nFUNCTION DEPRECATED IN Lua 5.2.",
      args = "([f: function|number])",
      returns = "(table)",
    },
    getmetatable = {
      type = "function",
      description = "If object does not have a metatable, returns nil. Otherwise, if the object's metatable has a \"__metatable\" field, returns the associated value. Otherwise, returns the metatable of the given object.",
      args = "(object: any)",
      returns = "(table|nil)",
      valuetype = "m",
    },
    ipairs = {
      type = "function",
      description = "If t has a metamethod __ipairs, calls it with t as argument and returns the first three results from the call. METAMETHOD BEHAVIOR ADDED IN Lua 5.2.\nOtherwise, returns three values: an iterator function, the table t, and 0, so that the construction\nfor i,v in ipairs(t) do body end\nwill iterate over the pairs (1,t[1]), (2,t[2]), ..., up to the first integer key absent from the table.",
      args = "(t: table)",
      returns = "(function, table, number)",
    },
    load = {
      type = "function",
      description = "Loads a chunk.\nIf ld is a string, the chunk is this string. If ld is a function, load calls it repeatedly to get the chunk pieces. Each call to ld must return a string that concatenates with previous results. A return of an empty string, nil, or no value signals the end of the chunk.\nIf there are no syntactic errors, returns the compiled chunk as a function; otherwise, returns nil plus the error message.\nIf the resulting function has upvalues, the first upvalue is set to the value of the global environment or to env, if that parameter is given. When loading main chunks, the first upvalue will be the _ENV variable. ARGUMENT ADDED IN Lua 5.2.\nsource is used as the source of the chunk for error messages and debug information. When absent, it defaults to ld, if ld is a string, or to \"=(load)\" otherwise.\nThe string mode controls whether the chunk can be text or binary (that is, a precompiled chunk). It may be the string \"b\" (only binary chunks), \"t\" (only text chunks), or \"bt\" (both binary and text). The default is \"bt\". ARGUMENT ADDED IN Lua 5.2.",
      args = "(ld: string|function [, source: string [, mode: string [, env: table]]])",
      returns = "(function|nil [, string])",
    },
    loadfile = {
      type = "function",
      description = "Loads a chunk from file filename or from the standard input, if no file name is given.\nIf there are no syntactic errors, returns the compiled chunk as a function; otherwise, returns nil plus the error message.\nIf the resulting function has upvalues, the first upvalue is set to the value of the global environment or to env, if that parameter is given. ARGUMENT ADDED IN Lua 5.2. When loading main chunks, the first upvalue will be the _ENV variable.\nThe string mode controls whether the chunk can be text or binary (that is, a precompiled chunk). It may be the string \"b\" (only binary chunks), \"t\" (only text chunks), or \"bt\" (both binary and text). The default is \"bt\". ARGUMENT ADDED IN Lua 5.2.",
      args = "([filename: string [, mode: string [, env: table]]])",
      returns = "(function|nil [, string])",
    },
    loadstring = {
      type = "function",
      description = "Loads a chunk from the given string.\nIf there are no errors, returns the compiled chunk as a function; otherwise, returns nil plus the error message. The environment of the returned function is the global environment.\nTo load and run a given string, use the idiom\nassert(loadstring(s))()\nWhen absent, chunkname defaults to the given string.\nFUNCTION DEPRECATED IN Lua 5.2.",
      args = "(string: string [, chunkname: string])",
      returns = "(function|nil [, string])",
    },
    next = {
      type = "function",
      description = "Allows a program to traverse all fields of a table.\nIts first argument is a table and its second argument is an index in this table. next returns the next index of the table and its associated value. When called with nil as its second argument, next returns an initial index and its associated value. When called with the last index, or with nil in an empty table, next returns nil. If the second argument is absent, then it is interpreted as nil. In particular, you can use next(t) to check whether a table is empty.\nThe order in which the indices are enumerated is not specified, even for numeric indices. (To traverse a table in numeric order, use a numerical for.)\nThe behavior of next is undefined if, during the traversal, you assign any value to a non-existent field in the table. You may however modify existing fields. In particular, you may clear existing fields.",
      args = "(table: table [, index: any])",
      returns = "(any [, any])",
    },
    pairs = {
      type = "function",
      description = "If t has a metamethod __pairs, calls it with t as argument and returns the first three results from the call. METAMETHOD BEHAVIOR ADDED IN Lua 5.2.\nOtherwise, returns three values: the next function, the table t, and nil, so that the construction\nfor k,v in pairs(t) do body end\nwill iterate over all key–value pairs of table t.\nSee function next for the caveats of modifying the table during its traversal.",
      args = "(t: table)",
      returns = "(function, table, nil)",
    },
    pcall = {
      type = "function",
      description = "Calls function f with the given arguments in protected mode.\nThis means that any error inside f is not propagated; instead, pcall catches the error and returns a status code. Its first result is the status code (a boolean), which is true if the call succeeds without errors. In such case, pcall also returns all results from the call, after this first result. In case of any error, pcall returns false plus the error message.",
      args = "(f: function [, arg1: any, ...])",
      returns = "(boolean, ...)",
    },
    print = {
      type = "function",
      description = "Receives any number of arguments and prints their values to stdout, using the tostring function to convert each argument to a string.\nprint is not intended for formatted output, but only as a quick way to show a value, for instance for debugging. For complete control over the output, use string.format and io.write.",
      args = "(...)",
      returns = "()",
    },
    rawequal = {
      type = "function",
      description = "Checks whether v1 is equal to v2, without invoking any metamethod.\nReturns a boolean.",
      args = "(v1: any, v2: any)",
      returns = "(boolean)",
    },
    rawget = {
      type = "function",
      description = "Gets the real value of table[index], without invoking any metamethod.\ntable must be a table; index may be any value.",
      args = "(table: table, index: any)",
      returns = "(any)",
    },
    rawlen = {
      type = "function",
      description = "Returns the length of the object v, which must be a table or a string, without invoking any metamethod.\nReturns an integer number.\nFUNCTION ADDED IN Lua 5.2.",
      args = "(v: table|string)",
      returns = "(number)",
    },
    rawset = {
      type = "function",
      description = "Sets the real value of table[index] to value, without invoking any metamethod.\ntable must be a table, index any value different from nil and NaN, and value any Lua value.\nThis function returns table.",
      args = "(table: table, index: any, value: any)",
      returns = "(table)",
    },
    select = {
      type = "function",
      description = "If index is a number, returns all arguments after argument number index.\nA negative number indexes from the end (-1 is the last argument). NEGATIVE VALUE ADDED IN Lua 5.2.\nOtherwise, index must be the string \"#\", and select returns the total number of extra arguments it received.",
      args = "(index: number|string, ...)",
      returns = "(...)",
    },
    setfenv = {
      type = "function",
      description = "Sets the environment to be used by the given function.\nf can be a Lua function or a number that specifies the function at that stack level: Level 1 is the function calling setfenv. setfenv returns the given function.\nAs a special case, when f is 0 setfenv changes the environment of the running thread. In this case, setfenv returns no values.\nFUNCTION DEPRECATED IN Lua 5.2.",
      args = "(f: function|number, table: table)",
      returns = "([function])",
    },
    setmetatable = {
      type = "function",
      description = "Sets the metatable for the given table.\n(You cannot change the metatable of other types from Lua, only from C.)\nIf metatable is nil, removes the metatable of the given table. If the original metatable has a \"__metatable\" field, raises an error.\nThis function returns table.",
      args = "(table: table, metatable: table|nil)",
      returns = "(table)",
      valuetype = "m",
    },
    tonumber = {
      type = "function",
      description = "When called with no base, tonumber tries to convert its argument to a number. If the argument is already a number or a string convertible to a number, then tonumber returns this number; otherwise, it returns nil.\nWhen called with base, then e should be a string to be interpreted as an integer numeral in that base. The base may be any integer between 2 and 36, inclusive. In bases above 10, the letter 'A' (in either upper or lower case) represents 10, 'B' represents 11, and so forth, with 'Z' representing 35. If the string e is not a valid numeral in the given base, the function returns nil.",
      args = "(e: any [, base: number])",
      returns = "(number|nil)",
    },
    tostring = {
      type = "function",
      description = "Receives a value of any type and converts it to a string in a reasonable format.\n(For complete control of how numbers are converted, use string.format.)\nIf the metatable of v has a \"__tostring\" field, then tostring calls the corresponding value with v as argument, and uses the result of the call as its result.",
      args = "(v: any)",
      returns = "(string)",
      valuetype = "string",
    },
    type = {
      type = "function",
      description = "Returns the type of its only argument, coded as a string.\nThe possible results of this function are \"nil\" (a string, not the value nil), \"number\", \"string\", \"boolean\", \"table\", \"function\", \"thread\", and \"userdata\".",
      args = "(v: any)",
      returns = "(string)",
    },
    unpack = {
      type = "function",
      description = "Returns the elements from the given table.\nThis function is equivalent to\nreturn list[i], list[i+1], ···, list[j]\nexcept that the above code can be written only for a fixed number of elements. By default, i is 1 and j is the length of the list, as defined by the length operator.\nFUNCTION DEPRECATED IN Lua 5.2.",
      args = "(list: table [, i: number [, j: number]])",
      returns = "(...)",
    },
    xpcall = {
      type = "function",
      description = "Calls function f with the given arguments in protected mode, using msgh as a message handler.\nThis means that any error inside f is not propagated; instead, xpcall catches the error, calls the msgh function with the original error object, and returns a status code. Its first result is the status code (a boolean), which is true if the call succeeds without errors. In such case, xpcall also returns all results from the call, after this first result. In case of any error, xpcall returns false plus the result from msgh.\nADDITIONAL ARGS ADDED IN Lua 5.2.",
      args = "(f: function, msgh: function [, arg1: any, ...])",
      returns = "(boolean, ...)",
    },
  
    -- Coroutine library
    coroutine = {
      type = "lib",
      description = "The operations related to coroutines comprise a sub-library of the basic library and come inside the table coroutine.\nLua supports coroutines, also called collaborative multithreading. A coroutine in Lua represents an independent thread of execution. Unlike threads in multithread systems, however, a coroutine only suspends its execution by explicitly calling a yield function.",
      childs = {
        create = {
          type = "function",
          description = "Creates a new coroutine, with body f.\nf must be a Lua function. Returns this new coroutine, an object with type \"thread\".",
          args = "(f: function)",
          returns = "(thread)",
        },
        resume = {
          type = "function",
          description = "Starts or continues the execution of coroutine co.\nThe first time you resume a coroutine, it starts running its body. The values val1, ... are passed as the arguments to the body function. If the coroutine has yielded, resume restarts it; the values val1, ... are passed as the results from the yield.\nIf the coroutine runs without any errors, resume returns true plus any values passed to yield (if the coroutine yields) or any values returned by the body function (if the coroutine terminates). If there is any error, resume returns false plus the error message.",
          args = "(co: thread [, val1: any, ...])",
          returns = "(boolean, ...)",
        },
        running = {
          type = "function",
          description = "Returns the running coroutine plus a boolean, true when the running coroutine is the main one.\nBOOLEAN RETURN ADDED IN Lua 5.2.",
          args = "()",
          returns = "(thread, boolean)",
        },
        status = {
          type = "function",
          description = "Returns the status of coroutine co, as a string.\nThe status can be one of the following: \"running\", if the coroutine is running (that is, it called status); \"suspended\", if the coroutine is suspended in a call to yield, or if it has not started running yet; \"normal\" if the coroutine is active but not running (that is, it has resumed another coroutine); and \"dead\" if the coroutine has finished its body function, or if it has stopped with an error.",
          args = "(co: thread)",
          returns = "(string)",
        },
        wrap = {
          type = "function",
          description = "Creates a new coroutine, with body f.\nf must be a Lua function. Returns a function that resumes the coroutine each time it is called. Any arguments passed to the function behave as the extra arguments to resume. Returns the same values returned by resume, except the first boolean. In case of error, propagates the error.",
          args = "(f: function)",
          returns = "(function)",
        },
        yield = {
          type = "function",
          description = "Suspends the execution of the calling coroutine.\nAny arguments to yield are passed as extra results to resume.",
          args = "(...)",
          returns = "()",
        },
        isyieldable = {
          type = "function",
          description = "Returns true when the running coroutine can yield. A running coroutine is yieldable if it is not the main thread and it is not inside a non-yieldable C function.\nFUNCTION ADDED IN Lua 5.3.",
          args = "()",
          returns = "(boolean)",
        },
      },
    },
  
    -- Module/Package library
    module = {
      type = "function",
      description = "Creates a module.\nIf there is a table in package.loaded[name], this table is the module. Otherwise, if there is a global table t with the given name, this table is the module. Otherwise creates a new table t and sets it as the value of the global name and the value of package.loaded[name]. This function also initializes t._NAME with the given name, t._M with the module (t itself), and t._PACKAGE with the package name (the full module name minus last component; see below). Finally, module sets t as the new environment of the current function and the new value of package.loaded[name], so that require returns t.\nIf name is a compound name (that is, one with components separated by dots), module creates (or reuses, if they already exist) tables for each component.\nThis function can receive optional options after the module name, where each option is a function to be applied over the module.\nFUNCTION DEPRECATED IN Lua 5.2.",
      args = "(name: string [, ...])",
      returns = "()",
    },
    require = {
      type = "function",
      description = "Loads the given module.\nThe function starts by looking into the package.loaded table to determine whether modname is already loaded. If it is, then require returns the value stored at package.loaded[modname]. Otherwise, it tries to find a loader for the module.\nTo find a loader, require is guided by the package.searchers sequence. By changing this sequence, we can change how require looks for a module. The following explanation is based on the default configuration for package.searchers.\nFirst require queries package.preload[modname]. If it has a value, this value (which should be a function) is the loader. Otherwise require searches for a Lua loader using the path stored in package.path. If that also fails, it searches for a C loader using the path stored in package.cpath. If that also fails, it tries an all-in-one loader (see package.searchers).\nOnce a loader is found, require calls the loader with two arguments: modname and an extra value dependent on how it got the loader. (If the loader came from a file, this extra value is the file name.) If the loader returns any non-nil value, require assigns the returned value to package.loaded[modname]. If the loader does not return a non-nil value and has not assigned any value to package.loaded[modname], then require assigns true to this entry. In any case, require returns the final value of package.loaded[modname].\nIf there is any error loading or running the module, or if it cannot find any loader for the module, then require raises an error.",
      args = "(modname: string)",
      returns = "(any)",
    },
    package = {
      type = "lib",
      description = "The package library provides basic facilities for loading modules in Lua.\nIt exports one function directly in the global environment: require. Everything else is exported in a table package.",
      childs = {
        config = {
          type = "value",
          description = "A string describing some compile-time configurations for packages.\nThis string is a sequence of lines:\n* The first line is the directory separator string. Default is '\\' for Windows and '/' for all other systems.\n* The second line is the character that separates templates in a path. Default is ';'.\n* The third line is the string that marks the substitution points in a template. Default is '?'.\n* The fourth line is a string that, in a path in Windows, is replaced by the executable's directory. Default is '!'.\n* The fifth line is a mark to ignore all text before it when building the luaopen_ function name. Default is '-'.",
        },
        cpath = {
          type = "value",
          description = "The path used by require to search for a C loader.\nLua initializes the C path package.cpath in the same way it initializes the Lua path package.path, using the environment variable LUA_CPATH_5_2 or the environment variable LUA_CPATH or a default path defined in luaconf.h.",
        },
        loaded = {
          type = "value",
          description = "A table used by require to control which modules are already loaded.\nWhen you require a module modname and package.loaded[modname] is not false, require simply returns the value stored there.\nThis variable is only a reference to the real table; assignments to this variable do not change the table used by require.",
        },
        loaders = {
          type = "value",
          description = "A table used by require to control how to load modules.\nEach entry in this table is a searcher function. When looking for a module, require calls each of these searchers in ascending order, with the module name (the argument given to require) as its sole parameter. The function can return another function (the module loader) or a string explaining why it did not find that module (or nil if it has nothing to say). Lua initializes this table with four functions.\nThe first searcher simply looks for a loader in the package.preload table.\nThe second searcher looks for a loader as a Lua library, using the path stored at package.path. A path is a sequence of templates separated by semicolons. For each template, the searcher will change each interrogation mark in the template by filename, which is the module name with each dot replaced by a \"directory separator\" (such as \"/\" in Unix); then it will try to open the resulting file name.\nThe third searcher looks for a loader as a C library, using the path given by the variable package.cpath. Once it finds a C library, this searcher first uses a dynamic link facility to link the application with the library. Then it tries to find a C function inside the library to be used as the loader. The name of this C function is the string \"luaopen_\" concatenated with a copy of the module name where each dot is replaced by an underscore. Moreover, if the module name has a hyphen, its prefix up to (and including) the first hyphen is removed.\nThe fourth searcher tries an all-in-one loader. It searches the C path for a library for the root name of the given module. If found, it looks into it for an open function for the submodule. With this facility, a package can pack several C submodules into one single library, with each submodule keeping its original open function.\nVALUE DEPRECATED IN Lua 5.2.",
        },
        loadlib = {
          type = "function",
          description = "Dynamically links the host program with the C library libname.\nIf funcname is \"*\", then it only links with the library, making the symbols exported by the library available to other dynamically linked libraries. VALUE ADDED IN Lua 5.2.\nOtherwise, it looks for a function funcname inside the library and returns this function as a C function. (So, funcname must follow the prototype lua_CFunction).\nThis is a low-level function. It completely bypasses the package and module system. Unlike require, it does not perform any path searching and does not automatically adds extensions. libname must be the complete file name of the C library, including if necessary a path and an extension. funcname must be the exact name exported by the C library (which may depend on the C compiler and linker used).\nThis function is not supported by Standard C. As such, it is only available on some platforms (Windows, Linux, Mac OS X, Solaris, BSD, plus other Unix systems that support the dlfcn standard).",
          args = "(libname: string, funcname: string)",
          returns = "([function])",
        },
        path = {
          type = "value",
          description = "The path used by require to search for a Lua loader.\nAt start-up, Lua initializes this variable with the value of the environment variable LUA_PATH_5_2 or the environment variable LUA_PATH or with a default path defined in luaconf.h, if those environment variables are not defined. Any \";;\" in the value of the environment variable is replaced by the default path.",
        },
        preload = {
          type = "value",
          description = "A table to store loaders for specific modules (see require).\nThis variable is only a reference to the real table; assignments to this variable do not change the table used by require.",
        },
        searchers = {
          type = "value",
          description = "A table used by require to control how to load modules.\nEach entry in this table is a searcher function. When looking for a module, require calls each of these searchers in ascending order, with the module name (the argument given to require) as its sole parameter. The function can return another function (the module loader) plus an extra value that will be passed to that loader, or a string explaining why it did not find that module (or nil if it has nothing to say).\nLua initializes this table with four searcher functions.\nThe first searcher simply looks for a loader in the package.preload table.\nThe second searcher looks for a loader as a Lua library, using the path stored at package.path. The search is done as described in function package.searchpath.\nThe third searcher looks for a loader as a C library, using the path given by the variable package.cpath. Again, the search is done as described in function package.searchpath. Once it finds a C library, this searcher first uses a dynamic link facility to link the application with the library. Then it tries to find a C function inside the library to be used as the loader. The name of this C function is the string \"luaopen_\" concatenated with a copy of the module name where each dot is replaced by an underscore. Moreover, if the module name has a hyphen, its prefix up to (and including) the first hyphen is removed.\nThe fourth searcher tries an all-in-one loader. It searches the C path for a library for the root name of the given module. If found, it looks into it for an open function for the submodule. With this facility, a package can pack several C submodules into one single library, with each submodule keeping its original open function.\nAll searchers except the first one (preload) return as the extra value the file name where the module was found, as returned by package.searchpath. The first searcher returns no extra value.\nVALUE ADDED IN Lua 5.2.",
        },
        searchpath = {
          type = "function",
          description = "Searches for the given name in the given path.\nA path is a string containing a sequence of templates separated by semicolons. For each template, the function replaces each interrogation mark (if any) in the template with a copy of name wherein all occurrences of sep (a dot, by default) were replaced by rep (the system's directory separator, by default), and then tries to open the resulting file name.\nReturns the resulting name of the first file that it can open in read mode (after closing the file), or nil plus an error message if none succeeds. (This error message lists all file names it tried to open.)\nFUNCTION ADDED IN Lua 5.2.",
          args = "(name: string, path: string [, sep: string [, rep: string]])",
          returns = "(string|nil [, string])",
        },
        seeall = {
          type = "function",
          description = "Sets a metatable for module with its __index field referring to the global environment, so that this module inherits values from the global environment.\nTo be used as an option to function module.\nFUNCTION DEPRECATED IN Lua 5.2.",
          args = "(module: table)",
          returns = "()",
        },
      },
    },
  
    -- String library
    string = {
      type = "lib",
      description = "This library provides generic functions for string manipulation, such as finding and extracting substrings, and pattern matching.\nWhen indexing a string in Lua, the first character is at position 1 (not at 0, as in C). Indices are allowed to be negative and are interpreted as indexing backwards, from the end of the string. Thus, the last character is at position -1, and so on.\nThe string library provides all its functions inside the table string. It also sets a metatable for strings where the __index field points to the string table. Therefore, you can use the string functions in object-oriented style. For instance, string.byte(s,i) can be written as s:byte(i).\nThe string library assumes one-byte character encodings.",
      childs = {
        byte = {
          type = "function",
          description = "Returns the internal numerical codes of the characters s[i], s[i+1], ..., s[j].\nThe default value for i is 1; the default value for j is i. These indices are corrected following the same rules of function string.sub.\nNumerical codes are not necessarily portable across platforms.",
          args = "(s: string [, i: number [, j: number]])",
          returns = "(number [, ...])",
        },
        char = {
          type = "function",
          description = "Receives zero or more integers. Returns a string with length equal to the number of arguments, in which each character has the internal numerical code equal to its corresponding argument.\nNumerical codes are not necessarily portable across platforms.",
          args = "(...)",
          returns = "(string)",
          valuetype = "string",
        },
        dump = {
          type = "function",
          description = "Returns a string containing a binary representation of the given function, so that a later load on this string returns a copy of the function (but with new upvalues).",
          args = "(function: function)",
          returns = "(string)",
          valuetype = "string",
        },
        find = {
          type = "function",
          description = "Looks for the first match of pattern in the string s.\nIf it finds a match, then find returns the indices of s where this occurrence starts and ends; otherwise, it returns nil.\nA third, optional numerical argument init specifies where to start the search; its default value is 1 and can be negative. A value of true as a fourth, optional argument plain turns off the pattern matching facilities, so the function does a plain \"find substring\" operation, with no characters in pattern being considered magic. Note that if plain is given, then init must be given as well.\nIf the pattern has captures, then in a successful match the captured values are also returned, after the two indices.",
          args = "(s: string, pattern: string [, init: number [, plain: boolean]])",
          returns = "(number|nil [, number [, ...]])",
        },
        format = {
          type = "function",
          description = "Returns a formatted version of its variable number of arguments following the description given in its first argument (which must be a string).\nThe format string follows the same rules as the C function sprintf. The only differences are that the options/modifiers *, h, L, l, n, and p are not supported and that there is an extra option, q. The q option formats a string between double quotes, using escape sequences when necessary to ensure that it can safely be read back by the Lua interpreter.\nOptions A and a (when available) (VALUES ADDED IN Lua 5.2), E, e, f, G, and g all expect a number as argument. Options c, d, i, o, u, X, and x also expect a number, but the range of that number may be limited by the underlying C implementation. For options o, u, X, and x, the number cannot be negative. Option q expects a string; option s expects a string without embedded zeros. If the argument to option s is not a string, it is converted to one following the same rules of tostring (BEHAVIOR ADDED IN Lua 5.2).",
          args = "(formatstring, ...)",
          returns = "(string)",
          valuetype = "string",
        },
        gmatch = {
          type = "function",
          description = "Returns an iterator function that, each time it is called, returns the next captures from pattern over the string s.\nIf pattern specifies no captures, then the whole match is produced in each call.\nFor this function, a caret '^' at the start of a pattern does not work as an anchor, as this would prevent the iteration.",
          args = "(s: string, pattern: string)",
          returns = "(function)",
        },
        pack = {
          type = "function",
          description = "Returns a binary string containing the values v1, v2, etc. packed (that is, serialized in binary form) according to the format string fmt.\nFUNCTION ADDED IN Lua 5.3.",
          args = "(fmt: string, v1, v2, ...)",
          returns = "(string)",
          valuetype = "string",
        },
        unpack = {
          type = "function",
          description = "Returns the values packed in string s (see string.pack) according to the format string fmt. An optional pos marks where to start reading in s (default is 1). After the read values, this function also returns the index of the first unread byte in s.\nFUNCTION ADDED IN Lua 5.3.",
          args = "(fmt: string, s: string [, pos: number])",
          returns = "(values)",
        },
        packsize = {
          type = "function",
          description = "Returns the size of a string resulting from string.pack with the given format. The format string cannot have the variable-length options 's' or 'z'.\nFUNCTION ADDED IN Lua 5.3.",
          args = "(fmt: string)",
          returns = "(number)",
        },
        gsub = {
          type = "function",
          description = "Returns a copy of s in which all (or the first n, if given) occurrences of the pattern have been replaced by a replacement string specified by repl, which can be a string, a table, or a function.\ngsub also returns, as its second value, the total number of matches that occurred. The name gsub comes from Global SUBstitution.\nIf repl is a string, then its value is used for replacement. The character % works as an escape character: any sequence in repl of the form %d, with d between 1 and 9, stands for the value of the d-th captured substring. The sequence %0 stands for the whole match. The sequence %% stands for a single %.\nIf repl is a table, then the table is queried for every match, using the first capture as the key.\nIf repl is a function, then this function is called every time a match occurs, with all captured substrings passed as arguments, in order.\nIn any case, if the pattern specifies no captures, then it behaves as if the whole pattern was inside a capture.\nIf the value returned by the table query or by the function call is a string or a number, then it is used as the replacement string; otherwise, if it is false or nil, then there is no replacement (that is, the original match is kept in the string).",
          args = "(s: string, pattern: string, repl: string|table|function [, n: number])",
          returns = "(string, number)",
          valuetype = "string",
        },
        len = {
          type = "function",
          description = "Receives a string and returns its length.\nThe empty string \"\" has length 0. Embedded zeros are counted, so \"a\\000bc\\000\" has length 5.",
          args = "(s: string)",
          returns = "(number)",
        },
        lower = {
          type = "function",
          description = "Receives a string and returns a copy of this string with all uppercase letters changed to lowercase.\nAll other characters are left unchanged. The definition of what an uppercase letter is depends on the current locale.",
          args = "(s: string)",
          returns = "(string)",
          valuetype = "string",
        },
        match = {
          type = "function",
          description = "Looks for the first match of pattern in the string s.\nIf it finds one, then match returns the captures from the pattern; otherwise it returns nil.\nIf pattern specifies no captures, then the whole match is returned. A third, optional numerical argument init specifies where to start the search; its default value is 1 and can be negative.",
          args = "(s: string, pattern: string [, init: number])",
          returns = "(string|nil [,...])",
          valuetype = "string",
        },
        rep = {
          type = "function",
          description = "Returns a string that is the concatenation of n copies of the string s separated by the string sep.\nThe default value for sep is the empty string (that is, no separator). ARGUMENT ADDED IN Lua 5.2.",
          args = "(s: string, n: number [, sep: string])",
          returns = "(string)",
          valuetype = "string",
        },
        reverse = {
          type = "function",
          description = "Returns a string that is the string s reversed.",
          args = "(s: string)",
          returns = "(string)",
          valuetype = "string",
        },
        sub = {
          type = "function",
          description = "Returns the substring of s that starts at i and continues until j; i and j can be negative.\nIf j is absent, then it is assumed to be equal to -1 (which is the same as the string length). In particular, the call string.sub(s,1,j) returns a prefix of s with length j, and string.sub(s, -i) returns a suffix of s with length i.\nIf, after the translation of negative indices, i is less than 1, it is corrected to 1. If j is greater than the string length, it is corrected to that length. If, after these corrections, i is greater than j, the function returns the empty string.",
          args = "(s: string, i: number [, j: number])",
          returns = "(string)",
          valuetype = "string",
        },
        upper = {
          type = "function",
          description = "Receives a string and returns a copy of this string with all lowercase letters changed to uppercase.\nAll other characters are left unchanged. The definition of what a lowercase letter is depends on the current locale.",
          args = "(s: string)",
          returns = "(string)",
          valuetype = "string",
        },
      },
    },
  
    -- Table library
    table = {
      type = "lib",
      description = "This library provides generic functions for table manipulation. It provides all its functions inside the table table.\nRemember that, whenever an operation needs the length of a table, the table should be a proper sequence or have a __len metamethod. All functions ignore non-numeric keys in tables given as arguments.\nFor performance reasons, all table accesses (get/set) performed by these functions are raw.",
      childs = {
        concat = {
          type = "function",
          description = "Given a list where all elements are strings or numbers, returns list[i]..sep..list[i+1] ··· sep..list[j].\nThe default value for sep is the empty string, the default for i is 1, and the default for j is #list. If i is greater than j, returns the empty string.",
          args = "(list: table [, sep: string [, i: number [, j: number]]])",
          returns = "(string)",
          valuetype = "string",
        },
        insert = {
          type = "function",
          description = "Inserts element value at position pos in list, shifting up the elements list[pos], list[pos+1], ···, list[#list].\nThe default value for pos is #list+1, so that a call table.insert(t,x) inserts x at the end of list t.",
          args = "(list: table, [pos: number,] value: any)",
          returns = "()",
        },
        maxn = {
          type = "function",
          description = "Returns the largest positive numerical index of the given table, or zero if the table has no positive numerical indices.\n(To do its job this function does a linear traversal of the whole table.)\nFUNCTION DEPRECATED IN Lua 5.2.",
          args = "(table: table)",
          returns = "(number)",
        },
        pack = {
          type = "function",
          description = "Returns a new table with all parameters stored into keys 1, 2, etc. and with a field \"n\" with the total number of parameters.\nNote that the resulting table may not be a sequence.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(...)",
          returns = "(table)",
        },
        move = {
          type = "function",
          description = "Moves elements from table a1 to table a2. This function performs the equivalent to the following multiple assignment: a2[t],··· = a1[f],···,a1[e]. The default for a2 is a1. The destination range can overlap with the source range. Index f must be positive.\nFUNCTION ADDED IN Lua 5.3.",
          args = "(a1: table, f, e, t [,a2: table])",
          returns = "()",
        },
        remove = {
          type = "function",
          description = "Removes from list the element at position pos, shifting down the elements list[pos+1], list[pos+2], ···, list[#list] and erasing element list[#list].\nReturns the value of the removed element.\nThe default value for pos is #list, so that a call table.remove(t) removes the last element of list t.",
          args = "(list: table [, pos: number])",
          returns = "(any)",
        },
        sort = {
          type = "function",
          description = "Sorts list elements in a given order, in-place, from list[1] to list[#list].\nIf comp is given, then it must be a function that receives two list elements and returns true when the first element must come before the second in the final order (so that not comp(list[i+1],list[i]) will be true after the sort). If comp is not given, then the standard Lua operator < is used instead.\nThe sort algorithm is not stable; that is, elements considered equal by the given order may have their relative positions changed by the sort.",
          args = "(list: table [, comp: function])",
          returns = "()",
        },
        unpack = {
          type = "function",
          description = "Returns the elements from the given table.\nThis function is equivalent to\nreturn list[i], list[i+1], ···, list[j]\nBy default, i is 1 and j is #list.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(list: table [, i: number [, j: number]])",
          returns = "(...)",
        },
      },
    },
  
    -- Math library
    math = {
      type = "lib",
      description = "This library is an interface to the standard C math library. It provides all its functions inside the table math.",
      childs = {
        abs = {
          type = "function",
          description = "Returns the absolute value of x.",
          args = "(x: number)",
          returns = "(number)",
        },
        acos = {
          type = "function",
          description = "Returns the arc cosine of x (in radians).",
          args = "(x: number)",
          returns = "(number)",
        },
        asin = {
          type = "function",
          description = "Returns the arc sine of x (in radians).",
          args = "(x: number)",
          returns = "(number)",
        },
        atan = {
          type = "function",
          description = "Returns the arc tangent of x (in radians).",
          args = "(x: number)",
          returns = "(number)",
        },
        atan2 = {
          type = "function",
          description = "Returns the arc tangent of y/x (in radians), but uses the signs of both parameters to find the quadrant of the result.\n(It also handles correctly the case of x being zero.)",
          args = "(y: number, x: number)",
          returns = "(number)",
        },
        ceil = {
          type = "function",
          description = "Returns the smallest integer larger than or equal to x.",
          args = "(x: number)",
          returns = "(number)",
        },
        cos = {
          type = "function",
          description = "Returns the cosine of x (assumed to be in radians).",
          args = "(x: number)",
          returns = "(number)",
        },
        cosh = {
          type = "function",
          description = "Returns the hyperbolic cosine of x.",
          args = "(x: number)",
          returns = "(number)",
        },
        deg = {
          type = "function",
          description = "Returns the angle x (given in radians) in degrees.",
          args = "(x: number)",
          returns = "(number)",
        },
        exp = {
          type = "function",
          description = "Returns the value exp(x).",
          args = "(x: number)",
          returns = "(number)",
        },
        floor = {
          type = "function",
          description = "Returns the largest integer smaller than or equal to x.",
          args = "(x: number)",
          returns = "(number)",
        },
        fmod = {
          type = "function",
          description = "Returns the remainder of the division of x by y that rounds the quotient towards zero.",
          args = "(x: number, y: number)",
          returns = "(number)",
        },
        frexp = {
          type = "function",
          description = "Returns m and e such that x = m2^e, e is an integer and the absolute value of m is in the range [0.5, 1) (or zero when x is zero).",
          args = "(x: number)",
          returns = "(number, number)",
        },
        huge = {
          type = "value",
          description = "The value HUGE_VAL, a value larger than or equal to any other numerical value.",
        },
        ldexp = {
          type = "function",
          description = "Returns m2^e (e should be an integer).",
          args = "(m: number, e: number)",
          returns = "(number)",
        },
        log = {
          type = "function",
          description = "Returns the logarithm of x in the given base.\nThe default for base is e (so that the function returns the natural logarithm of x). ARGUMENT ADDED IN Lua 5.2.",
          args = "(x: number [, base: number])",
          returns = "(number)",
        },
        log10 = {
          type = "function",
          description = "Returns the base-10 logarithm of x.\nFUNCTION DEPRECATED IN Lua 5.2.",
          args = "(x: number)",
          returns = "(number)",
        },
        max = {
          type = "function",
          description = "Returns the maximum value among its arguments.",
          args = "(x: number, ...)",
          returns = "(number)",
        },
        min = {
          type = "function",
          description = "Returns the minimum value among its arguments.",
          args = "(x: number, ...)",
          returns = "(number)",
        },
        modf = {
          type = "function",
          description = "Returns two numbers, the integral part of x and the fractional part of x.",
          args = "(x: number)",
          returns = "(number, number)",
        },
        pi = {
          type = "value",
          description = "The value of pi.",
        },
        mininteger = {
          type = "value",
          description = "An integer with the minimum value for an integer.\nVALUE ADDED IN Lua 5.3.",
        },
        maxinteger = {
          type = "value",
          description = "An integer with the maximum value for an integer.\nVALUE ADDED IN Lua 5.3.",
        },
        pow = {
          type = "function",
          description = "Returns x^y.\n(You can also use the expression x^y to compute this value.)",
          args = "(x: number, y: number)",
          returns = "(number)",
        },
        rad = {
          type = "function",
          description = "Returns the angle x (given in degrees) in radians.",
          args = "(x: number)",
          returns = "(number)",
        },
        random = {
          type = "function",
          description = "This function is an interface to the simple pseudo-random generator function rand provided by Standard C.\n(No guarantees can be given for its statistical properties.)\nWhen called without arguments, returns a uniform pseudo-random real number in the range [0,1). When called with an integer number m, math.random returns a uniform pseudo-random integer in the range [1, m]. When called with two integer numbers m and n, math.random returns a uniform pseudo-random integer in the range [m, n].",
          args = "([m: number [, n: number]])",
          returns = "(number)",
        },
        randomseed = {
          type = "function",
          description = "Sets x as the \"seed\" for the pseudo-random generator: equal seeds produce equal sequences of numbers.",
          args = "(x: number)",
          returns = "()",
        },
        sin = {
          type = "function",
          description = "Returns the sine of x (assumed to be in radians).",
          args = "(x: number)",
          returns = "(number)",
        },
        sinh = {
          type = "function",
          description = "Returns the hyperbolic sine of x.",
          args = "(x: number)",
          returns = "(number)",
        },
        sqrt = {
          type = "function",
          description = "Returns the square root of x.\n(You can also use the expression x^0.5 to compute this value.)",
          args = "(x: number)",
          returns = "(number)",
        },
        tan = {
          type = "function",
          description = "Returns the tangent of x (assumed to be in radians).",
          args = "(x: number)",
          returns = "(number)",
        },
        tanh = {
          type = "function",
          description = "Returns the hyperbolic tangent of x.",
          args = "(x: number)",
          returns = "(number)",
        },
        type = {
          type = "function",
          description = [[Returns "integer" if x is an integer, "float" if it is a float, or nil if x is not a number.\nFUNCTION ADDED IN Lua 5.3.]],
          args = "(x: number)",
          returns = "(string)",
        },
        tointeger = {
          type = "function",
          description = "If the value x is convertible to an integer, returns that integer. Otherwise, returns nil.\nFUNCTION ADDED IN Lua 5.3.",
          args = "(x: number)",
          returns = "(number)",
        },
        ult = {
          type = "function",
          description = "Returns a boolean, true if integer m is below integer n when they are compared as unsigned integers.\nFUNCTION ADDED IN Lua 5.3.",
          args = "(m: number, n: number)",
          returns = "(boolean)",
        },
      },
    },
  
    -- Bitwise library
    bit32 = {
      type = "lib",
      description = "This library provides bitwise operations. It provides all its functions inside the table bit32.\nUnless otherwise stated, all functions accept numeric arguments in the range (-2^51,+2^51); each argument is normalized to the remainder of its division by 2^32 and truncated to an integer (in some unspecified way), so that its final value falls in the range [0,2^32 - 1]. Similarly, all results are in the range [0,2^32 - 1]. Note that bit32.bnot(0) is 0xFFFFFFFF, which is different from -1.",
      childs = {
        arshift = {
          type = "function",
          description = "Returns the number x shifted disp bits to the right.\nThe number disp may be any representable integer. Negative displacements shift to the left.\nThis shift operation is what is called arithmetic shift. Vacant bits on the left are filled with copies of the higher bit of x; vacant bits on the right are filled with zeros. In particular, displacements with absolute values higher than 31 result in zero or 0xFFFFFFFF (all original bits are shifted out).\nFUNCTION ADDED IN Lua 5.2.",
          args = "(x: number, disp: number)",
          returns = "(number)",
        },
        band = {
          type = "function",
          description = "Returns the bitwise and of its operands.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(...)",
          returns = "(number)",
        },
        bnot = {
          type = "function",
          description = "Returns the bitwise negation of x.\nFor any integer x, the following identity holds:\nassert(bit32.bnot(x) == (-1 - x) % 2^32)\nFUNCTION ADDED IN Lua 5.2.",
          args = "(x: number)",
          returns = "(number)",
        },
        bor = {
          type = "function",
          description = "Returns the bitwise or of its operands.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(...)",
          returns = "(number)",
        },
        btest = {
          type = "function",
          description = "Returns a boolean signaling whether the bitwise and of its operands is different from zero.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(...)",
          returns = "(boolean)",
        },
        bxor = {
          type = "function",
          description = "Returns the bitwise exclusive or of its operands.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(...)",
          returns = "(number)",
        },
        extract = {
          type = "function",
          description = "Returns the unsigned number formed by the bits field to field + width - 1 from n.\nBits are numbered from 0 (least significant) to 31 (most significant). All accessed bits must be in the range [0, 31].\nThe default for width is 1.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(n: number, field: number [, width: number])",
          returns = "(number)",
        },
        replace = {
          type = "function",
          description = "Returns a copy of n with the bits field to field + width - 1 replaced by the value v.\nBits are numbered from 0 (least significant) to 31 (most significant). All accessed bits must be in the range [0, 31].\nThe default for width is 1.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(n: number, v: number, field: number [, width: number])",
          returns = "(number)",
        },
        lrotate = {
          type = "function",
          description = "Returns the number x rotated disp bits to the left.\nThe number disp may be any representable integer.\nFor any valid displacement, the following identity holds:\nassert(bit32.lrotate(x, disp) == bit32.lrotate(x, disp % 32))\nIn particular, negative displacements rotate to the right.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(x: number, disp: number)",
          returns = "(number)",
        },
        lshift = {
          type = "function",
          description = "Returns the number x shifted disp bits to the left.\nThe number disp may be any representable integer. Negative displacements shift to the right. In any direction, vacant bits are filled with zeros. In particular, displacements with absolute values higher than 31 result in zero (all bits are shifted out).\nFor positive displacements, the following equality holds:\nassert(bit32.lshift(b, disp) == (b * 2^disp) % 2^32)\nFUNCTION ADDED IN Lua 5.2.",
          args = "(x: number, disp: number)",
          returns = "(number)",
        },
        rrotate = {
          type = "function",
          description = "Returns the number x rotated disp bits to the right.\nThe number disp may be any representable integer.\nFor any valid displacement, the following identity holds:\nassert(bit32.rrotate(x, disp) == bit32.rrotate(x, disp % 32))\nIn particular, negative displacements rotate to the left.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(x: number, disp: number)",
          returns = "(number)",
        },
        rshift = {
          type = "function",
          description = "Returns the number x shifted disp bits to the right.\nThe number disp may be any representable integer. Negative displacements shift to the left. In any direction, vacant bits are filled with zeros. In particular, displacements with absolute values higher than 31 result in zero (all bits are shifted out).\nFor positive displacements, the following equality holds:\nassert(bit32.rshift(b, disp) == math.floor(b % 2^32 / 2^disp))\nThis shift operation is what is called logical shift.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(x: number, disp: number)",
          returns = "(number)",
        },
      },
    },
  
    -- I/O library
    io = {
      type = "lib",
      description = "The I/O library provides two different styles for file manipulation. The first one uses implicit file descriptors; that is, there are operations to set a default input file and a default output file, and all input/output operations are over these default files. The second style uses explicit file descriptors.\nWhen using implicit file descriptors, all operations are supplied by table io. When using explicit file descriptors, the operation io.open returns a file descriptor and then all operations are supplied as methods of the file descriptor.\nThe table io also provides three predefined file descriptors with their usual meanings from C: io.stdin, io.stdout, and io.stderr. The I/O library never closes these files.\nUnless otherwise stated, all I/O functions return nil on failure (plus an error message as a second result and a system-dependent error code as a third result) and some value different from nil on success.",
      childs = {
        stdin = { type = "value" },
        stdout = { type = "value" },
        stderr = { type = "value" },
        close = {
          type = "function",
          description = "Closes file. Equivalent to file:close().\nWithout a file, closes the default output file.",
          args = "([file: file])",
          returns = "(boolean|nil [, string, number])",
        },
        flush = {
          type = "function",
          description = "Saves any written data to the default output file. Equivalent to io.output():flush().",
          args = "()",
          returns = "()",
        },
        input = {
          type = "function",
          description = "When called with a file name, it opens the named file (in text mode), and sets its handle as the default input file. When called with a file handle, it simply sets this file handle as the default input file. When called without parameters, it returns the current default input file.\nIn case of errors this function raises the error, instead of returning an error code.",
          args = "([file: string|file])",
          returns = "([file])",
          valuetype = "f",
        },
        lines = {
          type = "function",
          description = "Opens the given file name in read mode and returns an iterator function that, each time it is called, reads the file according to the given formats.\nWhen no format is given, uses \"*l\" as a default. ARGUMENT ADDED IN Lua 5.2.\nWhen the iterator function detects the end of file, it returns nil (to finish the loop) and automatically closes the file.\nThe call io.lines() (with no file name) is equivalent to io.input():lines(); that is, it iterates over the lines of the default input file. In this case it does not close the file when the loop ends.\nIn case of errors this function raises the error, instead of returning an error code.",
          args = "([filename: string, ...])",
          returns = "(function)",
        },
        open = {
          type = "function",
          description = "This function opens a file, in the mode specified in the string mode.\nIt returns a new file handle, or, in case of errors, nil plus an error message.\nThe mode string can be any of the following:\n* \"r\": read mode (the default);\n* \"w\": write mode;\n* \"a\": append mode;\n* \"r+\": update mode, all previous data is preserved;\n* \"w+\": update mode, all previous data is erased;\n* \"a+\": append update mode, previous data is preserved, writing is only allowed at the end of file.\nThe mode string can also have a 'b' at the end, which is needed in some systems to open the file in binary mode.",
          args = "(filename: string [, mode: string])",
          returns = "(file|nil [, string])",
          valuetype = "f",
        },
        output = {
          type = "function",
          description = "When called with a file name, it opens the named file (in text mode), and sets its handle as the default output file. When called with a file handle, it simply sets this file handle as the default output file. When called without parameters, it returns the current default output file.\nIn case of errors this function raises the error, instead of returning an error code.",
          args = "([file: string|file])",
          returns = "([file])",
          valuetype = "f",
        },
        popen = {
          type = "function",
          description = "Starts program prog in a separated process and returns a file handle that you can use to read data from this program (if mode is \"r\", the default) or to write data to this program (if mode is \"w\").\nThis function is system dependent and is not available on all platforms.",
          args = "(prog: string [, mode: string])",
          returns = "(file|nil [, string])",
          valuetype = "f",
        },
        read = {
          type = "function",
          description = "Reads the default input file, according to the given formats. Equivalent to io.input():read(...).",
          args = "(...)",
          returns = "(...)",
        },
        tmpfile = {
          type = "function",
          description = "Returns a handle for a temporary file.\nThis file is opened in update mode and it is automatically removed when the program ends.",
          args = "()",
          returns = "(file)",
          valuetype = "f",
        },
        type = {
          type = "function",
          description = "Checks whether obj is a valid file handle.\nReturns the string \"file\" if obj is an open file handle, \"closed file\" if obj is a closed file handle, or nil if obj is not a file handle.",
          args = "(obj: file)",
          returns = "(string|nil)",
        },
        write = {
          type = "function",
          description = "Writes the value of each of its arguments to the default output file. Equivalent to io.output():write(...).",
          args = "(...)",
          returns = "(file|nil [, string])",
        },
      },
    },
  
    f = {
      type = "class",
      description = "Pseudoclass for operations on file handles.",
      childs = {
        close = {
          type = "method",
          description = "Closes file.\nNote that files are automatically closed when their handles are garbage collected, but that takes an unpredictable amount of time to happen.\nWhen closing a file handle created with io.popen, file:close returns the same values returned by os.execute. RETURN SPECIAL CASE ADDED IN Lua 5.2.",
          args = "(file: file)",
          returns = "(boolean|nil [, string, number])",
        },
        flush = {
          type = "method",
          description = "Saves any written data to file.",
          args = "(file: file)",
          returns = "(boolean|nil [, string])",
        },
        lines = {
          type = "method",
          description = "Returns an iterator function that, each time it is called, reads the file according to the given formats.\nWhen no format is given, uses \"*l\" as a default. ARGUMENT ADDED IN Lua 5.2.\nUnlike io.lines, this function does not close the file when the loop ends.\nIn case of errors this function raises the error, instead of returning an error code.",
          args = "(file: file, ...)",
          returns = "(function)",
        },
        read = {
          type = "method",
          description = "Reads the file file, according to the given formats, which specify what to read.\nFor each format, the function returns a string (or a number) with the characters read, or nil if it cannot read data with the specified format. When called without formats, it uses a default format that reads the next line (see below).\nThe available formats are\n* \"*n\": reads a number; this is the only format that returns a number instead of a string.\n* \"*a\": reads the whole file, starting at the current position. On end of file, it returns the empty string.\n* \"*l\": reads the next line skipping the end of line, returning nil on end of file. This is the default format.\n* \"*L\": reads the next line keeping the end of line (if present), returning nil on end of file. VALUE ADDED IN Lua 5.2.\n* number: reads a string with up to this number of bytes, returning nil on end of file. If number is zero, it reads nothing and returns an empty string, or nil on end of file.",
          args = "(file: file, ...)",
          returns = "(...)",
        },
        seek = {
          type = "method",
          description = "Sets and gets the file position, measured from the beginning of the file, to the position given by offset plus a base specified by the string whence.\nThe string whence is specified as follows:\n* \"set\": base is position 0 (beginning of the file);\n* \"cur\": base is current position;\n* \"end\": base is end of file.\nIn case of success, seek returns the final file position, measured in bytes from the beginning of the file. If seek fails, it returns nil, plus a string describing the error.\nThe default value for whence is \"cur\", and for offset is 0. Therefore, the call file:seek() returns the current file position, without changing it; the call file:seek(\"set\") sets the position to the beginning of the file (and returns 0); and the call file:seek(\"end\") sets the position to the end of the file, and returns its size.",
          args = "(file: file, [whence: string [, offset: number]])",
          returns = "(number|nil [, string])",
        },
        setvbuf = {
          type = "method",
          description = "Sets the buffering mode for an output file.\nThere are three available modes:\n* \"no\": no buffering; the result of any output operation appears immediately.\n* \"full\": full buffering; output operation is performed only when the buffer is full or when you explicitly flush the file (see io.flush).\n* \"line\": line buffering; output is buffered until a newline is output or there is any input from some special files (such as a terminal device).\nFor the last two cases, size specifies the size of the buffer, in bytes. The default is an appropriate size.",
          args = "(file: file, mode: string [, size: number])",
          returns = "(boolean|nil [, string])",
        },
        write = {
          type = "method",
          description = "Writes the value of each of its arguments to file.\nThe arguments must be strings or numbers.\nIn case of success, this function returns file (RETURN CHANGED IN Lua 5.2, BOOLEAN IN LUA 5.1). Otherwise it returns nil plus a string describing the error.",
          args = "(file: file, ...)",
          returns = "(file|nil [, string])",
        },
      },
    },
  
    m = {
      type = "class",
      description = "Pseudoclass for metamethods.",
      childs = {
        __add = {
          type = "function",
          description = "The + operation.",
          args = "(op1, op2)",
          returns = "(value)",
        },
        __sub = {
          type = "function",
          description = "The - operation.",
          args = "(op1, op2)",
          returns = "(value)",
        },
        __mul = {
          type = "function",
          description = "The * operation.",
          args = "(op1, op2)",
          returns = "(value)",
        },
        __div = {
          type = "function",
          description = "The / operation.",
          args = "(op1, op2)",
          returns = "(value)",
        },
        __mod = {
          type = "function",
          description = "The % operation. Behavior similar to the 'add' operation, with the operation o1 - floor(o1/o2)*o2 as the primitive operation.",
          args = "(op1, op2)",
          returns = "(value)",
        },
        __pow = {
          type = "function",
          description = "The ^ (exponentiation) operation. Behavior similar to the 'add' operation, with the function pow (from the C math library) as the primitive operation.",
          args = "(op1, op2)",
          returns = "(value)",
        },
        __concat = {
          type = "function",
          description = "The .. (concatenation) operation.",
          args = "(op1, op2)",
          returns = "(value)",
        },
        __unm = {
          type = "function",
          description = "The unary - operation.",
          args = "(op)",
          returns = "(value)",
        },
        __len = {
          type = "function",
          description = "The # (length) operation.",
          args = "(op)",
          returns = "(value)",
        },
        __eq = {
          type = "function",
          description = "The == operation. A metamethod is selected only when both values being compared have the same type and the same metamethod for the selected operation, and the values are either tables or full userdata.",
          args = "(op1, op2)",
          returns = "(boolean)",
        },
        __lt = {
          type = "function",
          description = "The < operation.",
          args = "(op1, op2)",
          returns = "(boolean)",
        },
        __le = {
          type = "function",
          description = "The <= operation. Note that, in the absence of a 'le' metamethod, Lua tries the 'lt', assuming that a <= b is equivalent to not (b < a).",
          args = "(op1, op2)",
          returns = "(boolean)",
        },
        __index = {
          type = "function",
          description = "The indexing access table[key]. Note that the metamethod is tried only when key is not present in table. When table is not a table, no key is ever present, so the metamethod is always tried.",
          args = "(table, key)",
          returns = "(value)",
        },
        __newindex = {
          type = "function",
          description = "The indexing assignment table[key] = value. Note that the metamethod is tried only when key is not present in table.",
          args = "(table, key, value)",
          returns = "(value)",
        },
        __call = {
          type = "function",
          description = "This method is called when Lua calls a value.",
          args = "(func, ...)",
          returns = "(values)",
        },
        __tostring = {
          type = "function",
          description = "Control string representation. When the builtin 'tostring(table)' function is called, if the metatable for myTable has a __tostring property set to a function, that function is invoked (passing table to it) and the return value is used as the string representation.",
          args = "(op)",
          returns = "(value)",
        },
        __pairs = {
          type = "function",
          description = "This method is called when pairs() is called and returns the first three results from the call (Lua 5.2+).",
          args = "(table)",
          returns = "(iterator, table, key)",
        },
        __ipairs = {
          type = "function",
          description = "This method is called when ipairs() is called and returns the first three results from the call (Lua 5.2+).",
          args = "(table)",
          returns = "(iterator, table, index)",
        },
        __gc = {
          type = "function",
          description = "Finalizer method. When userdata/table is set to be garbage collected, if the metatable has a __gc field pointing to a function, that function is first invoked, passing the userdata to it. Starting from Lua 5.2 this method is also called for tables.",
          args = "(func, ...)",
          returns = "(values)",
        },
        __mode = {
          type = "value",
          description = "Value that controls 'weakness' of the table. If the __mode field is a string containing the character 'k', the keys in the table are weak. If __mode contains 'v', the values in the table are weak.",
        },
        __metatable = {
          type = "value",
          description = "Value to hide the metatable. This value is returned as the result of getmetatable() call.",
        },
      },
    },
  
    -- OS library
    os = {
      type = "lib",
      description = "This library is implemented through table os.",
      childs = {
        clock = {
          type = "function",
          description = "Returns an approximation of the amount in seconds of CPU time used by the program.",
          args = "()",
          returns = "(number)",
        },
        date = {
          type = "function",
          description = "Returns a string or a table containing date and time, formatted according to the given string format.\nIf the time argument is present, this is the time to be formatted (see the os.time function for a description of this value). Otherwise, date formats the current time.\nIf format starts with '!', then the date is formatted in Coordinated Universal Time. After this optional character, if format is the string \"*t\", then date returns a table with the following fields: year (four digits), month (1–12), day (1–31), hour (0–23), min (0–59), sec (0–61), wday (weekday, Sunday is 1), yday (day of the year), and isdst (daylight saving flag, a boolean). This last field may be absent if the information is not available.\nIf format is not \"*t\", then date returns the date as a string, formatted according to the same rules as the C function strftime.\nWhen called without arguments, date returns a reasonable date and time representation that depends on the host system and on the current locale (that is, os.date() is equivalent to os.date(\"%c\")).\nOn some systems, this function may be not thread safe.",
          args = "([format: string [, time: number]])",
          returns = "(string|table)",
        },
        difftime = {
          type = "function",
          description = "Returns the number of seconds from time t1 to time t2.\nIn POSIX, Windows, and some other systems, this value is exactly t2-t1.",
          args = "(t2: number, t1: number)",
          returns = "(number)",
        },
        execute = {
          type = "function",
          description = "This function is equivalent to the C function system. It passes command to be executed by an operating system shell.\nRETURNS IN Lua 5.2:\nIts first result is true if the command terminated successfully, or nil otherwise. After this first result the function returns a string and a number, as follows:\n* \"exit\": the command terminated normally; the following number is the exit status of the command.\n* \"signal\": the command was terminated by a signal; the following number is the signal that terminated the command.\nWhen called without a command, os.execute returns a boolean that is true if a shell is available.\nRETURNS IN LUA 5.1:\nIt returns a status code, which is system-dependent. If command is absent, then it returns nonzero if a shell is available and zero otherwise.",
          args = "([command: string])",
          returns = "(boolean|nil [, string, number])",
        },
        exit = {
          type = "function",
          description = "Calls the C function exit to terminate the host program.\nIf code is true, the returned status is EXIT_SUCCESS; if code is false, the returned status is EXIT_FAILURE; if code is a number, the returned status is this number. The default value for code is true. BOOLEAN VALUE ADDED IN Lua 5.2.\nIf the optional second argument close is true, closes the Lua state before exiting. ARGUMENT ADDED IN Lua 5.2.",
          args = "([code: boolean|number [, close: boolean]])",
          returns = "()",
        },
        getenv = {
          type = "function",
          description = "Returns the value of the process environment variable varname, or nil if the variable is not defined.",
          args = "(varname: string)",
          returns = "(string|nil)",
        },
        remove = {
          type = "function",
          description = "Deletes the file (or empty directory, on POSIX systems) with the given name.\nIf this function fails, it returns nil, plus a string describing the error and the error code.",
          args = "(filename: string)",
          returns = "(boolean|nil [, string, number])",
        },
        rename = {
          type = "function",
          description = "Renames file or directory named oldname to newname.\nIf this function fails, it returns nil, plus a string describing the error and the error code.",
          args = "(oldname: string, newname: string)",
          returns = "(boolean|nil [, string, number])",
        },
        setlocale = {
          type = "function",
          description = "Sets the current locale of the program.\nlocale is a system-dependent string specifying a locale; category is an optional string describing which category to change: \"all\", \"collate\", \"ctype\", \"monetary\", \"numeric\", or \"time\"; the default category is \"all\". The function returns the name of the new locale, or nil if the request cannot be honored.\nIf locale is the empty string, the current locale is set to an implementation-defined native locale. If locale is the string \"C\", the current locale is set to the standard C locale.When called with nil as the first argument, this function only returns the name of the current locale for the given category.",
          args = "(locale: string [, category: string])",
          returns = "(string|nil)",
        },
        time = {
          type = "function",
          description = "Returns the current time when called without arguments, or a time representing the date and time specified by the given table.\nThis table must have fields year, month, and day, and may have fields hour (default is 12), min (default is 0), sec (default is 0), and isdst (default is nil). For a description of these fields, see the os.date function.\nThe returned value is a number, whose meaning depends on your system. In POSIX, Windows, and some other systems, this number counts the number of seconds since some given start time (the \"epoch\"). In other systems, the meaning is not specified, and the number returned by time can be used only as an argument to os.date and os.difftime.",
          args = "([table: table])",
          returns = "(number)",
        },
        tmpname = {
          type = "function",
          description = "Returns a string with a file name that can be used for a temporary file.\nThe file must be explicitly opened before its use and explicitly removed when no longer needed.\nOn POSIX systems, this function also creates a file with that name, to avoid security risks. (Someone else might create the file with wrong permissions in the time between getting the name and creating the file.) You still have to open the file to use it and to remove it (even if you do not use it).\nWhen possible, you may prefer to use io.tmpfile, which automatically removes the file when the program ends.",
          args = "()",
          returns = "(string)",
        },
      },
    },
  
    -- Debug library
    debug = {
      type = "lib",
      description = "This library provides the functionality of the debug interface to Lua programs.\nYou should exert care when using this library. Several of its functions violate basic assumptions about Lua code (e.g., that variables local to a function cannot be accessed from outside; that userdata metatables cannot be changed by Lua code; that Lua programs do not crash) and therefore can compromise otherwise secure code. Moreover, some functions in this library may be slow.\nAll functions in this library are provided inside the debug table. All functions that operate over a thread have an optional first argument which is the thread to operate over. The default is always the current thread.",
      childs = {
        debug = {
          type = "function",
          description = "Enters an interactive mode with the user, running each string that the user enters.\nUsing simple commands and other debug facilities, the user can inspect global and local variables, change their values, evaluate expressions, and so on. A line containing only the word cont finishes this function, so that the caller continues its execution.\nNote that commands for debug.debug are not lexically nested within any function and so have no direct access to local variables.",
          args = "()",
          returns = "()",
        },
        getfenv = {
          type = "function",
          description = "Returns the environment of object o.\nFUNCTION DEPRECATED IN Lua 5.2.",
          args = "(o: any)",
          returns = "(table)",
        },
        gethook = {
          type = "function",
          description = "Returns the current hook settings of the thread, as three values: the current hook function, the current hook mask, and the current hook count (as set by the debug.sethook function).",
          args = "([thread: thread])",
          returns = "(function, string, number)",
        },
        getinfo = {
          type = "function",
          description = "Returns a table with information about a function.\nYou can give the function directly or you can give a number as the value of f, which means the function running at level f of the call stack of the given thread: level 0 is the current function (getinfo itself); level 1 is the function that called getinfo (except for tail calls, which do not count on the stack); and so on. If f is a number larger than the number of active functions, then getinfo returns nil.\nThe returned table can contain all the fields returned by lua_getinfo, with the string what describing which fields to fill in. The default for what is to get all information available, except the table of valid lines. If present, the option 'f' adds a field named func with the function itself. If present, the option 'L' adds a field named activelines with the table of valid lines.",
          args = "([thread: thread,] f: function|number [, what: string])",
          returns = "(table|nil)",
        },
        getlocal = {
          type = "function",
          description = "This function returns the name and the value of the local variable with index local of the function at level f of the stack.\nThis function accesses not only explicit local variables, but also parameters, temporaries, etc.\nThe first parameter or local variable has index 1, and so on, until the last active variable. Negative indices refer to vararg parameters; -1 is the first vararg parameter (NEGATIVE VALUE ADDED IN Lua 5.2). The function returns nil if there is no variable with the given index, and raises an error when called with a level out of range. (You can call debug.getinfo to check whether the level is valid.)\nVariable names starting with '(' (open parentheses) represent internal variables (loop control variables, temporaries, varargs, and C function locals).\nThe parameter f may also be a function. In that case, getlocal returns only the name of function parameters. VALUE ADDED IN Lua 5.2.",
          args = "([thread: thread,] f: number|function, local: number)",
          returns = "(string|nil, any)",
        },
        getmetatable = {
          type = "function",
          description = "Returns the metatable of the given value or nil if it does not have a metatable.",
          args = "(value: any)",
          returns = "(table|nil)",
        },
        getregistry = {
          type = "function",
          description = "Returns the registry table.",
          args = "()",
          returns = "()",
        },
        getupvalue = {
          type = "function",
          description = "This function returns the name and the value of the upvalue with index up of the function f.\nThe function returns nil if there is no upvalue with the given index.",
          args = "(f: function, up: number)",
          returns = "(string|nil, any)",
        },
        getuservalue = {
          type = "function",
          description = "Returns the Lua value associated to u.\nIf u is not a userdata, returns nil.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(u: userdata)",
          returns = "(table|nil)",
        },
        setfenv = {
          type = "function",
          description = "Sets the environment of the given object to the given table. Returns object.\nFUNCTION DEPRECATED IN Lua 5.2.",
          args = "(object: any, table: table)",
          returns = "(any)",
        },
        sethook = {
          type = "function",
          description = "Sets the given function as a hook.\nThe string mask and the number count describe when the hook will be called. The string mask may have the following characters, with the given meaning:\n* 'c': the hook is called every time Lua calls a function;\n* 'r': the hook is called every time Lua returns from a function;\n* 'l': the hook is called every time Lua enters a new line of code.\nWith a count different from zero, the hook is called after every count instructions.\nWhen called without arguments, debug.sethook turns off the hook.\nWhen the hook is called, its first parameter is a string describing the event that has triggered its call: \"call\" (or \"tail call\"), \"return\", \"line\", and \"count\". For line events, the hook also gets the new line number as its second parameter. Inside a hook, you can call getinfo with level 2 to get more information about the running function (level 0 is the getinfo function, and level 1 is the hook function).",
          args = "([thread: thread,] hook: function, mask: string [, count: number])",
          returns = "()",
        },
        setlocal = {
          type = "function",
          description = "This function assigns the value value to the local variable with index local of the function at level level of the stack.\nThe function returns nil if there is no local variable with the given index, and raises an error when called with a level out of range. (You can call getinfo to check whether the level is valid.) Otherwise, it returns the name of the local variable.\nSee debug.getlocal for more information about variable indices and names.",
          args = "([thread: thread,] level: number, local: number, value: any)",
          returns = "(string|nil)",
        },
        setmetatable = {
          type = "function",
          description = "Sets the metatable for the given value to the given table (which can be nil).\nReturns value. RETURN ADDED IN Lua 5.2.",
          args = "(value: any, table: table|nil)",
          returns = "(any)",
        },
        setupvalue = {
          type = "function",
          description = "This function assigns the value value to the upvalue with index up of the function f.\nThe function returns nil if there is no upvalue with the given index. Otherwise, it returns the name of the upvalue.",
          args = "(f: function, up: number, value: any)",
          returns = "(string|nil)",
        },
        setuservalue = {
          type = "function",
          description = "Sets the given value as the Lua value associated to the given udata.\nvalue must be a table or nil; udata must be a full userdata.\nReturns udata.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(udata: userdata, value: table|nil)",
          returns = "(userdata)",
        },
        traceback = {
          type = "function",
          description = "If message is present but is neither a string nor nil, this function returns message without further processing. Otherwise, it returns a string with a traceback of the call stack.\nAn optional message string is appended at the beginning of the traceback. An optional level number tells at which level to start the traceback (default is 1, the function calling traceback).",
          args = "([thread: thread,] [message: any [, level: number]])",
          returns = "(string)",
        },
        upvalueid = {
          type = "function",
          description = "Returns an unique identifier (as a light userdata) for the upvalue numbered n from the given function.\nThese unique identifiers allow a program to check whether different closures share upvalues. Lua closures that share an upvalue (that is, that access a same external local variable) will return identical ids for those upvalue indices.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(f: function, n: number)",
          returns = "(userdata)",
        },
        upvaluejoin = {
          type = "function",
          description = "Make the n1-th upvalue of the Lua closure f1 refer to the n2-th upvalue of the Lua closure f2.\nFUNCTION ADDED IN Lua 5.2.",
          args = "(f1: function, n1: number, f2: function, n2: number)",
          returns = "()",
        },
      },
    },
  }


local function strip(str)
    return (str:gsub("%[", ""):gsub("%]", ""):gsub(" , ", ", "):gsub(" %)", ")"))
end

local function get_overloads(str)
    local out = {}
    table.insert(out, strip(str))
    while str:find("%[") do
        str = str:gsub("(.+)(%[.-%])", function(before, s) 
            return before
        end)
        table.insert(out, strip(str))
    end
    return out
end

local function get_declarations(k, v)
    local out = {}
    v.args = v.args:gsub("function", "function(...): any")
    v.returns = v.returns:gsub("function", "function(...): any")

    if v.returns == "()" then
        v.returns = "(nil)"
    end
    
    for i, args in ipairs(get_overloads(v.args)) do 
        local f = k .. " = function" .. args .. ": " .. v.returns:sub(2,-2)
        table.insert(out, f)
    end

    return out
end

local function walk(tbl)
    for lib, data in pairs(tbl) do
        if data.type == "table" then
            walk(data.childs)
        elseif data.type == "function" then
            for i,v in ipairs(get_declarations(lib, data)) do
                print(v)
            end
        end
    end
end

walk(lib)