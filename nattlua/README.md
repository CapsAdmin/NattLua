The parts involved from turning NattLua code into lua are as following

# syntax
Sets up the base syntax for the lexer and parser. Language constructs such as keywords, operators, operator precedence, etc are defined here.

# lexer
Used to create tokens from code. Each token can also contain whitespace.

# parser 
Parses the lua code into an abstract syntax tree

# analyzer
An optional step which traverses the AST and runs type checking on it.

uses base_typesystem.nl

# transpiler
Emits the lua code ready to be executed along with runtime.lua

# types
Algebraic types

# runtime
Includes the base type definitions