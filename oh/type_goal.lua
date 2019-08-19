-- true, number, string, userdata, table
-- false, nil

type boolean = true | false
type truthy = true | string | number | function | table
type falsey = false | nil
type object = userdata | table
type integer<T> math.ceil(T) == T
type list<T> = {}
type xyz = [number, number, number]

local pos: xyz = ent:GetPosition()


type OneToTen<T> = T > 1 and T < 10
type PowerOfTwo<T> = (T & (T - 1)) == 1

local a: OneToTen = 11 -- Cannot satisify value 
local a: PowOf2 = 4


local lol = function(n: number) assert(n > 1 and T < 10, "expected number above 1 and below 10") return n + 2 end
lol(20) -- assertion failed: expected number above 1 and below 10

local type OneToTen = function(T) return T>1 and T<10 and T or error("expected number above 1 and below 10") end
local lol = function(n: OneToTen) return n + 2 end
lol(20)

-- lol(20)
--     ^^: "expected number above 1 and below 10"