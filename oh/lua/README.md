The parts involved from turning oh code into lua are as following

# syntax.lua
Sets up the base syntax for the lexer and parser. You can define keywords, operators along with precedence, and other low level configuration.

# lexer.lua
Used to create tokens from code. Each token consists of whitespace

# parser.lua 
Parses the lua code into an abstract syntax tree

# analyzer.lua
An optional step which traverses the AST and runs type checking on it.

uses base_typesystem.oh

# emitter.lua
Emits the lua code ready to be ran along with runtime.lua