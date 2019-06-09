local oh = require("runtime")

print(10pb)

local @toclose foo = @(meta{__index = function(self, key) print(self, key) end}) {}

local test = struct {
    test: u32;
    bar: u32;
}

print(sizeof(test))

print(foo.test)

local meta = {}

local test: meta = {}

local {a, b, c = "!"} = {a="hello", b="world"}
print `${a} ${b}${c}`