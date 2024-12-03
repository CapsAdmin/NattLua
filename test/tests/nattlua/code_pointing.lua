local formating = require("nattlua.other.formating")

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
	equal(
		formating.BuildSourceCodePointMessage(test, "script.txt", "hello world", start, stop, 3),
		[[    ____________________________________________________
 2 | wad
 3 | 111111E
 4 |     waddwa
 5 |     FROM>baradwadwwda HERE awd wdadwa<TOwawaddawdaw
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
 6 |     22222E
 7 | new
 8 | ewww
    ----------------------------------------------------
-> | script.txt:5:5
-> | hello world]]
	)
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
	equal(
		formating.BuildSourceCodePointMessage(test, "script.txt", "hello world", start, stop, 3),
		[[     _____________________________________
  2 | wad
  3 | 111111E
  4 |     waddwa
  5 |     FROM>baradwadwwda HE
          ^^^^^^^^^^^^^^^^^^^^
  6 |     
      ^^^^
  7 |     
      ^^^^
  8 |     RE awd wdadwa<TOwawaddawdawafter
      ^^^^^^^^^^^^^^^^^^^^
  9 |     22222E
 10 | new
 11 | ewww
     -------------------------------------
 -> | script.txt:5:5
 -> | hello world]]
	)
end

do
	local test = ("x"):rep(50) .. "FROM---TO" .. ("x"):rep(50)
	local start, stop = test:find("FROM.-TO")
	equal(
		formating.BuildSourceCodePointMessage(test, "script.txt", "hello world", start, stop, 2),
		[[    ______________________________________________________________________________________________________________
 1 | xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxFROM---TOxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
                                                       ^^^^^^^^^
    --------------------------------------------------------------------------------------------------------------
-> | script.txt:1:51
-> | hello world]]
	)
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
	equal(
		formating.BuildSourceCodePointMessage(str, "script.txt", "hello world", start, stop, 3),
		[[     ______________________________________________
 47 |         foo
 48 |         foo
 49 |         foo
 50 |                                     FROM---TO
                                          ^^^^^^^^^
 51 |         foo
 52 |         foo
 53 |         foo
     ----------------------------------------------
 -> | script.txt:50:10
 -> | hello world]]
	)
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
	equal(
		formating.BuildSourceCodePointMessage(str, "script.txt", "hello world", start, stop, 1),
		[[     ______________________________________________
 49 |         foo
 50 |                                     FROM---TO
                                          ^^^^^^^^^
 51 |         foo
     ----------------------------------------------
 -> | script.txt:50:10
 -> | hello world]]
	)
end

do
	local str = [[local function foo(a, b)
	return a + b
end

local function deferred_func()
	foo()
end
]]
	equal(
		formating.BuildSourceCodePointMessage(str, "test", "aaa", 34, 38, 3),
		[[    _______________________________
 1 | local function foo(a, b)
 2 |     return a + b
                ^^^^^
 3 | end
 4 | 
 5 | local function deferred_func()
    -------------------------------
-> | test:2:9
-> | aaa]]
	)
end
