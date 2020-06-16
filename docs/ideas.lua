--[[other ideas
    string annotations, to allow lua inline strings, regex, pattern matching, ettc for syntax highlkighting

    " "regex
]]


-- how to best represent function overloading?

-- can a Map<Tuple, Tuple> serve as a way to deal with overloaded functions?
local type func = {
    [(string, number)] = ("foo!"),
    [(number, string)] = ("bar!"),
}
-- but what happens if you do local tbl: func and

-- a more traditional set
local type func = (function(string, number): ("foo!")) | (function(number, string): ("bar!"))

assert(func("", 0) == "foo!")
assert(func(0, "") == "bar!")

any:
    number = -math.huge .. math.huge | math.nan
    string = *all possible string values*
    boolean = true | false
    table = *all possible table values*
    function = *all possible function types*
        (string): string


type pcall = function(function, ...): (boolean, ...)

type tuple = (string, number)
type lol = tuple -> tuple
type lol = function(a,b,c) return a,b,c end




-- true, number, string, userdata, object
-- false, nil


-- text instead of string?

type boolean = true | false
type truthy = true | string | number | function | table
type falsey = false | nil
type object = userdata | table | cdata
type integer<T> math.ceil(T) == T
type list<T> = {}
type xyz = [number, number, number]

type a = string | 1 | 2 -- represent all string values and the nunmbers 2 and 3
type a = 1 .. 10 -- represent numbers from 1 to 10
type a = $"%d" -- represent strings that contain a digit
type OneToTen<T> = T > 1 and T < 10
type PowerOfTwo<T> = (T & (T - 1)) == 1
type a = function(T) end

type events = "Update" | "Draw" | "Initialize" | "Shutdown"

type events.AddListener = function(name) * extend events.AddListener function type * end
events.AddListener(event: events, function()

end)


type event.Call = function(name, ...) events = events + name end
event.Call("Update", system.GetFrameTime())

local pos: xyz = ent:GetPosition()




local a: OneToTen = 11 -- Cannot satisify value
local a: PowOf2 = 4


local lol = function(n: number) assert(n > 1 and T < 10, "expected number above 1 and below 10") return n + 2 end
lol(20) -- assertion failed: expected number above 1 and below 10

local type OneToTen = function(T) return T>1 and T<10 and T or error("expected number above 1 and below 10") end
local lol = function(n: OneToTen) return n + 2 end
lol(20)

-- lol(20)
--     ^^: "expected number above 1 and below 10"





--[[
    ? is a Lua(JIT) compatible language written in Lua with an optional typesystem

    There should not be any differences from Lua except for some extra syntax to deal with the typesystem.

    The way Lua is parsed is maybe a little bit different. Syntax errors are IMO a less amigious
]]


macro LOL = function(i)
    return i:Render() .. " + LOL"
 end

 for i = 1, 10 do
   @LOL(i)
 end

 >>

 for i = 1, 10 do
     i + "LOL"
 end

 ----

 -- various list types, from loose to strict
 local a: {[number] = any} = {}
 local a: {[1 .. math.huge] = any} = {}
 local a: {[1 .. #self + 1] = any} = {}
 local a: {[1 .. 10] = any} = {}

 -----------
 type foo = object({
     __newindex = function(self, key, val)
         if val.value == true then
             error("cannot assign true!")
         end
     end,
 })

 local test: foo = {}
 test.foo = true
      ^^^
      cannot assign true!
 -----------

 any:
     number = -math.huge .. math.huge | math.nan
     string = *all possible string values*
     boolean = true | false
     table = *all possible table values*
     function = *all possible function types*
         (string): string


 type pcall = function(function, ...): (boolean, ...)

 type tuple = (string, number)
 type lol = tuple -> tuple
 type lol = function(a,b,c) return a,b,c end


 -- tuples
     -- BAD
     type function io.open(string, string?): file | nil, string | nil
     -- GOOD
     type function io.open(string, string?): (file) | (nil, string)

     type error = (nil, string)
     type function io.open(string, string?): file | error



 -- true, number, string, userdata, object
 -- false, nil


 -- text instead of string?

 type boolean = true | false
 type truthy = true | string | number | function | table
 type falsey = false | nil
 type object = userdata | table | cdata
 type integer<T> math.ceil(T) == T
 type list<T> = {}
 type xyz = [number, number, number]

 type a = string | 1 | 2 -- represent all string values and the nunmbers 2 and 3
 type a = 1 .. 10 -- represent numbers from 1 to 10
 type a = $"%d" -- represent strings that contain a digit
 type OneToTen<T> = T > 1 and T < 10
 type PowerOfTwo<T> = (T & (T - 1)) == 1
 type a = function(T) end

 type events = "Update" | "Draw" | "Initialize" | "Shutdown"

 type events.AddListener = function(name) * extend events.AddListener function type * end
 events.AddListener(event: events, function()

 end)


 type event.Call = function(name, ...) events = events + name end
 event.Call("Update", system.GetFrameTime())

 local pos: xyz = ent:GetPosition()




 local a: OneToTen = 11 -- Cannot satisify value
 local a: PowOf2 = 4


 local lol = function(n: number) assert(n > 1 and T < 10, "expected number above 1 and below 10") return n + 2 end
 lol(20) -- assertion failed: expected number above 1 and below 10

 local type OneToTen = function(T) return T>1 and T<10 and T or error("expected number above 1 and below 10") end
 local lol = function(n: OneToTen) return n + 2 end
 lol(20)

 -- lol(20)
 --     ^^: "expected number above 1 and below 10"