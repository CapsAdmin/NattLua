local expression = {
    type = "expression",
    kind = "???",

    tokens = {
        -- parenthesis should be a table of tokens?
    },
    left = {
        -- expression
    },
    value = {
        --1,true,false,foo,bar,
    },
    right = {
        -- expression
    },
    suffixes = {
        -- expression.foo:bar(a) [1] {a} "a" 'a' [==[a]==] [[a]]
    },
}

local statement = {
    type = "statement",
    kind = "???",
    
    tokens = {
        -- usually a list of keywords such as do, end, for, while, etc
    },
    identifiers = {
        -- local a,b,c = 1,2,3
        -- function aasdfdasf(a,b,c)
    },  
    expressions = {
        -- one or more expressions

        -- single
        -- repeat until expression
        -- while expression do end
        -- if expression then elseif expression then else end
        -- expression()()()
        
        -- multiple
        -- for identifier = expression_list[3] do end
        -- for name_list in expression_list do end
        -- local name_list = expression_list
        -- return expression_list
        -- expression_list = expression_list
    },
    statements = {
        -- do statements end
        -- repeat statements until
        -- while do statements end
        -- if then statements elseif statements else statements end
        -- for do statements end
        -- function() statements end
    },
}