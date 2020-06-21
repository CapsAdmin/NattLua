local function test(...)
  return 1,2,...
end

local a,b,c = test(3)

print("123: ", a,b,c)

local function test(...)
  local a,b,c = ...
  print("123: ", a,b,c)
end

test(1,2,3)