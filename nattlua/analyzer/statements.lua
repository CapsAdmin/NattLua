
return function(META)
    require("nattlua.analyzer.statements.assignment")(META)
    require("nattlua.analyzer.statements.destructure_assignment")(META)
    require("nattlua.analyzer.statements.function")(META)
    require("nattlua.analyzer.statements.root")(META)
    require("nattlua.analyzer.statements.if")(META)
    require("nattlua.analyzer.statements.do")(META)
    require("nattlua.analyzer.statements.generic_for")(META)
    require("nattlua.analyzer.statements.call_expression")(META)
    require("nattlua.analyzer.statements.numeric_for")(META)
    require("nattlua.analyzer.statements.repeat")(META)
    require("nattlua.analyzer.statements.return")(META)
    require("nattlua.analyzer.statements.type_code")(META)
    require("nattlua.analyzer.statements.while")(META)

    function META:AnalyzeStatement(statement)
        self.current_statement = statement

        if 
            statement.kind == "assignment" or 
            statement.kind == "local_assignment" 
        then
           self:AnalyzeAssignmentStatement(statement)
        elseif 
            statement.kind == "destructure_assignment" or 
            statement.kind == "local_destructure_assignment" 
        then
            self:AnalyzeDestructureAssignment(statement)
        elseif 
            statement.kind == "function" or 
            statement.kind == "generics_type_function" or 
            statement.kind == "local_function" or 
            statement.kind == "local_generics_type_function" or 
            statement.kind == "local_type_function" or 
            statement.kind == "type_function" 
        then
            self:AnalyzeFunctionStatement(statement)
        elseif statement.kind == "if" then
            self:AnalyzeIfStatement(statement)
        elseif statement.kind == "while" then
            self:AnalyzeWhileStatement(statement)
        elseif statement.kind == "do" then
            self:AnalyzeDoStatement(statement)
        elseif statement.kind == "repeat" then
            self:AnalyzeRepeatStatement(statement)
        elseif statement.kind == "return" then
            self:AnalyzeReturnStatement(statement)
        elseif statement.kind == "break" then
            self:AnalyzeBreakStatement(statement)
        elseif statement.kind == "continue" then
            self:AnalyzeContinueStatement(statement)
        elseif statement.kind == "call_expression" then
            self:AnalyzeCallExpressionStatement(statement)
        elseif statement.kind == "generic_for" then
            self:AnalyzeGenericForStatement(statement)
        elseif statement.kind == "numeric_for" then
            self:AnalyzeNumericForStatement(statement)
        elseif statement.kind == "type_code" then
            self:AnalyzeTypeCodeStatement(statement)
        elseif statement.kind == "import" then
            
        elseif
            statement.kind ~= "end_of_file" and
            statement.kind ~= "semicolon" and
            statement.kind ~= "shebang" and
            statement.kind ~= "goto_label" and
            statement.kind ~= "goto"
        then
            self:FatalError("unhandled statement: " .. tostring(statement))
        end
    end
end
