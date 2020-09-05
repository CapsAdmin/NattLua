# what this is
This is a Lua based language that transpiles to Lua. It's mostly just a toy project and place for me to explore how programming languages are built.

I see this project as 5 parts at the moment. The lexer, parser, analyzer and emitter. And the typesystem which tries to exist separate from the analyzer.

# lexer and parser
I wrote the lexer and lua parser trying not to look at existing lua parsers as a learning experience. The syntax errors it can produce are more verbose than the original lua parser and it differentiates between some cases. Whitespace (which i define as whitespace and comments) are also preserved properly.

# analyzer and typesystem
The analyzer will execute the syntax tree by walking through it. I believe it works similar to how the lua vm works. Every branch of an if statement is executed unless it's known for sure to be false, a `for i = 1, 10 do` loop would be run once where i is a number type with a range from 1 to 10.

# emitter
This part is a bit boring, it just emits lua code from the syntax tree. The analyzer can also annotate the syntax tree so you can see the output with types.

# status
The analyzer and typesystem has been the hardest part of the project so far, I think mostly because I don't really have a clear long term design goal. I'm mostly fueled by motivation and "wouldn't it be cool/fun if X"

I focus strongly on correctness at the moment and not performance. I tend to refactor code in one swoop and after I get tests working.

to run tests run `luajit test/run`

Teal (https://github.com/teal-language/tl) is a language similar to this, with a much higher likelyhood of succeeding as it does not intend to be as verbose as this project. I'm thinking another nice goal is that I can contribute what I've learned here.