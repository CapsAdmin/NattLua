# Status

I love refactoring and coming up with simpler solutions.But this project has been a big challenge. I've started to get an idea of how inference should behave by writing tests first and code afterwards. The code is complex and hard to understand, but I hope to find simpler solutions in the future.

## Control Flow

Analyzing if statements work pretty well when there is a simple expression. So I want to use the same control flow code that analyzes statements for expressions.

For example, this will fail at the moment.

```lua
if string_or_nil and #string_or_nil > 4 then end
```

But this works fine

```lua
if string_or_nil then
    if #string_or_nil > 4 then
    end
end
```

Maybe something like internally representing expressions like if statements could work.

##
