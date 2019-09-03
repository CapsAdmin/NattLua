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

do
	-- authors: Luxinia Dev (Eike Decker & Christoph Kubisch)
	---------------------------------------------------------

	-- function helpers

	local function fn (description)
		local description2,returns,args = description:match("(.+)%-%s*(%b())%s*(%b())")
		if not description2 then
			return {type="function",description=description,
				returns="(?)"}
		end
		returns = returns:gsub("^%s+",""):gsub("%s+$","")
		local ret = returns:sub(2,-2)
		local vt = ret:match("^%[?string") and "string"
		vt = vt or ret:match("^%[?table") and "table"
		vt = vt or ret:match("^%[?file") and "io"
		return {type="function",description=description2,
			returns=returns, args = args, valuetype = vt}
	end

	local function val (description)
		return {type="value",description = description}
	end

	---------------------------

	lib.ffi = {
		description = "FFI",
		type = "lib",
		childs = {
			cdef = fn "Adds multiple C declarations for types or external symbols - ()(string)",
			load = fn "This loads the dynamic library given by name and returns a new C library namespace which binds to its symbols. On POSIX systems, if global is true, the library symbols are loaded into the global namespace, too. - (userdata)(string,[global])",
			new = fn "The following API functions create cdata objects (type() returns 'cdata'). All created cdata objects are garbage collected.  - (cdata)(string/ctype,nelement,init...)",
			typeof = fn "Creates a ctype object for the given ct. - (ctype)(ct)",
			cast = fn "Creates a scalar cdata object for the given ct. The cdata object is initialized with init according to C casting rules. - (cdata)(ctype,cdata init)",
			metatype = fn "Creates a ctype object for the given ct and associates it with a metatable. Only struct/union types, complex numbers and vectors are allowed. Other types may be wrapped in a struct, if needed. - (cdata)(ct,table meta)",
			gc = fn "Associates a finalizer with a pointer or aggregate cdata object. The cdata object is returned unchanged. - (cdata)(ct,function)",
			sizeof = fn "Returns the size of ct in bytes. Returns nil if the size is not known. - (number)(ct,[nelem])",
			alignof = fn "Returns the minimum required alignment for ct in bytes. - (number)(ct)",
			offsetof = fn "Returns the offset (in bytes) of field relative to the start of ct, which must be a struct. Additionally returns the position and the field size (in bits) for bit fields. - (number)(ct, field)",
			istype = fn "Returns true if obj has the C type given by ct. Returns false otherwise. - (boolean)(ct,obj)",
			string = fn "Creates an interned Lua string from the data pointed to by ptr. If the optional argument len is missing, ptr is converted to a 'char *' and the data is assumed to be zero-terminated. The length of the string is computed with strlen(). - (string)(ptr, [number len])",
			copy = fn "Copies the data pointed to by src to dst. dst is converted to a 'void *' and src is converted to a 'const void *'. - ()(dst,[src,len] / [string])",
			fill = fn "Fills the data pointed to by dst with len constant bytes, given by c. If c is omitted, the data is zero-filled. - ()(dst, len, [c])",
			abi = fn "Returns true if param (a Lua string) applies for the target ABI (Application Binary Interface). Returns false otherwise. 32bit 64bit lq be fpu softfp hardfp eabi win. - (boolean)(string)",
			os = val "string value of OS",
		}
	}
end

-- Copyright 2011-18 Paul Kulchenko, ZeroBrane LLC

-- Converted from love_api.lua in https://github.com/love2d-community/love-api
-- (API for LÖVE 11.2 as of Dec 20, 2018)
-- The conversion script is at the bottom of this file

-- To process:
-- 1. clone love-api and copy love_api.lua and modules/ folder to ZBS/api/lua folder
-- 2. run "../../bin/lua love2d.lua >newapi" from ZBS/api/lua folder
-- 3. copy the content of "newapi" file to replace "love" table in love2d.lua
-- 4. launch the IDE and switch to love2d to confirm that it's loading without issues

local love = {
	childs = {
	 Data = {
	  childs = {
	   getSize = {
		args = "()",
		description = "Gets the size of the Data.",
		returns = "(size: number)",
		type = "function"
	   },
	   getString = {
		args = "()",
		description = "Gets the full Data as a string.",
		returns = "(data: string)",
		type = "function"
	   }
	  },
	  description = "The superclass of all data.",
	  inherits = "Object",
	  type = "class"
	 },
	 Drawable = {
	  description = "Superclass for all things that can be drawn on screen. This is an abstract type that can't be created directly.",
	  inherits = "Object",
	  type = "class"
	 },
	 Object = {
	  childs = {
	   typeOf = {
		args = "(name: string)",
		description = "Checks whether an object is of a certain type. If the object has the type with the specified name in its hierarchy, this function will return true.",
		returns = "(b: boolean)",
		type = "function"
	   }
	  },
	  description = "The superclass of all LÖVE types.",
	  type = "lib"
	 },
	 audio = {
	  childs = {
	   DistanceModel = {
		childs = {
		 exponent = {
		  description = "Exponential attenuation.",
		  type = "value"
		 },
		 exponentclamped = {
		  description = "Exponential attenuation. Gain is clamped. In version 0.9.2 and older this is named exponent clamped.",
		  type = "value"
		 },
		 inverse = {
		  description = "Inverse distance attenuation.",
		  type = "value"
		 },
		 inverseclamped = {
		  description = "Inverse distance attenuation. Gain is clamped. In version 0.9.2 and older this is named inverse clamped.",
		  type = "value"
		 },
		 linear = {
		  description = "Linear attenuation.",
		  type = "value"
		 },
		 linearclamped = {
		  description = "Linear attenuation. Gain is clamped. In version 0.9.2 and older this is named linear clamped.",
		  type = "value"
		 },
		 none = {
		  description = "Sources do not get attenuated.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   EffectType = {
		childs = {
		 chorus = {
		  description = "Plays multiple copies of the sound with slight pitch and time variation. Used to make sounds sound \"fuller\" or \"thicker\".",
		  type = "value"
		 },
		 compressor = {
		  description = "Decreases the dynamic range of the sound, making the loud and quiet parts closer in volume, producing a more uniform amplitude throughout time.",
		  type = "value"
		 },
		 distortion = {
		  description = "Alters the sound by amplifying it until it clips, shearing off parts of the signal, leading to a compressed and distorted sound.",
		  type = "value"
		 },
		 echo = {
		  description = "Decaying feedback based effect, on the order of seconds. Also known as delay; causes the sound to repeat at regular intervals at a decreasing volume.",
		  type = "value"
		 },
		 equalizer = {
		  description = "Adjust the frequency components of the sound using a 4-band (low-shelf, two band-pass and a high-shelf) equalizer.",
		  type = "value"
		 },
		 flanger = {
		  description = "Plays two copies of the sound; while varying the phase, or equivalently delaying one of them, by amounts on the order of milliseconds, resulting in phasing sounds.",
		  type = "value"
		 },
		 reverb = {
		  description = "Decaying feedback based effect, on the order of milliseconds. Used to simulate the reflection off of the surroundings.",
		  type = "value"
		 },
		 ringmodulator = {
		  description = "An implementation of amplitude modulation; multiplies the source signal with a simple waveform, to produce either volume changes, or inharmonic overtones.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   EffectWaveform = {
		childs = {
		 sawtooth = {
		  description = "A sawtooth wave, also known as a ramp wave. Named for its linear rise, and (near-)instantaneous fall along time.",
		  type = "value"
		 },
		 sine = {
		  description = "A sine wave. Follows a trigonometric sine function.",
		  type = "value"
		 },
		 square = {
		  description = "A square wave. Switches between high and low states (near-)instantaneously.",
		  type = "value"
		 },
		 triangle = {
		  description = "A triangle wave. Follows a linear rise and fall that repeats periodically.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   FilterType = {
		childs = {
		 bandpass = {
		  description = "Band-pass filter. Both high and low frequency sounds are attenuated based on the given parameters.",
		  type = "value"
		 },
		 highpass = {
		  description = "High-pass filter. Low frequency sounds are attenuated.",
		  type = "value"
		 },
		 lowpass = {
		  description = "Low-pass filter. High frequency sounds are attenuated.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   RecordingDevice = {
		childs = {
		 getChannelCount = {
		  args = "()",
		  description = "Gets the number of channels currently being recorded (mono or stereo).",
		  returns = "(channels: number)",
		  type = "function"
		 },
		 getData = {
		  args = "()",
		  description = "Gets all recorded audio SoundData stored in the device's internal ring buffer.",
		  returns = "(data: SoundData)",
		  type = "function"
		 },
		 getName = {
		  args = "()",
		  description = "Gets the name of the recording device.",
		  returns = "(name: string)",
		  type = "function"
		 },
		 getSampleCount = {
		  args = "()",
		  description = "Gets the number of currently recorded samples.",
		  returns = "(samples: number)",
		  type = "function"
		 },
		 getSampleRate = {
		  args = "()",
		  description = "Gets the number of samples per second currently being recorded.",
		  returns = "(rate: number)",
		  type = "function"
		 },
		 isRecording = {
		  args = "()",
		  description = "Gets whether the device is currently recording.",
		  returns = "(recording: boolean)",
		  type = "function"
		 },
		 start = {
		  args = "(samplecount: number, samplerate: number, bitdepth: number, channels: number)",
		  description = "Begins recording audio using this device.",
		  returns = "(success: boolean)",
		  type = "function"
		 },
		 stop = {
		  args = "()",
		  description = "Stops recording audio from this device.",
		  returns = "(data: SoundData)",
		  type = "function"
		 }
		},
		description = "Represents an audio input device capable of recording sounds.",
		inherits = "Object",
		type = "class"
	   },
	   Source = {
		childs = {
		 getActiveEffects = {
		  args = "()",
		  description = "Returns a list of all the active effects currently applied to the Source",
		  returns = "(effects: table)",
		  type = "function"
		 },
		 getAttenuationDistances = {
		  args = "()",
		  description = "Returns the reference and maximum distance of the source.",
		  returns = "(ref: number, max: number)",
		  type = "function"
		 },
		 getChannelCount = {
		  args = "()",
		  description = "Gets the number of channels in the Source. Only 1-channel (mono) Sources can use directional and positional effects.",
		  returns = "(channels: number)",
		  type = "function"
		 },
		 getCone = {
		  args = "()",
		  description = "Gets the Source's directional volume cones. Together with Source:setDirection, the cone angles allow for the Source's volume to vary depending on its direction.",
		  returns = "(innerAngle: number, outerAngle: number, outerVolume: number, outerHighGain: number)",
		  type = "function"
		 },
		 getDirection = {
		  args = "()",
		  description = "Gets the direction of the Source.",
		  returns = "(x: number, y: number, z: number)",
		  type = "function"
		 },
		 getDuration = {
		  args = "(unit: TimeUnit)",
		  description = "Gets the duration of the Source. For streaming Sources it may not always be sample-accurate, and may return -1 if the duration cannot be determined at all.",
		  returns = "(duration: number)",
		  type = "function"
		 },
		 getEffect = {
		  args = "(name: string, filtersettings: table)",
		  description = "Gets the filter settings associated to a specific Effect.\n\nThis function returns nil if the Effect was applied with no filter settings associated to it.",
		  returns = "(filtersettings: table)",
		  type = "function"
		 },
		 getFilter = {
		  args = "(settings: table)",
		  description = "Gets the filter settings currently applied to the Source.",
		  returns = "(settings: table)",
		  type = "function"
		 },
		 getFreeBufferCount = {
		  args = "()",
		  description = "Gets the number of free buffer slots of a queueable Source.",
		  returns = "(buffers: number)",
		  type = "function"
		 },
		 getPitch = {
		  args = "()",
		  description = "Gets the current pitch of the Source.",
		  returns = "(pitch: number)",
		  type = "function"
		 },
		 getPosition = {
		  args = "()",
		  description = "Gets the position of the Source.",
		  returns = "(x: number, y: number, z: number)",
		  type = "function"
		 },
		 getRolloff = {
		  args = "()",
		  description = "Returns the rolloff factor of the source.",
		  returns = "(rolloff: number)",
		  type = "function"
		 },
		 getType = {
		  args = "()",
		  description = "Gets the type (static or stream) of the Source.",
		  returns = "(sourcetype: SourceType)",
		  type = "function"
		 },
		 getVelocity = {
		  args = "()",
		  description = "Gets the velocity of the Source.",
		  returns = "(x: number, y: number, z: number)",
		  type = "function"
		 },
		 getVolume = {
		  args = "()",
		  description = "Gets the current volume of the Source.",
		  returns = "(volume: number)",
		  type = "function"
		 },
		 getVolumeLimits = {
		  args = "()",
		  description = "Returns the volume limits of the source.",
		  returns = "(min: number, max: number)",
		  type = "function"
		 },
		 isLooping = {
		  args = "()",
		  description = "Returns whether the Source will loop.",
		  returns = "(loop: boolean)",
		  type = "function"
		 },
		 isPlaying = {
		  args = "()",
		  description = "Returns whether the Source is playing.",
		  returns = "(playing: boolean)",
		  type = "function"
		 },
		 isRelative = {
		  args = "()",
		  description = "Gets whether the Source's position and direction are relative to the listener.",
		  returns = "(relative: boolean)",
		  type = "function"
		 },
		 pause = {
		  args = "()",
		  description = "Pauses the Source.",
		  returns = "()",
		  type = "function"
		 },
		 play = {
		  args = "()",
		  description = "Starts playing the Source.",
		  returns = "(success: boolean)",
		  type = "function"
		 },
		 queue = {
		  args = "(sounddata: SoundData)",
		  description = "Queues SoundData for playback in a queueable Source.\n\nThis method requires the Source to be created via love.audio.newQueueableSource.",
		  returns = "(success: boolean)",
		  type = "function"
		 },
		 seek = {
		  args = "(position: number, unit: TimeUnit)",
		  description = "Sets the playing position of the Source.",
		  returns = "()",
		  type = "function"
		 },
		 setAttenuationDistances = {
		  args = "(ref: number, max: number)",
		  description = "Sets the reference and maximum distance of the source.",
		  returns = "()",
		  type = "function"
		 },
		 setCone = {
		  args = "(innerAngle: number, outerAngle: number, outerVolume: number, outerHighGain: number)",
		  description = "Sets the Source's directional volume cones. Together with Source:setDirection, the cone angles allow for the Source's volume to vary depending on its direction.",
		  returns = "()",
		  type = "function"
		 },
		 setDirection = {
		  args = "(x: number, y: number, z: number)",
		  description = "Sets the direction vector of the Source. A zero vector makes the source non-directional.",
		  returns = "()",
		  type = "function"
		 },
		 setEffect = {
		  args = "(name: string, enable: boolean)",
		  description = "Applies an audio effect to the Source.\n\nThe effect must have been previously defined using love.audio.setEffect.",
		  returns = "(success: boolean)",
		  type = "function"
		 },
		 setFilter = {
		  args = "(settings: table)",
		  description = "Sets a low-pass, high-pass, or band-pass filter to apply when playing the Source.",
		  returns = "(success: boolean)",
		  type = "function"
		 },
		 setLooping = {
		  args = "(loop: boolean)",
		  description = "Sets whether the Source should loop.",
		  returns = "()",
		  type = "function"
		 },
		 setPitch = {
		  args = "(pitch: number)",
		  description = "Sets the pitch of the Source.",
		  returns = "()",
		  type = "function"
		 },
		 setPosition = {
		  args = "(x: number, y: number, z: number)",
		  description = "Sets the position of the Source.",
		  returns = "()",
		  type = "function"
		 },
		 setRelative = {
		  args = "(enable: boolean)",
		  description = "Sets whether the Source's position and direction are relative to the listener. Relative Sources move with the listener so they aren't affected by it's position",
		  returns = "()",
		  type = "function"
		 },
		 setRolloff = {
		  args = "(rolloff: number)",
		  description = "Sets the rolloff factor which affects the strength of the used distance attenuation.\n\nExtended information and detailed formulas can be found in the chapter \"3.4. Attenuation By Distance\" of OpenAL 1.1 specification.",
		  returns = "()",
		  type = "function"
		 },
		 setVelocity = {
		  args = "(x: number, y: number, z: number)",
		  description = "Sets the velocity of the Source.\n\nThis does not change the position of the Source, but is used to calculate the doppler effect.",
		  returns = "()",
		  type = "function"
		 },
		 setVolume = {
		  args = "(volume: number)",
		  description = "Sets the volume of the Source.",
		  returns = "()",
		  type = "function"
		 },
		 setVolumeLimits = {
		  args = "(min: number, max: number)",
		  description = "Sets the volume limits of the source. The limits have to be numbers from 0 to 1.",
		  returns = "()",
		  type = "function"
		 },
		 stop = {
		  args = "()",
		  description = "Stops a Source.",
		  returns = "()",
		  type = "function"
		 },
		 tell = {
		  args = "(unit: TimeUnit)",
		  description = "Gets the currently playing position of the Source.",
		  returns = "(position: number)",
		  type = "function"
		 }
		},
		description = "A Source represents audio you can play back. You can do interesting things with Sources, like set the volume, pitch, and its position relative to the listener.",
		inherits = "Object",
		type = "class"
	   },
	   SourceType = {
		childs = {
		 queue = {
		  description = "The audio must be manually queued by the user with Source:queue.",
		  type = "value"
		 },
		 static = {
		  description = "The whole audio is decoded.",
		  type = "value"
		 },
		 stream = {
		  description = "The audio is decoded in chunks when needed.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   TimeUnit = {
		childs = {
		 samples = {
		  description = "Audio samples.",
		  type = "value"
		 },
		 seconds = {
		  description = "Regular seconds.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   getActiveSourceCount = {
		args = "()",
		description = "Gets the current number of simultaneously playing sources.",
		returns = "(count: number)",
		type = "function"
	   },
	   getDistanceModel = {
		args = "()",
		description = "Returns the distance attenuation model.",
		returns = "(model: DistanceModel)",
		type = "function"
	   },
	   getDopplerScale = {
		args = "()",
		description = "Gets the current global scale factor for velocity-based doppler effects.",
		returns = "(scale: number)",
		type = "function"
	   },
	   getEffect = {
		args = "(name: string)",
		description = "Gets the settings associated with an effect.",
		returns = "(settings: table)",
		type = "function"
	   },
	   getMaxSceneEffects = {
		args = "()",
		description = "Gets the maximum number of active Effects, supported by the system.",
		returns = "(maximum: number)",
		type = "function"
	   },
	   getMaxSourceEffects = {
		args = "()",
		description = "Gets the maximum number of active Effects in a single Source object, that the system can support.",
		returns = "(maximum: number)",
		type = "function"
	   },
	   getOrientation = {
		args = "()",
		description = "Returns the orientation of the listener.",
		returns = "(fx: number, fy: number, fz: number, ux: number, uy: number, uz: number)",
		type = "function"
	   },
	   getPosition = {
		args = "()",
		description = "Returns the position of the listener.",
		returns = "(x: number, y: number, z: number)",
		type = "function"
	   },
	   getRecordingDevices = {
		args = "()",
		description = "Gets a list of RecordingDevices on the system. The first device in the list is the user's default recording device.\n\nIf no device is available, it will return an empty list.\nRecording is not supported on iOS",
		returns = "(devices: table)",
		type = "function"
	   },
	   getSourceCount = {
		args = "()",
		description = "Returns the number of sources which are currently playing or paused.",
		returns = "(numSources: number)",
		type = "function"
	   },
	   getVelocity = {
		args = "()",
		description = "Returns the velocity of the listener.",
		returns = "(x: number, y: number, z: number)",
		type = "function"
	   },
	   getVolume = {
		args = "()",
		description = "Returns the master volume.",
		returns = "(volume: number)",
		type = "function"
	   },
	   isEffectsSupported = {
		args = "()",
		description = "Gets whether Effects are supported in the system.",
		returns = "(supported: boolean)",
		type = "function"
	   },
	   newQueueableSource = {
		args = "(samplerate: number, bitdepth: number, channels: number, buffercount: number)",
		description = "Creates a new Source usable for real-time generated sound playback with Source:queue.",
		returns = "(source: Source)",
		type = "function"
	   },
	   newSource = {
		args = "(filename: string, type: SourceType)",
		description = "Creates a new Source from a filepath, File, Decoder or SoundData. Sources created from SoundData are always static.",
		returns = "(source: Source)",
		type = "function"
	   },
	   pause = {
		args = "(source: Source)",
		description = "Pauses currently played Sources.",
		returns = "()",
		type = "function"
	   },
	   play = {
		args = "(source: Source)",
		description = "Plays the specified Source.",
		returns = "()",
		type = "function"
	   },
	   setDistanceModel = {
		args = "(model: DistanceModel)",
		description = "Sets the distance attenuation model.",
		returns = "()",
		type = "function"
	   },
	   setDopplerScale = {
		args = "(scale: number)",
		description = "Sets a global scale factor for velocity-based doppler effects. The default scale value is 1.",
		returns = "()",
		type = "function"
	   },
	   setEffect = {
		args = "(name: string, settings: table)",
		description = "Defines an effect that can be applied to a Source.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   setMixWithSystem = {
		args = "(mix: boolean)",
		description = "Sets whether the system should mix the audio with the system's audio.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   setOrientation = {
		args = "(fx: number, fy: number, fz: number, ux: number, uy: number, uz: number)",
		description = "Sets the orientation of the listener.",
		returns = "()",
		type = "function"
	   },
	   setPosition = {
		args = "(x: number, y: number, z: number)",
		description = "Sets the position of the listener, which determines how sounds play.",
		returns = "()",
		type = "function"
	   },
	   setVelocity = {
		args = "(x: number, y: number, z: number)",
		description = "Sets the velocity of the listener.",
		returns = "()",
		type = "function"
	   },
	   setVolume = {
		args = "(volume: number)",
		description = "Sets the master volume.",
		returns = "()",
		type = "function"
	   },
	   stop = {
		args = "(source: Source)",
		description = "Stops currently played sources.",
		returns = "()",
		type = "function"
	   }
	  },
	  description = "Provides an interface to create noise with the user's speakers.",
	  type = "class"
	 },
	 conf = {
	  args = "(t: table)",
	  description = "If a file called conf.lua is present in your game folder (or .love file), it is run before the LÖVE modules are loaded. You can use this file to overwrite the love.conf function, which is later called by the LÖVE 'boot' script. Using the love.conf function, you can set some configuration options, and change things like the default size of the window, which modules are loaded, and other stuff.",
	  returns = "()",
	  type = "function"
	 },
	 data = {
	  childs = {
	   ContainerType = {
		childs = {
		 data = {
		  description = "Return type is Data.",
		  type = "value"
		 },
		 string = {
		  description = "Return type is string.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   HashFunction = {
		childs = {
		 md5 = {
		  description = "MD5 hash algorithm (16 bytes).",
		  type = "value"
		 },
		 sha1 = {
		  description = "SHA1 hash algorithm (20 bytes).",
		  type = "value"
		 },
		 sha224 = {
		  description = "SHA2 hash algorithm with message digest size of 224 bits (28 bytes).",
		  type = "value"
		 },
		 sha256 = {
		  description = "SHA2 hash algorithm with message digest size of 256 bits (32 bytes).",
		  type = "value"
		 },
		 sha384 = {
		  description = "SHA2 hash algorithm with message digest size of 384 bits (48 bytes).",
		  type = "value"
		 },
		 sha512 = {
		  description = "SHA2 hash algorithm with message digest size of 512 bits (64 bytes).",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   decode = {
		args = "(containerType: ContainerType, format: EncodeFormat, sourceString: string)",
		description = "Decode Data or a string from any of the EncodeFormats to Data or string.",
		returns = "(decoded: Variant)",
		type = "function"
	   },
	   decompress = {
		args = "(container: ContainerType, compressedData: CompressedData)",
		description = "Decompresses a CompressedData or previously compressed string or Data object.",
		returns = "(rawstring: string)",
		type = "function"
	   },
	   encode = {
		args = "(containerType: ContainerType, format: EncodeFormat, sourceString: string, lineLength: number)",
		description = "Encode Data or a string to a Data or string in one of the EncodeFormats.",
		returns = "(encoded: Variant)",
		type = "function"
	   },
	   hash = {
		args = "(hashFunction: HashFunction, string: string)",
		description = "Compute the message digest of a string using a specified hash algorithm.",
		returns = "(rawdigest: string)",
		type = "function"
	   }
	  },
	  description = "Provides functionality for creating and transforming data.",
	  type = "lib"
	 },
	 directorydropped = {
	  args = "(path: string)",
	  description = "Callback function triggered when a directory is dragged and dropped onto the window.",
	  returns = "()",
	  type = "function"
	 },
	 draw = {
	  args = "()",
	  description = "Callback function used to draw on the screen every frame.",
	  returns = "()",
	  type = "function"
	 },
	 errorhandler = {
	  args = "(msg: string)",
	  description = "The error handler, used to display error messages.",
	  returns = "()",
	  type = "function"
	 },
	 event = {
	  childs = {
	   Event = {
		childs = {
		 focus = {
		  description = "Window focus gained or lost",
		  type = "value"
		 },
		 joystickaxis = {
		  description = "Joystick axis motion",
		  type = "value"
		 },
		 joystickhat = {
		  description = "Joystick hat pressed",
		  type = "value"
		 },
		 joystickpressed = {
		  description = "Joystick pressed",
		  type = "value"
		 },
		 joystickreleased = {
		  description = "Joystick released",
		  type = "value"
		 },
		 keypressed = {
		  description = "Key pressed",
		  type = "value"
		 },
		 keyreleased = {
		  description = "Key released",
		  type = "value"
		 },
		 mousefocus = {
		  description = "Window mouse focus gained or lost",
		  type = "value"
		 },
		 mousepressed = {
		  description = "Mouse pressed",
		  type = "value"
		 },
		 mousereleased = {
		  description = "Mouse released",
		  type = "value"
		 },
		 quit = {
		  description = "Quit",
		  type = "value"
		 },
		 resize = {
		  description = "Window size changed by the user",
		  type = "value"
		 },
		 threaderror = {
		  description = "A Lua error has occurred in a thread.",
		  type = "value"
		 },
		 visible = {
		  description = "Window is minimized or un-minimized by the user",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   poll = {
		args = "()",
		description = "Returns an iterator for messages in the event queue.",
		returns = "(i: function)",
		type = "function"
	   },
	   pump = {
		args = "()",
		description = "Pump events into the event queue. This is a low-level function, and is usually not called by the user, but by love.run. Note that this does need to be called for any OS to think you're still running, and if you want to handle OS-generated events at all (think callbacks). love.event.pump can only be called from the main thread, but afterwards, the rest of love.event can be used from any other thread.",
		returns = "()",
		type = "function"
	   },
	   push = {
		args = "(e: Event, a: Variant, b: Variant, c: Variant, d: Variant)",
		description = "Adds an event to the event queue.",
		returns = "()",
		type = "function"
	   },
	   quit = {
		args = "(exitstatus: number)",
		description = "Adds the quit event to the queue.\n\nThe quit event is a signal for the event handler to close LÖVE. It's possible to abort the exit process with the love.quit callback.",
		returns = "()",
		type = "function"
	   },
	   wait = {
		args = "()",
		description = "Like love.event.poll but blocks until there is an event in the queue.",
		returns = "(e: Event, a: Variant, b: Variant, c: Variant, d: Variant)",
		type = "function"
	   }
	  },
	  description = "Manages events, like keypresses.",
	  type = "lib"
	 },
	 filedropped = {
	  args = "(file: File)",
	  description = "Callback function triggered when a file is dragged and dropped onto the window.",
	  returns = "()",
	  type = "function"
	 },
	 filesystem = {
	  childs = {
	   BufferMode = {
		childs = {
		 full = {
		  description = "Full buffering. Write and append operations are always buffered until the buffer size limit is reached.",
		  type = "value"
		 },
		 line = {
		  description = "Line buffering. Write and append operations are buffered until a newline is output or the buffer size limit is reached.",
		  type = "value"
		 },
		 none = {
		  description = "No buffering. The result of write and append operations appears immediately.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   File = {
		childs = {
		 flush = {
		  args = "()",
		  description = "Flushes any buffered written data in the file to the disk.",
		  returns = "(success: boolean, err: string)",
		  type = "function"
		 },
		 getBuffer = {
		  args = "()",
		  description = "Gets the buffer mode of a file.",
		  returns = "(mode: BufferMode, size: number)",
		  type = "function"
		 },
		 getFilename = {
		  args = "()",
		  description = "Gets the filename that the File object was created with. If the file object originated from the love.filedropped callback, the filename will be the full platform-dependent file path.",
		  returns = "(filename: string)",
		  type = "function"
		 },
		 getMode = {
		  args = "()",
		  description = "Gets the FileMode the file has been opened with.",
		  returns = "(mode: FileMode)",
		  type = "function"
		 },
		 getSize = {
		  args = "()",
		  description = "Returns the file size.",
		  returns = "(size: number)",
		  type = "function"
		 },
		 isEOF = {
		  args = "()",
		  description = "Gets whether end-of-file has been reached.",
		  returns = "(eof: boolean)",
		  type = "function"
		 },
		 isOpen = {
		  args = "()",
		  description = "Gets whether the file is open.",
		  returns = "(open: boolean)",
		  type = "function"
		 },
		 lines = {
		  args = "()",
		  description = "Iterate over all the lines in a file",
		  returns = "(iterator: function)",
		  type = "function"
		 },
		 open = {
		  args = "(mode: FileMode)",
		  description = "Open the file for write, read or append.\n\nIf you are getting the error message \"Could not set write directory\", try setting the save directory. This is done either with love.filesystem.setIdentity or by setting the identity field in love.conf.",
		  returns = "(success: boolean)",
		  type = "function"
		 },
		 read = {
		  args = "(bytes: number)",
		  description = "Read a number of bytes from a file.",
		  returns = "(contents: string, size: number)",
		  type = "function"
		 },
		 seek = {
		  args = "(position: number)",
		  description = "Seek to a position in a file.",
		  returns = "(success: boolean)",
		  type = "function"
		 },
		 setBuffer = {
		  args = "(mode: BufferMode, size: number)",
		  description = "Sets the buffer mode for a file opened for writing or appending. Files with buffering enabled will not write data to the disk until the buffer size limit is reached, depending on the buffer mode.",
		  returns = "(success: boolean, errorstr: string)",
		  type = "function"
		 },
		 tell = {
		  args = "()",
		  description = "Returns the position in the file.",
		  returns = "(pos: number)",
		  type = "function"
		 },
		 write = {
		  args = "(data: string, size: number)",
		  description = "Write data to a file.",
		  returns = "(success: boolean)",
		  type = "function"
		 }
		},
		description = "Represents a file on the filesystem.",
		inherits = "Object",
		type = "class"
	   },
	   FileData = {
		childs = {
		 getFilename = {
		  args = "()",
		  description = "Gets the filename of the FileData.",
		  returns = "(name: string)",
		  type = "function"
		 }
		},
		description = "Data representing the contents of a file.",
		inherits = "Data",
		type = "class"
	   },
	   FileDecoder = {
		childs = {
		 base64 = {
		  description = "The data is base64-encoded.",
		  type = "value"
		 },
		 file = {
		  description = "The data is unencoded.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   FileMode = {
		childs = {
		 a = {
		  description = "Open a file for append.",
		  type = "value"
		 },
		 c = {
		  description = "Do not open a file (represents a closed file.)",
		  type = "value"
		 },
		 r = {
		  description = "Open a file for read.",
		  type = "value"
		 },
		 w = {
		  description = "Open a file for write.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   FileType = {
		childs = {
		 directory = {
		  description = "Directory",
		  type = "value"
		 },
		 file = {
		  description = "Regular file.",
		  type = "value"
		 },
		 other = {
		  description = "Something completely different like a device.",
		  type = "value"
		 },
		 symlink = {
		  description = "Symbolic link.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   areSymlinksEnabled = {
		args = "()",
		description = "Gets whether love.filesystem follows symbolic links.",
		returns = "(enable: boolean)",
		type = "function"
	   },
	   createDirectory = {
		args = "(name: string)",
		description = "Creates a directory.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   getAppdataDirectory = {
		args = "()",
		description = "Returns the application data directory (could be the same as getUserDirectory)",
		returns = "(path: string)",
		type = "function"
	   },
	   getCRequirePath = {
		args = "()",
		description = "Gets the filesystem paths that will be searched for c libraries when require is called.\n\nThe paths string returned by this function is a sequence of path templates separated by semicolons. The argument passed to require will be inserted in place of any question mark (\"?\") character in each template (after the dot characters in the argument passed to require are replaced by directory separators.) Additionally, any occurrence of a double question mark (\"??\") will be replaced by the name passed to require and the default library extension for the platform.\n\nThe paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.",
		returns = "(paths: string)",
		type = "function"
	   },
	   getDirectoryItems = {
		args = "(dir: string)",
		description = "Returns a table with the names of files and subdirectories in the specified path. The table is not sorted in any way; the order is undefined.\n\nIf the path passed to the function exists in the game and the save directory, it will list the files and directories from both places.",
		returns = "(items: table)",
		type = "function"
	   },
	   getIdentity = {
		args = "(name: string)",
		description = "Gets the write directory name for your game. Note that this only returns the name of the folder to store your files in, not the full location.",
		returns = "()",
		type = "function"
	   },
	   getInfo = {
		args = "(path: string)",
		description = "Gets information about the specified file or directory.",
		returns = "(info: table)",
		type = "function"
	   },
	   getRealDirectory = {
		args = "(filepath: string)",
		description = "Gets the platform-specific absolute path of the directory containing a filepath.\n\nThis can be used to determine whether a file is inside the save directory or the game's source .love.",
		returns = "(realdir: string)",
		type = "function"
	   },
	   getRequirePath = {
		args = "()",
		description = "Gets the filesystem paths that will be searched when require is called.\n\nThe paths string returned by this function is a sequence of path templates separated by semicolons. The argument passed to require will be inserted in place of any question mark (\"?\") character in each template (after the dot characters in the argument passed to require are replaced by directory separators.)\n\nThe paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.",
		returns = "(paths: string)",
		type = "function"
	   },
	   getSaveDirectory = {
		args = "()",
		description = "Gets the full path to the designated save directory. This can be useful if you want to use the standard io library (or something else) to read or write in the save directory.",
		returns = "(path: string)",
		type = "function"
	   },
	   getSource = {
		args = "()",
		description = "Returns the full path to the the .love file or directory. If the game is fused to the LÖVE executable, then the executable is returned.",
		returns = "(path: string)",
		type = "function"
	   },
	   getSourceBaseDirectory = {
		args = "()",
		description = "Returns the full path to the directory containing the .love file. If the game is fused to the LÖVE executable, then the directory containing the executable is returned.\n\nIf love.filesystem.isFused is true, the path returned by this function can be passed to love.filesystem.mount, which will make the directory containing the main game readable by love.filesystem.",
		returns = "(path: string)",
		type = "function"
	   },
	   getUserDirectory = {
		args = "()",
		description = "Returns the path of the user's directory.",
		returns = "(path: string)",
		type = "function"
	   },
	   getWorkingDirectory = {
		args = "()",
		description = "Gets the current working directory.",
		returns = "(path: string)",
		type = "function"
	   },
	   init = {
		args = "(appname: string)",
		description = "Initializes love.filesystem, will be called internally, so should not be used explicitly.",
		returns = "()",
		type = "function"
	   },
	   isFused = {
		args = "()",
		description = "Gets whether the game is in fused mode or not.\n\nIf a game is in fused mode, its save directory will be directly in the Appdata directory instead of Appdata/LOVE/. The game will also be able to load C Lua dynamic libraries which are located in the save directory.\n\nA game is in fused mode if the source .love has been fused to the executable (see Game Distribution), or if \"--fused\" has been given as a command-line argument when starting the game.",
		returns = "(fused: boolean)",
		type = "function"
	   },
	   lines = {
		args = "(name: string)",
		description = "Iterate over the lines in a file.",
		returns = "(iterator: function)",
		type = "function"
	   },
	   load = {
		args = "(name: string, errormsg: string)",
		description = "Loads a Lua file (but does not run it).",
		returns = "(chunk: function)",
		type = "function"
	   },
	   mount = {
		args = "(archive: string, mountpoint: string)",
		description = "Mounts a zip file or folder in the game's save directory for reading.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   newFile = {
		args = "(filename: string, mode: FileMode)",
		description = "Creates a new File object. It needs to be opened before it can be accessed.",
		returns = "(file: File, errorstr: string)",
		type = "function"
	   },
	   newFileData = {
		args = "(contents: string, name: string)",
		description = "Creates a new FileData object.",
		returns = "(data: FileData)",
		type = "function"
	   },
	   read = {
		args = "(name: string, bytes: number)",
		description = "Read the contents of a file.",
		returns = "(contents: string, size: number)",
		type = "function"
	   },
	   remove = {
		args = "(name: string)",
		description = "Removes a file or directory.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   setCRequirePath = {
		args = "(paths: string)",
		description = "Sets the filesystem paths that will be searched for c libraries when require is called.\n\nThe paths string returned by this function is a sequence of path templates separated by semicolons. The argument passed to require will be inserted in place of any question mark (\"?\") character in each template (after the dot characters in the argument passed to require are replaced by directory separators.) Additionally, any occurrence of a double question mark (\"??\") will be replaced by the name passed to require and the default library extension for the platform.\n\nThe paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.",
		returns = "()",
		type = "function"
	   },
	   setIdentity = {
		args = "(name: string, appendToPath: boolean)",
		description = "Sets the write directory for your game. Note that you can only set the name of the folder to store your files in, not the location.",
		returns = "()",
		type = "function"
	   },
	   setRequirePath = {
		args = "(paths: string)",
		description = "Sets the filesystem paths that will be searched when require is called.\n\nThe paths string given to this function is a sequence of path templates separated by semicolons. The argument passed to require will be inserted in place of any question mark (\"?\") character in each template (after the dot characters in the argument passed to require are replaced by directory separators.)\n\nThe paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.",
		returns = "()",
		type = "function"
	   },
	   setSource = {
		args = "(path: string)",
		description = "Sets the source of the game, where the code is present. This function can only be called once, and is normally automatically done by LÖVE.",
		returns = "()",
		type = "function"
	   },
	   setSymlinksEnabled = {
		args = "(enable: boolean)",
		description = "Sets whether love.filesystem follows symbolic links. It is enabled by default in version 0.10.0 and newer, and disabled by default in 0.9.2.",
		returns = "()",
		type = "function"
	   },
	   unmount = {
		args = "(archive: string)",
		description = "Unmounts a zip file or folder previously mounted for reading with love.filesystem.mount.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   write = {
		args = "(name: string, data: string, size: number)",
		description = "Write data to a file.\n\nIf you are getting the error message \"Could not set write directory\", try setting the save directory. This is done either with love.filesystem.setIdentity or by setting the identity field in love.conf.",
		returns = "(success: boolean, message: string)",
		type = "function"
	   }
	  },
	  description = "Provides an interface to the user's filesystem.",
	  type = "class"
	 },
	 focus = {
	  args = "(focus: boolean)",
	  description = "Callback function triggered when window receives or loses focus.",
	  returns = "()",
	  type = "function"
	 },
	 gamepadaxis = {
	  args = "(joystick: Joystick, axis: GamepadAxis, value: number)",
	  description = "Called when a Joystick's virtual gamepad axis is moved.",
	  returns = "()",
	  type = "function"
	 },
	 gamepadpressed = {
	  args = "(joystick: Joystick, button: GamepadButton)",
	  description = "Called when a Joystick's virtual gamepad button is pressed.",
	  returns = "()",
	  type = "function"
	 },
	 gamepadreleased = {
	  args = "(joystick: Joystick, button: GamepadButton)",
	  description = "Called when a Joystick's virtual gamepad button is released.",
	  returns = "()",
	  type = "function"
	 },
	 getVersion = {
	  args = "()",
	  description = "Gets the current running version of LÖVE.",
	  returns = "(major: number, minor: number, revision: number, codename: string)",
	  type = "function"
	 },
	 graphics = {
	  childs = {
	   AlignMode = {
		childs = {
		 center = {
		  description = "Align text center.",
		  type = "value"
		 },
		 justify = {
		  description = "Align text both left and right.",
		  type = "value"
		 },
		 left = {
		  description = "Align text left.",
		  type = "value"
		 },
		 right = {
		  description = "Align text right.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   ArcType = {
		childs = {
		 closed = {
		  description = "The arc circle's two end-points are connected to each other.",
		  type = "value"
		 },
		 open = {
		  description = "The arc circle's two end-points are unconnected when the arc is drawn as a line. Behaves like the \"closed\" arc type when the arc is drawn in filled mode.",
		  type = "value"
		 },
		 pie = {
		  description = "The arc is drawn like a slice of pie, with the arc circle connected to the center at its end-points.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   AreaSpreadDistribution = {
		childs = {
		 ellipse = {
		  description = "Uniform distribution in an ellipse.",
		  type = "value"
		 },
		 none = {
		  description = "No distribution - area spread is disabled.",
		  type = "value"
		 },
		 normal = {
		  description = "Normal (gaussian) distribution.",
		  type = "value"
		 },
		 uniform = {
		  description = "Uniform distribution.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   BlendAlphaMode = {
		childs = {
		 alphamultiply = {
		  description = "The RGB values of what's drawn are multiplied by the alpha values of those colors during blending. This is the default alpha mode.",
		  type = "value"
		 },
		 premultiplied = {
		  description = "The RGB values of what's drawn are not multiplied by the alpha values of those colors during blending. For most blend modes to work correctly with this alpha mode, the colors of a drawn object need to have had their RGB values multiplied by their alpha values at some point previously (\"premultiplied alpha\").",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   BlendMode = {
		childs = {
		 add = {
		  description = "The pixel colors of what's drawn are added to the pixel colors already on the screen. The alpha of the screen is not modified.",
		  type = "value"
		 },
		 alpha = {
		  description = "Alpha blending (normal). The alpha of what's drawn determines its opacity.",
		  type = "value"
		 },
		 darken = {
		  description = "The pixel colors of what's drawn are compared to the existing pixel colors, and the smaller of the two values for each color component is used. Only works when the \"premultiplied\" BlendAlphaMode is used in love.graphics.setBlendMode.",
		  type = "value"
		 },
		 lighten = {
		  description = "The pixel colors of what's drawn are compared to the existing pixel colors, and the larger of the two values for each color component is used. Only works when the \"premultiplied\" BlendAlphaMode is used in love.graphics.setBlendMode.",
		  type = "value"
		 },
		 multiply = {
		  description = "The pixel colors of what's drawn are multiplied with the pixel colors already on the screen (darkening them). The alpha of drawn objects is multiplied with the alpha of the screen rather than determining how much the colors on the screen are affected, even when the \"alphamultiply\" BlendAlphaMode is used.",
		  type = "value"
		 },
		 replace = {
		  description = "The colors of what's drawn completely replace what was on the screen, with no additional blending. The BlendAlphaMode specified in love.graphics.setBlendMode still affects what happens.",
		  type = "value"
		 },
		 screen = {
		  description = "\"Screen\" blending.",
		  type = "value"
		 },
		 subtract = {
		  description = "The pixel colors of what's drawn are subtracted from the pixel colors already on the screen. The alpha of the screen is not modified.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   Canvas = {
		childs = {
		 getFilter = {
		  args = "()",
		  description = "Gets the filter mode of the Canvas.",
		  returns = "(min: FilterMode, mag: FilterMode, anisotropy: number)",
		  type = "function"
		 },
		 getHeight = {
		  args = "()",
		  description = "Gets the height of the Canvas.",
		  returns = "(height: number)",
		  type = "function"
		 },
		 getMSAA = {
		  args = "()",
		  description = "Gets the number of multisample antialiasing (MSAA) samples used when drawing to the Canvas.\n\nThis may be different than the number used as an argument to love.graphics.newCanvas if the system running LÖVE doesn't support that number.",
		  returns = "(samples: number)",
		  type = "function"
		 },
		 getWidth = {
		  args = "()",
		  description = "Gets the width of the Canvas.",
		  returns = "(width: number)",
		  type = "function"
		 },
		 getWrap = {
		  args = "()",
		  description = "Gets the wrapping properties of a Canvas.\n\nThis function returns the currently set horizontal and vertical wrapping modes for the Canvas.",
		  returns = "(horizontal: WrapMode, vertical: WrapMode)",
		  type = "function"
		 },
		 newImageData = {
		  args = "(x: number, y: number, width: number, height: number)",
		  description = "Generates ImageData from the contents of the Canvas.",
		  returns = "(data: ImageData)",
		  type = "function"
		 },
		 renderTo = {
		  args = "(func: function)",
		  description = "Render to the Canvas using a function.",
		  returns = "()",
		  type = "function"
		 },
		 setFilter = {
		  args = "(min: FilterMode, mag: FilterMode, anisotropy: number)",
		  description = "Sets the filter of the Canvas.",
		  returns = "()",
		  type = "function"
		 },
		 setWrap = {
		  args = "(horizontal: WrapMode, vertical: WrapMode)",
		  description = "Sets the wrapping properties of a Canvas.\n\nThis function sets the way the edges of a Canvas are treated if it is scaled or rotated. If the WrapMode is set to \"clamp\", the edge will not be interpolated. If set to \"repeat\", the edge will be interpolated with the pixels on the opposing side of the framebuffer.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A Canvas is used for off-screen rendering. Think of it as an invisible screen that you can draw to, but that will not be visible until you draw it to the actual visible screen. It is also known as \"render to texture\".\n\nBy drawing things that do not change position often (such as background items) to the Canvas, and then drawing the entire Canvas instead of each item, you can reduce the number of draw operations performed each frame.\n\nIn versions prior to 0.10.0, not all graphics cards that LÖVE supported could use Canvases. love.graphics.isSupported(\"canvas\") could be used to check for support at runtime.",
		inherits = "Texture",
		type = "class"
	   },
	   CompareMode = {
		childs = {
		 equal = {
		  description = "The stencil value of the pixel must be equal to the supplied value.",
		  type = "value"
		 },
		 gequal = {
		  description = "The stencil value of the pixel must be greater than or equal to the supplied value.",
		  type = "value"
		 },
		 greater = {
		  description = "The stencil value of the pixel must be greater than the supplied value.",
		  type = "value"
		 },
		 lequal = {
		  description = "The stencil value of the pixel must be less than or equal to the supplied value.",
		  type = "value"
		 },
		 less = {
		  description = "The stencil value of the pixel must be less than the supplied value.",
		  type = "value"
		 },
		 notequal = {
		  description = "The stencil value of the pixel must not be equal to the supplied value.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   CullMode = {
		childs = {
		 back = {
		  description = "Back-facing triangles in Meshes are culled (not rendered). The vertex order of a triangle determines whether it is back- or front-facing.",
		  type = "value"
		 },
		 front = {
		  description = "Front-facing triangles in Meshes are culled.",
		  type = "value"
		 },
		 none = {
		  description = "Both back- and front-facing triangles in Meshes are rendered.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   DrawMode = {
		childs = {
		 fill = {
		  description = "Draw filled shape.",
		  type = "value"
		 },
		 line = {
		  description = "Draw outlined shape.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   FilterMode = {
		childs = {
		 linear = {
		  description = "Scale image with linear interpolation.",
		  type = "value"
		 },
		 nearest = {
		  description = "Scale image with nearest neighbor interpolation.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   Font = {
		childs = {
		 getBaseline = {
		  args = "()",
		  description = "Gets the baseline of the Font. Most scripts share the notion of a baseline: an imaginary horizontal line on which characters rest. In some scripts, parts of glyphs lie below the baseline.",
		  returns = "(baseline: number)",
		  type = "function"
		 },
		 getDescent = {
		  args = "()",
		  description = "Gets the descent of the Font. The descent spans the distance between the baseline and the lowest descending glyph in a typeface.",
		  returns = "(descent: number)",
		  type = "function"
		 },
		 getFilter = {
		  args = "()",
		  description = "Gets the filter mode for a font.",
		  returns = "(min: FilterMode, mag: FilterMode, anisotropy: number)",
		  type = "function"
		 },
		 getHeight = {
		  args = "()",
		  description = "Gets the height of the Font. The height of the font is the size including any spacing; the height which it will need.",
		  returns = "(height: number)",
		  type = "function"
		 },
		 getLineHeight = {
		  args = "()",
		  description = "Gets the line height. This will be the value previously set by Font:setLineHeight, or 1.0 by default.",
		  returns = "(height: number)",
		  type = "function"
		 },
		 getWidth = {
		  args = "(line: string)",
		  description = "Determines the horizontal size a line of text needs. Does not support line-breaks.",
		  returns = "(width: number)",
		  type = "function"
		 },
		 getWrap = {
		  args = "(text: string, wraplimit: number)",
		  description = "Gets formatting information for text, given a wrap limit.\n\nThis function accounts for newlines correctly (i.e. '\\n').",
		  returns = "(width: number, wrappedtext: table)",
		  type = "function"
		 },
		 hasGlyphs = {
		  args = "(character: string)",
		  description = "Gets whether the font can render a particular character.",
		  returns = "(hasglyph: boolean)",
		  type = "function"
		 },
		 setFallbacks = {
		  args = "(fallbackfont1: Font, ...: Font)",
		  description = "Sets the fallback fonts. When the Font doesn't contain a glyph, it will substitute the glyph from the next subsequent fallback Fonts. This is akin to setting a \"font stack\" in Cascading Style Sheets (CSS).",
		  returns = "()",
		  type = "function"
		 },
		 setFilter = {
		  args = "(min: FilterMode, mag: FilterMode, anisotropy: number)",
		  description = "Sets the filter mode for a font.",
		  returns = "()",
		  type = "function"
		 },
		 setLineHeight = {
		  args = "(height: number)",
		  description = "Sets the line height. When rendering the font in lines the actual height will be determined by the line height multiplied by the height of the font. The default is 1.0.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Defines the shape of characters than can be drawn onto the screen.",
		inherits = "Object",
		type = "class"
	   },
	   GraphicsFeature = {
		childs = {
		 clampzero = {
		  description = "Whether the \"clampzero\" WrapMode is supported.",
		  type = "value"
		 },
		 lighten = {
		  description = "Whether the \"lighten\" and \"darken\" BlendModes are supported.",
		  type = "value"
		 },
		 multicanvasformats = {
		  description = "Whether multiple Canvases with different formats can be used in the same love.graphics.setCanvas call.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   GraphicsLimit = {
		childs = {
		 canvasmsaa = {
		  description = "The maximum number of antialiasing samples for a Canvas.",
		  type = "value"
		 },
		 multicanvas = {
		  description = "The maximum number of simultaneously active canvases (via love.graphics.setCanvas).",
		  type = "value"
		 },
		 pointsize = {
		  description = "The maximum size of points.",
		  type = "value"
		 },
		 texturesize = {
		  description = "The maximum width or height of Images and Canvases.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   Image = {
		childs = {
		 getFilter = {
		  args = "()",
		  description = "Gets the filter mode for an image.",
		  returns = "(min: FilterMode, mag: FilterMode)",
		  type = "function"
		 },
		 getFlags = {
		  args = "()",
		  description = "Gets the flags used when the image was created.",
		  returns = "(flags: table)",
		  type = "function"
		 },
		 getHeight = {
		  args = "()",
		  description = "Gets the height of the Image.",
		  returns = "(height: number)",
		  type = "function"
		 },
		 getMipmapFilter = {
		  args = "()",
		  description = "Gets the mipmap filter mode for an Image.",
		  returns = "(mode: FilterMode, sharpness: number)",
		  type = "function"
		 },
		 getWidth = {
		  args = "()",
		  description = "Gets the width of the Image.",
		  returns = "(width: number)",
		  type = "function"
		 },
		 getWrap = {
		  args = "()",
		  description = "Gets the wrapping properties of an Image.\n\nThis function returns the currently set horizontal and vertical wrapping modes for the image.",
		  returns = "(horizontal: WrapMode, vertical: WrapMode)",
		  type = "function"
		 },
		 replacePixels = {
		  args = "(data: ImageData, slice: number, mipmap: number)",
		  description = "Replaces the contents of an Image.",
		  returns = "()",
		  type = "function"
		 },
		 setFilter = {
		  args = "(min: FilterMode, mag: FilterMode)",
		  description = "Sets the filter mode for an image.",
		  returns = "()",
		  type = "function"
		 },
		 setMipmapFilter = {
		  args = "(filtermode: FilterMode, sharpness: number)",
		  description = "Sets the mipmap filter mode for an Image.\n\nMipmapping is useful when drawing an image at a reduced scale. It can improve performance and reduce aliasing issues.\n\nIn 0.10.0 and newer, the Image must be created with the mipmaps flag enabled for the mipmap filter to have any effect.",
		  returns = "()",
		  type = "function"
		 },
		 setWrap = {
		  args = "(horizontal: WrapMode, vertical: WrapMode)",
		  description = "Sets the wrapping properties of an Image.\n\nThis function sets the way an Image is repeated when it is drawn with a Quad that is larger than the image's extent. An image may be clamped or set to repeat in both horizontal and vertical directions. Clamped images appear only once, but repeated ones repeat as many times as there is room in the Quad.\n\nIf you use a Quad that is larger than the image extent and do not use repeated tiling, there may be an unwanted visual effect of the image stretching all the way to fill the Quad. If this is the case, setting Image:getWrap(\"repeat\", \"repeat\") for all the images to be repeated, and using Quad of appropriate size will result in the best visual appearance.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Drawable image type.",
		inherits = "Texture",
		type = "class"
	   },
	   LineJoin = {
		childs = {
		 bevel = {
		  description = "No cap applied to the ends of the line segments.",
		  type = "value"
		 },
		 miter = {
		  description = "The ends of the line segments beveled in an angle so that they join seamlessly.",
		  type = "value"
		 },
		 none = {
		  description = "Flattens the point where line segments join together.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   LineStyle = {
		childs = {
		 rough = {
		  description = "Draw rough lines.",
		  type = "value"
		 },
		 smooth = {
		  description = "Draw smooth lines.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   Mesh = {
		childs = {
		 detachAttribute = {
		  args = "(name: string)",
		  description = "Removes a previously attached vertex attribute from this Mesh.",
		  returns = "(success: boolean)",
		  type = "function"
		 },
		 getDrawMode = {
		  args = "()",
		  description = "Gets the mode used when drawing the Mesh.",
		  returns = "(mode: MeshDrawMode)",
		  type = "function"
		 },
		 getDrawRange = {
		  args = "()",
		  description = "Gets the range of vertices used when drawing the Mesh.\n\nIf the Mesh's draw range has not been set previously with Mesh:setDrawRange, this function will return nil.",
		  returns = "(min: number, max: number)",
		  type = "function"
		 },
		 getTexture = {
		  args = "()",
		  description = "Gets the texture (Image or Canvas) used when drawing the Mesh.",
		  returns = "(texture: Texture)",
		  type = "function"
		 },
		 getVertex = {
		  args = "(index: number)",
		  description = "Gets the properties of a vertex in the Mesh.",
		  returns = "(attributecomponent: number, ...: number)",
		  type = "function"
		 },
		 getVertexAttribute = {
		  args = "(vertexindex: number, attributeindex: number)",
		  description = "Gets the properties of a specific attribute within a vertex in the Mesh.\n\nMeshes without a custom vertex format specified in love.graphics.newMesh have position as their first attribute, texture coordinates as their second attribute, and color as their third attribute.",
		  returns = "(value1: number, value2: number, ...: number)",
		  type = "function"
		 },
		 getVertexCount = {
		  args = "()",
		  description = "Returns the total number of vertices in the Mesh.",
		  returns = "(num: number)",
		  type = "function"
		 },
		 getVertexFormat = {
		  args = "()",
		  description = "Gets the vertex format that the Mesh was created with.",
		  returns = "(format: table)",
		  type = "function"
		 },
		 getVertexMap = {
		  args = "()",
		  description = "Gets the vertex map for the Mesh. The vertex map describes the order in which the vertices are used when the Mesh is drawn. The vertices, vertex map, and mesh draw mode work together to determine what exactly is displayed on the screen.\n\nIf no vertex map has been set previously via Mesh:setVertexMap, then this function will return nil in LÖVE 0.10.0+, or an empty table in 0.9.2 and older.",
		  returns = "(map: table)",
		  type = "function"
		 },
		 isAttributeEnabled = {
		  args = "(name: string)",
		  description = "Gets whether a specific vertex attribute in the Mesh is enabled. Vertex data from disabled attributes is not used when drawing the Mesh.",
		  returns = "(enabled: boolean)",
		  type = "function"
		 },
		 setAttributeEnabled = {
		  args = "(name: string, enable: boolean)",
		  description = "Enables or disables a specific vertex attribute in the Mesh. Vertex data from disabled attributes is not used when drawing the Mesh.",
		  returns = "()",
		  type = "function"
		 },
		 setDrawMode = {
		  args = "(mode: MeshDrawMode)",
		  description = "Sets the mode used when drawing the Mesh.",
		  returns = "()",
		  type = "function"
		 },
		 setDrawRange = {
		  args = "(min: number, max: number)",
		  description = "Restricts the drawn vertices of the Mesh to a subset of the total.\n\nIf a vertex map is used with the Mesh, this method will set a subset of the values in the vertex map array to use, instead of a subset of the total vertices in the Mesh.\n\nFor example, if Mesh:setVertexMap(1, 2, 3, 1, 3, 4) and Mesh:setDrawRange(4, 6) are called, vertices 1, 3, and 4 will be drawn.",
		  returns = "()",
		  type = "function"
		 },
		 setTexture = {
		  args = "(texture: Texture)",
		  description = "Sets the texture (Image or Canvas) used when drawing the Mesh.\n\nWhen called without an argument disables the texture. Untextured meshes have a white color by default.",
		  returns = "()",
		  type = "function"
		 },
		 setVertex = {
		  args = "(index: number, attributecomponent: number, ...: number)",
		  description = "Sets the properties of a vertex in the Mesh.",
		  returns = "()",
		  type = "function"
		 },
		 setVertexAttribute = {
		  args = "(vertexindex: number, attributeindex: number, value1: number, value2: number, ...: number)",
		  description = "Sets the properties of a specific attribute within a vertex in the Mesh.\n\nMeshes without a custom vertex format specified in love.graphics.newMesh have position as their first attribute, texture coordinates as their second attribute, and color as their third attribute.",
		  returns = "()",
		  type = "function"
		 },
		 setVertexMap = {
		  args = "(map: table)",
		  description = "Sets the vertex map for the Mesh. The vertex map describes the order in which the vertices are used when the Mesh is drawn. The vertices, vertex map, and mesh draw mode work together to determine what exactly is displayed on the screen.\n\nThe vertex map allows you to re-order or reuse vertices when drawing without changing the actual vertex parameters or duplicating vertices. It is especially useful when combined with different Mesh Draw Modes.",
		  returns = "()",
		  type = "function"
		 },
		 setVertices = {
		  args = "(vertices: table)",
		  description = "Replaces a range of vertices in the Mesh with new ones. The total number of vertices in a Mesh cannot be changed after it has been created.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A 2D polygon mesh used for drawing arbitrary textured shapes.",
		inherits = "Drawable",
		type = "class"
	   },
	   MeshDrawMode = {
		childs = {
		 fan = {
		  description = "The vertices create a \"fan\" shape with the first vertex acting as the hub point. Can be easily used to draw simple convex polygons.",
		  type = "value"
		 },
		 points = {
		  description = "The vertices are drawn as unconnected points (see love.graphics.setPointSize.)",
		  type = "value"
		 },
		 strip = {
		  description = "The vertices create a series of connected triangles using vertices 1, 2, 3, then 3, 2, 4 (note the order), then 3, 4, 5 and so on.",
		  type = "value"
		 },
		 triangles = {
		  description = "The vertices create unconnected triangles.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   ParticleInsertMode = {
		childs = {
		 bottom = {
		  description = "Particles are inserted at the bottom of the ParticleSystem's list of particles.",
		  type = "value"
		 },
		 random = {
		  description = "Particles are inserted at random positions in the ParticleSystem's list of particles.",
		  type = "value"
		 },
		 top = {
		  description = "Particles are inserted at the top of the ParticleSystem's list of particles.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   ParticleSystem = {
		childs = {
		 emit = {
		  args = "(numparticles: number)",
		  description = "Emits a burst of particles from the particle emitter.",
		  returns = "()",
		  type = "function"
		 },
		 getAreaSpread = {
		  args = "()",
		  description = "Gets the area-based spawn parameters for the particles.",
		  returns = "(distribution: AreaSpreadDistribution, dx: number, dy: number)",
		  type = "function"
		 },
		 getBufferSize = {
		  args = "()",
		  description = "Gets the size of the buffer (the max allowed amount of particles in the system).",
		  returns = "(buffer: number)",
		  type = "function"
		 },
		 getColors = {
		  args = "()",
		  description = "Gets a series of colors to apply to the particle sprite. The particle system will interpolate between each color evenly over the particle's lifetime. Color modulation needs to be activated for this function to have any effect.\n\nArguments are passed in groups of four, representing the components of the desired RGBA value. At least one color must be specified. A maximum of eight may be used.",
		  returns = "(r1: number, g1: number, b1: number, a1: number, r2: number, g2: number, b2: number, a2: number, ...: number)",
		  type = "function"
		 },
		 getCount = {
		  args = "()",
		  description = "Gets the amount of particles that are currently in the system.",
		  returns = "(count: number)",
		  type = "function"
		 },
		 getDirection = {
		  args = "()",
		  description = "Gets the direction the particles will be emitted in.",
		  returns = "(direction: number)",
		  type = "function"
		 },
		 getEmissionRate = {
		  args = "()",
		  description = "Gets the amount of particles emitted per second.",
		  returns = "(rate: number)",
		  type = "function"
		 },
		 getEmitterLifetime = {
		  args = "()",
		  description = "Gets how long the particle system should emit particles (if -1 then it emits particles forever).",
		  returns = "(life: number)",
		  type = "function"
		 },
		 getInsertMode = {
		  args = "()",
		  description = "Gets the mode to use when the ParticleSystem adds new particles.",
		  returns = "(mode: ParticleInsertMode)",
		  type = "function"
		 },
		 getLinearAcceleration = {
		  args = "()",
		  description = "Gets the linear acceleration (acceleration along the x and y axes) for particles.\n\nEvery particle created will accelerate along the x and y axes between xmin,ymin and xmax,ymax.",
		  returns = "(xmin: number, ymin: number, xmax: number, ymax: number)",
		  type = "function"
		 },
		 getLinearDamping = {
		  args = "()",
		  description = "Gets the amount of linear damping (constant deceleration) for particles.",
		  returns = "(min: number, max: number)",
		  type = "function"
		 },
		 getOffset = {
		  args = "()",
		  description = "Get the offget position which the particle sprite is rotated around. If this function is not used, the particles rotate around their center.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getParticleLifetime = {
		  args = "()",
		  description = "Gets the life of the particles.",
		  returns = "(min: number, max: number)",
		  type = "function"
		 },
		 getPosition = {
		  args = "()",
		  description = "Gets the position of the emitter.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getQuads = {
		  args = "()",
		  description = "Gets the series of Quads used for the particle sprites.",
		  returns = "(quads: table)",
		  type = "function"
		 },
		 getRadialAcceleration = {
		  args = "()",
		  description = "Get the radial acceleration (away from the emitter).",
		  returns = "(min: number, max: number)",
		  type = "function"
		 },
		 getRotation = {
		  args = "()",
		  description = "Gets the rotation of the image upon particle creation (in radians).",
		  returns = "(min: number, max: number)",
		  type = "function"
		 },
		 getSizeVariation = {
		  args = "()",
		  description = "Gets the degree of variation (0 meaning no variation and 1 meaning full variation between start and end).",
		  returns = "(variation: number)",
		  type = "function"
		 },
		 getSizes = {
		  args = "()",
		  description = "Gets a series of sizes by which to scale a particle sprite. 1.0 is normal size. The particle system will interpolate between each size evenly over the particle's lifetime.\n\nAt least one size must be specified. A maximum of eight may be used.",
		  returns = "(size1: number, size2: number, ...: number)",
		  type = "function"
		 },
		 getSpeed = {
		  args = "()",
		  description = "Gets the speed of the particles.",
		  returns = "(min: number, max: number)",
		  type = "function"
		 },
		 getSpin = {
		  args = "()",
		  description = "Gets the spin of the sprite.",
		  returns = "(min: number, max: number)",
		  type = "function"
		 },
		 getSpinVariation = {
		  args = "()",
		  description = "Gets the degree of variation (0 meaning no variation and 1 meaning full variation between start and end).",
		  returns = "(variation: number)",
		  type = "function"
		 },
		 getSpread = {
		  args = "()",
		  description = "Gets the amount of spread for the system.",
		  returns = "(spread: number)",
		  type = "function"
		 },
		 getTangentialAcceleration = {
		  args = "()",
		  description = "Gets the tangential acceleration (acceleration perpendicular to the particle's direction).",
		  returns = "(min: number, max: number)",
		  type = "function"
		 },
		 getTexture = {
		  args = "()",
		  description = "Gets the Image or Canvas which is to be emitted.",
		  returns = "(texture: Texture)",
		  type = "function"
		 },
		 hasRelativeRotation = {
		  args = "()",
		  description = "Gets whether particle angles and rotations are relative to their velocities. If enabled, particles are aligned to the angle of their velocities and rotate relative to that angle.",
		  returns = "(enabled: boolean)",
		  type = "function"
		 },
		 isActive = {
		  args = "()",
		  description = "Checks whether the particle system is actively emitting particles.",
		  returns = "(active: boolean)",
		  type = "function"
		 },
		 isPaused = {
		  args = "()",
		  description = "Checks whether the particle system is paused.",
		  returns = "(paused: boolean)",
		  type = "function"
		 },
		 isStopped = {
		  args = "()",
		  description = "Checks whether the particle system is stopped.",
		  returns = "(stopped: boolean)",
		  type = "function"
		 },
		 moveTo = {
		  args = "(x: number, y: number)",
		  description = "Moves the position of the emitter. This results in smoother particle spawning behaviour than if ParticleSystem:setPosition is used every frame.",
		  returns = "()",
		  type = "function"
		 },
		 pause = {
		  args = "()",
		  description = "Pauses the particle emitter.",
		  returns = "()",
		  type = "function"
		 },
		 reset = {
		  args = "()",
		  description = "Resets the particle emitter, removing any existing particles and resetting the lifetime counter.",
		  returns = "()",
		  type = "function"
		 },
		 setAreaSpread = {
		  args = "(distribution: AreaSpreadDistribution, dx: number, dy: number)",
		  description = "Sets area-based spawn parameters for the particles. Newly created particles will spawn in an area around the emitter based on the parameters to this function.",
		  returns = "()",
		  type = "function"
		 },
		 setBufferSize = {
		  args = "(buffer: number)",
		  description = "Sets the size of the buffer (the max allowed amount of particles in the system).",
		  returns = "()",
		  type = "function"
		 },
		 setColors = {
		  args = "(r1: number, g1: number, b1: number, a1: number, r2: number, g2: number, b2: number, a2: number, ...: number)",
		  description = "Sets a series of colors to apply to the particle sprite. The particle system will interpolate between each color evenly over the particle's lifetime. Color modulation needs to be activated for this function to have any effect.\n\nArguments are passed in groups of four, representing the components of the desired RGBA value. At least one color must be specified. A maximum of eight may be used.",
		  returns = "()",
		  type = "function"
		 },
		 setDirection = {
		  args = "(direction: number)",
		  description = "Sets the direction the particles will be emitted in.",
		  returns = "()",
		  type = "function"
		 },
		 setEmissionRate = {
		  args = "(rate: number)",
		  description = "Sets the amount of particles emitted per second.",
		  returns = "()",
		  type = "function"
		 },
		 setEmitterLifetime = {
		  args = "(life: number)",
		  description = "Sets how long the particle system should emit particles (if -1 then it emits particles forever).",
		  returns = "()",
		  type = "function"
		 },
		 setInsertMode = {
		  args = "(mode: ParticleInsertMode)",
		  description = "Sets the mode to use when the ParticleSystem adds new particles.",
		  returns = "()",
		  type = "function"
		 },
		 setLinearAcceleration = {
		  args = "(xmin: number, ymin: number, xmax: number, ymax: number)",
		  description = "Sets the linear acceleration (acceleration along the x and y axes) for particles.\n\nEvery particle created will accelerate along the x and y axes between xmin,ymin and xmax,ymax.",
		  returns = "()",
		  type = "function"
		 },
		 setLinearDamping = {
		  args = "(min: number, max: number)",
		  description = "Sets the amount of linear damping (constant deceleration) for particles.",
		  returns = "()",
		  type = "function"
		 },
		 setOffset = {
		  args = "(x: number, y: number)",
		  description = "Set the offset position which the particle sprite is rotated around. If this function is not used, the particles rotate around their center.",
		  returns = "()",
		  type = "function"
		 },
		 setParticleLifetime = {
		  args = "(min: number, max: number)",
		  description = "Sets the life of the particles.",
		  returns = "()",
		  type = "function"
		 },
		 setPosition = {
		  args = "(x: number, y: number)",
		  description = "Sets the position of the emitter.",
		  returns = "()",
		  type = "function"
		 },
		 setQuads = {
		  args = "(quad1: Quad, quad2: Quad)",
		  description = "Sets a series of Quads to use for the particle sprites. Particles will choose a Quad from the list based on the particle's current lifetime, allowing for the use of animated sprite sheets with ParticleSystems.",
		  returns = "()",
		  type = "function"
		 },
		 setRadialAcceleration = {
		  args = "(min: number, max: number)",
		  description = "Set the radial acceleration (away from the emitter).",
		  returns = "()",
		  type = "function"
		 },
		 setRelativeRotation = {
		  args = "(enable: boolean)",
		  description = "Sets whether particle angles and rotations are relative to their velocities. If enabled, particles are aligned to the angle of their velocities and rotate relative to that angle.",
		  returns = "()",
		  type = "function"
		 },
		 setRotation = {
		  args = "(min: number, max: number)",
		  description = "Sets the rotation of the image upon particle creation (in radians).",
		  returns = "()",
		  type = "function"
		 },
		 setSizeVariation = {
		  args = "(variation: number)",
		  description = "Sets the degree of variation (0 meaning no variation and 1 meaning full variation between start and end).",
		  returns = "()",
		  type = "function"
		 },
		 setSizes = {
		  args = "(size1: number, size2: number, ...: number)",
		  description = "Sets a series of sizes by which to scale a particle sprite. 1.0 is normal size. The particle system will interpolate between each size evenly over the particle's lifetime.\n\nAt least one size must be specified. A maximum of eight may be used.",
		  returns = "()",
		  type = "function"
		 },
		 setSpeed = {
		  args = "(min: number, max: number)",
		  description = "Sets the speed of the particles.",
		  returns = "()",
		  type = "function"
		 },
		 setSpin = {
		  args = "(min: number, max: number)",
		  description = "Sets the spin of the sprite.",
		  returns = "()",
		  type = "function"
		 },
		 setSpinVariation = {
		  args = "(variation: number)",
		  description = "Sets the degree of variation (0 meaning no variation and 1 meaning full variation between start and end).",
		  returns = "()",
		  type = "function"
		 },
		 setSpread = {
		  args = "(spread: number)",
		  description = "Sets the amount of spread for the system.",
		  returns = "()",
		  type = "function"
		 },
		 setTangentialAcceleration = {
		  args = "(min: number, max: number)",
		  description = "Sets the tangential acceleration (acceleration perpendicular to the particle's direction).",
		  returns = "()",
		  type = "function"
		 },
		 setTexture = {
		  args = "(texture: Texture)",
		  description = "Sets the Image or Canvas which is to be emitted.",
		  returns = "()",
		  type = "function"
		 },
		 start = {
		  args = "()",
		  description = "Starts the particle emitter.",
		  returns = "()",
		  type = "function"
		 },
		 stop = {
		  args = "()",
		  description = "Stops the particle emitter, resetting the lifetime counter.",
		  returns = "()",
		  type = "function"
		 },
		 update = {
		  args = "(dt: number)",
		  description = "Updates the particle system; moving, creating and killing particles.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Used to create cool effects, like fire. The particle systems are created and drawn on the screen using functions in love.graphics. They also need to be updated in the update(dt) callback for you to see any changes in the particles emitted.",
		inherits = "Drawable",
		type = "class"
	   },
	   Quad = {
		childs = {
		 getViewport = {
		  args = "()",
		  description = "Gets the current viewport of this Quad.",
		  returns = "(x: number, y: number, w: number, h: number)",
		  type = "function"
		 },
		 setViewport = {
		  args = "(x: number, y: number, w: number, h: number)",
		  description = "Sets the texture coordinates according to a viewport.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A quadrilateral (a polygon with four sides and four corners) with texture coordinate information.\n\nQuads can be used to select part of a texture to draw. In this way, one large texture atlas can be loaded, and then split up into sub-images.",
		inherits = "Object",
		type = "class"
	   },
	   Shader = {
		childs = {
		 hasUniform = {
		  args = "(name: string)",
		  description = "Gets whether a uniform / extern variable exists in the Shader.\n\nIf a graphics driver's shader compiler determines that a uniform / extern variable doesn't affect the final output of the shader, it may optimize the variable out. This function will return false in that case.",
		  returns = "(hasuniform: boolean)",
		  type = "function"
		 },
		 send = {
		  args = "(name: string, number: number, ...: number)",
		  description = "Sends one or more values to a special (uniform) variable inside the shader. Uniform variables have to be marked using the uniform or extern keyword.",
		  returns = "()",
		  type = "function"
		 },
		 sendColor = {
		  args = "(name: string, color: table, ...: table)",
		  description = "Sends one or more colors to a special (extern / uniform) vec3 or vec4 variable inside the shader. The color components must be in the range of [0, 255], unlike Shader:send. The colors are gamma-corrected if global gamma-correction is enabled.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A Shader is used for advanced hardware-accelerated pixel or vertex manipulation. These effects are written in a language based on GLSL (OpenGL Shading Language) with a few things simplified for easier coding.\n\nPotential uses for shaders include HDR/bloom, motion blur, grayscale/invert/sepia/any kind of color effect, reflection/refraction, distortions, bump mapping, and much more! Here is a collection of basic shaders and good starting point to learn: https://github.com/vrld/shine",
		inherits = "Object",
		type = "class"
	   },
	   SpriteBatch = {
		childs = {
		 attachAttribute = {
		  args = "(name: string, mesh: Mesh)",
		  description = "Attaches a per-vertex attribute from a Mesh onto this SpriteBatch, for use when drawing. This can be combined with a Shader to augment a SpriteBatch with per-vertex or additional per-sprite information instead of just having per-sprite colors.\n\nEach sprite in a SpriteBatch has 4 vertices in the following order: top-left, bottom-left, top-right, bottom-right. The index returned by SpriteBatch:add (and used by SpriteBatch:set) can used to determine the first vertex of a specific sprite with the formula \"1 + 4 * ( id - 1 )\".",
		  returns = "()",
		  type = "function"
		 },
		 clear = {
		  args = "()",
		  description = "Removes all sprites from the buffer.",
		  returns = "()",
		  type = "function"
		 },
		 flush = {
		  args = "()",
		  description = "Immediately sends all new and modified sprite data in the batch to the graphics card.",
		  returns = "()",
		  type = "function"
		 },
		 getBufferSize = {
		  args = "()",
		  description = "Gets the maximum number of sprites the SpriteBatch can hold.",
		  returns = "(size: number)",
		  type = "function"
		 },
		 getColor = {
		  args = "()",
		  description = "Gets the color that will be used for the next add and set operations.\n\nIf no color has been set with SpriteBatch:setColor or the current SpriteBatch color has been cleared, this method will return nil.",
		  returns = "(r: number, g: number, b: number, a: number)",
		  type = "function"
		 },
		 getCount = {
		  args = "()",
		  description = "Gets the amount of sprites currently in the SpriteBatch.",
		  returns = "(count: number)",
		  type = "function"
		 },
		 getTexture = {
		  args = "()",
		  description = "Returns the Image or Canvas used by the SpriteBatch.",
		  returns = "(texture: Texture)",
		  type = "function"
		 },
		 set = {
		  args = "(id: number, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)",
		  description = "Changes a sprite in the batch. This requires the identifier returned by add and addq.",
		  returns = "()",
		  type = "function"
		 },
		 setColor = {
		  args = "(r: number, g: number, b: number, a: number)",
		  description = "Sets the color that will be used for the next add and set operations. Calling the function without arguments will clear the color.\n\nIn version [[0.9.2]] and older, the global color set with love.graphics.setColor will not work on the SpriteBatch if any of the sprites has its own color.",
		  returns = "()",
		  type = "function"
		 },
		 setDrawRange = {
		  args = "(start: number, count: number)",
		  description = "Restricts the drawn sprites in the SpriteBatch to a subset of the total.",
		  returns = "()",
		  type = "function"
		 },
		 setTexture = {
		  args = "(texture: Texture)",
		  description = "Replaces the Image or Canvas used for the sprites.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Using a single image, draw any number of identical copies of the image using a single call to love.graphics.draw. This can be used, for example, to draw repeating copies of a single background image.\n\nA SpriteBatch can be even more useful when the underlying image is a Texture Atlas (a single image file containing many independent images); by adding Quad to the batch, different sub-images from within the atlas can be drawn.",
		inherits = "Drawable",
		type = "class"
	   },
	   SpriteBatchUsage = {
		childs = {
		 dynamic = {
		  description = "The object's data will change occasionally during its lifetime.",
		  type = "value"
		 },
		 static = {
		  description = "The object will not be modified after initial sprites or vertices are added.",
		  type = "value"
		 },
		 stream = {
		  description = "The object data will always change between draws.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   StackType = {
		childs = {
		 all = {
		  description = "All love.graphics state, including transform state.",
		  type = "value"
		 },
		 transform = {
		  description = "The transformation stack (love.graphics.translate, love.graphics.rotate, etc.)",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   StencilAction = {
		childs = {
		 decrement = {
		  description = "The stencil value of a pixel will be decremented by 1 for each object that touches the pixel. If the stencil value reaches 0 it will stay at 0.",
		  type = "value"
		 },
		 decrementwrap = {
		  description = "The stencil value of a pixel will be decremented by 1 for each object that touches the pixel. If the stencil value of 0 is decremented it will be set to 255.",
		  type = "value"
		 },
		 increment = {
		  description = "The stencil value of a pixel will be incremented by 1 for each object that touches the pixel. If the stencil value reaches 255 it will stay at 255.",
		  type = "value"
		 },
		 incrementwrap = {
		  description = "The stencil value of a pixel will be incremented by 1 for each object that touches the pixel. If a stencil value of 255 is incremented it will be set to 0.",
		  type = "value"
		 },
		 invert = {
		  description = "The stencil value of a pixel will be bitwise-inverted for each object that touches the pixel. If a stencil value of 0 is inverted it will become 255.",
		  type = "value"
		 },
		 replace = {
		  description = "The stencil value of a pixel will be replaced by the value specified in love.graphics.stencil, if any object touches the pixel.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   Text = {
		childs = {
		 addf = {
		  args = "(textstring: string, wraplimit: number, align: AlignMode, x: number, y: number, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)",
		  description = "Adds additional formatted / colored text to the Text object at the specified position.",
		  returns = "(index: number)",
		  type = "function"
		 },
		 clear = {
		  args = "()",
		  description = "Clears the contents of the Text object.",
		  returns = "()",
		  type = "function"
		 },
		 getDimensions = {
		  args = "(index: number)",
		  description = "Gets the width and height of the text in pixels.",
		  returns = "(width: number, height: number)",
		  type = "function"
		 },
		 getFont = {
		  args = "()",
		  description = "Gets the Font used with the Text object.",
		  returns = "(font: Font)",
		  type = "function"
		 },
		 getHeight = {
		  args = "(index: number)",
		  description = "Gets the height of the text in pixels.",
		  returns = "(height: number)",
		  type = "function"
		 },
		 getWidth = {
		  args = "(index: number)",
		  description = "Gets the width of the text in pixels.",
		  returns = "(width: number)",
		  type = "function"
		 },
		 set = {
		  args = "(textstring: string)",
		  description = "Replaces the contents of the Text object with a new unformatted string.",
		  returns = "()",
		  type = "function"
		 },
		 setFont = {
		  args = "(font: Font)",
		  description = "Replaces the Font used with the text.",
		  returns = "()",
		  type = "function"
		 },
		 setf = {
		  args = "(textstring: string, wraplimit: number, align: AlignMode)",
		  description = "Replaces the contents of the Text object with a new formatted string.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Drawable text.",
		inherits = "Drawable",
		type = "class"
	   },
	   Texture = {
		childs = {
		 getFormat = {
		  args = "()",
		  description = "Gets the PixelFormat of the Texture.",
		  returns = "(format: PixelFormat)",
		  type = "function"
		 },
		 getLayerCount = {
		  args = "()",
		  description = "Gets the number of layers / slices in an Array Texture. Returns 1 for 2D, Cubemap, and Volume textures.",
		  returns = "(layers: number)",
		  type = "function"
		 },
		 getMipmapCount = {
		  args = "()",
		  description = "Gets the number of mipmaps contained in the Texture. If the texture was not created with mipmaps, it will return 1.",
		  returns = "(mipmaps: number)",
		  type = "function"
		 },
		 getTextureType = {
		  args = "()",
		  description = "Gets the type of the Texture.",
		  returns = "(texturetype: TextureType)",
		  type = "function"
		 },
		 isReadable = {
		  args = "()",
		  description = "Gets whether the Texture can be drawn and sent to a Shader.\n\nCanvases created with stencil and/or depth PixelFormats are not readable by default, unless readable=true is specified in the settings table passed into love.graphics.newCanvas.\n\nNon-readable Canvases can still be rendered to.",
		  returns = "(readable: boolean)",
		  type = "function"
		 }
		},
		description = "Superclass for drawable objects which represent a texture. All Textures can be drawn with Quads. This is an abstract type that can't be created directly.",
		inherits = "Drawable",
		type = "class"
	   },
	   VertexWinding = {
		childs = {
		 ccw = {
		  description = "Counter-clockwise.",
		  type = "value"
		 },
		 cw = {
		  description = "Clockwise.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   Video = {
		childs = {
		 getFilter = {
		  args = "()",
		  description = "Gets the scaling filters used when drawing the Video.",
		  returns = "(min: FilterMode, mag: FilterMode, anisotropy: number)",
		  type = "function"
		 },
		 getHeight = {
		  args = "()",
		  description = "Gets the height of the Video in pixels.",
		  returns = "(height: number)",
		  type = "function"
		 },
		 getSource = {
		  args = "()",
		  description = "Gets the audio Source used for playing back the video's audio. May return nil if the video has no audio, or if Video:setSource is called with a nil argument.",
		  returns = "(source: Source)",
		  type = "function"
		 },
		 getStream = {
		  args = "()",
		  description = "Gets the VideoStream object used for decoding and controlling the video.",
		  returns = "(stream: VideoStream)",
		  type = "function"
		 },
		 getWidth = {
		  args = "()",
		  description = "Gets the width of the Video in pixels.",
		  returns = "(width: number)",
		  type = "function"
		 },
		 isPlaying = {
		  args = "()",
		  description = "Gets whether the Video is currently playing.",
		  returns = "(playing: boolean)",
		  type = "function"
		 },
		 pause = {
		  args = "()",
		  description = "Pauses the Video.",
		  returns = "()",
		  type = "function"
		 },
		 play = {
		  args = "()",
		  description = "Starts playing the Video. In order for the video to appear onscreen it must be drawn with love.graphics.draw.",
		  returns = "()",
		  type = "function"
		 },
		 rewind = {
		  args = "()",
		  description = "Rewinds the Video to the beginning.",
		  returns = "()",
		  type = "function"
		 },
		 seek = {
		  args = "(offset: number)",
		  description = "Sets the current playback position of the Video.",
		  returns = "()",
		  type = "function"
		 },
		 setFilter = {
		  args = "(min: FilterMode, mag: FilterMode, anisotropy: number)",
		  description = "Sets the scaling filters used when drawing the Video.",
		  returns = "()",
		  type = "function"
		 },
		 setSource = {
		  args = "(source: Source)",
		  description = "Sets the audio Source used for playing back the video's audio. The audio Source also controls playback speed and synchronization.",
		  returns = "()",
		  type = "function"
		 },
		 tell = {
		  args = "(seconds: number)",
		  description = "Gets the current playback position of the Video.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A drawable video.",
		inherits = "Drawable",
		type = "class"
	   },
	   WrapMode = {
		childs = {
		 clamp = {
		  description = "How the image wraps inside a Quad with a larger quad size than image size. This also affects how Meshes with texture coordinates which are outside the range of [0, 1] are drawn, and the color returned by the Texel Shader function when using it to sample from texture coordinates outside of the range of [0, 1].",
		  type = "value"
		 },
		 clampzero = {
		  description = "Clamp the texture. Fills the area outside the texture's normal range with transparent black (or opaque black for textures with no alpha channel.)",
		  type = "value"
		 },
		 mirroredrepeat = {
		  description = "Repeat the texture, flipping it each time it repeats. May produce better visual results than the repeat mode when the texture doesn't seamlessly tile.",
		  type = "value"
		 },
		 ["repeat"] = {
		  description = "Repeat the image. Fills the whole available extent.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   applyTransform = {
		args = "(transform: Transform)",
		description = "Applies the given Transform object to the current coordinate transformation.\n\nThis effectively multiplies the existing coordinate transformation's matrix with the Transform object's internal matrix to produce the new coordinate transformation.",
		returns = "()",
		type = "function"
	   },
	   captureScreenshot = {
		args = "(filename: string)",
		description = "Creates a screenshot once the current frame is done (after love.draw has finished).\n\nSince this function enqueues a screenshot capture rather than executing it immediately, it can be called from an input callback or love.update and it will still capture all of what's drawn to the screen in that frame.",
		returns = "()",
		type = "function"
	   },
	   circle = {
		args = "(mode: DrawMode, x: number, y: number, radius: number)",
		description = "Draws a circle.",
		returns = "()",
		type = "function"
	   },
	   clear = {
		args = "(r: number, g: number, b: number, a: number)",
		description = "Clears the screen to the background color in LÖVE 0.9.2 and earlier, or to the specified color in 0.10.0 and newer.\n\nThis function is called automatically before love.draw in the default love.run function. See the example in love.run for a typical use of this function.\n\nNote that the scissor area bounds the cleared region.",
		returns = "()",
		type = "function"
	   },
	   discard = {
		args = "(discardcolor: boolean, discardstencil: boolean)",
		description = "Discards (trashes) the contents of the screen or active Canvas. This is a performance optimization function with niche use cases.\n\nIf the active Canvas has just been changed and the \"replace\" BlendMode is about to be used to draw something which covers the entire screen, calling love.graphics.discard rather than calling love.graphics.clear or doing nothing may improve performance on mobile devices.\n\nOn some desktop systems this function may do nothing.",
		returns = "()",
		type = "function"
	   },
	   draw = {
		args = "(drawable: Drawable, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)",
		description = "Draws a Drawable object (an Image, Canvas, SpriteBatch, ParticleSystem, Mesh, Text object, or Video) on the screen with optional rotation, scaling and shearing.\n\nObjects are drawn relative to their local coordinate system. The origin is by default located at the top left corner of Image and Canvas. All scaling, shearing, and rotation arguments transform the object relative to that point. Also, the position of the origin can be specified on the screen coordinate system.\n\nIt's possible to rotate an object about its center by offsetting the origin to the center. Angles must be given in radians for rotation. One can also use a negative scaling factor to flip about its centerline.\n\nNote that the offsets are applied before rotation, scaling, or shearing; scaling and shearing are applied before rotation.\n\nThe right and bottom edges of the object are shifted at an angle defined by the shearing factors.",
		returns = "()",
		type = "function"
	   },
	   drawInstanced = {
		args = "(mesh: Mesh, instancecount: number, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)",
		description = "Draws many instances of a Mesh with a single draw call, using hardware geometry instancing.\n\nEach instance can have unique properties (positions, colors, etc.) but will not by default unless a custom Shader along with either per-instance attributes or the love_InstanceID GLSL 3 vertex shader variable is used, otherwise they will all render at the same position on top of each other.\n\nInstancing is not supported by some older GPUs that are only capable of using OpenGL ES 2 or OpenGL 2. Use love.graphics.getSupported to check.",
		returns = "()",
		type = "function"
	   },
	   drawLayer = {
		args = "(texture: Texture, layerindex: number, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)",
		description = "Draws a layer of an Array Texture.",
		returns = "()",
		type = "function"
	   },
	   ellipse = {
		args = "(mode: DrawMode, x: number, y: number, radiusx: number, radiusy: number)",
		description = "Draws an ellipse.",
		returns = "()",
		type = "function"
	   },
	   flushBatch = {
		args = "()",
		description = "Immediately renders any pending automatically batched draws.\n\nLÖVE will call this function internally as needed when most state is changed, so it is not necessary to manually call it.\n\nThe current batch will be automatically flushed by love.graphics state changes (except for the transform stack and the current color), as well as Shader:send and methods on Textures which change their state. Using a different Image in consecutive love.graphics.draw calls will also flush the current batch.\n\nSpriteBatches, ParticleSystems, Meshes, and Text objects do their own batching and do not affect automatic batching of other draws.",
		returns = "()",
		type = "function"
	   },
	   getBackgroundColor = {
		args = "()",
		description = "Gets the current background color.",
		returns = "(r: number, g: number, b: number, a: number)",
		type = "function"
	   },
	   getBlendMode = {
		args = "()",
		description = "Gets the blending mode.",
		returns = "(mode: BlendMode, alphamode: BlendAlphaMode)",
		type = "function"
	   },
	   getCanvas = {
		args = "()",
		description = "Gets the current target Canvas.",
		returns = "(canvas: Canvas)",
		type = "function"
	   },
	   getCanvasFormats = {
		args = "(readable: boolean)",
		description = "Gets the available Canvas formats, and whether each is supported.",
		returns = "(formats: table)",
		type = "function"
	   },
	   getColor = {
		args = "()",
		description = "Gets the current color.",
		returns = "(r: number, g: number, b: number, a: number)",
		type = "function"
	   },
	   getColorMask = {
		args = "()",
		description = "Gets the active color components used when drawing. Normally all 4 components are active unless love.graphics.setColorMask has been used.\n\nThe color mask determines whether individual components of the colors of drawn objects will affect the color of the screen. They affect love.graphics.clear and Canvas:clear as well.",
		returns = "(r: boolean, g: boolean, b: boolean, a: boolean)",
		type = "function"
	   },
	   getDefaultFilter = {
		args = "()",
		description = "Returns the default scaling filters used with Images, Canvases, and Fonts.",
		returns = "(min: FilterMode, mag: FilterMode, anisotropy: number)",
		type = "function"
	   },
	   getDepthMode = {
		args = "()",
		description = "Gets the current depth test mode and whether writing to the depth buffer is enabled.\n\nThis is low-level functionality designed for use with custom vertex shaders and Meshes with custom vertex attributes. No higher level APIs are provided to set the depth of 2D graphics such as shapes, lines, and Images.",
		returns = "(comparemode: CompareMode, write: boolean)",
		type = "function"
	   },
	   getDimensions = {
		args = "()",
		description = "Gets the width and height of the window.",
		returns = "(width: number, height: number)",
		type = "function"
	   },
	   getFont = {
		args = "()",
		description = "Gets the current Font object.",
		returns = "(font: Font)",
		type = "function"
	   },
	   getFrontFaceWinding = {
		args = "()",
		description = "Gets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-facing.\n\nThis is designed for use in combination with Mesh face culling. Other love.graphics shapes, lines, and sprites are not guaranteed to have a specific winding order to their internal vertices.",
		returns = "(winding: VertexWinding)",
		type = "function"
	   },
	   getHeight = {
		args = "()",
		description = "Gets the height of the window.",
		returns = "(height: number)",
		type = "function"
	   },
	   getImageFormats = {
		args = "()",
		description = "Gets the raw and compressed pixel formats usable for Images, and whether each is supported.",
		returns = "(formats: table)",
		type = "function"
	   },
	   getLineJoin = {
		args = "()",
		description = "Gets the line join style.",
		returns = "(join: LineJoin)",
		type = "function"
	   },
	   getLineStyle = {
		args = "()",
		description = "Gets the line style.",
		returns = "(style: LineStyle)",
		type = "function"
	   },
	   getLineWidth = {
		args = "()",
		description = "Gets the current line width.",
		returns = "(width: number)",
		type = "function"
	   },
	   getMeshCullMode = {
		args = "()",
		description = "Gets whether back-facing triangles in a Mesh are culled.\n\nMesh face culling is designed for use with low level custom hardware-accelerated 3D rendering via custom vertex attributes on Meshes, custom vertex shaders, and depth testing with a depth buffer.",
		returns = "(mode: CullMode)",
		type = "function"
	   },
	   getPointSize = {
		args = "()",
		description = "Gets the point size.",
		returns = "(size: number)",
		type = "function"
	   },
	   getRendererInfo = {
		args = "()",
		description = "Gets information about the system's video card and drivers.",
		returns = "(name: string, version: string, vendor: string, device: string)",
		type = "function"
	   },
	   getScissor = {
		args = "()",
		description = "Gets the current scissor box.",
		returns = "(x: number, y: number, width: number, height: number)",
		type = "function"
	   },
	   getShader = {
		args = "()",
		description = "Returns the current Shader. Returns nil if none is set.",
		returns = "(shader: Shader)",
		type = "function"
	   },
	   getStackDepth = {
		args = "()",
		description = "Gets the current depth of the transform / state stack (the number of pushes without corresponding pops).",
		returns = "(depth: number)",
		type = "function"
	   },
	   getStats = {
		args = "()",
		description = "Gets performance-related rendering statistics.",
		returns = "(stats: table)",
		type = "function"
	   },
	   getStencilTest = {
		args = "()",
		description = "Gets whether stencil testing is enabled.\n\nWhen stencil testing is enabled, the geometry of everything that is drawn will be clipped / stencilled out based on whether it intersects with what has been previously drawn to the stencil buffer.\n\nEach Canvas has its own stencil buffer.",
		returns = "(enabled: boolean, inverted: boolean)",
		type = "function"
	   },
	   getSupported = {
		args = "()",
		description = "Gets the optional graphics features and whether they're supported on the system.\n\nSome older or low-end systems don't always support all graphics features.",
		returns = "(features: table)",
		type = "function"
	   },
	   getSystemLimits = {
		args = "()",
		description = "Gets the system-dependent maximum values for love.graphics features.",
		returns = "(limits: table)",
		type = "function"
	   },
	   getTextureTypes = {
		args = "()",
		description = "Gets the available texture types, and whether each is supported.",
		returns = "(texturetypes: table)",
		type = "function"
	   },
	   getWidth = {
		args = "()",
		description = "Gets the width of the window.",
		returns = "(width: number)",
		type = "function"
	   },
	   intersectScissor = {
		args = "(x: number, y: number, width: number, height: number)",
		description = "Sets the scissor to the rectangle created by the intersection of the specified rectangle with the existing scissor. If no scissor is active yet, it behaves like love.graphics.setScissor.\n\nThe scissor limits the drawing area to a specified rectangle. This affects all graphics calls, including love.graphics.clear.\n\nThe dimensions of the scissor is unaffected by graphical transformations (translate, scale, ...).",
		returns = "()",
		type = "function"
	   },
	   inverseTransformPoint = {
		args = "(screenX: number, screenY: number)",
		description = "Converts the given 2D position from screen-space into global coordinates.\n\nThis effectively applies the reverse of the current graphics transformations to the given position. A similar Transform:inverseTransformPoint method exists for Transform objects.",
		returns = "(globalX: number, globalY: number)",
		type = "function"
	   },
	   isGammaCorrect = {
		args = "()",
		description = "Gets whether gamma-correct rendering is supported and enabled. It can be enabled by setting t.gammacorrect = true in love.conf.\n\nNot all devices support gamma-correct rendering, in which case it will be automatically disabled and this function will return false. It is supported on desktop systems which have graphics cards that are capable of using OpenGL 3 / DirectX 10, and iOS devices that can use OpenGL ES 3.",
		returns = "(gammacorrect: boolean)",
		type = "function"
	   },
	   isWireframe = {
		args = "()",
		description = "Gets whether wireframe mode is used when drawing.",
		returns = "(wireframe: boolean)",
		type = "function"
	   },
	   line = {
		args = "(x1: number, y1: number, x2: number, y2: number, ...: number)",
		description = "Draws lines between points.",
		returns = "()",
		type = "function"
	   },
	   newCanvas = {
		args = "(width: number, height: number, format: CanvasFormat, msaa: number)",
		description = "Creates a new Canvas object for offscreen rendering.\n\nAntialiased Canvases have slightly higher system requirements than normal Canvases. Additionally, the supported maximum number of MSAA samples varies depending on the system. Use love.graphics.getSystemLimit to check.\n\nIf the number of MSAA samples specified is greater than the maximum supported by the system, the Canvas will still be created but only using the maximum supported amount (this includes 0.)",
		returns = "(canvas: Canvas)",
		type = "function"
	   },
	   newFont = {
		args = "(filename: string)",
		description = "Creates a new Font from a TrueType Font or BMFont file. Created fonts are not cached, in that calling this function with the same arguments will always create a new Font object.\n\nAll variants which accept a filename can also accept a Data object instead.",
		returns = "(font: Font)",
		type = "function"
	   },
	   newImage = {
		args = "(filename: string)",
		description = "Creates a new Image from a filepath, FileData, an ImageData, or a CompressedImageData, and optionally generates or specifies mipmaps for the image.",
		returns = "(image: Image)",
		type = "function"
	   },
	   newImageFont = {
		args = "(filename: string, glyphs: string)",
		description = "Creates a new Font by loading a specifically formatted image.\n\nIn versions prior to 0.9.0, LÖVE expects ISO 8859-1 encoding for the glyphs string.",
		returns = "(font: Font)",
		type = "function"
	   },
	   newMesh = {
		args = "(vertices: table, mode: MeshDrawMode, usage: SpriteBatchUsage)",
		description = "Creates a new Mesh.\n\nUse Mesh:setTexture if the Mesh should be textured with an Image or Canvas when it's drawn.",
		returns = "(mesh: Mesh)",
		type = "function"
	   },
	   newParticleSystem = {
		args = "(texture: Texture, buffer: number)",
		description = "Creates a new ParticleSystem.",
		returns = "(system: ParticleSystem)",
		type = "function"
	   },
	   newQuad = {
		args = "(x: number, y: number, width: number, height: number, sw: number, sh: number)",
		description = "Creates a new Quad.\n\nThe purpose of a Quad is to describe the result of the following transformation on any drawable object. The object is first scaled to dimensions sw * sh. The Quad then describes the rectangular area of dimensions width * height whose upper left corner is at position (x, y) inside the scaled object.",
		returns = "(quad: Quad)",
		type = "function"
	   },
	   newShader = {
		args = "(code: string)",
		description = "Creates a new Shader object for hardware-accelerated vertex and pixel effects. A Shader contains either vertex shader code, pixel shader code, or both.\n\nVertex shader code must contain at least one function, named position, which is the function that will produce transformed vertex positions of drawn objects in screen-space.\n\nPixel shader code must contain at least one function, named effect, which is the function that will produce the color which is blended onto the screen for each pixel a drawn object touches.",
		returns = "(shader: Shader)",
		type = "function"
	   },
	   newSpriteBatch = {
		args = "(texture: Texture, maxsprites: number, usage: SpriteBatchUsage)",
		description = "Creates a new SpriteBatch object.",
		returns = "(spriteBatch: SpriteBatch)",
		type = "function"
	   },
	   newText = {
		args = "(font: Font, textstring: string)",
		description = "Creates a new drawable Text object.",
		returns = "(text: Text)",
		type = "function"
	   },
	   newVideo = {
		args = "(filename: string, loadaudio: boolean)",
		description = "Creates a new drawable Video. Currently only Ogg Theora video files are supported.",
		returns = "(video: Video)",
		type = "function"
	   },
	   origin = {
		args = "()",
		description = "Resets the current coordinate transformation.\n\nThis function is always used to reverse any previous calls to love.graphics.rotate, love.graphics.scale, love.graphics.shear or love.graphics.translate. It returns the current transformation state to its defaults.",
		returns = "()",
		type = "function"
	   },
	   points = {
		args = "(x: number, y: number, ...: number)",
		description = "Draws one or more points.",
		returns = "()",
		type = "function"
	   },
	   polygon = {
		args = "(mode: DrawMode, ...: number)",
		description = "Draw a polygon.\n\nFollowing the mode argument, this function can accept multiple numeric arguments or a single table of numeric arguments. In either case the arguments are interpreted as alternating x and y coordinates of the polygon's vertices.\n\nWhen in fill mode, the polygon must be convex and simple or rendering artifacts may occur.",
		returns = "()",
		type = "function"
	   },
	   pop = {
		args = "()",
		description = "Pops the current coordinate transformation from the transformation stack.\n\nThis function is always used to reverse a previous push operation. It returns the current transformation state to what it was before the last preceding push. For an example, see the description of love.graphics.push.",
		returns = "()",
		type = "function"
	   },
	   present = {
		args = "()",
		description = "Displays the results of drawing operations on the screen.\n\nThis function is used when writing your own love.run function. It presents all the results of your drawing operations on the screen. See the example in love.run for a typical use of this function.",
		returns = "()",
		type = "function"
	   },
	   print = {
		args = "(text: string, x: number, y: number, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)",
		description = "Draws text on screen. If no Font is set, one will be created and set (once) if needed.\n\nAs of LOVE 0.7.1, when using translation and scaling functions while drawing text, this function assumes the scale occurs first. If you don't script with this in mind, the text won't be in the right position, or possibly even on screen.\n\nlove.graphics.print and love.graphics.printf both support UTF-8 encoding. You'll also need a proper Font for special characters.\n\nIn versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.",
		returns = "()",
		type = "function"
	   },
	   printf = {
		args = "(text: string, x: number, y: number, limit: number, align: AlignMode, r: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)",
		description = "Draws formatted text, with word wrap and alignment.\n\nSee additional notes in love.graphics.print.\n\nIn version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case.",
		returns = "()",
		type = "function"
	   },
	   push = {
		args = "(stack: StackType)",
		description = "Copies and pushes the current coordinate transformation to the transformation stack.\n\nThis function is always used to prepare for a corresponding pop operation later. It stores the current coordinate transformation state into the transformation stack and keeps it active. Later changes to the transformation can be undone by using the pop operation, which returns the coordinate transform to the state it was in before calling push.",
		returns = "()",
		type = "function"
	   },
	   rectangle = {
		args = "(mode: DrawMode, x: number, y: number, width: number, height: number)",
		description = "Draws a rectangle.",
		returns = "()",
		type = "function"
	   },
	   replaceTransform = {
		args = "(transform: Transform)",
		description = "Replaces the current coordinate transformation with the given Transform object.",
		returns = "()",
		type = "function"
	   },
	   reset = {
		args = "()",
		description = "Resets the current graphics settings.\n\nCalling reset makes the current drawing color white, the current background color black, resets any active Canvas or Shader, and removes any scissor settings. It sets the BlendMode to alpha. It also sets both the point and line drawing modes to smooth and their sizes to 1.0.",
		returns = "()",
		type = "function"
	   },
	   rotate = {
		args = "(angle: number)",
		description = "Rotates the coordinate system in two dimensions.\n\nCalling this function affects all future drawing operations by rotating the coordinate system around the origin by the given amount of radians. This change lasts until love.draw exits.",
		returns = "()",
		type = "function"
	   },
	   scale = {
		args = "(sx: number, sy: number)",
		description = "Scales the coordinate system in two dimensions.\n\nBy default the coordinate system in LÖVE corresponds to the display pixels in horizontal and vertical directions one-to-one, and the x-axis increases towards the right while the y-axis increases downwards. Scaling the coordinate system changes this relation.\n\nAfter scaling by sx and sy, all coordinates are treated as if they were multiplied by sx and sy. Every result of a drawing operation is also correspondingly scaled, so scaling by (2, 2) for example would mean making everything twice as large in both x- and y-directions. Scaling by a negative value flips the coordinate system in the corresponding direction, which also means everything will be drawn flipped or upside down, or both. Scaling by zero is not a useful operation.\n\nScale and translate are not commutative operations, therefore, calling them in different orders will change the outcome.\n\nScaling lasts until love.draw exits.",
		returns = "()",
		type = "function"
	   },
	   setBackgroundColor = {
		args = "(r: number, g: number, b: number, a: number)",
		description = "Sets the background color.",
		returns = "()",
		type = "function"
	   },
	   setBlendMode = {
		args = "(mode: BlendMode)",
		description = "Sets the blending mode.",
		returns = "()",
		type = "function"
	   },
	   setCanvas = {
		args = "(canvas: Canvas)",
		description = "Captures drawing operations to a Canvas.",
		returns = "()",
		type = "function"
	   },
	   setColor = {
		args = "(red: number, green: number, blue: number, alpha: number)",
		description = "Sets the color used for drawing.",
		returns = "()",
		type = "function"
	   },
	   setColorMask = {
		args = "(red: boolean, green: boolean, blue: boolean, alpha: boolean)",
		description = "Sets the color mask. Enables or disables specific color components when rendering and clearing the screen. For example, if red is set to false, no further changes will be made to the red component of any pixels.\n\nEnables all color components when called without arguments.",
		returns = "()",
		type = "function"
	   },
	   setDefaultFilter = {
		args = "(min: FilterMode, mag: FilterMode, anisotropy: number)",
		description = "Sets the default scaling filters used with Images, Canvases, and Fonts.\n\nThis function does not apply retroactively to loaded images.",
		returns = "()",
		type = "function"
	   },
	   setDepthMode = {
		args = "(comparemode: CompareMode, write: boolean)",
		description = "Configures depth testing and writing to the depth buffer.\n\nThis is low-level functionality designed for use with custom vertex shaders and Meshes with custom vertex attributes. No higher level APIs are provided to set the depth of 2D graphics such as shapes, lines, and Images.",
		returns = "()",
		type = "function"
	   },
	   setFont = {
		args = "(font: Font)",
		description = "Set an already-loaded Font as the current font or create and load a new one from the file and size.\n\nIt's recommended that Font objects are created with love.graphics.newFont in the loading stage and then passed to this function in the drawing stage.",
		returns = "()",
		type = "function"
	   },
	   setFrontFaceWinding = {
		args = "(winding: VertexWinding)",
		description = "Sets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-facing.\n\nThis is designed for use in combination with Mesh face culling. Other love.graphics shapes, lines, and sprites are not guaranteed to have a specific winding order to their internal vertices.",
		returns = "()",
		type = "function"
	   },
	   setLineJoin = {
		args = "(join: LineJoin)",
		description = "Sets the line join style.",
		returns = "()",
		type = "function"
	   },
	   setLineStyle = {
		args = "(style: LineStyle)",
		description = "Sets the line style.",
		returns = "()",
		type = "function"
	   },
	   setLineWidth = {
		args = "(width: number)",
		description = "Sets the line width.",
		returns = "()",
		type = "function"
	   },
	   setMeshCullMode = {
		args = "(mode: CullMode)",
		description = "Sets whether back-facing triangles in a Mesh are culled.\n\nThis is designed for use with low level custom hardware-accelerated 3D rendering via custom vertex attributes on Meshes, custom vertex shaders, and depth testing with a depth buffer.",
		returns = "()",
		type = "function"
	   },
	   setNewFont = {
		args = "(filename: string, size: number)",
		description = "Creates and sets a new font.",
		returns = "(font: Font)",
		type = "function"
	   },
	   setPointSize = {
		args = "(size: number)",
		description = "Sets the point size.",
		returns = "()",
		type = "function"
	   },
	   setScissor = {
		args = "(x: number, y: number, width: number, height: number)",
		description = "Sets or disables scissor.\n\nThe scissor limits the drawing area to a specified rectangle. This affects all graphics calls, including love.graphics.clear.",
		returns = "()",
		type = "function"
	   },
	   setShader = {
		args = "(shader: Shader)",
		description = "Sets or resets a Shader as the current pixel effect or vertex shaders. All drawing operations until the next love.graphics.setShader will be drawn using the Shader object specified.\n\nDisables the shaders when called without arguments.",
		returns = "()",
		type = "function"
	   },
	   setStencilTest = {
		args = "(comparemode: CompareMode, comparevalue: number)",
		description = "Configures or disables stencil testing.\n\nWhen stencil testing is enabled, the geometry of everything that is drawn afterward will be clipped / stencilled out based on a comparison between the arguments of this function and the stencil value of each pixel that the geometry touches. The stencil values of pixels are affected via love.graphics.stencil.\n\nEach Canvas has its own per-pixel stencil values.",
		returns = "()",
		type = "function"
	   },
	   setWireframe = {
		args = "(enable: boolean)",
		description = "Sets whether wireframe lines will be used when drawing.\n\nWireframe mode should only be used for debugging. The lines drawn with it enabled do not behave like regular love.graphics lines: their widths don't scale with the coordinate transformations or with love.graphics.setLineWidth, and they don't use the smooth LineStyle.",
		returns = "()",
		type = "function"
	   },
	   shear = {
		args = "(kx: number, ky: number)",
		description = "Shears the coordinate system.",
		returns = "()",
		type = "function"
	   },
	   stencil = {
		args = "(stencilfunction: function, action: StencilAction, value: number, keepvalues: boolean)",
		description = "Draws geometry as a stencil.\n\nThe geometry drawn by the supplied function sets invisible stencil values of pixels, instead of setting pixel colors. The stencil values of pixels can act like a mask / stencil - love.graphics.setStencilTest can be used afterward to determine how further rendering is affected by the stencil values in each pixel.\n\nEach Canvas has its own per-pixel stencil values. Stencil values are within the range of [0, 255].",
		returns = "()",
		type = "function"
	   },
	   transformPoint = {
		args = "(globalX: number, globalY: number)",
		description = "Converts the given 2D position from global coordinates into screen-space.\n\nThis effectively applies the current graphics transformations to the given position. A similar Transform:transformPoint method exists for Transform objects.",
		returns = "(screenX: number, sreenY: number)",
		type = "function"
	   },
	   translate = {
		args = "(dx: number, dy: number)",
		description = "Translates the coordinate system in two dimensions.\n\nWhen this function is called with two numbers, dx, and dy, all the following drawing operations take effect as if their x and y coordinates were x+dx and y+dy.\n\nScale and translate are not commutative operations, therefore, calling them in different orders will change the outcome.\n\nThis change lasts until love.graphics.clear is called (which is called automatically before love.draw in the default love.run function), or a love.graphics.pop reverts to a previous coordinate system state.\n\nTranslating using whole numbers will prevent tearing/blurring of images and fonts draw after translating.",
		returns = "()",
		type = "function"
	   },
	   validateShader = {
		args = "(gles: boolean, code: string)",
		description = "Validates shader code. Check if specificed shader code does not contain any errors.",
		returns = "(status: boolean, message: string)",
		type = "function"
	   }
	  },
	  description = "The primary responsibility for the love.graphics module is the drawing of lines, shapes, text, Images and other Drawable objects onto the screen. Its secondary responsibilities include loading external files (including Images and Fonts) into memory, creating specialized objects (such as ParticleSystems or Canvases) and managing screen geometry.\n\nLÖVE's coordinate system is rooted in the upper-left corner of the screen, which is at location (0, 0). The x axis is horizontal: larger values are further to the right. The y axis is vertical: larger values are further towards the bottom.\n\nIn many cases, you draw images or shapes in terms of their upper-left corner.\n\nMany of the functions are used to manipulate the graphics coordinate system, which is essentially the way coordinates are mapped to the display. You can change the position, scale, and even rotation in this way.",
	  type = "class"
	 },
	 hasDeprecationOutput = {
	  args = "()",
	  description = "Gets whether LÖVE displays warnings when using deprecated functionality. It is disabled by default in fused mode, and enabled by default otherwise.\n\nWhen deprecation output is enabled, the first use of a formally deprecated LÖVE API will show a message at the bottom of the screen for a short time, and print the message to the console.",
	  returns = "(enabled: boolean)",
	  type = "function"
	 },
	 image = {
	  childs = {
	   CompressedImageData = {
		childs = {
		 getFormat = {
		  args = "()",
		  description = "Gets the format of the CompressedImageData.",
		  returns = "(format: CompressedImageFormat)",
		  type = "function"
		 },
		 getHeight = {
		  args = "(level: number)",
		  description = "Gets the height of the CompressedImageData.",
		  returns = "(height: number)",
		  type = "function"
		 },
		 getMipmapCount = {
		  args = "()",
		  description = "Gets the number of mipmap levels in the CompressedImageData. The base mipmap level (original image) is included in the count.",
		  returns = "(mipmaps: number)",
		  type = "function"
		 },
		 getWidth = {
		  args = "(level: number)",
		  description = "Gets the width of the CompressedImageData.",
		  returns = "(width: number)",
		  type = "function"
		 }
		},
		description = "Represents compressed image data designed to stay compressed in RAM.\n\nCompressedImageData encompasses standard compressed texture formats such as DXT1, DXT5, and BC5 / 3Dc.\n\nYou can't draw CompressedImageData directly to the screen. See Image for that.",
		inherits = "Data",
		type = "class"
	   },
	   CompressedImageFormat = {
		childs = {
		 ASTC4x4 = {
		  description = "The 4x4 pixels per block variant of the ASTC format. RGBA data at 8 bits per pixel.",
		  type = "value"
		 },
		 ASTC5x4 = {
		  description = "The 5x4 pixels per block variant of the ASTC format. RGBA data at 6.4 bits per pixel.",
		  type = "value"
		 },
		 ASTC5x5 = {
		  description = "The 5x5 pixels per block variant of the ASTC format. RGBA data at 5.12 bits per pixel.",
		  type = "value"
		 },
		 ASTC6x5 = {
		  description = "The 6x5 pixels per block variant of the ASTC format. RGBA data at 4.27 bits per pixel.",
		  type = "value"
		 },
		 ASTC6x6 = {
		  description = "The 6x6 pixels per block variant of the ASTC format. RGBA data at 3.56 bits per pixel.",
		  type = "value"
		 },
		 ASTC8x5 = {
		  description = "The 8x5 pixels per block variant of the ASTC format. RGBA data at 3.2 bits per pixel.",
		  type = "value"
		 },
		 ASTC8x6 = {
		  description = "The 8x6 pixels per block variant of the ASTC format. RGBA data at 2.67 bits per pixel.",
		  type = "value"
		 },
		 ASTC8x8 = {
		  description = "The 8x8 pixels per block variant of the ASTC format. RGBA data at 2 bits per pixel.",
		  type = "value"
		 },
		 ASTC10x5 = {
		  description = "The 10x5 pixels per block variant of the ASTC format. RGBA data at 2.56 bits per pixel.",
		  type = "value"
		 },
		 ASTC10x6 = {
		  description = "The 10x6 pixels per block variant of the ASTC format. RGBA data at 2.13 bits per pixel.",
		  type = "value"
		 },
		 ASTC10x8 = {
		  description = "The 10x8 pixels per block variant of the ASTC format. RGBA data at 1.6 bits per pixel.",
		  type = "value"
		 },
		 ASTC10x10 = {
		  description = "The 10x10 pixels per block variant of the ASTC format. RGBA data at 1.28 bits per pixel.",
		  type = "value"
		 },
		 ASTC12x10 = {
		  description = "The 12x10 pixels per block variant of the ASTC format. RGBA data at 1.07 bits per pixel.",
		  type = "value"
		 },
		 ASTC12x12 = {
		  description = "The 12x12 pixels per block variant of the ASTC format. RGBA data at 0.89 bits per pixel.",
		  type = "value"
		 },
		 BC4 = {
		  description = "The BC4 format (also known as 3Dc+ or ATI1.) Stores just the red channel, at 4 bits per pixel.",
		  type = "value"
		 },
		 BC4s = {
		  description = "The signed variant of the BC4 format. Same as above but the pixel values in the texture are in the range of [-1, 1] instead of [0, 1] in shaders.",
		  type = "value"
		 },
		 BC5 = {
		  description = "The BC5 format (also known as 3Dc or ATI2.) Stores red and green channels at 8 bits per pixel.",
		  type = "value"
		 },
		 BC5s = {
		  description = "The signed variant of the BC5 format.",
		  type = "value"
		 },
		 BC6h = {
		  description = "The BC6H format. Stores half-precision floating-point RGB data in the range of [0, 65504] at 8 bits per pixel. Suitable for HDR images on desktop systems.",
		  type = "value"
		 },
		 BC6hs = {
		  description = "The signed variant of the BC6H format. Stores RGB data in the range of [-65504, +65504].",
		  type = "value"
		 },
		 BC7 = {
		  description = "The BC7 format (also known as BPTC.) Stores RGB or RGBA data at 8 bits per pixel.",
		  type = "value"
		 },
		 DXT1 = {
		  description = "The DXT1 format. RGB data at 4 bits per pixel (compared to 32 bits for ImageData and regular Images.) Suitable for fully opaque images. Suitable for fully opaque images on desktop systems.",
		  type = "value"
		 },
		 DXT3 = {
		  description = "The DXT3 format. RGBA data at 8 bits per pixel. Smooth variations in opacity do not mix well with this format.",
		  type = "value"
		 },
		 DXT5 = {
		  description = "The DXT5 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on desktop systems.",
		  type = "value"
		 },
		 EACr = {
		  description = "The single-channel variant of the EAC format. Stores just the red channel, at 4 bits per pixel.",
		  type = "value"
		 },
		 EACrg = {
		  description = "The two-channel variant of the EAC format. Stores red and green channels at 8 bits per pixel.",
		  type = "value"
		 },
		 EACrgs = {
		  description = "The signed two-channel variant of the EAC format.",
		  type = "value"
		 },
		 EACrs = {
		  description = "The signed single-channel variant of the EAC format. Same as above but pixel values in the texture are in the range of [-1, 1] instead of [0, 1] in shaders.",
		  type = "value"
		 },
		 ETC1 = {
		  description = "The ETC1 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on older Android devices.",
		  type = "value"
		 },
		 ETC2rgb = {
		  description = "The RGB variant of the ETC2 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on newer mobile devices.",
		  type = "value"
		 },
		 ETC2rgba = {
		  description = "The RGBA variant of the ETC2 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on newer mobile devices.",
		  type = "value"
		 },
		 ETC2rgba1 = {
		  description = "The RGBA variant of the ETC2 format where pixels are either fully transparent or fully opaque. RGBA data at 4 bits per pixel.",
		  type = "value"
		 },
		 PVR1rgb2 = {
		  description = "The 2 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 2 bits per pixel. Textures compressed with PVRTC1 formats must be square and power-of-two sized.",
		  type = "value"
		 },
		 PVR1rgb4 = {
		  description = "The 4 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 4 bits per pixel.",
		  type = "value"
		 },
		 PVR1rgba2 = {
		  description = "The 2 bit per pixel RGBA variant of the PVRTC1 format.",
		  type = "value"
		 },
		 PVR1rgba4 = {
		  description = "The 4 bit per pixel RGBA variant of the PVRTC1 format.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   ImageData = {
		childs = {
		 getDimensions = {
		  args = "()",
		  description = "Gets the width and height of the ImageData in pixels.",
		  returns = "(width: number, height: number)",
		  type = "function"
		 },
		 getHeight = {
		  args = "()",
		  description = "Gets the height of the ImageData in pixels.",
		  returns = "(height: number)",
		  type = "function"
		 },
		 getPixel = {
		  args = "(x: number, y: number)",
		  description = "Gets the color of a pixel at a specific position in the image.\n\nValid x and y values start at 0 and go up to image width and height minus 1. Non-integer values are floored.",
		  returns = "(r: number, g: number, b: number, a: number)",
		  type = "function"
		 },
		 getWidth = {
		  args = "()",
		  description = "Gets the width of the ImageData in pixels.",
		  returns = "(width: number)",
		  type = "function"
		 },
		 mapPixel = {
		  args = "(pixelFunction: function)",
		  description = "Transform an image by applying a function to every pixel.\n\nThis function is a higher order function. It takes another function as a parameter, and calls it once for each pixel in the ImageData.\n\nThe function parameter is called with six parameters for each pixel in turn. The parameters are numbers that represent the x and y coordinates of the pixel and its red, green, blue and alpha values. The function parameter can return up to four number values, which become the new r, g, b and a values of the pixel. If the function returns fewer values, the remaining components are set to 0.",
		  returns = "()",
		  type = "function"
		 },
		 paste = {
		  args = "(source: ImageData, dx: number, dy: number, sx: number, sy: number, sw: number, sh: number)",
		  description = "Paste into ImageData from another source ImageData.",
		  returns = "()",
		  type = "function"
		 },
		 setPixel = {
		  args = "(x: number, y: number, r: number, g: number, b: number, a: number)",
		  description = "Sets the color of a pixel at a specific position in the image.\n\nValid x and y values start at 0 and go up to image width and height minus 1.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Raw (decoded) image data.\n\nYou can't draw ImageData directly to screen. See Image for that.",
		inherits = "Data",
		type = "class"
	   },
	   ImageFormat = {
		childs = {
		 png = {
		  description = "PNG image format.",
		  type = "value"
		 },
		 tga = {
		  description = "Targa image format.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   newCompressedData = {
		args = "(filename: string)",
		description = "Create a new CompressedImageData object from a compressed image file. LÖVE supports several compressed texture formats, enumerated in the CompressedImageFormat page.",
		returns = "(compressedImageData: CompressedImageData)",
		type = "function"
	   },
	   newImageData = {
		args = "(width: number, height: number)",
		description = "Create a new ImageData object.",
		returns = "(imageData: ImageData)",
		type = "function"
	   }
	  },
	  description = "Provides an interface to decode encoded image data.",
	  type = "class"
	 },
	 joystick = {
	  childs = {
	   GamepadAxis = {
		childs = {
		 leftx = {
		  description = "The x-axis of the left thumbstick.",
		  type = "value"
		 },
		 lefty = {
		  description = "The y-axis of the left thumbstick.",
		  type = "value"
		 },
		 rightx = {
		  description = "The x-axis of the right thumbstick.",
		  type = "value"
		 },
		 righty = {
		  description = "The y-axis of the right thumbstick.",
		  type = "value"
		 },
		 triggerleft = {
		  description = "Left analog trigger.",
		  type = "value"
		 },
		 triggerright = {
		  description = "Right analog trigger.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   GamepadButton = {
		childs = {
		 a = {
		  description = "Bottom face button (A).",
		  type = "value"
		 },
		 b = {
		  description = "Right face button (B).",
		  type = "value"
		 },
		 back = {
		  description = "Back button.",
		  type = "value"
		 },
		 dpdown = {
		  description = "D-pad down.",
		  type = "value"
		 },
		 dpleft = {
		  description = "D-pad left.",
		  type = "value"
		 },
		 dpright = {
		  description = "D-pad right.",
		  type = "value"
		 },
		 dpup = {
		  description = "D-pad up.",
		  type = "value"
		 },
		 guide = {
		  description = "Guide button.",
		  type = "value"
		 },
		 leftshoulder = {
		  description = "Left bumper.",
		  type = "value"
		 },
		 leftstick = {
		  description = "Left stick click button.",
		  type = "value"
		 },
		 rightshoulder = {
		  description = "Right bumper.",
		  type = "value"
		 },
		 rightstick = {
		  description = "Right stick click button.",
		  type = "value"
		 },
		 start = {
		  description = "Start button.",
		  type = "value"
		 },
		 x = {
		  description = "Left face button (X).",
		  type = "value"
		 },
		 y = {
		  description = "Top face button (Y).",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   Joystick = {
		childs = {
		 getAxis = {
		  args = "(axis: number)",
		  description = "Gets the direction of an axis.",
		  returns = "(direction: number)",
		  type = "function"
		 },
		 getAxisCount = {
		  args = "()",
		  description = "Gets the number of axes on the joystick.",
		  returns = "(axes: number)",
		  type = "function"
		 },
		 getButtonCount = {
		  args = "()",
		  description = "Gets the number of buttons on the joystick.",
		  returns = "(buttons: number)",
		  type = "function"
		 },
		 getGUID = {
		  args = "()",
		  description = "Gets a stable GUID unique to the type of the physical joystick which does not change over time. For example, all Sony Dualshock 3 controllers in OS X have the same GUID. The value is platform-dependent.",
		  returns = "(guid: string)",
		  type = "function"
		 },
		 getGamepadAxis = {
		  args = "(axis: GamepadAxis)",
		  description = "Gets the direction of a virtual gamepad axis. If the Joystick isn't recognized as a gamepad or isn't connected, this function will always return 0.",
		  returns = "(direction: number)",
		  type = "function"
		 },
		 getGamepadMapping = {
		  args = "(axis: GamepadAxis)",
		  description = "Gets the button, axis or hat that a virtual gamepad input is bound to.",
		  returns = "(inputtype: JoystickInputType, inputindex: number, hatdirection: JoystickHat)",
		  type = "function"
		 },
		 getHat = {
		  args = "(hat: number)",
		  description = "Gets the direction of the Joystick's hat.",
		  returns = "(direction: JoystickHat)",
		  type = "function"
		 },
		 getHatCount = {
		  args = "()",
		  description = "Gets the number of hats on the joystick.",
		  returns = "(hats: number)",
		  type = "function"
		 },
		 getID = {
		  args = "()",
		  description = "Gets the joystick's unique identifier. The identifier will remain the same for the life of the game, even when the Joystick is disconnected and reconnected, but it will change when the game is re-launched.",
		  returns = "(id: number, instanceid: number)",
		  type = "function"
		 },
		 getName = {
		  args = "()",
		  description = "Gets the name of the joystick.",
		  returns = "(name: string)",
		  type = "function"
		 },
		 getVibration = {
		  args = "()",
		  description = "Gets the current vibration motor strengths on a Joystick with rumble support.",
		  returns = "(left: number, right: number)",
		  type = "function"
		 },
		 isConnected = {
		  args = "()",
		  description = "Gets whether the Joystick is connected.",
		  returns = "(connected: boolean)",
		  type = "function"
		 },
		 isDown = {
		  args = "(...: number)",
		  description = "Checks if a button on the Joystick is pressed.\n\nLÖVE 0.9.0 had a bug which required the button indices passed to Joystick:isDown to be 0-based instead of 1-based, for example button 1 would be 0 for this function. It was fixed in 0.9.1.",
		  returns = "(anyDown: boolean)",
		  type = "function"
		 },
		 isGamepad = {
		  args = "()",
		  description = "Gets whether the Joystick is recognized as a gamepad. If this is the case, the Joystick's buttons and axes can be used in a standardized manner across different operating systems and joystick models via Joystick:getGamepadAxis and related functions.\n\nLÖVE automatically recognizes most popular controllers with a similar layout to the Xbox 360 controller as gamepads, but you can add more with love.joystick.setGamepadMapping.",
		  returns = "(isgamepad: boolean)",
		  type = "function"
		 },
		 isGamepadDown = {
		  args = "(...: GamepadButton)",
		  description = "Checks if a virtual gamepad button on the Joystick is pressed. If the Joystick is not recognized as a Gamepad or isn't connected, then this function will always return false.",
		  returns = "(anyDown: boolean)",
		  type = "function"
		 },
		 isVibrationSupported = {
		  args = "()",
		  description = "Gets whether the Joystick supports vibration.",
		  returns = "(supported: boolean)",
		  type = "function"
		 },
		 setVibration = {
		  args = "(left: number, right: number)",
		  description = "Sets the vibration motor speeds on a Joystick with rumble support.",
		  returns = "(success: boolean)",
		  type = "function"
		 }
		},
		description = "Represents a physical joystick.",
		inherits = "Object",
		type = "class"
	   },
	   JoystickHat = {
		childs = {
		 c = {
		  description = "Centered",
		  type = "value"
		 },
		 d = {
		  description = "Down",
		  type = "value"
		 },
		 l = {
		  description = "Left",
		  type = "value"
		 },
		 ld = {
		  description = "Left+Down",
		  type = "value"
		 },
		 lu = {
		  description = "Left+Up",
		  type = "value"
		 },
		 r = {
		  description = "Right",
		  type = "value"
		 },
		 rd = {
		  description = "Right+Down",
		  type = "value"
		 },
		 ru = {
		  description = "Right+Up",
		  type = "value"
		 },
		 u = {
		  description = "Up",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   JoystickInputType = {
		childs = {
		 axis = {
		  description = "Analog axis.",
		  type = "value"
		 },
		 button = {
		  description = "Button.",
		  type = "value"
		 },
		 hat = {
		  description = "8-direction hat value.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   getJoysticks = {
		args = "()",
		description = "Gets a list of connected Joysticks.",
		returns = "(joysticks: table)",
		type = "function"
	   },
	   loadGamepadMappings = {
		args = "(filename: string)",
		description = "Loads a gamepad mappings string or file created with love.joystick.saveGamepadMappings.",
		returns = "()",
		type = "function"
	   },
	   saveGamepadMappings = {
		args = "(filename: string)",
		description = "Saves the virtual gamepad mappings of all Joysticks that are recognized as gamepads and have either been recently used or their gamepad bindings have been modified.",
		returns = "(mappings: string)",
		type = "function"
	   },
	   setGamepadMapping = {
		args = "(guid: string, button: GamepadButton, inputtype: JoystickInputType, inputindex: number, hatdirection: JoystickHat)",
		description = "Binds a virtual gamepad input to a button, axis or hat for all Joysticks of a certain type. For example, if this function is used with a GUID returned by a Dualshock 3 controller in OS X, the binding will affect Joystick:getGamepadAxis and Joystick:isGamepadDown for all Dualshock 3 controllers used with the game when run in OS X.\n\nLÖVE includes built-in gamepad bindings for many common controllers. This function lets you change the bindings or add new ones for types of Joysticks which aren't recognized as gamepads by default.\n\nThe virtual gamepad buttons and axes are designed around the Xbox 360 controller layout.",
		returns = "(success: boolean)",
		type = "function"
	   }
	  },
	  description = "Provides an interface to the user's joystick.",
	  type = "class"
	 },
	 joystickadded = {
	  args = "(joystick: Joystick)",
	  description = "Called when a Joystick is connected.\n\nThis callback is also triggered after love.load for every Joystick which was already connected when the game started up.",
	  returns = "()",
	  type = "function"
	 },
	 joystickaxis = {
	  args = "(joystick: Joystick, axis: number, value: number)",
	  description = "Called when a joystick axis moves.",
	  returns = "()",
	  type = "function"
	 },
	 joystickhat = {
	  args = "(joystick: Joystick, hat: number, direction: JoystickHat)",
	  description = "Called when a joystick hat direction changes.",
	  returns = "()",
	  type = "function"
	 },
	 joystickpressed = {
	  args = "(joystick: number, button: number)",
	  description = "Called when a joystick button is pressed.",
	  returns = "()",
	  type = "function"
	 },
	 joystickreleased = {
	  args = "(joystick: number, button: number)",
	  description = "Called when a joystick button is released.",
	  returns = "()",
	  type = "function"
	 },
	 joystickremoved = {
	  args = "(joystick: Joystick)",
	  description = "Called when a Joystick is disconnected.",
	  returns = "()",
	  type = "function"
	 },
	 keyboard = {
	  childs = {
	   KeyConstant = {
		childs = {
		 ["!"] = {
		  description = "Exclamation mark key",
		  type = "value"
		 },
		 ["\""] = {
		  description = "Double quote key",
		  type = "value"
		 },
		 ["#"] = {
		  description = "Hash key",
		  type = "value"
		 },
		 ["$"] = {
		  description = "Dollar key",
		  type = "value"
		 },
		 ["&"] = {
		  description = "Ampersand key",
		  type = "value"
		 },
		 ["'"] = {
		  description = "Single quote key",
		  type = "value"
		 },
		 ["("] = {
		  description = "Left parenthesis key",
		  type = "value"
		 },
		 [")"] = {
		  description = "Right parenthesis key",
		  type = "value"
		 },
		 ["*"] = {
		  description = "Asterisk key",
		  type = "value"
		 },
		 ["+"] = {
		  description = "Plus key",
		  type = "value"
		 },
		 [","] = {
		  description = "Comma key",
		  type = "value"
		 },
		 ["-"] = {
		  description = "Hyphen-minus key",
		  type = "value"
		 },
		 ["."] = {
		  description = "Full stop key",
		  type = "value"
		 },
		 ["/"] = {
		  description = "Slash key",
		  type = "value"
		 },
		 ["0"] = {
		  description = "The zero key",
		  type = "value"
		 },
		 ["1"] = {
		  description = "The one key",
		  type = "value"
		 },
		 ["2"] = {
		  description = "The two key",
		  type = "value"
		 },
		 ["3"] = {
		  description = "The three key",
		  type = "value"
		 },
		 ["4"] = {
		  description = "The four key",
		  type = "value"
		 },
		 ["5"] = {
		  description = "The five key",
		  type = "value"
		 },
		 ["6"] = {
		  description = "The six key",
		  type = "value"
		 },
		 ["7"] = {
		  description = "The seven key",
		  type = "value"
		 },
		 ["8"] = {
		  description = "The eight key",
		  type = "value"
		 },
		 ["9"] = {
		  description = "The nine key",
		  type = "value"
		 },
		 [":"] = {
		  description = "Colon key",
		  type = "value"
		 },
		 [";"] = {
		  description = "Semicolon key",
		  type = "value"
		 },
		 ["<"] = {
		  description = "Less-than key",
		  type = "value"
		 },
		 ["="] = {
		  description = "Equal key",
		  type = "value"
		 },
		 [">"] = {
		  description = "Greater-than key",
		  type = "value"
		 },
		 ["?"] = {
		  description = "Question mark key",
		  type = "value"
		 },
		 ["@"] = {
		  description = "At sign key",
		  type = "value"
		 },
		 ["["] = {
		  description = "Left square bracket key",
		  type = "value"
		 },
		 ["\\"] = {
		  description = "Backslash key",
		  type = "value"
		 },
		 ["]"] = {
		  description = "Right square bracket key",
		  type = "value"
		 },
		 ["^"] = {
		  description = "Caret key",
		  type = "value"
		 },
		 _ = {
		  description = "Underscore key",
		  type = "value"
		 },
		 ["`"] = {
		  description = "Grave accent key",
		  notes = "Also known as the \"Back tick\" key",
		  type = "value"
		 },
		 a = {
		  description = "The A key",
		  type = "value"
		 },
		 appback = {
		  description = "Application back key",
		  type = "value"
		 },
		 appbookmarks = {
		  description = "Application bookmarks key",
		  type = "value"
		 },
		 appforward = {
		  description = "Application forward key",
		  type = "value"
		 },
		 apphome = {
		  description = "Application home key",
		  type = "value"
		 },
		 apprefresh = {
		  description = "Application refresh key",
		  type = "value"
		 },
		 appsearch = {
		  description = "Application search key",
		  type = "value"
		 },
		 b = {
		  description = "The B key",
		  type = "value"
		 },
		 backspace = {
		  description = "Backspace key",
		  type = "value"
		 },
		 ["break"] = {
		  description = "Break key",
		  type = "value"
		 },
		 c = {
		  description = "The C key",
		  type = "value"
		 },
		 calculator = {
		  description = "Calculator key",
		  type = "value"
		 },
		 capslock = {
		  description = "Caps-lock key",
		  notes = "Caps-on is a key press. Caps-off is a key release.",
		  type = "value"
		 },
		 clear = {
		  description = "Clear key",
		  type = "value"
		 },
		 compose = {
		  description = "Compose key",
		  type = "value"
		 },
		 d = {
		  description = "The D key",
		  type = "value"
		 },
		 delete = {
		  description = "Delete key",
		  type = "value"
		 },
		 down = {
		  description = "Down cursor key",
		  type = "value"
		 },
		 e = {
		  description = "The E key",
		  type = "value"
		 },
		 ["end"] = {
		  description = "End key",
		  type = "value"
		 },
		 escape = {
		  description = "Escape key",
		  type = "value"
		 },
		 euro = {
		  description = "Euro (&euro;) key",
		  type = "value"
		 },
		 f = {
		  description = "The F key",
		  type = "value"
		 },
		 f1 = {
		  description = "The 1st function key",
		  type = "value"
		 },
		 f2 = {
		  description = "The 2nd function key",
		  type = "value"
		 },
		 f3 = {
		  description = "The 3rd function key",
		  type = "value"
		 },
		 f4 = {
		  description = "The 4th function key",
		  type = "value"
		 },
		 f5 = {
		  description = "The 5th function key",
		  type = "value"
		 },
		 f6 = {
		  description = "The 6th function key",
		  type = "value"
		 },
		 f7 = {
		  description = "The 7th function key",
		  type = "value"
		 },
		 f8 = {
		  description = "The 8th function key",
		  type = "value"
		 },
		 f9 = {
		  description = "The 9th function key",
		  type = "value"
		 },
		 f10 = {
		  description = "The 10th function key",
		  type = "value"
		 },
		 f11 = {
		  description = "The 11th function key",
		  type = "value"
		 },
		 f12 = {
		  description = "The 12th function key",
		  type = "value"
		 },
		 f13 = {
		  description = "The 13th function key",
		  type = "value"
		 },
		 f14 = {
		  description = "The 14th function key",
		  type = "value"
		 },
		 f15 = {
		  description = "The 15th function key",
		  type = "value"
		 },
		 g = {
		  description = "The G key",
		  type = "value"
		 },
		 h = {
		  description = "The H key",
		  type = "value"
		 },
		 help = {
		  description = "Help key",
		  type = "value"
		 },
		 home = {
		  description = "Home key",
		  type = "value"
		 },
		 i = {
		  description = "The I key",
		  type = "value"
		 },
		 insert = {
		  description = "Insert key",
		  type = "value"
		 },
		 j = {
		  description = "The J key",
		  type = "value"
		 },
		 k = {
		  description = "The K key",
		  type = "value"
		 },
		 ["kp*"] = {
		  description = "The numpad multiplication key",
		  type = "value"
		 },
		 ["kp+"] = {
		  description = "The numpad addition key",
		  type = "value"
		 },
		 ["kp-"] = {
		  description = "The numpad substraction key",
		  type = "value"
		 },
		 ["kp."] = {
		  description = "The numpad decimal point key",
		  type = "value"
		 },
		 ["kp/"] = {
		  description = "The numpad division key",
		  type = "value"
		 },
		 kp0 = {
		  description = "The numpad zero key",
		  type = "value"
		 },
		 kp1 = {
		  description = "The numpad one key",
		  type = "value"
		 },
		 kp2 = {
		  description = "The numpad two key",
		  type = "value"
		 },
		 kp3 = {
		  description = "The numpad three key",
		  type = "value"
		 },
		 kp4 = {
		  description = "The numpad four key",
		  type = "value"
		 },
		 kp5 = {
		  description = "The numpad five key",
		  type = "value"
		 },
		 kp6 = {
		  description = "The numpad six key",
		  type = "value"
		 },
		 kp7 = {
		  description = "The numpad seven key",
		  type = "value"
		 },
		 kp8 = {
		  description = "The numpad eight key",
		  type = "value"
		 },
		 kp9 = {
		  description = "The numpad nine key",
		  type = "value"
		 },
		 ["kp="] = {
		  description = "The numpad equals key",
		  type = "value"
		 },
		 kpenter = {
		  description = "The numpad enter key",
		  type = "value"
		 },
		 l = {
		  description = "The L key",
		  type = "value"
		 },
		 lalt = {
		  description = "Left alt key",
		  type = "value"
		 },
		 lctrl = {
		  description = "Left control key",
		  type = "value"
		 },
		 left = {
		  description = "Left cursor key",
		  type = "value"
		 },
		 lmeta = {
		  description = "Left meta key",
		  type = "value"
		 },
		 lshift = {
		  description = "Left shift key",
		  type = "value"
		 },
		 lsuper = {
		  description = "Left super key",
		  type = "value"
		 },
		 m = {
		  description = "The M key",
		  type = "value"
		 },
		 mail = {
		  description = "Mail key",
		  type = "value"
		 },
		 menu = {
		  description = "Menu key",
		  type = "value"
		 },
		 mode = {
		  description = "Mode key",
		  type = "value"
		 },
		 n = {
		  description = "The N key",
		  type = "value"
		 },
		 numlock = {
		  description = "Num-lock key",
		  type = "value"
		 },
		 o = {
		  description = "The O key",
		  type = "value"
		 },
		 p = {
		  description = "The P key",
		  type = "value"
		 },
		 pagedown = {
		  description = "Page down key",
		  type = "value"
		 },
		 pageup = {
		  description = "Page up key",
		  type = "value"
		 },
		 pause = {
		  description = "Pause key",
		  type = "value"
		 },
		 power = {
		  description = "Power key",
		  type = "value"
		 },
		 print = {
		  description = "Print key",
		  type = "value"
		 },
		 q = {
		  description = "The Q key",
		  type = "value"
		 },
		 r = {
		  description = "The R key",
		  type = "value"
		 },
		 ralt = {
		  description = "Right alt key",
		  type = "value"
		 },
		 rctrl = {
		  description = "Right control key",
		  type = "value"
		 },
		 ["return"] = {
		  description = "Return key",
		  notes = "Also known as the Enter key",
		  type = "value"
		 },
		 right = {
		  description = "Right cursor key",
		  type = "value"
		 },
		 rmeta = {
		  description = "Right meta key",
		  type = "value"
		 },
		 rshift = {
		  description = "Right shift key",
		  type = "value"
		 },
		 rsuper = {
		  description = "Right super key",
		  type = "value"
		 },
		 s = {
		  description = "The S key",
		  type = "value"
		 },
		 scrollock = {
		  description = "Scroll-lock key",
		  type = "value"
		 },
		 space = {
		  description = "Space key",
		  notes = "In version 0.9.2 and earlier this is represented by the actual space character",
		  type = "value"
		 },
		 sysreq = {
		  description = "System request key",
		  type = "value"
		 },
		 t = {
		  description = "The T key",
		  type = "value"
		 },
		 tab = {
		  description = "Tab key",
		  type = "value"
		 },
		 u = {
		  description = "The U key",
		  type = "value"
		 },
		 undo = {
		  description = "Undo key",
		  type = "value"
		 },
		 up = {
		  description = "Up cursor key",
		  type = "value"
		 },
		 v = {
		  description = "The V key",
		  type = "value"
		 },
		 w = {
		  description = "The W key",
		  type = "value"
		 },
		 www = {
		  description = "WWW key",
		  type = "value"
		 },
		 x = {
		  description = "The X key",
		  type = "value"
		 },
		 y = {
		  description = "The Y key",
		  type = "value"
		 },
		 z = {
		  description = "The Z key",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   Scancode = {
		childs = {
		 ["'"] = {
		  description = "The apostrophe key on an American layout.",
		  type = "value"
		 },
		 [","] = {
		  description = "The comma key on an American layout.",
		  type = "value"
		 },
		 ["-"] = {
		  description = "The minus key on an American layout.",
		  type = "value"
		 },
		 ["."] = {
		  description = "The period key on an American layout.",
		  type = "value"
		 },
		 ["/"] = {
		  description = "The forward-slash key on an American layout.",
		  type = "value"
		 },
		 ["0"] = {
		  description = "The '0' key on an American layout.",
		  type = "value"
		 },
		 ["1"] = {
		  description = "The '1' key on an American layout.",
		  type = "value"
		 },
		 ["2"] = {
		  description = "The '2' key on an American layout.",
		  type = "value"
		 },
		 ["3"] = {
		  description = "The '3' key on an American layout.",
		  type = "value"
		 },
		 ["4"] = {
		  description = "The '4' key on an American layout.",
		  type = "value"
		 },
		 ["5"] = {
		  description = "The '5' key on an American layout.",
		  type = "value"
		 },
		 ["6"] = {
		  description = "The '6' key on an American layout.",
		  type = "value"
		 },
		 ["7"] = {
		  description = "The '7' key on an American layout.",
		  type = "value"
		 },
		 ["8"] = {
		  description = "The '8' key on an American layout.",
		  type = "value"
		 },
		 ["9"] = {
		  description = "The '9' key on an American layout.",
		  type = "value"
		 },
		 [";"] = {
		  description = "The semicolon key on an American layout.",
		  type = "value"
		 },
		 ["="] = {
		  description = "The equals key on an American layout.",
		  type = "value"
		 },
		 ["["] = {
		  description = "The left-bracket key on an American layout.",
		  type = "value"
		 },
		 ["\\"] = {
		  description = "The backslash key on an American layout.",
		  type = "value"
		 },
		 ["]"] = {
		  description = "The right-bracket key on an American layout.",
		  type = "value"
		 },
		 ["`"] = {
		  description = "The back-tick / grave key on an American layout.",
		  type = "value"
		 },
		 a = {
		  description = "The 'A' key on an American layout.",
		  type = "value"
		 },
		 acback = {
		  description = "The AC Back key on an American layout.",
		  type = "value"
		 },
		 acbookmarks = {
		  description = "The AC Bookmarks key on an American layout.",
		  type = "value"
		 },
		 acforward = {
		  description = "The AC Forward key on an American layout.",
		  type = "value"
		 },
		 achome = {
		  description = "The AC Home key on an American layout.",
		  type = "value"
		 },
		 acrefresh = {
		  description = "The AC Refresh key on an American layout.",
		  type = "value"
		 },
		 acsearch = {
		  description = "The AC Search key on an American layout.",
		  type = "value"
		 },
		 acstop = {
		  description = "Th AC Stop key on an American layout.",
		  type = "value"
		 },
		 again = {
		  description = "The 'again' key on an American layout.",
		  type = "value"
		 },
		 alterase = {
		  description = "The alt-erase key on an American layout.",
		  type = "value"
		 },
		 app1 = {
		  description = "The 'app1' scancode.",
		  type = "value"
		 },
		 app2 = {
		  description = "The 'app2' scancode.",
		  type = "value"
		 },
		 application = {
		  description = "The application key on an American layout. Windows contextual menu, compose key.",
		  type = "value"
		 },
		 audiomute = {
		  description = "The audio mute key on an American layout.",
		  type = "value"
		 },
		 audionext = {
		  description = "The audio next track key on an American layout.",
		  type = "value"
		 },
		 audioplay = {
		  description = "The audio play key on an American layout.",
		  type = "value"
		 },
		 audioprev = {
		  description = "The audio previous track key on an American layout.",
		  type = "value"
		 },
		 audiostop = {
		  description = "The audio stop key on an American layout.",
		  type = "value"
		 },
		 b = {
		  description = "The 'B' key on an American layout.",
		  type = "value"
		 },
		 backspace = {
		  description = "The 'backspace' key on an American layout.",
		  type = "value"
		 },
		 brightnessdown = {
		  description = "The brightness-down scancode.",
		  type = "value"
		 },
		 brightnessup = {
		  description = "The brightness-up scancode.",
		  type = "value"
		 },
		 c = {
		  description = "The 'C' key on an American layout.",
		  type = "value"
		 },
		 calculator = {
		  description = "The calculator key on an American layout.",
		  type = "value"
		 },
		 cancel = {
		  description = "The 'cancel' key on an American layout.",
		  type = "value"
		 },
		 capslock = {
		  description = "The capslock key on an American layout.",
		  type = "value"
		 },
		 clear = {
		  description = "The 'clear' key on an American layout.",
		  type = "value"
		 },
		 clearagain = {
		  description = "The 'clearagain' key on an American layout.",
		  type = "value"
		 },
		 computer = {
		  description = "The 'computer' key on an American layout.",
		  type = "value"
		 },
		 copy = {
		  description = "The 'copy' key on an American layout.",
		  type = "value"
		 },
		 crsel = {
		  description = "The 'crsel' key on an American layout.",
		  type = "value"
		 },
		 currencysubunit = {
		  description = "The currency sub-unit key on an American layout.",
		  type = "value"
		 },
		 currencyunit = {
		  description = "The currency unit key on an American layout.",
		  type = "value"
		 },
		 cut = {
		  description = "The 'cut' key on an American layout.",
		  type = "value"
		 },
		 d = {
		  description = "The 'D' key on an American layout.",
		  type = "value"
		 },
		 decimalseparator = {
		  description = "The decimal separator key on an American layout.",
		  type = "value"
		 },
		 delete = {
		  description = "The forward-delete key on an American layout.",
		  type = "value"
		 },
		 displayswitch = {
		  description = "The display switch scancode.",
		  type = "value"
		 },
		 down = {
		  description = "The down-arrow key on an American layout.",
		  type = "value"
		 },
		 e = {
		  description = "The 'E' key on an American layout.",
		  type = "value"
		 },
		 eject = {
		  description = "The eject scancode.",
		  type = "value"
		 },
		 ["end"] = {
		  description = "The end key on an American layout.",
		  type = "value"
		 },
		 escape = {
		  description = "The 'escape' key on an American layout.",
		  type = "value"
		 },
		 execute = {
		  description = "The 'execute' key on an American layout.",
		  type = "value"
		 },
		 exsel = {
		  description = "The 'exsel' key on an American layout.",
		  type = "value"
		 },
		 f = {
		  description = "The 'F' key on an American layout.",
		  type = "value"
		 },
		 f1 = {
		  description = "The F1 key on an American layout.",
		  type = "value"
		 },
		 f2 = {
		  description = "The F2 key on an American layout.",
		  type = "value"
		 },
		 f3 = {
		  description = "The F3 key on an American layout.",
		  type = "value"
		 },
		 f4 = {
		  description = "The F4 key on an American layout.",
		  type = "value"
		 },
		 f5 = {
		  description = "The F5 key on an American layout.",
		  type = "value"
		 },
		 f6 = {
		  description = "The F6 key on an American layout.",
		  type = "value"
		 },
		 f7 = {
		  description = "The F7 key on an American layout.",
		  type = "value"
		 },
		 f8 = {
		  description = "The F8 key on an American layout.",
		  type = "value"
		 },
		 f9 = {
		  description = "The F9 key on an American layout.",
		  type = "value"
		 },
		 f10 = {
		  description = "The F10 key on an American layout.",
		  type = "value"
		 },
		 f11 = {
		  description = "The F11 key on an American layout.",
		  type = "value"
		 },
		 f12 = {
		  description = "The F12 key on an American layout.",
		  type = "value"
		 },
		 f13 = {
		  description = "The F13 key on an American layout.",
		  type = "value"
		 },
		 f14 = {
		  description = "The F14 key on an American layout.",
		  type = "value"
		 },
		 f15 = {
		  description = "The F15 key on an American layout.",
		  type = "value"
		 },
		 f16 = {
		  description = "The F16 key on an American layout.",
		  type = "value"
		 },
		 f17 = {
		  description = "The F17 key on an American layout.",
		  type = "value"
		 },
		 f18 = {
		  description = "The F18 key on an American layout.",
		  type = "value"
		 },
		 f19 = {
		  description = "The F19 key on an American layout.",
		  type = "value"
		 },
		 f20 = {
		  description = "The F20 key on an American layout.",
		  type = "value"
		 },
		 f21 = {
		  description = "The F21 key on an American layout.",
		  type = "value"
		 },
		 f22 = {
		  description = "The F22 key on an American layout.",
		  type = "value"
		 },
		 f23 = {
		  description = "The F23 key on an American layout.",
		  type = "value"
		 },
		 f24 = {
		  description = "The F24 key on an American layout.",
		  type = "value"
		 },
		 find = {
		  description = "The 'find' key on an American layout.",
		  type = "value"
		 },
		 g = {
		  description = "The 'G' key on an American layout.",
		  type = "value"
		 },
		 h = {
		  description = "The 'H' key on an American layout.",
		  type = "value"
		 },
		 help = {
		  description = "The 'help' key on an American layout.",
		  type = "value"
		 },
		 home = {
		  description = "The home key on an American layout.",
		  type = "value"
		 },
		 i = {
		  description = "The 'I' key on an American layout.",
		  type = "value"
		 },
		 insert = {
		  description = "The insert key on an American layout.",
		  type = "value"
		 },
		 international1 = {
		  description = "The 1st international key on an American layout. Used on Asian keyboards.",
		  type = "value"
		 },
		 international2 = {
		  description = "The 2nd international key on an American layout.",
		  type = "value"
		 },
		 international3 = {
		  description = "The 3rd international key on an American layout. Yen.",
		  type = "value"
		 },
		 international4 = {
		  description = "The 4th international key on an American layout.",
		  type = "value"
		 },
		 international5 = {
		  description = "The 5th international key on an American layout.",
		  type = "value"
		 },
		 international6 = {
		  description = "The 6th international key on an American layout.",
		  type = "value"
		 },
		 international7 = {
		  description = "The 7th international key on an American layout.",
		  type = "value"
		 },
		 international8 = {
		  description = "The 8th international key on an American layout.",
		  type = "value"
		 },
		 international9 = {
		  description = "The 9th international key on an American layout.",
		  type = "value"
		 },
		 j = {
		  description = "The 'J' key on an American layout.",
		  type = "value"
		 },
		 k = {
		  description = "The 'K' key on an American layout.",
		  type = "value"
		 },
		 kbdillumdown = {
		  description = "The keyboard illumination down scancode.",
		  type = "value"
		 },
		 kbdillumtoggle = {
		  description = "The keyboard illumination toggle scancode.",
		  type = "value"
		 },
		 kbdillumup = {
		  description = "The keyboard illumination up scancode.",
		  type = "value"
		 },
		 ["kp*"] = {
		  description = "The keypad '*' key on an American layout.",
		  type = "value"
		 },
		 ["kp+"] = {
		  description = "The keypad plus key on an American layout.",
		  type = "value"
		 },
		 ["kp-"] = {
		  description = "The keypad minus key on an American layout.",
		  type = "value"
		 },
		 ["kp."] = {
		  description = "The keypad period key on an American layout.",
		  type = "value"
		 },
		 ["kp/"] = {
		  description = "The keypad forward-slash key on an American layout.",
		  type = "value"
		 },
		 kp00 = {
		  description = "The keypad 00 key on an American layout.",
		  type = "value"
		 },
		 kp000 = {
		  description = "The keypad 000 key on an American layout.",
		  type = "value"
		 },
		 kp0 = {
		  description = "The keypad '0' key on an American layout.",
		  type = "value"
		 },
		 kp1 = {
		  description = "The keypad '1' key on an American layout.",
		  type = "value"
		 },
		 kp2 = {
		  description = "The keypad '2' key on an American layout.",
		  type = "value"
		 },
		 kp3 = {
		  description = "The keypad '3' key on an American layout.",
		  type = "value"
		 },
		 kp4 = {
		  description = "The keypad '4' key on an American layout.",
		  type = "value"
		 },
		 kp5 = {
		  description = "The keypad '5' key on an American layout.",
		  type = "value"
		 },
		 kp6 = {
		  description = "The keypad '6' key on an American layout.",
		  type = "value"
		 },
		 kp7 = {
		  description = "The keypad '7' key on an American layout.",
		  type = "value"
		 },
		 kp8 = {
		  description = "The keypad '8' key on an American layout.",
		  type = "value"
		 },
		 kp9 = {
		  description = "The keypad '9' key on an American layout.",
		  type = "value"
		 },
		 ["kp="] = {
		  description = "The keypad equals key on an American layout.",
		  type = "value"
		 },
		 kpenter = {
		  description = "The keypad enter key on an American layout.",
		  type = "value"
		 },
		 l = {
		  description = "The 'L' key on an American layout.",
		  type = "value"
		 },
		 lalt = {
		  description = "The left alt / option key on an American layout.",
		  type = "value"
		 },
		 lang1 = {
		  description = "Hangul/English toggle scancode.",
		  type = "value"
		 },
		 lang2 = {
		  description = "Hanja conversion scancode.",
		  type = "value"
		 },
		 lang3 = {
		  description = "Katakana scancode.",
		  type = "value"
		 },
		 lang4 = {
		  description = "Hiragana scancode.",
		  type = "value"
		 },
		 lang5 = {
		  description = "Zenkaku/Hankaku scancode.",
		  type = "value"
		 },
		 lctrl = {
		  description = "The left control key on an American layout.",
		  type = "value"
		 },
		 left = {
		  description = "The left-arrow key on an American layout.",
		  type = "value"
		 },
		 lgui = {
		  description = "The left GUI (command / windows / super) key on an American layout.",
		  type = "value"
		 },
		 lshift = {
		  description = "The left shift key on an American layout.",
		  type = "value"
		 },
		 m = {
		  description = "The 'M' key on an American layout.",
		  type = "value"
		 },
		 mail = {
		  description = "The Mail key on an American layout.",
		  type = "value"
		 },
		 mediaselect = {
		  description = "The media select key on an American layout.",
		  type = "value"
		 },
		 menu = {
		  description = "The 'menu' key on an American layout.",
		  type = "value"
		 },
		 mute = {
		  description = "The mute key on an American layout.",
		  type = "value"
		 },
		 n = {
		  description = "The 'N' key on an American layout.",
		  type = "value"
		 },
		 ["nonus#"] = {
		  description = "The non-U.S. hash scancode.",
		  type = "value"
		 },
		 nonusbackslash = {
		  description = "The non-U.S. backslash scancode.",
		  type = "value"
		 },
		 numlock = {
		  description = "The numlock / clear key on an American layout.",
		  type = "value"
		 },
		 o = {
		  description = "The 'O' key on an American layout.",
		  type = "value"
		 },
		 oper = {
		  description = "The 'oper' key on an American layout.",
		  type = "value"
		 },
		 out = {
		  description = "The 'out' key on an American layout.",
		  type = "value"
		 },
		 p = {
		  description = "The 'P' key on an American layout.",
		  type = "value"
		 },
		 pagedown = {
		  description = "The page-down key on an American layout.",
		  type = "value"
		 },
		 pageup = {
		  description = "The page-up key on an American layout.",
		  type = "value"
		 },
		 paste = {
		  description = "The 'paste' key on an American layout.",
		  type = "value"
		 },
		 pause = {
		  description = "The pause key on an American layout.",
		  type = "value"
		 },
		 power = {
		  description = "The system power scancode.",
		  type = "value"
		 },
		 printscreen = {
		  description = "The printscreen key on an American layout.",
		  type = "value"
		 },
		 prior = {
		  description = "The 'prior' key on an American layout.",
		  type = "value"
		 },
		 q = {
		  description = "The 'Q' key on an American layout.",
		  type = "value"
		 },
		 r = {
		  description = "The 'R' key on an American layout.",
		  type = "value"
		 },
		 ralt = {
		  description = "The right alt / option key on an American layout.",
		  type = "value"
		 },
		 rctrl = {
		  description = "The right control key on an American layout.",
		  type = "value"
		 },
		 ["return"] = {
		  description = "The 'return' / 'enter' key on an American layout.",
		  type = "value"
		 },
		 return2 = {
		  description = "The 'return2' key on an American layout.",
		  type = "value"
		 },
		 rgui = {
		  description = "The right GUI (command / windows / super) key on an American layout.",
		  type = "value"
		 },
		 right = {
		  description = "The right-arrow key on an American layout.",
		  type = "value"
		 },
		 rshift = {
		  description = "The right shift key on an American layout.",
		  type = "value"
		 },
		 s = {
		  description = "The 'S' key on an American layout.",
		  type = "value"
		 },
		 scrolllock = {
		  description = "The scroll-lock key on an American layout.",
		  type = "value"
		 },
		 select = {
		  description = "The 'select' key on an American layout.",
		  type = "value"
		 },
		 separator = {
		  description = "The 'separator' key on an American layout.",
		  type = "value"
		 },
		 sleep = {
		  description = "The system sleep scancode.",
		  type = "value"
		 },
		 space = {
		  description = "The spacebar on an American layout.",
		  type = "value"
		 },
		 stop = {
		  description = "The 'stop' key on an American layout.",
		  type = "value"
		 },
		 sysreq = {
		  description = "The sysreq key on an American layout.",
		  type = "value"
		 },
		 t = {
		  description = "The 'T' key on an American layout.",
		  type = "value"
		 },
		 tab = {
		  description = "The 'tab' key on an American layout.",
		  type = "value"
		 },
		 thsousandsseparator = {
		  description = "The thousands-separator key on an American layout.",
		  type = "value"
		 },
		 u = {
		  description = "The 'U' key on an American layout.",
		  type = "value"
		 },
		 undo = {
		  description = "The 'undo' key on an American layout.",
		  type = "value"
		 },
		 unknown = {
		  description = "An unknown key.",
		  type = "value"
		 },
		 up = {
		  description = "The up-arrow key on an American layout.",
		  type = "value"
		 },
		 v = {
		  description = "The 'V' key on an American layout.",
		  type = "value"
		 },
		 volumedown = {
		  description = "The volume down key on an American layout.",
		  type = "value"
		 },
		 volumeup = {
		  description = "The volume up key on an American layout.",
		  type = "value"
		 },
		 w = {
		  description = "The 'W' key on an American layout.",
		  type = "value"
		 },
		 www = {
		  description = "The 'WWW' key on an American layout.",
		  type = "value"
		 },
		 x = {
		  description = "The 'X' key on an American layout.",
		  type = "value"
		 },
		 y = {
		  description = "The 'Y' key on an American layout.",
		  type = "value"
		 },
		 z = {
		  description = "The 'Z' key on an American layout.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   getScancodeFromKey = {
		args = "(key: KeyConstant)",
		description = "Gets the hardware scancode corresponding to the given key.\n\nUnlike key constants, Scancodes are keyboard layout-independent. For example the scancode \"w\" will be generated if the key in the same place as the \"w\" key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.\n\nScancodes are useful for creating default controls that have the same physical locations on on all systems.",
		returns = "(scancode: Scancode)",
		type = "function"
	   },
	   hasKeyRepeat = {
		args = "()",
		description = "Gets whether key repeat is enabled.",
		returns = "(enabled: boolean)",
		type = "function"
	   },
	   hasTextInput = {
		args = "()",
		description = "Gets whether text input events are enabled.",
		returns = "(enabled: boolean)",
		type = "function"
	   },
	   isDown = {
		args = "(key: KeyConstant)",
		description = "Checks whether a certain key is down. Not to be confused with love.keypressed or love.keyreleased.",
		returns = "(down: boolean)",
		type = "function"
	   },
	   isScancodeDown = {
		args = "(scancode: Scancode, ...: Scancode)",
		description = "Checks whether the specified Scancodes are pressed. Not to be confused with love.keypressed or love.keyreleased.\n\nUnlike regular KeyConstants, Scancodes are keyboard layout-independent. The scancode \"w\" is used if the key in the same place as the \"w\" key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.",
		returns = "(down: boolean)",
		type = "function"
	   },
	   setKeyRepeat = {
		args = "(enable: boolean)",
		description = "Enables or disables key repeat. It is disabled by default.\n\nThe interval between repeats depends on the user's system settings.",
		returns = "()",
		type = "function"
	   },
	   setTextInput = {
		args = "(enable: boolean)",
		description = "Enables or disables text input events. It is enabled by default on Windows, Mac, and Linux, and disabled by default on iOS and Android.",
		returns = "()",
		type = "function"
	   }
	  },
	  description = "Provides an interface to the user's keyboard.",
	  type = "lib"
	 },
	 keypressed = {
	  args = "(key: KeyConstant, scancode: Scancode, isrepeat: boolean)",
	  description = "Callback function triggered when a key is pressed.",
	  returns = "()",
	  type = "function"
	 },
	 keyreleased = {
	  args = "(key: KeyConstant, scancode: Scancode)",
	  description = "Callback function triggered when a keyboard key is released.",
	  returns = "()",
	  type = "function"
	 },
	 load = {
	  args = "(arg: table)",
	  description = "This function is called exactly once at the beginning of the game.",
	  returns = "()",
	  type = "function"
	 },
	 lowmemory = {
	  args = "()",
	  description = "Callback function triggered when the system is running out of memory on mobile devices.\n\n Mobile operating systems may forcefully kill the game if it uses too much memory, so any non-critical resource should be removed if possible (by setting all variables referencing the resources to nil, and calling collectgarbage()), when this event is triggered. Sounds and images in particular tend to use the most memory.",
	  returns = "()",
	  type = "function"
	 },
	 math = {
	  childs = {
	   BezierCurve = {
		childs = {
		 getControlPoint = {
		  args = "(i: number)",
		  description = "Get coordinates of the i-th control point. Indices start with 1.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getControlPointCount = {
		  args = "()",
		  description = "Get the number of control points in the Bézier curve.",
		  returns = "(count: number)",
		  type = "function"
		 },
		 getDegree = {
		  args = "()",
		  description = "Get degree of the Bézier curve. The degree is equal to number-of-control-points - 1.",
		  returns = "(degree: number)",
		  type = "function"
		 },
		 getDerivative = {
		  args = "()",
		  description = "Get the derivative of the Bézier curve.\n\nThis function can be used to rotate sprites moving along a curve in the direction of the movement and compute the direction perpendicular to the curve at some parameter t.",
		  returns = "(derivative: BezierCurve)",
		  type = "function"
		 },
		 getSegment = {
		  args = "(startpoint: number, endpoint: number)",
		  description = "Gets a BezierCurve that corresponds to the specified segment of this BezierCurve.",
		  returns = "(curve: BezierCurve)",
		  type = "function"
		 },
		 insertControlPoint = {
		  args = "(x: number, y: number, i: number)",
		  description = "Insert control point as the new i-th control point. Existing control points from i onwards are pushed back by 1. Indices start with 1. Negative indices wrap around: -1 is the last control point, -2 the one before the last, etc.",
		  returns = "()",
		  type = "function"
		 },
		 removeControlPoint = {
		  args = "(index: number)",
		  description = "Removes the specified control point.",
		  returns = "()",
		  type = "function"
		 },
		 render = {
		  args = "(depth: number)",
		  description = "Get a list of coordinates to be used with love.graphics.line.\n\nThis function samples the Bézier curve using recursive subdivision. You can control the recursion depth using the depth parameter.\n\nIf you are just interested to know the position on the curve given a parameter, use BezierCurve:evaluate.",
		  returns = "(coordinates: table)",
		  type = "function"
		 },
		 renderSegment = {
		  args = "(startpoint: number, endpoint: number, depth: number)",
		  description = "Get a list of coordinates on a specific part of the curve, to be used with love.graphics.line.\n\nThis function samples the Bézier curve using recursive subdivision. You can control the recursion depth using the depth parameter.\n\nIf you are just need to know the position on the curve given a parameter, use BezierCurve:evaluate.",
		  returns = "(coordinates: table)",
		  type = "function"
		 },
		 rotate = {
		  args = "(angle: number, ox: number, oy: number)",
		  description = "Rotate the Bézier curve by an angle.",
		  returns = "()",
		  type = "function"
		 },
		 scale = {
		  args = "(s: number, ox: number, oy: number)",
		  description = "Scale the Bézier curve by a factor.",
		  returns = "()",
		  type = "function"
		 },
		 setControlPoint = {
		  args = "(i: number, ox: number, oy: number)",
		  description = "Set coordinates of the i-th control point. Indices start with 1.",
		  returns = "()",
		  type = "function"
		 },
		 translate = {
		  args = "(dx: number, dy: number)",
		  description = "Move the Bézier curve by an offset.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A Bézier curve object that can evaluate and render Bézier curves of arbitrary degree.",
		inherits = "Object",
		type = "class"
	   },
	   CompressedData = {
		childs = {
		 getFormat = {
		  args = "()",
		  description = "Gets the compression format of the CompressedData.",
		  returns = "(format: CompressedDataFormat)",
		  type = "function"
		 }
		},
		description = "Represents byte data compressed using a specific algorithm.\n\nlove.math.decompress can be used to de-compress the data.",
		inherits = "Data",
		type = "class"
	   },
	   CompressedDataFormat = {
		childs = {
		 gzip = {
		  description = "The gzip format is DEFLATE-compressed data with a slightly larger header than zlib. Since it uses DEFLATE it has the same compression characteristics as the zlib format.",
		  type = "value"
		 },
		 lz4 = {
		  description = "The LZ4 compression format. Compresses and decompresses very quickly, but the compression ratio is not the best. LZ4-HC is used when compression level 9 is specified.",
		  type = "value"
		 },
		 zlib = {
		  description = "The zlib format is DEFLATE-compressed data with a small bit of header data. Compresses relatively slowly and decompresses moderately quickly, and has a decent compression ratio.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   MatrixLayout = {
		childs = {
		 column = {
		  description = "The matrix is column-major.",
		  type = "value"
		 },
		 row = {
		  description = "The matrix is row-major.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   RandomGenerator = {
		childs = {
		 getState = {
		  args = "()",
		  description = "Gets the current state of the random number generator. This returns an opaque implementation-dependent string which is only useful for later use with RandomGenerator:setState.\n\nThis is different from RandomGenerator:getSeed in that getState gets the RandomGenerator's current state, whereas getSeed gets the previously set seed number.\n\nThe value of the state string does not depend on the current operating system.",
		  returns = "(state: string)",
		  type = "function"
		 },
		 random = {
		  args = "(max: number)",
		  description = "Generates a pseudo-random number in a platform independent manner.",
		  returns = "(number: number)",
		  type = "function"
		 },
		 randomNormal = {
		  args = "(stddev: number, mean: number)",
		  description = "Get a normally distributed pseudo random number.",
		  returns = "(number: number)",
		  type = "function"
		 },
		 setSeed = {
		  args = "(seed: number)",
		  description = "Sets the seed of the random number generator using the specified integer number.",
		  returns = "()",
		  type = "function"
		 },
		 setState = {
		  args = "(state: string)",
		  description = "Sets the current state of the random number generator. The value used as an argument for this function is an opaque implementation-dependent string and should only originate from a previous call to RandomGenerator:getState.\n\nThis is different from RandomGenerator:setSeed in that setState directly sets the RandomGenerator's current implementation-dependent state, whereas setSeed gives it a new seed value.\n\nThe effect of the state string does not depend on the current operating system.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A random number generation object which has its own random state.",
		inherits = "Object",
		type = "class"
	   },
	   Transform = {
		childs = {
		 clone = {
		  args = "()",
		  description = "Creates a new copy of this Transform.",
		  returns = "(clone: Transform)",
		  type = "function"
		 },
		 getMatrix = {
		  args = "()",
		  description = "Gets the internal 4x4 transformation matrix stored by this Transform. The matrix is returned in row-major order.",
		  returns = "(e1_1: number, e1_2: number, ...: number, e4_4: number)",
		  type = "function"
		 },
		 inverse = {
		  args = "()",
		  description = "Creates a new Transform containing the inverse of this Transform.",
		  returns = "(inverse: Transform)",
		  type = "function"
		 },
		 inverseTransformPoint = {
		  args = "(localX: number, localY: number)",
		  description = "Applies the reverse of the Transform object's transformation to the given 2D position.\n\nThis effectively converts the given position from the local coordinate space of the Transform into global coordinates.\n\nOne use of this method can be to convert a screen-space mouse position into global world coordinates, if the given Transform has transformations applied that are used for a camera system in-game.",
		  returns = "(globalX: number, globalY: number)",
		  type = "function"
		 },
		 reset = {
		  args = "()",
		  description = "Resets the Transform to an identity state. All previously applied transformations are erased.",
		  returns = "(transform: Transform)",
		  type = "function"
		 },
		 rotate = {
		  args = "(angle: number)",
		  description = "Applies a rotation to the Transform's coordinate system. This method does not reset any previously applied transformations.",
		  returns = "(transform: Transform)",
		  type = "function"
		 },
		 scale = {
		  args = "(sx: number, sy: number)",
		  description = "Scales the Transform's coordinate system. This method does not reset any previously applied transformations.",
		  returns = "(transform: Transform)",
		  type = "function"
		 },
		 setMatrix = {
		  args = "(e1_1: number, e1_2: number, ...: number, e4_4: number)",
		  description = "Directly sets the Transform's internal 4x4 transformation matrix.",
		  returns = "(transform: Transform)",
		  type = "function"
		 },
		 setTransformation = {
		  args = "(x: number, y: number, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)",
		  description = "Resets the Transform to the specified transformation parameters.",
		  returns = "(transform: Transform)",
		  type = "function"
		 },
		 shear = {
		  args = "(kx: number, ky: number)",
		  description = "Applies a shear factor (skew) to the Transform's coordinate system. This method does not reset any previously applied transformations.",
		  returns = "(transform: Transform)",
		  type = "function"
		 },
		 transformPoint = {
		  args = "(globalX: number, globalY: number)",
		  description = "Applies the Transform object's transformation to the given 2D position.\n\nThis effectively converts the given position from global coordinates into the local coordinate space of the Transform.",
		  returns = "(localX: number, localY: number)",
		  type = "function"
		 },
		 translate = {
		  args = "(dx: number, dy: number)",
		  description = "Applies a translation to the Transform's coordinate system. This method does not reset any previously applied transformations.",
		  returns = "(transform: Transform)",
		  type = "function"
		 }
		},
		description = "Object containing a coordinate system transformation.\n\nThe love.graphics module has several functions and function variants which accept Transform objects.",
		inherits = "Object",
		notes = "Transform objects have a custom * (multiplication) operator. result = tA * tB is equivalent to result = tA:clone():apply(tB). It maps to the matrix multiplication operation that Transform:apply performs.\n\nThe * operator creates a new Transform object, so it is not recommended to use it heavily in per-frame code.",
		type = "class"
	   },
	   decompress = {
		args = "(compressedData: CompressedData)",
		description = "Decompresses a CompressedData or previously compressed string or Data object.",
		returns = "(rawstring: string)",
		type = "function"
	   },
	   gammaToLinear = {
		args = "(r: number, g: number, b: number)",
		description = "Converts a color from gamma-space (sRGB) to linear-space (RGB). This is useful when doing gamma-correct rendering and you need to do math in linear RGB in the few cases where LÖVE doesn't handle conversions automatically.",
		returns = "(lr: number, lg: number, lb: number)",
		type = "function"
	   },
	   getRandomSeed = {
		args = "()",
		description = "Gets the seed of the random number generator.\n\nThe state is split into two numbers due to Lua's use of doubles for all number values - doubles can't accurately represent integer values above 2^53.",
		returns = "(low: number, high: number)",
		type = "function"
	   },
	   getRandomState = {
		args = "()",
		description = "Gets the current state of the random number generator. This returns an opaque implementation-dependent string which is only useful for later use with RandomGenerator:setState.\n\nThis is different from RandomGenerator:getSeed in that getState gets the RandomGenerator's current state, whereas getSeed gets the previously set seed number.\n\nThe value of the state string does not depend on the current operating system.",
		returns = "(state: string)",
		type = "function"
	   },
	   isConvex = {
		args = "(vertices: table)",
		description = "Checks whether a polygon is convex.\n\nPolygonShapes in love.physics, some forms of Mesh, and polygons drawn with love.graphics.polygon must be simple convex polygons.",
		returns = "(convex: boolean)",
		type = "function"
	   },
	   linearToGamma = {
		args = "(lr: number, lg: number, lb: number)",
		description = "Converts a color from linear-space (RGB) to gamma-space (sRGB). This is useful when storing linear RGB color values in an image, because the linear RGB color space has less precision than sRGB for dark colors, which can result in noticeable color banding when drawing.\n\nIn general, colors chosen based on what they look like on-screen are already in gamma-space and should not be double-converted. Colors calculated using math are often in the linear RGB space.",
		returns = "(cr: number, cg: number, cb: number)",
		type = "function"
	   },
	   newBezierCurve = {
		args = "(vertices: table)",
		description = "Creates a new BezierCurve object.\n\nThe number of vertices in the control polygon determines the degree of the curve, e.g. three vertices define a quadratic (degree 2) Bézier curve, four vertices define a cubic (degree 3) Bézier curve, etc.",
		returns = "(curve: BezierCurve)",
		type = "function"
	   },
	   newRandomGenerator = {
		args = "(seed: number)",
		description = "Creates a new RandomGenerator object which is completely independent of other RandomGenerator objects and random functions.",
		returns = "(rng: RandomGenerator)",
		type = "function"
	   },
	   newTransform = {
		args = "(x: number, y: number, angle: number, sx: number, sy: number, ox: number, oy: number, kx: number, ky: number)",
		description = "Creates a new Transform object.",
		returns = "(transform: Transform)",
		type = "function"
	   },
	   noise = {
		args = "(x: number)",
		description = "Generates a Simplex or Perlin noise value in 1-4 dimensions. The return value will always be the same, given the same arguments.\n\nSimplex noise is closely related to Perlin noise. It is widely used for procedural content generation.\n\nThere are many webpages which discuss Perlin and Simplex noise in detail.",
		returns = "(value: number)",
		type = "function"
	   },
	   random = {
		args = "(max: number)",
		description = "Generates a pseudo-random number in a platform independent manner.",
		returns = "(number: number)",
		type = "function"
	   },
	   randomNormal = {
		args = "(stddev: number, mean: number)",
		description = "Get a normally distributed pseudo random number.",
		returns = "(number: number)",
		type = "function"
	   },
	   setRandomSeed = {
		args = "(seed: number)",
		description = "Sets the seed of the random number generator using the specified integer number.",
		returns = "()",
		type = "function"
	   },
	   setRandomState = {
		args = "(state: string)",
		description = "Gets the current state of the random number generator. This returns an opaque implementation-dependent string which is only useful for later use with RandomGenerator:setState.\n\nThis is different from RandomGenerator:getSeed in that getState gets the RandomGenerator's current state, whereas getSeed gets the previously set seed number.\n\nThe value of the state string does not depend on the current operating system.",
		returns = "()",
		type = "function"
	   },
	   triangulate = {
		args = "(polygon: table)",
		description = "Triangulate a simple polygon.",
		returns = "(triangles: table)",
		type = "function"
	   }
	  },
	  description = "Provides system-independent mathematical functions.",
	  type = "class"
	 },
	 mouse = {
	  childs = {
	   Cursor = {
		childs = {
		 getType = {
		  args = "()",
		  description = "Gets the type of the Cursor.",
		  returns = "(cursortype: CursorType)",
		  type = "function"
		 }
		},
		description = "Represents a hardware cursor.",
		inherits = "Object",
		type = "class"
	   },
	   CursorType = {
		childs = {
		 arrow = {
		  description = "An arrow pointer.",
		  type = "value"
		 },
		 crosshair = {
		  description = "Crosshair symbol.",
		  type = "value"
		 },
		 hand = {
		  description = "Hand symbol.",
		  type = "value"
		 },
		 ibeam = {
		  description = "An I-beam, normally used when mousing over editable or selectable text.",
		  type = "value"
		 },
		 image = {
		  description = "The cursor is using a custom image.",
		  type = "value"
		 },
		 no = {
		  description = "Slashed circle or crossbones.",
		  type = "value"
		 },
		 sizeall = {
		  description = "Four-pointed arrow pointing up, down, left, and right.",
		  type = "value"
		 },
		 sizenesw = {
		  description = "Double arrow pointing to the top-right and bottom-left.",
		  type = "value"
		 },
		 sizens = {
		  description = "Double arrow pointing up and down.",
		  type = "value"
		 },
		 sizenwse = {
		  description = "Double arrow pointing to the top-left and bottom-right.",
		  type = "value"
		 },
		 sizewe = {
		  description = "Double arrow pointing left and right.",
		  type = "value"
		 },
		 wait = {
		  description = "Wait graphic.",
		  type = "value"
		 },
		 waitarrow = {
		  description = "Small wait cursor with an arrow pointer.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   getPosition = {
		args = "()",
		description = "Returns the current position of the mouse.",
		returns = "(x: number, y: number)",
		type = "function"
	   },
	   getRelativeMode = {
		args = "()",
		description = "Gets whether relative mode is enabled for the mouse.\n\nIf relative mode is enabled, the cursor is hidden and doesn't move when the mouse does, but relative mouse motion events are still generated via love.mousemoved. This lets the mouse move in any direction indefinitely without the cursor getting stuck at the edges of the screen.\n\nThe reported position of the mouse is not updated while relative mode is enabled, even when relative mouse motion events are generated.",
		returns = "(enabled: boolean)",
		type = "function"
	   },
	   getSystemCursor = {
		args = "(ctype: CursorType)",
		description = "Gets a Cursor object representing a system-native hardware cursor.\n\n Hardware cursors are framerate-independent and work the same way as normal operating system cursors. Unlike drawing an image at the mouse's current coordinates, hardware cursors never have visible lag between when the mouse is moved and when the cursor position updates, even at low framerates.",
		returns = "(cursor: Cursor)",
		type = "function"
	   },
	   getX = {
		args = "()",
		description = "Returns the current x position of the mouse.",
		returns = "(x: number)",
		type = "function"
	   },
	   getY = {
		args = "()",
		description = "Returns the current y position of the mouse.",
		returns = "(y: number)",
		type = "function"
	   },
	   hasCursor = {
		args = "()",
		description = "Gets whether cursor functionality is supported.\n\nIf it isn't supported, calling love.mouse.newCursor and love.mouse.getSystemCursor will cause an error. Mobile devices do not support cursors.",
		returns = "(hascursor: boolean)",
		type = "function"
	   },
	   isCursorSupported = {
		args = "()",
		description = "Gets whether cursor functionality is supported.\n\nIf it isn't supported, calling love.mouse.newCursor and love.mouse.getSystemCursor will cause an error. Mobile devices do not support cursors.",
		returns = "(supported: boolean)",
		type = "function"
	   },
	   isDown = {
		args = "(button: number, ...: number)",
		description = "Checks whether a certain mouse button is down. This function does not detect mousewheel scrolling; you must use the love.wheelmoved (or love.mousepressed in version 0.9.2 and older) callback for that.",
		returns = "(down: boolean)",
		type = "function"
	   },
	   isGrabbed = {
		args = "()",
		description = "Checks if the mouse is grabbed.",
		returns = "(grabbed: boolean)",
		type = "function"
	   },
	   isVisible = {
		args = "()",
		description = "Checks if the cursor is visible.",
		returns = "(visible: boolean)",
		type = "function"
	   },
	   newCursor = {
		args = "(imageData: ImageData, hotx: number, hoty: number)",
		description = "Creates a new hardware Cursor object from an image file or ImageData.\n\nHardware cursors are framerate-independent and work the same way as normal operating system cursors. Unlike drawing an image at the mouse's current coordinates, hardware cursors never have visible lag between when the mouse is moved and when the cursor position updates, even at low framerates.\n\nThe hot spot is the point the operating system uses to determine what was clicked and at what position the mouse cursor is. For example, the normal arrow pointer normally has its hot spot at the top left of the image, but a crosshair cursor might have it in the middle.",
		returns = "(cursor: Cursor)",
		type = "function"
	   },
	   setCursor = {
		args = "(cursor: Cursor)",
		description = "Sets the current mouse cursor.\n\nResets the current mouse cursor to the default when called without arguments.",
		returns = "()",
		type = "function"
	   },
	   setGrabbed = {
		args = "(grab: boolean)",
		description = "Grabs the mouse and confines it to the window.",
		returns = "()",
		type = "function"
	   },
	   setPosition = {
		args = "(x: number, y: number)",
		description = "Sets the current position of the mouse. Non-integer values are floored.",
		returns = "()",
		type = "function"
	   },
	   setRelativeMode = {
		args = "(enable: boolean)",
		description = "Sets whether relative mode is enabled for the mouse.\n\nWhen relative mode is enabled, the cursor is hidden and doesn't move when the mouse does, but relative mouse motion events are still generated via love.mousemoved. This lets the mouse move in any direction indefinitely without the cursor getting stuck at the edges of the screen.\n\nThe reported position of the mouse is not updated while relative mode is enabled, even when relative mouse motion events are generated.",
		returns = "()",
		type = "function"
	   },
	   setVisible = {
		args = "(visible: boolean)",
		description = "Sets the visibility of the cursor.",
		returns = "()",
		type = "function"
	   },
	   setX = {
		args = "(x: number)",
		description = "Sets the current X position of the mouse. Non-integer values are floored.",
		returns = "()",
		type = "function"
	   },
	   setY = {
		args = "(y: number)",
		description = "Sets the current Y position of the mouse. Non-integer values are floored.",
		returns = "()",
		type = "function"
	   }
	  },
	  description = "Provides an interface to the user's mouse.",
	  type = "class"
	 },
	 mousefocus = {
	  args = "(focus: boolean)",
	  description = "Callback function triggered when window receives or loses mouse focus.",
	  returns = "()",
	  type = "function"
	 },
	 mousemoved = {
	  args = "(x: number, y: number, dx: number, dy: number, istouch: boolean)",
	  description = "Callback function triggered when the mouse is moved.",
	  returns = "()",
	  type = "function"
	 },
	 mousepressed = {
	  args = "(x: number, y: number, button: number, isTouch: boolean, presses: number)",
	  description = "Callback function triggered when a mouse button is pressed.",
	  returns = "()",
	  type = "function"
	 },
	 mousereleased = {
	  args = "(x: number, y: number, button: number, isTouch: boolean, presses: number)",
	  description = "Callback function triggered when a mouse button is released.",
	  returns = "()",
	  type = "function"
	 },
	 physics = {
	  childs = {
	   Body = {
		childs = {
		 applyForce = {
		  args = "(fx: number, fy: number)",
		  description = "Apply force to a Body.\n\nA force pushes a body in a direction. A body with with a larger mass will react less. The reaction also depends on how long a force is applied: since the force acts continuously over the entire timestep, a short timestep will only push the body for a short time. Thus forces are best used for many timesteps to give a continuous push to a body (like gravity). For a single push that is independent of timestep, it is better to use Body:applyLinearImpulse.\n\nIf the position to apply the force is not given, it will act on the center of mass of the body. The part of the force not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia).\n\nNote that the force components and position must be given in world coordinates.",
		  returns = "()",
		  type = "function"
		 },
		 applyLinearImpulse = {
		  args = "(ix: number, iy: number)",
		  description = "Applies an impulse to a body. This makes a single, instantaneous addition to the body momentum.\n\nAn impulse pushes a body in a direction. A body with with a larger mass will react less. The reaction does not depend on the timestep, and is equivalent to applying a force continuously for 1 second. Impulses are best used to give a single push to a body. For a continuous push to a body it is better to use Body:applyForce.\n\nIf the position to apply the impulse is not given, it will act on the center of mass of the body. The part of the impulse not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia).\n\nNote that the impulse components and position must be given in world coordinates.",
		  returns = "()",
		  type = "function"
		 },
		 applyTorque = {
		  args = "(torque: number)",
		  description = "Apply torque to a body.\n\nTorque is like a force that will change the angular velocity (spin) of a body. The effect will depend on the rotational inertia a body has.",
		  returns = "()",
		  type = "function"
		 },
		 destroy = {
		  args = "()",
		  description = "Explicitly destroys the Body. When you don't have time to wait for garbage collection, this function may be used to free the object immediately, but note that an error will occur if you attempt to use the object after calling this function.",
		  returns = "()",
		  type = "function"
		 },
		 getAngle = {
		  args = "()",
		  description = "Get the angle of the body.\n\nThe angle is measured in radians. If you need to transform it to degrees, use math.deg.\n\nA value of 0 radians will mean \"looking to the right\". Although radians increase counter-clockwise, the y-axis points down so it becomes clockwise from our point of view.",
		  returns = "(angle: number)",
		  type = "function"
		 },
		 getAngularDamping = {
		  args = "()",
		  description = "Gets the Angular damping of the Body\n\nThe angular damping is the rate of decrease of the angular velocity over time: A spinning body with no damping and no external forces will continue spinning indefinitely. A spinning body with damping will gradually stop spinning.\n\nDamping is not the same as friction - they can be modelled together. However, only damping is provided by Box2D (and LÖVE).\n\nDamping parameters should be between 0 and infinity, with 0 meaning no damping, and infinity meaning full damping. Normally you will use a damping value between 0 and 0.1.",
		  returns = "(damping: number)",
		  type = "function"
		 },
		 getAngularVelocity = {
		  args = "()",
		  description = "Get the angular velocity of the Body.\n\nThe angular velocity is the rate of change of angle over time.\n\nIt is changed in World:update by applying torques, off centre forces/impulses, and angular damping. It can be set directly with Body:setAngularVelocity.\n\nIf you need the rate of change of position over time, use Body:getLinearVelocity.",
		  returns = "(w: number)",
		  type = "function"
		 },
		 getContactList = {
		  args = "()",
		  description = "Gets a list of all Contacts attached to the Body.",
		  returns = "(contacts: table)",
		  type = "function"
		 },
		 getFixtureList = {
		  args = "()",
		  description = "Returns a table with all fixtures.",
		  returns = "(fixtures: table)",
		  type = "function"
		 },
		 getGravityScale = {
		  args = "()",
		  description = "Returns the gravity scale factor.",
		  returns = "(scale: number)",
		  type = "function"
		 },
		 getInertia = {
		  args = "()",
		  description = "Gets the rotational inertia of the body.\n\nThe rotational inertia is how hard is it to make the body spin.",
		  returns = "(inertia: number)",
		  type = "function"
		 },
		 getJointList = {
		  args = "()",
		  description = "Returns a table containing the Joints attached to this Body.",
		  returns = "(joints: table)",
		  type = "function"
		 },
		 getLinearDamping = {
		  args = "()",
		  description = "Gets the linear damping of the Body.\n\nThe linear damping is the rate of decrease of the linear velocity over time. A moving body with no damping and no external forces will continue moving indefinitely, as is the case in space. A moving body with damping will gradually stop moving.\n\nDamping is not the same as friction - they can be modelled together. However, only damping is provided by Box2D (and LÖVE).",
		  returns = "(damping: number)",
		  type = "function"
		 },
		 getLinearVelocity = {
		  args = "()",
		  description = "Gets the linear velocity of the Body from its center of mass.\n\nThe linear velocity is the rate of change of position over time.\n\nIf you need the rate of change of angle over time, use Body:getAngularVelocity. If you need to get the linear velocity of a point different from the center of mass:\n\nBody:getLinearVelocityFromLocalPoint allows you to specify the point in local coordinates.\n\nBody:getLinearVelocityFromWorldPoint allows you to specify the point in world coordinates.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getLinearVelocityFromLocalPoint = {
		  args = "(x: number, y: number)",
		  description = "Get the linear velocity of a point on the body.\n\nThe linear velocity for a point on the body is the velocity of the body center of mass plus the velocity at that point from the body spinning.\n\nThe point on the body must given in local coordinates. Use Body:getLinearVelocityFromWorldPoint to specify this with world coordinates.",
		  returns = "(vx: number, vy: number)",
		  type = "function"
		 },
		 getLinearVelocityFromWorldPoint = {
		  args = "(x: number, y: number)",
		  description = "Get the linear velocity of a point on the body.\n\nThe linear velocity for a point on the body is the velocity of the body center of mass plus the velocity at that point from the body spinning.\n\nThe point on the body must given in world coordinates. Use Body:getLinearVelocityFromLocalPoint to specify this with local coordinates.",
		  returns = "(vx: number, vy: number)",
		  type = "function"
		 },
		 getLocalCenter = {
		  args = "()",
		  description = "Get the center of mass position in local coordinates.\n\nUse Body:getWorldCenter to get the center of mass in world coordinates.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getLocalPoint = {
		  args = "(worldX: number, worldY: number)",
		  description = "Transform a point from world coordinates to local coordinates.",
		  returns = "(localX: number, localY: number)",
		  type = "function"
		 },
		 getLocalVector = {
		  args = "(worldX: number, worldY: number)",
		  description = "Transform a vector from world coordinates to local coordinates.",
		  returns = "(localX: number, localY: number)",
		  type = "function"
		 },
		 getMass = {
		  args = "()",
		  description = "Get the mass of the body.",
		  returns = "(mass: number)",
		  type = "function"
		 },
		 getMassData = {
		  args = "()",
		  description = "Returns the mass, its center, and the rotational inertia.",
		  returns = "(x: number, y: number, mass: number, inertia: number)",
		  type = "function"
		 },
		 getPosition = {
		  args = "()",
		  description = "Get the position of the body.\n\nNote that this may not be the center of mass of the body.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getType = {
		  args = "()",
		  description = "Returns the type of the body.",
		  returns = "(type: BodyType)",
		  type = "function"
		 },
		 getUserData = {
		  args = "()",
		  description = "Returns the Lua value associated with this Body.",
		  returns = "(value: any)",
		  type = "function"
		 },
		 getWorld = {
		  args = "()",
		  description = "Gets the World the body lives in.",
		  returns = "(world: World)",
		  type = "function"
		 },
		 getWorldCenter = {
		  args = "()",
		  description = "Get the center of mass position in world coordinates.\n\nUse Body:getLocalCenter to get the center of mass in local coordinates.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getWorldPoint = {
		  args = "(localX: number, localY: number)",
		  description = "Transform a point from local coordinates to world coordinates.",
		  returns = "(worldX: number, worldY: number)",
		  type = "function"
		 },
		 getWorldPoints = {
		  args = "(x1: number, y1: number, x2: number, y2: number, ...: number)",
		  description = "Transforms multiple points from local coordinates to world coordinates.",
		  returns = "(x1: number, y1: number, x2: number, y2: number, ...: number)",
		  type = "function"
		 },
		 getWorldVector = {
		  args = "(localX: number, localY: number)",
		  description = "Transform a vector from local coordinates to world coordinates.",
		  returns = "(worldX: number, worldY: number)",
		  type = "function"
		 },
		 getX = {
		  args = "()",
		  description = "Get the x position of the body in world coordinates.",
		  returns = "(x: number)",
		  type = "function"
		 },
		 getY = {
		  args = "()",
		  description = "Get the y position of the body in world coordinates.",
		  returns = "(y: number)",
		  type = "function"
		 },
		 isActive = {
		  args = "()",
		  description = "Returns whether the body is actively used in the simulation.",
		  returns = "(status: boolean)",
		  type = "function"
		 },
		 isAwake = {
		  args = "()",
		  description = "Returns the sleep status of the body.",
		  returns = "(status: boolean)",
		  type = "function"
		 },
		 isBullet = {
		  args = "()",
		  description = "Get the bullet status of a body.\n\nThere are two methods to check for body collisions:\n\nat their location when the world is updated (default)\n\nusing continuous collision detection (CCD)\n\nThe default method is efficient, but a body moving very quickly may sometimes jump over another body without producing a collision. A body that is set as a bullet will use CCD. This is less efficient, but is guaranteed not to jump when moving quickly.\n\nNote that static bodies (with zero mass) always use CCD, so your walls will not let a fast moving body pass through even if it is not a bullet.",
		  returns = "(status: boolean)",
		  type = "function"
		 },
		 isDestroyed = {
		  args = "()",
		  description = "Gets whether the Body is destroyed. Destroyed bodies cannot be used.",
		  returns = "(destroyed: boolean)",
		  type = "function"
		 },
		 isFixedRotation = {
		  args = "()",
		  description = "Returns whether the body rotation is locked.",
		  returns = "(fixed: boolean)",
		  type = "function"
		 },
		 isSleepingAllowed = {
		  args = "()",
		  description = "Returns the sleeping behaviour of the body.",
		  returns = "(status: boolean)",
		  type = "function"
		 },
		 resetMassData = {
		  args = "()",
		  description = "Resets the mass of the body by recalculating it from the mass properties of the fixtures.",
		  returns = "()",
		  type = "function"
		 },
		 setActive = {
		  args = "(active: boolean)",
		  description = "Sets whether the body is active in the world.\n\nAn inactive body does not take part in the simulation. It will not move or cause any collisions.",
		  returns = "()",
		  type = "function"
		 },
		 setAngle = {
		  args = "(angle: number)",
		  description = "Set the angle of the body.\n\nThe angle is measured in radians. If you need to transform it from degrees, use math.rad.\n\nA value of 0 radians will mean \"looking to the right\". Although radians increase counter-clockwise, the y-axis points down so it becomes clockwise from our point of view.\n\nIt is possible to cause a collision with another body by changing its angle.",
		  returns = "()",
		  type = "function"
		 },
		 setAngularDamping = {
		  args = "(damping: number)",
		  description = "Sets the angular damping of a Body.\n\nSee Body:getAngularDamping for a definition of angular damping.\n\nAngular damping can take any value from 0 to infinity. It is recommended to stay between 0 and 0.1, though. Other values will look unrealistic.",
		  returns = "()",
		  type = "function"
		 },
		 setAngularVelocity = {
		  args = "(w: number)",
		  description = "Sets the angular velocity of a Body.\n\nThe angular velocity is the rate of change of angle over time.\n\nThis function will not accumulate anything; any impulses previously applied since the last call to World:update will be lost.",
		  returns = "()",
		  type = "function"
		 },
		 setAwake = {
		  args = "(awake: boolean)",
		  description = "Wakes the body up or puts it to sleep.",
		  returns = "()",
		  type = "function"
		 },
		 setBullet = {
		  args = "(status: boolean)",
		  description = "Set the bullet status of a body.\n\nThere are two methods to check for body collisions:\n\nat their location when the world is updated (default)\n\nusing continuous collision detection (CCD)\n\nThe default method is efficient, but a body moving very quickly may sometimes jump over another body without producing a collision. A body that is set as a bullet will use CCD. This is less efficient, but is guaranteed not to jump when moving quickly.\n\nNote that static bodies (with zero mass) always use CCD, so your walls will not let a fast moving body pass through even if it is not a bullet.",
		  returns = "()",
		  type = "function"
		 },
		 setFixedRotation = {
		  args = "(fixed: boolean)",
		  description = "Set whether a body has fixed rotation.\n\nBodies with fixed rotation don't vary the speed at which they rotate.",
		  returns = "()",
		  type = "function"
		 },
		 setGravityScale = {
		  args = "(scale: number)",
		  description = "Sets a new gravity scale factor for the body.",
		  returns = "()",
		  type = "function"
		 },
		 setInertia = {
		  args = "(inertia: number)",
		  description = "Set the inertia of a body.",
		  returns = "()",
		  type = "function"
		 },
		 setLinearDamping = {
		  args = "(ld: number)",
		  description = "Sets the linear damping of a Body\n\nSee Body:getLinearDamping for a definition of linear damping.\n\nLinear damping can take any value from 0 to infinity. It is recommended to stay between 0 and 0.1, though. Other values will make the objects look \"floaty\".",
		  returns = "()",
		  type = "function"
		 },
		 setLinearVelocity = {
		  args = "(x: number, y: number)",
		  description = "Sets a new linear velocity for the Body.\n\nThis function will not accumulate anything; any impulses previously applied since the last call to World:update will be lost.",
		  returns = "()",
		  type = "function"
		 },
		 setMass = {
		  args = "(mass: number)",
		  description = "Sets the mass in kilograms.",
		  returns = "()",
		  type = "function"
		 },
		 setMassData = {
		  args = "(x: number, y: number, mass: number, inertia: number)",
		  description = "Overrides the calculated mass data.",
		  returns = "()",
		  type = "function"
		 },
		 setPosition = {
		  args = "(x: number, y: number)",
		  description = "Set the position of the body.\n\nNote that this may not be the center of mass of the body.",
		  returns = "()",
		  type = "function"
		 },
		 setSleepingAllowed = {
		  args = "(allowed: boolean)",
		  description = "Sets the sleeping behaviour of the body.",
		  returns = "()",
		  type = "function"
		 },
		 setType = {
		  args = "(type: BodyType)",
		  description = "Sets a new body type.",
		  returns = "()",
		  type = "function"
		 },
		 setUserData = {
		  args = "(value: any)",
		  description = "Associates a Lua value with the Body.\n\nTo delete the reference, explicitly pass nil.",
		  returns = "()",
		  type = "function"
		 },
		 setX = {
		  args = "(x: number)",
		  description = "Set the x position of the body.",
		  returns = "()",
		  type = "function"
		 },
		 setY = {
		  args = "(y: number)",
		  description = "Set the y position of the body.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Bodies are objects with velocity and position.",
		inherits = "Object",
		type = "class"
	   },
	   BodyType = {
		childs = {
		 dynamic = {
		  description = "Dynamic bodies collide with all bodies.",
		  type = "value"
		 },
		 kinematic = {
		  description = "Kinematic bodies only collide with dynamic bodies.",
		  type = "value"
		 },
		 static = {
		  description = "Static bodies do not move.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   ChainShape = {
		childs = {
		 getNextVertex = {
		  args = "(x: number, y: number)",
		  description = "Gets the vertex that establishes a connection to the next shape.\n\nSetting next and previous ChainShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.",
		  returns = "()",
		  type = "function"
		 },
		 getPoint = {
		  args = "(index: number)",
		  description = "Returns a point of the shape.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getPoints = {
		  args = "()",
		  description = "Returns all points of the shape.",
		  returns = "(x1: number, y1: number, x2: number, y2: number, ...: number)",
		  type = "function"
		 },
		 getPreviousVertex = {
		  args = "()",
		  description = "Gets the vertex that establishes a connection to the previous shape.\n\nSetting next and previous ChainShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getVertexCount = {
		  args = "()",
		  description = "Returns the number of vertices the shape has.",
		  returns = "(count: number)",
		  type = "function"
		 },
		 setNextVertex = {
		  args = "(x: number, y: number)",
		  description = "Sets a vertex that establishes a connection to the next shape.\n\nThis can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.",
		  returns = "()",
		  type = "function"
		 },
		 setPreviousVertex = {
		  args = "(x: number, y: number)",
		  description = "Sets a vertex that establishes a connection to the previous shape.\n\nThis can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A ChainShape consists of multiple line segments. It can be used to create the boundaries of your terrain. The shape does not have volume and can only collide with PolygonShape and CircleShape.\n\nUnlike the PolygonShape, the ChainShape does not have a vertices limit or has to form a convex shape, but self intersections are not supported.",
		inherits = "Shape",
		type = "class"
	   },
	   CircleShape = {
		childs = {
		 getRadius = {
		  args = "()",
		  description = "Gets the radius of the circle shape.",
		  returns = "(radius: number)",
		  type = "function"
		 },
		 setPoint = {
		  args = "(x: number, y: number)",
		  description = "Sets the location of the center of the circle shape.",
		  returns = "()",
		  type = "function"
		 },
		 setRadius = {
		  args = "(radius: number)",
		  description = "Sets the radius of the circle.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Circle extends Shape and adds a radius and a local position.",
		inherits = "Shape",
		type = "class"
	   },
	   Contact = {
		childs = {
		 getFriction = {
		  args = "()",
		  description = "Get the friction between two shapes that are in contact.",
		  returns = "(friction: number)",
		  type = "function"
		 },
		 getNormal = {
		  args = "()",
		  description = "Get the normal vector between two shapes that are in contact.\n\nThis function returns the coordinates of a unit vector that points from the first shape to the second.",
		  returns = "(nx: number, ny: number)",
		  type = "function"
		 },
		 getPositions = {
		  args = "()",
		  description = "Returns the contact points of the two colliding fixtures. There can be one or two points.",
		  returns = "(x1: number, y1: number, x2: number, y2: number)",
		  type = "function"
		 },
		 getRestitution = {
		  args = "()",
		  description = "Get the restitution between two shapes that are in contact.",
		  returns = "(restitution: number)",
		  type = "function"
		 },
		 isEnabled = {
		  args = "()",
		  description = "Returns whether the contact is enabled. The collision will be ignored if a contact gets disabled in the preSolve callback.",
		  returns = "(enabled: boolean)",
		  type = "function"
		 },
		 isTouching = {
		  args = "()",
		  description = "Returns whether the two colliding fixtures are touching each other.",
		  returns = "(touching: boolean)",
		  type = "function"
		 },
		 resetFriction = {
		  args = "()",
		  description = "Resets the contact friction to the mixture value of both fixtures.",
		  returns = "()",
		  type = "function"
		 },
		 resetRestitution = {
		  args = "()",
		  description = "Resets the contact restitution to the mixture value of both fixtures.",
		  returns = "()",
		  type = "function"
		 },
		 setEnabled = {
		  args = "(enabled: boolean)",
		  description = "Enables or disables the contact.",
		  returns = "()",
		  type = "function"
		 },
		 setFriction = {
		  args = "(friction: number)",
		  description = "Sets the contact friction.",
		  returns = "()",
		  type = "function"
		 },
		 setRestitution = {
		  args = "(restitution: number)",
		  description = "Sets the contact restitution.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Contacts are objects created to manage collisions in worlds.",
		inherits = "Object",
		type = "class"
	   },
	   DistanceJoint = {
		childs = {
		 getFrequency = {
		  args = "()",
		  description = "Gets the response speed.",
		  returns = "(Hz: number)",
		  type = "function"
		 },
		 getLength = {
		  args = "()",
		  description = "Gets the equilibrium distance between the two Bodies.",
		  returns = "(l: number)",
		  type = "function"
		 },
		 setDampingRatio = {
		  args = "(ratio: number)",
		  description = "Sets the damping ratio.",
		  returns = "()",
		  type = "function"
		 },
		 setFrequency = {
		  args = "(Hz: number)",
		  description = "Sets the response speed.",
		  returns = "()",
		  type = "function"
		 },
		 setLength = {
		  args = "(l: number)",
		  description = "Sets the equilibrium distance between the two Bodies.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Keeps two bodies at the same distance.",
		inherits = "Joint",
		type = "class"
	   },
	   EdgeShape = {
		childs = {
		 getNextVertex = {
		  args = "()",
		  description = "Gets the vertex that establishes a connection to the next shape.\n\nSetting next and previous EdgeShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getPreviousVertex = {
		  args = "()",
		  description = "Gets the vertex that establishes a connection to the previous shape.\n\nSetting next and previous EdgeShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 setNextVertex = {
		  args = "(x: number, y: number)",
		  description = "Sets a vertex that establishes a connection to the next shape.\n\nThis can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.",
		  returns = "()",
		  type = "function"
		 },
		 setPreviousVertex = {
		  args = "(x: number, y: number)",
		  description = "Sets a vertex that establishes a connection to the previous shape.\n\nThis can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A EdgeShape is a line segment. They can be used to create the boundaries of your terrain. The shape does not have volume and can only collide with PolygonShape and CircleShape.",
		inherits = "Shape",
		type = "class"
	   },
	   Fixture = {
		childs = {
		 getBody = {
		  args = "()",
		  description = "Returns the body to which the fixture is attached.",
		  returns = "(body: Body)",
		  type = "function"
		 },
		 getBoundingBox = {
		  args = "(index: number)",
		  description = "Returns the points of the fixture bounding box. In case the fixture has multiple children a 1-based index can be specified. For example, a fixture will have multiple children with a chain shape.",
		  returns = "(topLeftX: number, topLeftY: number, bottomRightX: number, bottomRightY: number)",
		  type = "function"
		 },
		 getCategory = {
		  args = "()",
		  description = "Returns the categories the fixture belongs to.",
		  returns = "(category1: number, category2: number, ...: number)",
		  type = "function"
		 },
		 getDensity = {
		  args = "()",
		  description = "Returns the density of the fixture.",
		  returns = "(density: number)",
		  type = "function"
		 },
		 getFilterData = {
		  args = "()",
		  description = "Returns the filter data of the fixture. Categories and masks are encoded as the bits of a 16-bit integer.",
		  returns = "(categories: number, mask: number, group: number)",
		  type = "function"
		 },
		 getFriction = {
		  args = "()",
		  description = "Returns the friction of the fixture.",
		  returns = "(friction: number)",
		  type = "function"
		 },
		 getGroupIndex = {
		  args = "()",
		  description = "Returns the group the fixture belongs to. Fixtures with the same group will always collide if the group is positive or never collide if it's negative. The group zero means no group.\n\nThe groups range from -32768 to 32767.",
		  returns = "(group: number)",
		  type = "function"
		 },
		 getMask = {
		  args = "()",
		  description = "Returns the category mask of the fixture.",
		  returns = "(mask1: number, mask2: number, ...: number)",
		  type = "function"
		 },
		 getMassData = {
		  args = "()",
		  description = "Returns the mass, its center and the rotational inertia.",
		  returns = "(x: number, y: number, mass: number, inertia: number)",
		  type = "function"
		 },
		 getRestitution = {
		  args = "()",
		  description = "Returns the restitution of the fixture.",
		  returns = "(restitution: number)",
		  type = "function"
		 },
		 getShape = {
		  args = "()",
		  description = "Returns the shape of the fixture. This shape is a reference to the actual data used in the simulation. It's possible to change its values between timesteps.\n\nDo not call any functions on this shape after the parent fixture has been destroyed. This shape will point to an invalid memory address and likely cause crashes if you interact further with it.",
		  returns = "(shape: Shape)",
		  type = "function"
		 },
		 getUserData = {
		  args = "()",
		  description = "Returns the Lua value associated with this fixture.\n\nUse this function in one thread only.",
		  returns = "(value: any)",
		  type = "function"
		 },
		 isDestroyed = {
		  args = "()",
		  description = "Gets whether the Fixture is destroyed. Destroyed fixtures cannot be used.",
		  returns = "(destroyed: boolean)",
		  type = "function"
		 },
		 isSensor = {
		  args = "()",
		  description = "Returns whether the fixture is a sensor.",
		  returns = "(sensor: boolean)",
		  type = "function"
		 },
		 rayCast = {
		  args = "(x1: number, y1: number, x2: number, y2: number, maxFraction: number, childIndex: number)",
		  description = "Casts a ray against the shape of the fixture and returns the surface normal vector and the line position where the ray hit. If the ray missed the shape, nil will be returned.\n\nThe ray starts on the first point of the input line and goes towards the second point of the line. The fourth argument is the maximum distance the ray is going to travel as a scale factor of the input line length.\n\nThe childIndex parameter is used to specify which child of a parent shape, such as a ChainShape, will be ray casted. For ChainShapes, the index of 1 is the first edge on the chain. Ray casting a parent shape will only test the child specified so if you want to test every shape of the parent, you must loop through all of its children.\n\nThe world position of the impact can be calculated by multiplying the line vector with the third return value and adding it to the line starting point.\n\nhitx, hity = x1 + (x2 - x1) * fraction, y1 + (y2 - y1) * fraction",
		  returns = "(x: number, y: number, fraction: number)",
		  type = "function"
		 },
		 setCategory = {
		  args = "(category1: number, category2: number, ...: number)",
		  description = "Sets the categories the fixture belongs to. There can be up to 16 categories represented as a number from 1 to 16.",
		  returns = "()",
		  type = "function"
		 },
		 setDensity = {
		  args = "(density: number)",
		  description = "Sets the density of the fixture. Call Body:resetMassData if this needs to take effect immediately.",
		  returns = "()",
		  type = "function"
		 },
		 setFilterData = {
		  args = "(categories: number, mask: number, group: number)",
		  description = "Sets the filter data of the fixture.\n\nGroups, categories, and mask can be used to define the collision behaviour of the fixture.\n\nIf two fixtures are in the same group they either always collide if the group is positive, or never collide if it's negative. If the group is zero or they do not match, then the contact filter checks if the fixtures select a category of the other fixture with their masks. The fixtures do not collide if that's not the case. If they do have each other's categories selected, the return value of the custom contact filter will be used. They always collide if none was set.\n\nThere can be up to 16 categories. Categories and masks are encoded as the bits of a 16-bit integer.",
		  returns = "()",
		  type = "function"
		 },
		 setFriction = {
		  args = "(friction: number)",
		  description = "Sets the friction of the fixture.",
		  returns = "()",
		  type = "function"
		 },
		 setGroupIndex = {
		  args = "(group: number)",
		  description = "Sets the group the fixture belongs to. Fixtures with the same group will always collide if the group is positive or never collide if it's negative. The group zero means no group.\n\nThe groups range from -32768 to 32767.",
		  returns = "()",
		  type = "function"
		 },
		 setMask = {
		  args = "(mask1: number, mask2: number, ...: number)",
		  description = "Sets the category mask of the fixture. There can be up to 16 categories represented as a number from 1 to 16.\n\nThis fixture will collide with the fixtures that are in the selected categories if the other fixture also has a category of this fixture selected.",
		  returns = "()",
		  type = "function"
		 },
		 setRestitution = {
		  args = "(restitution: number)",
		  description = "Sets the restitution of the fixture.",
		  returns = "()",
		  type = "function"
		 },
		 setSensor = {
		  args = "(sensor: boolean)",
		  description = "Sets whether the fixture should act as a sensor.\n\nSensor do not produce collisions responses, but the begin and end callbacks will still be called for this fixture.",
		  returns = "()",
		  type = "function"
		 },
		 setUserData = {
		  args = "(value: any)",
		  description = "Associates a Lua value with the fixture.\n\nUse this function in one thread only.",
		  returns = "()",
		  type = "function"
		 },
		 testPoint = {
		  args = "(x: number, y: number)",
		  description = "Checks if a point is inside the shape of the fixture.",
		  returns = "(isInside: boolean)",
		  type = "function"
		 }
		},
		description = "Fixtures attach shapes to bodies.",
		inherits = "Object",
		type = "class"
	   },
	   FrictionJoint = {
		childs = {
		 getMaxTorque = {
		  args = "()",
		  description = "Gets the maximum friction torque in Newton-meters.",
		  returns = "(torque: number)",
		  type = "function"
		 },
		 setMaxForce = {
		  args = "(maxForce: number)",
		  description = "Sets the maximum friction force in Newtons.",
		  returns = "()",
		  type = "function"
		 },
		 setMaxTorque = {
		  args = "(torque: number)",
		  description = "Sets the maximum friction torque in Newton-meters.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A FrictionJoint applies friction to a body.",
		inherits = "Joint",
		type = "class"
	   },
	   GearJoint = {
		childs = {
		 getRatio = {
		  args = "()",
		  description = "Get the ratio of a gear joint.",
		  returns = "(ratio: number)",
		  type = "function"
		 },
		 setRatio = {
		  args = "(ratio: number)",
		  description = "Set the ratio of a gear joint.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Keeps bodies together in such a way that they act like gears.",
		inherits = "Joint",
		type = "class"
	   },
	   Joint = {
		childs = {
		 getAnchors = {
		  args = "()",
		  description = "Get the anchor points of the joint.",
		  returns = "(x1: number, y1: number, x2: number, y2: number)",
		  type = "function"
		 },
		 getBodies = {
		  args = "()",
		  description = "Gets the bodies that the Joint is attached to.",
		  returns = "(bodyA: Body, bodyB: Body)",
		  type = "function"
		 },
		 getCollideConnected = {
		  args = "()",
		  description = "Gets whether the connected Bodies collide.",
		  returns = "(c: boolean)",
		  type = "function"
		 },
		 getReactionForce = {
		  args = "()",
		  description = "Gets the reaction force on Body 2 at the joint anchor.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getReactionTorque = {
		  args = "(invdt: number)",
		  description = "Returns the reaction torque on the second body.",
		  returns = "(torque: number)",
		  type = "function"
		 },
		 getType = {
		  args = "()",
		  description = "Gets a string representing the type.",
		  returns = "(type: JointType)",
		  type = "function"
		 },
		 getUserData = {
		  args = "()",
		  description = "Returns the Lua value associated with this Joint.",
		  returns = "(value: any)",
		  type = "function"
		 },
		 isDestroyed = {
		  args = "()",
		  description = "Gets whether the Joint is destroyed. Destroyed joints cannot be used.",
		  returns = "(destroyed: boolean)",
		  type = "function"
		 },
		 setUserData = {
		  args = "(value: any)",
		  description = "Associates a Lua value with the Joint.\n\nTo delete the reference, explicitly pass nil.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Attach multiple bodies together to interact in unique ways.",
		inherits = "Object",
		type = "class"
	   },
	   JointType = {
		childs = {
		 distance = {
		  description = "A DistanceJoint.",
		  type = "value"
		 },
		 friction = {
		  description = "A FrictionJoint.",
		  type = "value"
		 },
		 gear = {
		  description = "A GearJoint.",
		  type = "value"
		 },
		 mouse = {
		  description = "A MouseJoint.",
		  type = "value"
		 },
		 prismatic = {
		  description = "A PrismaticJoint.",
		  type = "value"
		 },
		 pulley = {
		  description = "A PulleyJoint.",
		  type = "value"
		 },
		 revolute = {
		  description = "A RevoluteJoint.",
		  type = "value"
		 },
		 rope = {
		  description = "A RopeJoint.",
		  type = "value"
		 },
		 weld = {
		  description = "A WeldJoint.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   MotorJoint = {
		childs = {
		 getLinearOffset = {
		  args = "()",
		  description = "Gets the target linear offset between the two Bodies the Joint is attached to.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 setAngularOffset = {
		  args = "(angularoffset: number)",
		  description = "Sets the target angluar offset between the two Bodies the Joint is attached to.",
		  returns = "()",
		  type = "function"
		 },
		 setLinearOffset = {
		  args = "(x: number, y: number)",
		  description = "Sets the target linear offset between the two Bodies the Joint is attached to.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Controls the relative motion between two Bodies. Position and rotation offsets can be specified, as well as the maximum motor force and torque that will be applied to reach the target offsets.",
		inherits = "Joint",
		type = "class"
	   },
	   MouseJoint = {
		childs = {
		 getFrequency = {
		  args = "()",
		  description = "Returns the frequency.",
		  returns = "(freq: number)",
		  type = "function"
		 },
		 getMaxForce = {
		  args = "()",
		  description = "Gets the highest allowed force.",
		  returns = "(f: number)",
		  type = "function"
		 },
		 getTarget = {
		  args = "()",
		  description = "Gets the target point.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 setDampingRatio = {
		  args = "(ratio: number)",
		  description = "Sets a new damping ratio.",
		  returns = "()",
		  type = "function"
		 },
		 setFrequency = {
		  args = "(freq: number)",
		  description = "Sets a new frequency.",
		  returns = "()",
		  type = "function"
		 },
		 setMaxForce = {
		  args = "(f: number)",
		  description = "Sets the highest allowed force.",
		  returns = "()",
		  type = "function"
		 },
		 setTarget = {
		  args = "(x: number, y: number)",
		  description = "Sets the target point.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "For controlling objects with the mouse.",
		inherits = "Joint",
		type = "class"
	   },
	   PolygonShape = {
		childs = {
		 getPoints = {
		  args = "()",
		  description = "Get the local coordinates of the polygon's vertices.\n\nThis function has a variable number of return values. It can be used in a nested fashion with love.graphics.polygon.\n\nThis function may have up to 16 return values, since it returns two values for each vertex in the polygon. In other words, it can return the coordinates of up to 8 points.",
		  returns = "(x1: number, y1: number, x2: number, y2: number, ...: number)",
		  type = "function"
		 }
		},
		description = "Polygon is a convex polygon with up to 8 sides.",
		inherits = "Shape",
		type = "class"
	   },
	   PrismaticJoint = {
		childs = {
		 getAxis = {
		  args = "()",
		  description = "Gets the world-space axis vector of the Prismatic Joint.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getJointSpeed = {
		  args = "()",
		  description = "Get the current joint angle speed.",
		  returns = "(s: number)",
		  type = "function"
		 },
		 getJointTranslation = {
		  args = "()",
		  description = "Get the current joint translation.",
		  returns = "(t: number)",
		  type = "function"
		 },
		 getLimits = {
		  args = "()",
		  description = "Gets the joint limits.",
		  returns = "(lower: number, upper: number)",
		  type = "function"
		 },
		 getLowerLimit = {
		  args = "()",
		  description = "Gets the lower limit.",
		  returns = "(lower: number)",
		  type = "function"
		 },
		 getMaxMotorForce = {
		  args = "()",
		  description = "Gets the maximum motor force.",
		  returns = "(f: number)",
		  type = "function"
		 },
		 getMotorForce = {
		  args = "()",
		  description = "Get the current motor force.",
		  returns = "(f: number)",
		  type = "function"
		 },
		 getMotorSpeed = {
		  args = "()",
		  description = "Gets the motor speed.",
		  returns = "(s: number)",
		  type = "function"
		 },
		 getUpperLimit = {
		  args = "()",
		  description = "Gets the upper limit.",
		  returns = "(upper: number)",
		  type = "function"
		 },
		 isMotorEnabled = {
		  args = "()",
		  description = "Checks whether the motor is enabled.",
		  returns = "(enabled: boolean)",
		  type = "function"
		 },
		 setLimits = {
		  args = "(lower: number, upper: number)",
		  description = "Sets the limits.",
		  returns = "()",
		  type = "function"
		 },
		 setLimitsEnabled = {
		  args = "(enable: boolean)",
		  description = "Enables or disables the limits of the joint.",
		  returns = "()",
		  type = "function"
		 },
		 setLowerLimit = {
		  args = "(lower: number)",
		  description = "Sets the lower limit.",
		  returns = "()",
		  type = "function"
		 },
		 setMaxMotorForce = {
		  args = "(f: number)",
		  description = "Set the maximum motor force.",
		  returns = "()",
		  type = "function"
		 },
		 setMotorEnabled = {
		  args = "(enable: boolean)",
		  description = "Starts or stops the joint motor.",
		  returns = "()",
		  type = "function"
		 },
		 setMotorSpeed = {
		  args = "(s: number)",
		  description = "Sets the motor speed.",
		  returns = "()",
		  type = "function"
		 },
		 setUpperLimit = {
		  args = "(upper: number)",
		  description = "Sets the upper limit.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Restricts relative motion between Bodies to one shared axis.",
		inherits = "Joint",
		type = "class"
	   },
	   PulleyJoint = {
		childs = {
		 getGroundAnchors = {
		  args = "()",
		  description = "Get the ground anchor positions in world coordinates.",
		  returns = "(a1x: number, a1y: number, a2x: number, a2y: number)",
		  type = "function"
		 },
		 getLengthA = {
		  args = "()",
		  description = "Get the current length of the rope segment attached to the first body.",
		  returns = "(length: number)",
		  type = "function"
		 },
		 getLengthB = {
		  args = "()",
		  description = "Get the current length of the rope segment attached to the second body.",
		  returns = "(length: number)",
		  type = "function"
		 },
		 getMaxLengths = {
		  args = "()",
		  description = "Get the maximum lengths of the rope segments.",
		  returns = "(len1: number, len2: number)",
		  type = "function"
		 },
		 getRatio = {
		  args = "()",
		  description = "Get the pulley ratio.",
		  returns = "(ratio: number)",
		  type = "function"
		 },
		 setConstant = {
		  args = "(length: number)",
		  description = "Set the total length of the rope.\n\nSetting a new length for the rope updates the maximum length values of the joint.",
		  returns = "()",
		  type = "function"
		 },
		 setMaxLengths = {
		  args = "(max1: number, max2: number)",
		  description = "Set the maximum lengths of the rope segments.\n\nThe physics module also imposes maximum values for the rope segments. If the parameters exceed these values, the maximum values are set instead of the requested values.",
		  returns = "()",
		  type = "function"
		 },
		 setRatio = {
		  args = "(ratio: number)",
		  description = "Set the pulley ratio.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Allows you to simulate bodies connected through pulleys.",
		inherits = "Joint",
		type = "class"
	   },
	   RevoluteJoint = {
		childs = {
		 getJointAngle = {
		  args = "()",
		  description = "Get the current joint angle.",
		  returns = "(angle: number)",
		  type = "function"
		 },
		 getJointSpeed = {
		  args = "()",
		  description = "Get the current joint angle speed.",
		  returns = "(s: number)",
		  type = "function"
		 },
		 getLimits = {
		  args = "()",
		  description = "Gets the joint limits.",
		  returns = "(lower: number, upper: number)",
		  type = "function"
		 },
		 getLowerLimit = {
		  args = "()",
		  description = "Gets the lower limit.",
		  returns = "(lower: number)",
		  type = "function"
		 },
		 getMaxMotorTorque = {
		  args = "()",
		  description = "Gets the maximum motor force.",
		  returns = "(f: number)",
		  type = "function"
		 },
		 getMotorSpeed = {
		  args = "()",
		  description = "Gets the motor speed.",
		  returns = "(s: number)",
		  type = "function"
		 },
		 getMotorTorque = {
		  args = "()",
		  description = "Get the current motor force.",
		  returns = "(f: number)",
		  type = "function"
		 },
		 getUpperLimit = {
		  args = "()",
		  description = "Gets the upper limit.",
		  returns = "(upper: number)",
		  type = "function"
		 },
		 isMotorEnabled = {
		  args = "()",
		  description = "Checks whether the motor is enabled.",
		  returns = "(enabled: boolean)",
		  type = "function"
		 },
		 setLimits = {
		  args = "(lower: number, upper: number)",
		  description = "Sets the limits.",
		  returns = "()",
		  type = "function"
		 },
		 setLimitsEnabled = {
		  args = "(enable: boolean)",
		  description = "Enables or disables the joint limits.",
		  returns = "()",
		  type = "function"
		 },
		 setLowerLimit = {
		  args = "(lower: number)",
		  description = "Sets the lower limit.",
		  returns = "()",
		  type = "function"
		 },
		 setMaxMotorTorque = {
		  args = "(f: number)",
		  description = "Set the maximum motor force.",
		  returns = "()",
		  type = "function"
		 },
		 setMotorEnabled = {
		  args = "(enable: boolean)",
		  description = "Starts or stops the joint motor.",
		  returns = "()",
		  type = "function"
		 },
		 setMotorSpeed = {
		  args = "(s: number)",
		  description = "Sets the motor speed.",
		  returns = "()",
		  type = "function"
		 },
		 setUpperLimit = {
		  args = "(upper: number)",
		  description = "Sets the upper limit.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Allow two Bodies to revolve around a shared point.",
		inherits = "Joint",
		type = "class"
	   },
	   RopeJoint = {
		childs = {
		 setMaxLength = {
		  args = "(maxLength: number)",
		  description = "Sets the maximum length of a RopeJoint.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "The RopeJoint enforces a maximum distance between two points on two bodies. It has no other effect.",
		inherits = "Joint",
		type = "class"
	   },
	   Shape = {
		childs = {
		 computeMass = {
		  args = "(density: number)",
		  description = "Computes the mass properties for the shape with the specified density.",
		  returns = "(x: number, y: number, mass: number, inertia: number)",
		  type = "function"
		 },
		 getChildCount = {
		  args = "()",
		  description = "Returns the number of children the shape has.",
		  returns = "(count: number)",
		  type = "function"
		 },
		 getRadius = {
		  args = "()",
		  description = "Gets the radius of the shape.",
		  returns = "(radius: number)",
		  type = "function"
		 },
		 getType = {
		  args = "()",
		  description = "Gets a string representing the Shape. This function can be useful for conditional debug drawing.",
		  returns = "(type: ShapeType)",
		  type = "function"
		 },
		 rayCast = {
		  args = "(x1: number, y1: number, x2: number, y2: number, maxFraction: number, tx: number, ty: number, tr: number, childIndex: number)",
		  description = "Casts a ray against the shape and returns the surface normal vector and the line position where the ray hit. If the ray missed the shape, nil will be returned. The Shape can be transformed to get it into the desired position.\n\nThe ray starts on the first point of the input line and goes towards the second point of the line. The fourth argument is the maximum distance the ray is going to travel as a scale factor of the input line length.\n\nThe childIndex parameter is used to specify which child of a parent shape, such as a ChainShape, will be ray casted. For ChainShapes, the index of 1 is the first edge on the chain. Ray casting a parent shape will only test the child specified so if you want to test every shape of the parent, you must loop through all of its children.\n\nThe world position of the impact can be calculated by multiplying the line vector with the third return value and adding it to the line starting point.\n\nhitx, hity = x1 + (x2 - x1) * fraction, y1 + (y2 - y1) * fraction",
		  returns = "(xn: number, yn: number, fraction: number)",
		  type = "function"
		 },
		 testPoint = {
		  args = "(x: number, y: number)",
		  description = "Checks whether a point lies inside the shape. This is particularly useful for mouse interaction with the shapes. By looping through all shapes and testing the mouse position with this function, we can find which shapes the mouse touches.",
		  returns = "(hit: boolean)",
		  type = "function"
		 }
		},
		description = "Shapes are solid 2d geometrical objects used in love.physics.\n\nShapes are attached to a Body via a Fixture. The Shape object is copied when this happens. Shape position is relative to Body position.",
		inherits = "Object",
		type = "class"
	   },
	   ShapeType = {
		childs = {
		 chain = {
		  description = "The Shape is a ChainShape.",
		  type = "value"
		 },
		 circle = {
		  description = "The Shape is a CircleShape.",
		  type = "value"
		 },
		 edge = {
		  description = "The Shape is a EdgeShape.",
		  type = "value"
		 },
		 polygon = {
		  description = "The Shape is a PolygonShape.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   WeldJoint = {
		childs = {
		 getFrequency = {
		  args = "()",
		  description = "Returns the frequency.",
		  returns = "(freq: number)",
		  type = "function"
		 },
		 setDampingRatio = {
		  args = "(ratio: number)",
		  description = "The new damping ratio.",
		  returns = "()",
		  type = "function"
		 },
		 setFrequency = {
		  args = "(freq: number)",
		  description = "Sets a new frequency.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A WeldJoint essentially glues two bodies together.",
		inherits = "Joint",
		type = "class"
	   },
	   WheelJoint = {
		childs = {
		 getJointSpeed = {
		  args = "()",
		  description = "Returns the current joint translation speed.",
		  returns = "(speed: number)",
		  type = "function"
		 },
		 getJointTranslation = {
		  args = "()",
		  description = "Returns the current joint translation.",
		  returns = "(position: number)",
		  type = "function"
		 },
		 getMaxMotorTorque = {
		  args = "()",
		  description = "Returns the maximum motor torque.",
		  returns = "(maxTorque: number)",
		  type = "function"
		 },
		 getMotorSpeed = {
		  args = "()",
		  description = "Returns the speed of the motor.",
		  returns = "(speed: number)",
		  type = "function"
		 },
		 getMotorTorque = {
		  args = "(invdt: number)",
		  description = "Returns the current torque on the motor.",
		  returns = "(torque: number)",
		  type = "function"
		 },
		 getSpringDampingRatio = {
		  args = "()",
		  description = "Returns the damping ratio.",
		  returns = "(ratio: number)",
		  type = "function"
		 },
		 getSpringFrequency = {
		  args = "()",
		  description = "Returns the spring frequency.",
		  returns = "(freq: number)",
		  type = "function"
		 },
		 setMaxMotorTorque = {
		  args = "(maxTorque: number)",
		  description = "Sets a new maximum motor torque.",
		  returns = "()",
		  type = "function"
		 },
		 setMotorEnabled = {
		  args = "(enable: boolean)",
		  description = "Starts and stops the joint motor.",
		  returns = "()",
		  type = "function"
		 },
		 setMotorSpeed = {
		  args = "(speed: number)",
		  description = "Sets a new speed for the motor.",
		  returns = "()",
		  type = "function"
		 },
		 setSpringDampingRatio = {
		  args = "(ratio: number)",
		  description = "Sets a new damping ratio.",
		  returns = "()",
		  type = "function"
		 },
		 setSpringFrequency = {
		  args = "(freq: number)",
		  description = "Sets a new spring frequency.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Restricts a point on the second body to a line on the first body.",
		inherits = "Joint",
		type = "class"
	   },
	   World = {
		childs = {
		 getBodyCount = {
		  args = "()",
		  description = "Get the number of bodies in the world.",
		  returns = "(n: number)",
		  type = "function"
		 },
		 getBodyList = {
		  args = "()",
		  description = "Returns a table with all bodies.",
		  returns = "(bodies: table)",
		  type = "function"
		 },
		 getCallbacks = {
		  args = "()",
		  description = "Returns functions for the callbacks during the world update.",
		  returns = "(beginContact: function, endContact: function, preSolve: function, postSolve: function)",
		  type = "function"
		 },
		 getContactCount = {
		  args = "()",
		  description = "Returns the number of contacts in the world.",
		  returns = "(n: number)",
		  type = "function"
		 },
		 getContactFilter = {
		  args = "()",
		  description = "Returns the function for collision filtering.",
		  returns = "(contactFilter: function)",
		  type = "function"
		 },
		 getContactList = {
		  args = "()",
		  description = "Returns a table with all contacts.",
		  returns = "(contacts: table)",
		  type = "function"
		 },
		 getGravity = {
		  args = "()",
		  description = "Get the gravity of the world.",
		  returns = "(x: number, y: number)",
		  type = "function"
		 },
		 getJointCount = {
		  args = "()",
		  description = "Get the number of joints in the world.",
		  returns = "(n: number)",
		  type = "function"
		 },
		 getJointList = {
		  args = "()",
		  description = "Returns a table with all joints.",
		  returns = "(joints: table)",
		  type = "function"
		 },
		 isDestroyed = {
		  args = "()",
		  description = "Gets whether the World is destroyed. Destroyed worlds cannot be used.",
		  returns = "(destroyed: boolean)",
		  type = "function"
		 },
		 isLocked = {
		  args = "()",
		  description = "Returns if the world is updating its state.\n\nThis will return true inside the callbacks from World:setCallbacks.",
		  returns = "(locked: boolean)",
		  type = "function"
		 },
		 isSleepingAllowed = {
		  args = "()",
		  description = "Returns the sleep behaviour of the world.",
		  returns = "(allowSleep: boolean)",
		  type = "function"
		 },
		 queryBoundingBox = {
		  args = "(topLeftX: number, topLeftY: number, bottomRightX: number, bottomRightY: number, callback: function)",
		  description = "Calls a function for each fixture inside the specified area.",
		  returns = "()",
		  type = "function"
		 },
		 rayCast = {
		  args = "(x1: number, y1: number, x2: number, y2: number, callback: function)",
		  description = "Casts a ray and calls a function for each fixtures it intersects.",
		  returns = "()",
		  type = "function"
		 },
		 setCallbacks = {
		  args = "(beginContact: function, endContact: function, preSolve: function, postSolve: function)",
		  description = "Sets functions for the collision callbacks during the world update.\n\nFour Lua functions can be given as arguments. The value nil removes a function.\n\nWhen called, each function will be passed three arguments. The first two arguments are the colliding fixtures and the third argument is the Contact between them. The PostSolve callback additionally gets the normal and tangent impulse for each contact point.",
		  returns = "()",
		  type = "function"
		 },
		 setContactFilter = {
		  args = "(filter: function)",
		  description = "Sets a function for collision filtering.\n\nIf the group and category filtering doesn't generate a collision decision, this function gets called with the two fixtures as arguments. The function should return a boolean value where true means the fixtures will collide and false means they will pass through each other.",
		  returns = "()",
		  type = "function"
		 },
		 setGravity = {
		  args = "(x: number, y: number)",
		  description = "Set the gravity of the world.",
		  returns = "()",
		  type = "function"
		 },
		 setSleepingAllowed = {
		  args = "(allowSleep: boolean)",
		  description = "Set the sleep behaviour of the world.\n\nA sleeping body is much more efficient to simulate than when awake.\n\nIf sleeping is allowed, any body that has come to rest will sleep.",
		  returns = "()",
		  type = "function"
		 },
		 translateOrigin = {
		  args = "(x: number, y: number)",
		  description = "Translates the World's origin. Useful in large worlds where floating point precision issues become noticeable at far distances from the origin.",
		  returns = "()",
		  type = "function"
		 },
		 update = {
		  args = "(dt: number, velocityiterations: number, positioniterations: number)",
		  description = "Update the state of the world.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A world is an object that contains all bodies and joints.",
		inherits = "Object",
		type = "class"
	   },
	   getMeter = {
		args = "()",
		description = "Get the scale of the world.\n\nThe world scale is the number of pixels per meter. Try to keep your shape sizes less than 10 times this scale.\n\nThis is important because the physics in Box2D is tuned to work well for objects of size 0.1m up to 10m. All physics coordinates are divided by this number for the physics calculations.",
		returns = "(scale: number)",
		type = "function"
	   },
	   newBody = {
		args = "(world: World, x: number, y: number, type: BodyType)",
		description = "Creates a new body.\n\nThere are three types of bodies. Static bodies do not move, have a infinite mass, and can be used for level boundaries. Dynamic bodies are the main actors in the simulation, they collide with everything. Kinematic bodies do not react to forces and only collide with dynamic bodies.\n\nThe mass of the body gets calculated when a Fixture is attached or removed, but can be changed at any time with Body:setMass or Body:resetMassData.",
		returns = "(body: Body)",
		type = "function"
	   },
	   newChainShape = {
		args = "(loop: boolean, x1: number, y1: number, x2: number, y2: number, ...: number)",
		description = "Creates a new ChainShape.",
		returns = "(shape: ChainShape)",
		type = "function"
	   },
	   newCircleShape = {
		args = "(radius: number)",
		description = "Creates a new CircleShape.",
		returns = "(shape: CircleShape)",
		type = "function"
	   },
	   newDistanceJoint = {
		args = "(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, collideConnected: boolean)",
		description = "Create a distance joint between two bodies.\n\nThis joint constrains the distance between two points on two bodies to be constant. These two points are specified in world coordinates and the two bodies are assumed to be in place when this joint is created. The first anchor point is connected to the first body and the second to the second body, and the points define the length of the distance joint.",
		returns = "(joint: DistanceJoint)",
		type = "function"
	   },
	   newEdgeShape = {
		args = "(x1: number, y1: number, x2: number, y2: number)",
		description = "Creates a edge shape.",
		returns = "(shape: EdgeShape)",
		type = "function"
	   },
	   newFixture = {
		args = "(body: Body, shape: Shape, density: number)",
		description = "Creates and attaches a Fixture to a body.",
		returns = "(fixture: Fixture)",
		type = "function"
	   },
	   newFrictionJoint = {
		args = "(body1: Body, body2: Body, x: number, y: number, collideConnected: boolean)",
		description = "Create a friction joint between two bodies. A FrictionJoint applies friction to a body.",
		returns = "(joint: FrictionJoint)",
		type = "function"
	   },
	   newGearJoint = {
		args = "(joint1: Joint, joint2: Joint, ratio: number, collideConnected: boolean)",
		description = "Create a gear joint connecting two joints.\n\nThe gear joint connects two joints that must be either prismatic or revolute joints. Using this joint requires that the joints it uses connect their respective bodies to the ground and have the ground as the first body. When destroying the bodies and joints you must make sure you destroy the gear joint before the other joints.\n\nThe gear joint has a ratio the determines how the angular or distance values of the connected joints relate to each other. The formula coordinate1 + ratio * coordinate2 always has a constant value that is set when the gear joint is created.",
		returns = "(joint: GearJoint)",
		type = "function"
	   },
	   newMotorJoint = {
		args = "(body1: Body, body2: Body, correctionFactor: number)",
		description = "Creates a joint between two bodies which controls the relative motion between them.\n\nPosition and rotation offsets can be specified once the MotorJoint has been created, as well as the maximum motor force and torque that will be be applied to reach the target offsets.",
		returns = "(joint: MotorJoint)",
		type = "function"
	   },
	   newMouseJoint = {
		args = "(body: Body, x: number, y: number)",
		description = "Create a joint between a body and the mouse.\n\nThis joint actually connects the body to a fixed point in the world. To make it follow the mouse, the fixed point must be updated every timestep (example below).\n\nThe advantage of using a MouseJoint instead of just changing a body position directly is that collisions and reactions to other joints are handled by the physics engine.",
		returns = "(joint: MouseJoint)",
		type = "function"
	   },
	   newPolygonShape = {
		args = "(x1: number, y1: number, x2: number, y2: number, ...: number)",
		description = "Creates a new PolygonShape.\n\nThis shape can have 8 vertices at most, and must form a convex shape.",
		returns = "(shape: PolygonShape)",
		type = "function"
	   },
	   newPrismaticJoint = {
		args = "(body1: Body, body2: Body, x: number, y: number, ax: number, ay: number, collideConnected: boolean)",
		description = "Create a prismatic joints between two bodies.\n\nA prismatic joint constrains two bodies to move relatively to each other on a specified axis. It does not allow for relative rotation. Its definition and operation are similar to a revolute joint, but with translation and force substituted for angle and torque.",
		returns = "(joint: PrismaticJoint)",
		type = "function"
	   },
	   newPulleyJoint = {
		args = "(body1: Body, body2: Body, gx1: number, gy1: number, gx2: number, gy2: number, x1: number, y1: number, x2: number, y2: number, ratio: number, collideConnected: boolean)",
		description = "Create a pulley joint to join two bodies to each other and the ground.\n\nThe pulley joint simulates a pulley with an optional block and tackle. If the ratio parameter has a value different from one, then the simulated rope extends faster on one side than the other. In a pulley joint the total length of the simulated rope is the constant length1 + ratio * length2, which is set when the pulley joint is created.\n\nPulley joints can behave unpredictably if one side is fully extended. It is recommended that the method setMaxLengths  be used to constrain the maximum lengths each side can attain.",
		returns = "(joint: PulleyJoint)",
		type = "function"
	   },
	   newRectangleShape = {
		args = "(width: number, height: number)",
		description = "Shorthand for creating rectangular PolygonShapes.\n\nBy default, the local origin is located at the center of the rectangle as opposed to the top left for graphics.",
		returns = "(shape: PolygonShape)",
		type = "function"
	   },
	   newRevoluteJoint = {
		args = "(body1: Body, body2: Body, x: number, y: number, collideConnected: boolean)",
		description = "Creates a pivot joint between two bodies.\n\nThis joint connects two bodies to a point around which they can pivot.",
		returns = "(joint: RevoluteJoint)",
		type = "function"
	   },
	   newRopeJoint = {
		args = "(body1: Body, body2: Body, x1: number, y1: number, x2: number, y2: number, maxLength: number, collideConnected: boolean)",
		description = "Create a joint between two bodies. Its only function is enforcing a max distance between these bodies.",
		returns = "(joint: RopeJoint)",
		type = "function"
	   },
	   newWeldJoint = {
		args = "(body1: Body, body2: Body, x: number, y: number, collideConnected: boolean)",
		description = "Creates a constraint joint between two bodies. A WeldJoint essentially glues two bodies together. The constraint is a bit soft, however, due to Box2D's iterative solver.",
		returns = "(joint: WeldJoint)",
		type = "function"
	   },
	   newWheelJoint = {
		args = "(body1: Body, body2: Body, x: number, y: number, ax: number, ay: number, collideConnected: boolean)",
		description = "Creates a wheel joint.",
		returns = "(joint: WheelJoint)",
		type = "function"
	   },
	   newWorld = {
		args = "(xg: number, yg: number, sleep: boolean)",
		description = "Creates a new World.",
		returns = "(world: World)",
		type = "function"
	   },
	   setMeter = {
		args = "(scale: number)",
		description = "Sets the pixels to meter scale factor.\n\nAll coordinates in the physics module are divided by this number and converted to meters, and it creates a convenient way to draw the objects directly to the screen without the need for graphics transformations.\n\nIt is recommended to create shapes no larger than 10 times the scale. This is important because Box2D is tuned to work well with shape sizes from 0.1 to 10 meters. The default meter scale is 30.\n\nlove.physics.setMeter does not apply retroactively to created objects. Created objects retain their meter coordinates but the scale factor will affect their pixel coordinates.",
		returns = "()",
		type = "function"
	   }
	  },
	  description = "Can simulate 2D rigid body physics in a realistic manner. This module is based on Box2D, and this API corresponds to the Box2D API as closely as possible.",
	  type = "class"
	 },
	 quit = {
	  args = "()",
	  description = "Callback function triggered when the game is closed.",
	  returns = "(r: boolean)",
	  type = "function"
	 },
	 resize = {
	  args = "(w: number, h: number)",
	  description = "Called when the window is resized, for example if the user resizes the window, or if love.window.setMode is called with an unsupported width or height in fullscreen and the window chooses the closest appropriate size.\n\nCalls to love.window.setMode will only trigger this event if the width or height of the window after the call doesn't match the requested width and height. This can happen if a fullscreen mode is requested which doesn't match any supported mode, or if the fullscreen type is 'desktop' and the requested width or height don't match the desktop resolution.",
	  returns = "()",
	  type = "function"
	 },
	 run = {
	  args = "()",
	  description = "The main function, containing the main loop. A sensible default is used when left out.",
	  returns = "()",
	  type = "function"
	 },
	 setDeprecationOutput = {
	  args = "(enable: boolean)",
	  description = "Sets whether LÖVE displays warnings when using deprecated functionality. It is disabled by default in fused mode, and enabled by default otherwise.\n\nWhen deprecation output is enabled, the first use of a formally deprecated LÖVE API will show a message at the bottom of the screen for a short time, and print the message to the console.",
	  returns = "()",
	  type = "function"
	 },
	 sound = {
	  childs = {
	   Decoder = {
		childs = {
		 getChannelCount = {
		  args = "()",
		  description = "Returns the number of channels in the stream.",
		  returns = "(channels: number)",
		  type = "function"
		 },
		 getDuration = {
		  args = "()",
		  description = "Gets the duration of the sound file. It may not always be sample-accurate, and it may return -1 if the duration cannot be determined at all.",
		  returns = "(duration: number)",
		  type = "function"
		 },
		 getSampleRate = {
		  args = "()",
		  description = "Returns the sample rate of the Decoder.",
		  returns = "(rate: number)",
		  type = "function"
		 }
		},
		description = "An object which can gradually decode a sound file.",
		inherits = "Object",
		type = "class"
	   },
	   SoundData = {
		childs = {
		 getChannelCount = {
		  args = "()",
		  description = "Returns the number of channels in the stream.",
		  returns = "(channels: number)",
		  type = "function"
		 },
		 getDuration = {
		  args = "()",
		  description = "Gets the duration of the sound data.",
		  returns = "(duration: number)",
		  type = "function"
		 },
		 getSample = {
		  args = "(i: number)",
		  description = "Gets the sample at the specified position.",
		  returns = "(sample: number)",
		  type = "function"
		 },
		 getSampleCount = {
		  args = "()",
		  description = "Returns the number of samples per channel of the SoundData.",
		  returns = "(count: number)",
		  type = "function"
		 },
		 getSampleRate = {
		  args = "()",
		  description = "Returns the sample rate of the SoundData.",
		  returns = "(rate: number)",
		  type = "function"
		 },
		 setSample = {
		  args = "(i: number, sample: number)",
		  description = "Sets the sample at the specified position.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "Contains raw audio samples. You can not play SoundData back directly. You must wrap a Source object around it.",
		inherits = "Data",
		type = "class"
	   },
	   newSoundData = {
		args = "(filename: string)",
		description = "Creates new SoundData from a file. It's also possible to create SoundData with a custom sample rate, channel and bit depth.\n\nThe sound data will be decoded to the memory in a raw format. It is recommended to create only short sounds like effects, as a 3 minute song uses 30 MB of memory this way.",
		returns = "(soundData: SoundData)",
		type = "function"
	   }
	  },
	  description = "This module is responsible for decoding sound files. It can't play the sounds, see love.audio for that.",
	  type = "class"
	 },
	 system = {
	  childs = {
	   PowerState = {
		childs = {
		 battery = {
		  description = "Not plugged in, running on a battery.",
		  type = "value"
		 },
		 charged = {
		  description = "Plugged in, battery is fully charged.",
		  type = "value"
		 },
		 charging = {
		  description = "Plugged in, charging battery.",
		  type = "value"
		 },
		 nobattery = {
		  description = "Plugged in, no battery available.",
		  type = "value"
		 },
		 unknown = {
		  description = "Cannot determine power status.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   getOS = {
		args = "()",
		description = "Gets the current operating system. In general, LÖVE abstracts away the need to know the current operating system, but there are a few cases where it can be useful (especially in combination with os.execute.)",
		returns = "(osString: string)",
		type = "function"
	   },
	   getPowerInfo = {
		args = "()",
		description = "Gets information about the system's power supply.",
		returns = "(state: PowerState, percent: number, seconds: number)",
		type = "function"
	   },
	   getProcessorCount = {
		args = "()",
		description = "Gets the amount of logical processor in the system.",
		returns = "(processorCount: number)",
		type = "function"
	   },
	   openURL = {
		args = "(url: string)",
		description = "Opens a URL with the user's web or file browser.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   setClipboardText = {
		args = "(text: string)",
		description = "Puts text in the clipboard.",
		returns = "()",
		type = "function"
	   },
	   vibrate = {
		args = "(seconds: number)",
		description = "Causes the device to vibrate, if possible. Currently this will only work on Android and iOS devices that have a built-in vibration motor.",
		returns = "()",
		type = "function"
	   }
	  },
	  description = "Provides access to information about the user's system.",
	  type = "lib"
	 },
	 textedited = {
	  args = "(text: string, start: number, length: number)",
	  description = "Called when the candidate text for an IME (Input Method Editor) has changed.\n\nThe candidate text is not the final text that the user will eventually choose. Use love.textinput for that.",
	  returns = "()",
	  type = "function"
	 },
	 textinput = {
	  args = "(text: string)",
	  description = "Called when text has been entered by the user. For example if shift-2 is pressed on an American keyboard layout, the text \"@\" will be generated.",
	  returns = "()",
	  type = "function"
	 },
	 thread = {
	  childs = {
	   Channel = {
		childs = {
		 demand = {
		  args = "(timeout: number)",
		  description = "Retrieves the value of a Channel message and removes it from the message queue.\n\nIt waits until a message is in the queue then returns the message value.",
		  returns = "(value: Variant)",
		  type = "function"
		 },
		 getCount = {
		  args = "()",
		  description = "Retrieves the number of messages in the thread Channel queue.",
		  returns = "(count: number)",
		  type = "function"
		 },
		 hasRead = {
		  args = "(id: number)",
		  description = "Gets whether a pushed value has been popped or otherwise removed from the Channel.",
		  returns = "(hasread: boolean)",
		  type = "function"
		 },
		 peek = {
		  args = "()",
		  description = "Retrieves the value of a Channel message, but leaves it in the queue.\n\nIt returns nil if there's no message in the queue.",
		  returns = "(value: Variant)",
		  type = "function"
		 },
		 performAtomic = {
		  args = "(func: function, arg1: any, ...: any)",
		  description = "Executes the specified function atomically with respect to this Channel.\n\nCalling multiple methods in a row on the same Channel is often useful. However if multiple Threads are calling this Channel's methods at the same time, the different calls on each Thread might end up interleaved (e.g. one or more of the second thread's calls may happen in between the first thread's calls.)\n\nThis method avoids that issue by making sure the Thread calling the method has exclusive access to the Channel until the specified function has returned.",
		  returns = "(ret1: any, ...: any)",
		  type = "function"
		 },
		 pop = {
		  args = "()",
		  description = "Retrieves the value of a Channel message and removes it from the message queue.\n\nIt returns nil if there are no messages in the queue.",
		  returns = "(value: Variant)",
		  type = "function"
		 },
		 push = {
		  args = "(value: Variant)",
		  description = "Send a message to the thread Channel.\n\nSee Variant for the list of supported types.",
		  returns = "()",
		  type = "function"
		 },
		 supply = {
		  args = "(value: Variant)",
		  description = "Send a message to the thread Channel and wait for a thread to accept it.\n\nSee Variant for the list of supported types.",
		  returns = "(success: boolean)",
		  type = "function"
		 }
		},
		description = "A channel is a way to send and receive data to and from different threads.",
		inherits = "Object",
		type = "class"
	   },
	   Thread = {
		childs = {
		 isRunning = {
		  args = "()",
		  description = "Returns whether the thread is currently running.\n\nThreads which are not running can be (re)started with Thread:start.",
		  returns = "(running: boolean)",
		  type = "function"
		 },
		 start = {
		  args = "(arg1: Variant, arg2: Variant, ...: Variant)",
		  description = "Starts the thread.\n\nThreads can be restarted after they have completed their execution.",
		  returns = "()",
		  type = "function"
		 },
		 wait = {
		  args = "()",
		  description = "Wait for a thread to finish. This call will block until the thread finishes.",
		  returns = "()",
		  type = "function"
		 }
		},
		description = "A Thread is a chunk of code that can run in parallel with other threads. Data can be sent between different threads with Channel objects.",
		inherits = "Object",
		type = "class"
	   },
	   newChannel = {
		args = "()",
		description = "Create a new unnamed thread channel.\n\nOne use for them is to pass new unnamed channels to other threads via Channel:push",
		returns = "(channel: Channel)",
		type = "function"
	   },
	   newThread = {
		args = "(filename: string)",
		description = "Creates a new Thread from a File or Data object.",
		returns = "(thread: Thread)",
		type = "function"
	   }
	  },
	  description = "Allows you to work with threads.\n\nThreads are separate Lua environments, running in parallel to the main code. As their code runs separately, they can be used to compute complex operations without adversely affecting the frame rate of the main thread. However, as they are separate environments, they cannot access the variables and functions of the main thread, and communication between threads is limited.\n\nAll LOVE objects (userdata) are shared among threads so you'll only have to send their references across threads. You may run into concurrency issues if you manipulate an object on multiple threads at the same time.\n\nWhen a Thread is started, it only loads the love.thread module. Every other module has to be loaded with require.",
	  type = "class"
	 },
	 threaderror = {
	  args = "(thread: Thread, errorstr: string)",
	  description = "Callback function triggered when a Thread encounters an error.",
	  returns = "()",
	  type = "function"
	 },
	 timer = {
	  childs = {
	   getDelta = {
		args = "()",
		description = "Returns the time between the last two frames.",
		returns = "(dt: number)",
		type = "function"
	   },
	   getFPS = {
		args = "()",
		description = "Returns the current frames per second.",
		returns = "(fps: number)",
		type = "function"
	   },
	   getTime = {
		args = "()",
		description = "Returns the value of a timer with an unspecified starting time. This function should only be used to calculate differences between points in time, as the starting time of the timer is unknown.",
		returns = "(time: number)",
		type = "function"
	   },
	   sleep = {
		args = "(s: number)",
		description = "Sleeps the program for the specified amount of time.",
		returns = "()",
		type = "function"
	   },
	   step = {
		args = "()",
		description = "Measures the time between two frames. Calling this changes the return value of love.timer.getDelta.",
		returns = "(dt: number)",
		type = "function"
	   }
	  },
	  description = "Provides an interface to the user's clock.",
	  type = "lib"
	 },
	 touch = {
	  childs = {
	   getPressure = {
		args = "(id: light userdata)",
		description = "Gets the current pressure of the specified touch-press.",
		returns = "(pressure: number)",
		type = "function"
	   },
	   getTouches = {
		args = "()",
		description = "Gets a list of all active touch-presses.",
		returns = "(touches: table)",
		type = "function"
	   }
	  },
	  description = "Provides an interface to touch-screen presses.",
	  type = "lib"
	 },
	 touchmoved = {
	  args = "(id: light userdata, x: number, y: number, dx: number, dy: number, pressure: number)",
	  description = "Callback function triggered when a touch press moves inside the touch screen.",
	  returns = "()",
	  type = "function"
	 },
	 touchpressed = {
	  args = "(id: light userdata, x: number, y: number, dx: number, dy: number, pressure: number)",
	  description = "Callback function triggered when the touch screen is touched.",
	  returns = "()",
	  type = "function"
	 },
	 touchreleased = {
	  args = "(id: light userdata, x: number, y: number, dx: number, dy: number, pressure: number)",
	  description = "Callback function triggered when the touch screen stops being touched.",
	  returns = "()",
	  type = "function"
	 },
	 update = {
	  args = "(dt: number)",
	  description = "Callback function used to update the state of the game every frame.",
	  returns = "()",
	  type = "function"
	 },
	 video = {
	  childs = {
	   VideoStream = {
		description = "An object which decodes, streams, and controls Videos.",
		inherits = "Object",
		type = "class"
	   },
	   newVideoStream = {
		args = "(filename: string)",
		description = "Creates a new VideoStream. Currently only Ogg Theora video files are supported. VideoStreams can't draw videos, see love.graphics.newVideo for that.",
		returns = "(videostream: VideoStream)",
		type = "function"
	   }
	  },
	  description = "This module is responsible for decoding, controlling, and streaming video files.\n\nIt can't draw the videos, see love.graphics.newVideo and Video objects for that.",
	  type = "class"
	 },
	 visible = {
	  args = "(visible: boolean)",
	  description = "Callback function triggered when window is minimized/hidden or unminimized by the user.",
	  returns = "()",
	  type = "function"
	 },
	 wheelmoved = {
	  args = "(x: number, y: number)",
	  description = "Callback function triggered when the mouse wheel is moved.",
	  returns = "()",
	  type = "function"
	 },
	 window = {
	  childs = {
	   FullscreenType = {
		childs = {
		 desktop = {
		  description = "Sometimes known as borderless fullscreen windowed mode. A borderless screen-sized window is created which sits on top of all desktop UI elements. The window is automatically resized to match the dimensions of the desktop, and its size cannot be changed.",
		  type = "value"
		 },
		 exclusive = {
		  description = "Standard exclusive-fullscreen mode. Changes the display mode (actual resolution) of the monitor.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   MessageBoxType = {
		childs = {
		 error = {
		  description = "Error dialog.",
		  type = "value"
		 },
		 info = {
		  description = "Informational dialog.",
		  type = "value"
		 },
		 warning = {
		  description = "Warning dialog.",
		  type = "value"
		 }
		},
		description = "class constants",
		type = "class"
	   },
	   fromPixels = {
		args = "(pixelvalue: number)",
		description = "Converts a number from pixels to density-independent units.\n\nThe pixel density inside the window might be greater (or smaller) than the \"size\" of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.fromPixels(1600) would return 800 in that case.\n\nThis function converts coordinates from pixels to the size users are expecting them to display at onscreen. love.window.toPixels does the opposite. The highdpi window flag must be enabled to use the full pixel density of a Retina screen on Mac OS X and iOS. The flag currently does nothing on Windows and Linux, and on Android it is effectively always enabled.\n\nMost LÖVE functions return values and expect arguments in terms of pixels rather than density-independent units.",
		returns = "(value: number)",
		type = "function"
	   },
	   getDPIScale = {
		args = "()",
		description = "Gets the DPI scale factor associated with the window.\n\nThe pixel density inside the window might be greater (or smaller) than the \"size\" of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.getDPIScale() would return 2.0 in that case.\n\nThe love.window.fromPixels and love.window.toPixels functions can also be used to convert between units.\n\nThe highdpi window flag must be enabled to use the full pixel density of a Retina screen on Mac OS X and iOS. The flag currently does nothing on Windows and Linux, and on Android it is effectively always enabled.",
		returns = "(scale: number)",
		type = "function"
	   },
	   getDisplayName = {
		args = "(displayindex: number)",
		description = "Gets the name of a display.",
		returns = "(name: string)",
		type = "function"
	   },
	   getFullscreen = {
		args = "()",
		description = "Gets whether the window is fullscreen.",
		returns = "(fullscreen: boolean, fstype: FullscreenType)",
		type = "function"
	   },
	   getFullscreenModes = {
		args = "(display: number)",
		description = "Gets a list of supported fullscreen modes.",
		returns = "(modes: table)",
		type = "function"
	   },
	   getIcon = {
		args = "()",
		description = "Gets the window icon.",
		returns = "(imagedata: ImageData)",
		type = "function"
	   },
	   getMode = {
		args = "()",
		description = "Returns the current display mode.",
		returns = "(width: number, height: number, flags: table)",
		type = "function"
	   },
	   getPixelScale = {
		args = "()",
		description = "Gets the DPI scale factor associated with the window.\n\nThe pixel density inside the window might be greater (or smaller) than the \"size\" of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.getPixelScale() would return 2.0 in that case.\n\nThe love.window.fromPixels and love.window.toPixels functions can also be used to convert between units.\n\nThe highdpi window flag must be enabled to use the full pixel density of a Retina screen on Mac OS X and iOS. The flag currently does nothing on Windows and Linux, and on Android it is effectively always enabled.",
		returns = "(scale: number)",
		type = "function"
	   },
	   getPosition = {
		args = "()",
		description = "Gets the position of the window on the screen.\n\nThe window position is in the coordinate space of the display it is currently in.",
		returns = "(x: number, y: number, display: number)",
		type = "function"
	   },
	   getTitle = {
		args = "()",
		description = "Gets the window title.",
		returns = "(title: string)",
		type = "function"
	   },
	   hasFocus = {
		args = "()",
		description = "Checks if the game window has keyboard focus.",
		returns = "(focus: boolean)",
		type = "function"
	   },
	   hasMouseFocus = {
		args = "()",
		description = "Checks if the game window has mouse focus.",
		returns = "(focus: boolean)",
		type = "function"
	   },
	   isDisplaySleepEnabled = {
		args = "()",
		description = "Gets whether the display is allowed to sleep while the program is running.\n\nDisplay sleep is disabled by default. Some types of input (e.g. joystick button presses) might not prevent the display from sleeping, if display sleep is allowed.",
		returns = "(enabled: boolean)",
		type = "function"
	   },
	   isMaximized = {
		args = "()",
		description = "Gets whether the Window is currently maximized.\n\nThe window can be maximized if it is not fullscreen and is resizable, and either the user has pressed the window's Maximize button or love.window.maximize has been called.",
		returns = "(maximized: boolean)",
		type = "function"
	   },
	   isMinimized = {
		args = "()",
		description = "Gets whether the Window is currently minimized.",
		returns = "(maximized: boolean)",
		type = "function"
	   },
	   isOpen = {
		args = "()",
		description = "Checks if the window is open.",
		returns = "(open: boolean)",
		type = "function"
	   },
	   isVisible = {
		args = "()",
		description = "Checks if the game window is visible.\n\nThe window is considered visible if it's not minimized and the program isn't hidden.",
		returns = "(visible: boolean)",
		type = "function"
	   },
	   maximize = {
		args = "()",
		description = "Makes the window as large as possible.\n\nThis function has no effect if the window isn't resizable, since it essentially programmatically presses the window's \"maximize\" button.",
		returns = "()",
		type = "function"
	   },
	   minimize = {
		args = "()",
		description = "Minimizes the window to the system's task bar / dock.",
		returns = "()",
		type = "function"
	   },
	   requestAttention = {
		args = "(continuous: boolean)",
		description = "Causes the window to request the attention of the user if it is not in the foreground.\n\nIn Windows the taskbar icon will flash, and in OS X the dock icon will bounce.",
		returns = "()",
		type = "function"
	   },
	   restore = {
		args = "()",
		description = "Restores the size and position of the window if it was minimized or maximized.",
		returns = "()",
		type = "function"
	   },
	   setDisplaySleepEnabled = {
		args = "(enable: boolean)",
		description = "Sets whether the display is allowed to sleep while the program is running.\n\nDisplay sleep is disabled by default. Some types of input (e.g. joystick button presses) might not prevent the display from sleeping, if display sleep is allowed.",
		returns = "()",
		type = "function"
	   },
	   setFullscreen = {
		args = "(fullscreen: boolean)",
		description = "Enters or exits fullscreen. The display to use when entering fullscreen is chosen based on which display the window is currently in, if multiple monitors are connected.\n\nIf fullscreen mode is entered and the window size doesn't match one of the monitor's display modes (in normal fullscreen mode) or the window size doesn't match the desktop size (in 'desktop' fullscreen mode), the window will be resized appropriately. The window will revert back to its original size again when fullscreen mode is exited using this function.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   setIcon = {
		args = "(imagedata: ImageData)",
		description = "Sets the window icon until the game is quit. Not all operating systems support very large icon images.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   setMode = {
		args = "(width: number, height: number, flags: table)",
		description = "Sets the display mode and properties of the window.\n\nIf width or height is 0, setMode will use the width and height of the desktop.\n\nChanging the display mode may have side effects: for example, canvases will be cleared and values sent to shaders with Shader:send will be erased. Make sure to save the contents of canvases beforehand or re-draw to them afterward if you need to.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   setPosition = {
		args = "(x: number, y: number, display: number)",
		description = "Sets the position of the window on the screen.\n\nThe window position is in the coordinate space of the specified display.",
		returns = "()",
		type = "function"
	   },
	   setTitle = {
		args = "(title: string)",
		description = "Sets the window title.",
		returns = "()",
		type = "function"
	   },
	   showMessageBox = {
		args = "(title: string, message: string, type: MessageBoxType, attachtowindow: boolean)",
		description = "Displays a message box dialog above the love window. The message box contains a title, optional text, and buttons.",
		returns = "(success: boolean)",
		type = "function"
	   },
	   toPixels = {
		args = "(value: number)",
		description = "Converts a number from density-independent units to pixels.\n\nThe pixel density inside the window might be greater (or smaller) than the \"size\" of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.toPixels(800) would return 1600 in that case.\n\nThis is used to convert coordinates from the size users are expecting them to display at onscreen to pixels. love.window.fromPixels does the opposite. The highdpi window flag must be enabled to use the full pixel density of a Retina screen on Mac OS X and iOS. The flag currently does nothing on Windows and Linux, and on Android it is effectively always enabled.\n\nMost LÖVE functions return values and expect arguments in terms of pixels rather than density-independent units.",
		returns = "(pixelvalue: number)",
		type = "function"
	   },
	   updateMode = {
		args = "(width: number, height: number, settings: table)",
		description = "Sets the display mode and properties of the window, without modifying unspecified properties.\n\nIf width or height is 0, updateMode will use the width and height of the desktop.\n\nChanging the display mode may have side effects: for example, canvases will be cleared. Make sure to save the contents of canvases beforehand or re-draw to them afterward if you need to.",
		returns = "(success: boolean)",
		type = "function"
	   }
	  },
	  description = "Provides an interface for modifying and retrieving information about the program's window.",
	  type = "lib"
	 }
	},
	description = "Love2d modules, functions, and callbacks.",
	type = "lib",
	version = "11.1"
   }

lib.love = love


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

local indent = 0

local function get_declarations(k, v)
	local out = {}
	v.args = v.args:gsub("function", "empty_function")
	v.returns = v.returns:gsub("function", "empty_function")


	if v.returns == "()" then
		v.returns = "(nil)"
	end

	v.returns = strip(v.returns:sub(2,-2):gsub("%[", ""):gsub("%]", "|nil"))
	v.returns = v.returns:gsub("%S+:%s*(%S+)", "%1")

	v.args = v.args:gsub("light userdata", "light_userdata")
	v.args = v.args:gsub("table meta", "table")
	v.args = v.args:gsub("cdata init", "cdata")
	v.args = v.args:gsub("number len", "number")
	v.args = v.args:gsub("local", "local_")

	if v.args:find("/") then
		if k == "new" then
			v.args = "(ctype, number, ...)"
		elseif k == "copy" then
			v.args = "(cdata, [cdata, number])"
		end
	end

	local str = {}

	for i, args in ipairs(get_overloads(v.args)) do
		if args:find("...", nil, true) then
			args = args:gsub("(%.%.%.: %S+)%)", "%1[])")
		end

		table.insert(str,  "\n" .. ("\t"):rep(indent+1) .."(function" .. args .. ": " .. v.returns .. ")")
	end

	table.insert(out, ("\t"):rep(indent) .. k .. " = " .. table.concat(str, " | "))

	return out
end


local str = {}

local interfaces = {}

local function walk(key, tbl)
	table.insert(str, ("\t"):rep(indent) .. key .. " = {")

	for lib, data in pairs(tbl) do
		if data.type == "function" then
			indent = indent + 1
			for i,v in ipairs(get_declarations(lib, data)) do
				table.insert(str, v .. ",")
			end
			indent = indent - 1
		end
	end

	for lib, data in pairs(tbl) do
		if data.childs then
			indent = indent + 1
			walk(lib, data.childs)
			indent = indent - 1
		end
	end

	table.insert(str, ("\t"):rep(indent) .. "},")
end

walk("_G", lib)

local lua = ""

lua = lua .. [[
local type empty_function = function(...): any

]]
lua = lua .. "type " .. table.concat(str, "\n")
lua = lua .. [[

	type _G._G = _G

	type _G.string.match = function(s, pattern, init)
		if s.value and pattern.value then
			local res = {s.value:match(pattern.value)}
			for i,v in ipairs(res) do
				res[i] = types.Type("string", v)
			end
			return unpack(res)
		end

		if pattern.value then
			local out = {}
			for s in pattern.value:gmatch("%b()") do
				table.insert(out, types.Type("string") + types.Type("nil"))
			end
			return unpack(out)
		end
	end

	type _G.type_assert = function(what, type, value, ...)
		if not what:IsType(type) then
			error("expected type " .. tostring(type) .." got " .. tostring(what))
		end

		if type.value ~= nil then
			if what.value ~= type.value then
				print(what, type, value)
				error("expected type value " .. tostring(type) .." got " .. tostring(what))
			end
		end
	end

	type _G.next = function(tbl, _)
		local T = tbl
		if not tbl then return T:Type("any"), T:Type("any") end
		local key, val

		for _, tbl in ipairs(tbl.types or {tbl}) do
			if tbl.value then
				for k, v in pairs(tbl.value) do
					if not key then
						if types.IsTypeObject(k) then
							key = k
						else
							key = T:Type(type(k))
						end
					else
						if types.IsTypeObject(k) then
							key = types.Fuse(key, k)
						elseif type(k) == "string" then
							key = types.Fuse(key, T:Type("string"))
						elseif type(k) == "number" then
							key = types.Fuse(key, T:Type("number"))
						elseif not key:IsType(k) then
							key = types.Fuse(key, T:Type(k.name))
						end
					end

					if not val then
						if types.IsTypeObject(v) then
							val = v
						else
							val = T:Type(type(v))
						end
					else
						if types.IsTypeObject(v) then
							val = types.Fuse(val, v)
						elseif not val:IsType(v) then
							val = types.Fuse(val, T:Type(v.name))
						end
					end
				end
			end
		end

		return key, val
	end

	type _G.pairs = function(tbl)
		local next = analyzer:GetValue("next", "typesystem")
		return next, tbl, nil
	end

	type _G.ipairs = function(tbl)
		local next = analyzer:GetValue("next", "typesystem")
		return next, tbl, nil
	end

	type _G.require = function(name)
		local str = name.value

		if analyzer:GetValue(str, "typesystem") then
			return analyzer:GetValue(str, "typesystem")
		end

		for _, searcher in ipairs(package.loaders) do
			local loader = searcher(str)
			if type(loader) == "function" then
				local path = debug.getinfo(loader).source
				if path:sub(1, 1) == "@" then
					local path = path:sub(2)

					local ast = assert(require("oh").FileToAST(path))
					analyzer:AnalyzeStatement(ast)

					return unpack(analyzer.last_return)
				end
			end
		end

		error("unable to find module " .. str)
	end

	type _G.table.insert = function(tbl, ...)
		local pos, val = ...

		if not val then
			val = ...
			pos = #tbl.value + 1
		else
			pos = pos.value
		end

		local l = types.Type("list")

		local list_type = tbl.list_type

		for k,v in pairs(tbl) do
			if k ~= "value" then
				tbl[k] = nil
			end
		end

		for k,v in pairs(l) do
			tbl[k] = v
		end

		table.insert(tbl.value, pos, val)

		if list_type then
			list_type = list_type + val
		end

		tbl.list_type = list_type or val
		tbl.length = pos
	end

	type _G.TPRINT = function(...) print(...) end


    type _G.table.sort = function(tbl, func)
        local next = oh.GetBaseAnalyzeer():GetValue("_G", "typesystem"):get("next").func
        local k,v = next(tbl)
        func.arguments[1] = v
        func.arguments[2] = v
    end
]]
lua = lua:gsub("\t", "    ")

local oh = require("oh")
local Analyzer = require("oh.analyzer")
local base = Analyzer()
base.Index = nil

base:AnalyzeStatement(assert(oh.Code(lua, "base_library"):Parse()).SyntaxTree)

io.open("oh/base_lib.oh", "w"):write(lua)

