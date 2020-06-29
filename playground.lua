-- nil, true and false is declared internally as symbols

type function_ = function(any...): any...
type number = -inf .. inf | nan
type string = $".-"
type boolean = true | false
type table = {[any] = any}

print(test, test2)