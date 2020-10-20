The parts involved from turning NattLua code into lua are as following

# syntax.lua
Sets up the base syntax for the lexer and parser. Language constructs such as keywords, operators, operator precedence, etc are defined here.

# lexer.lua
Used to create tokens from code. Each token can also contain whitespace.

# parser.lua 
Parses the lua code into an abstract syntax tree

# analyzer.lua
An optional step which traverses the AST and runs type checking on it.

uses base_typesystem.nl

# emitter.lua
Emits the lua code ready to be executed along with runtime.lua
