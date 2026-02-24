local formating = require("nattlua.other.formating")
-- Disable ANSI color output for tests: we compare plain text strings
formating.SetColor(false)

for _, formating_SubPosToLineChar in ipairs({formating.SubPosToLineChar, formating.SubPosToLineCharCached}) do
	do
		local test = [[1]]
		local data = formating_SubPosToLineChar(test, 1, 1)
		equal(data.line_start, 1)
		equal(data.line_stop, 1)
		equal(data.character_start, 1)
		equal(data.character_stop, 1)
	end

	do
		local test = [[foo
bar
faz]]
		local start, stop = test:find("bar")
		local data = formating_SubPosToLineChar(test, start, stop)
		equal(data.line_start, 2)
		equal(data.line_stop, 2)
		equal(data.character_start, 1)
		equal(data.character_stop, 3)
	end

	do
		local test = [[foo
bar
faz]]
		local data = formating_SubPosToLineChar(test, 1, #test)
		equal(data.line_start, 1)
		equal(data.line_stop, 3)
		equal(data.character_start, 1)
		equal(data.character_stop, 3)
	end

	do
		local test = [[foo
bar
faz]]
		local start, stop = test:find("faz")
		equal(test:sub(start, stop), "faz")
		local data = formating_SubPosToLineChar(test, start, stop)
		equal(data.line_start, 3)
		equal(data.line_stop, 3)
		equal(data.character_start, 1)
		equal(data.character_stop, 3)
	end
end

-- Helper: assert output contains all given plain substrings
local function contains(output, ...)
	for _, s in ipairs({...}) do
		if not output:find(s, 1, true) then
			error(
				"expected output to contain:\n  " .. tostring(s) .. "\nbut got:\n" .. tostring(output),
				2
			)
		end
	end
end

do
	local test = [[foo
wad
111111E
    waddwa
    FROM>baradwadwwda HERE awd wdadwa<TOwawaddawdaw
    22222E
new
ewww
faz]]
	local start, stop = test:find("FROM.-TO")
	local out = formating.BuildSourceCodePointMessage(test, "script.txt", "hello world", start, stop, 3)
	-- correct source lines shown with line numbers
	contains(out, " 2 | wad")
	contains(out, " 5 |     FROM>baradwadwwda HERE awd wdadwa<TOwawaddawdaw")
	contains(out, " 8 | ewww")
	-- carets present
	contains(out, "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
	-- path and message present
	contains(out, "script.txt:5:5")
	contains(out, "hello world")
end

do
	local test = [[foo
wad
111111E
    waddwa
    FROM>baradwadwwda HE
    
    
    RE awd wdadwa<TOwawaddawdawafter
    22222E
new
ewww
faz]]
	local start, stop = test:find("FROM.-TO")
	local out = formating.BuildSourceCodePointMessage(test, "script.txt", "hello world", start, stop, 3)
	-- correct source lines shown across the multi-line span
	contains(out, "  5 |     FROM>baradwadwwda HE")
	contains(out, "  8 |     RE awd wdadwa<TOwawaddawdawafter")
	-- carets on every spanned source line
	contains(out, "^^^^^^^^^^^^^^^^^^^^")
	contains(out, "script.txt:5:5")
	contains(out, "hello world")
end

do
	local test = ("x"):rep(50) .. "FROM---TO" .. ("x"):rep(50)
	local start, stop = test:find("FROM.-TO")
	local out = formating.BuildSourceCodePointMessage(test, "script.txt", "hello world", start, stop, 2)
	-- long line is truncated with ellipsis but FROM---TO is kept
	contains(out, "FROM---TO")
	contains(out, "...")
	contains(out, "^^^^^^^^^")
	contains(out, "script.txt:1:51")
	contains(out, "hello world")
end

do
	local test = [[]]
	local pos = formating.LineCharToSubPos(test, 2, 6)
	equal(pos, #test)
end

do
	local test = [[foo]]
	local pos = formating.LineCharToSubPos(test, 2, 6)
	equal(pos, #test)
end

do
	local test = [[foo]]
	local pos = formating.LineCharToSubPos(test, 1, 1)
	equal(pos, 1)
end

do
	local test = [[foo]]
	local pos = formating.LineCharToSubPos(test, 0, 0)
	equal(pos, 1)
end

do
	local test = [[foo]]
	local pos = formating.LineCharToSubPos(test, 1, 2)
	equal(pos, 2)
end

do
	local test = [[foo
wddwaFOOdawdaw
dwadawadwdaw
dwdwadw
]]
	local pos = formating.LineCharToSubPos(test, 2, 6)
	local start = pos
	local stop = pos + #"FOO" - 1
	equal(test:sub(start, stop), "FOO")
end

do
	local test = "\tfoo\n\tbar"
	local C = function(l, c)
		local pos = formating.LineCharToSubPos(test, l, c)
		return test:sub(pos, pos)
	end
	equal(C(1, 1), "\t")
	equal(C(1, 2), "f")
	equal(C(1, 3), "o")
	equal(C(1, 4), "o")
	equal(C(1, 5), "o") -- don't go above the newline
	equal(C(2, 1), "\t")
	equal(C(2, 2), "b")
	equal(C(2, 3), "a")
	equal(C(2, 4), "r")
	equal(C(2, 5), "r") -- don't go above the newline
end

do
	local str = ""

	for i = 1, 100 do
		if i == 50 then
			str = str .. "\t\t\t\t\t\t\t\t\tFROM---TO\n"
		else
			str = str .. "\t\tfoo\n"
		end
	end

	local start, stop = str:find("FROM.-TO")
	local out = formating.BuildSourceCodePointMessage(str, "script.txt", "hello world", start, stop, 3)
	-- context lines visible
	contains(out, " 47 |         foo")
	contains(out, " 53 |         foo")
	-- highlighted line with token
	contains(out, " 50 |")
	contains(out, "FROM---TO")
	-- carets
	contains(out, "^^^^^^^^^")
	-- path uses correct tab-expanded column
	contains(out, "script.txt:50:10")
	contains(out, "hello world")
end

do
	local str = ""

	for i = 1, 100 do
		if i == 50 then
			str = str .. "\t\t\t\t\t\t\t\t\tFROM---TO\n"
		else
			str = str .. "\t\tfoo\n"
		end
	end

	local start, stop = str:find("FROM.-TO")
	local out = formating.BuildSourceCodePointMessage(str, "script.txt", "hello world", start, stop, 1)
	-- only 1 context line each side
	contains(out, " 49 |         foo")
	contains(out, " 51 |         foo")
	contains(out, " 50 |")
	contains(out, "FROM---TO")
	contains(out, "^^^^^^^^^")
	contains(out, "script.txt:50:10")
	contains(out, "hello world")
end

do
	local str = [[local function foo(a, b)
	return a + b
end

local function deferred_func()
	foo()
end
]]
	local out = formating.BuildSourceCodePointMessage(str, "test", "aaa", 34, 38, 3)
	-- the highlighted line and its content
	contains(out, " 2 |")
	contains(out, "return a + b")
	-- carets span "a + b" (5 chars)
	contains(out, "^^^^^")
	-- path and message
	contains(out, "test:2:9")
	contains(out, "aaa")
end

do
	-- Token that IS a tab character: the ^ must cover all 4 expanded spaces,
	-- not just the last one (bug: char_start was captured after tab expansion).
	local test = "\tFOO"
	local start, stop = 1, 1
	local out = formating.BuildSourceCodePointMessage(test, nil, "tab token", start, stop, 0)
	-- source line shows tab expanded to spaces
	contains(out, " 1 |")
	contains(out, "FOO")
	-- 4 carets for the tab-width expansion
	contains(out, "^^^^")
	contains(out, "tab token")
end

do
	-- Token at the very end of the string (no trailing newline): the flush that
	-- happens at i==#local_str must not zero out char_start before it is captured.
	local test = "abc"
	local start, stop = 3, 3
	local out = formating.BuildSourceCodePointMessage(test, nil, "last char", start, stop, 0)
	contains(out, " 1 | abc")
	contains(out, "^")
	contains(out, "last char")
end

do
	-- When the span sits inside a very long line the context around it must
	-- be truncated with '...' markers so the output stays within
	-- MAX_CONTENT_WIDTH (100) columns.  The span itself ('HELLO') is kept
	-- intact; 45 chars of context from `before` and 44 from `after` are shown.
	local pre = ("a"):rep(60)
	local between = "HELLO"
	local post = ("z"):rep(60)
	local code = pre .. between .. post
	local s, e = #pre + 1, #pre + #between
	local out = formating.BuildSourceCodePointMessage2(code, s, e, {messages = {"long span test"}})
	-- token is preserved intact
	contains(out, "HELLO")
	-- ellipsis truncation applied
	contains(out, "...")
	-- carets span HELLO (5 chars)
	contains(out, "^^^^^")
	contains(out, "long span test")
end
