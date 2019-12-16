type test = (function(boolean, boolean): number) | (function(boolean): string)
--local a = test(true)
local b = test(true,true)
TPRINT(a,b)