import {
  editor as MonacoEditor,
  languages,
  MarkerSeverity,
} from "monaco-editor";
import { PublishDiagnosticsParams, Range, DidChangeTextDocumentParams } from "vscode-languageserver";
import { createEditor } from "./editor";
import { loadLua } from "./lua";
import { registerSyntax } from "./syntax";

const main = async () => {
  const lua = await loadLua();
  await registerSyntax(lua);

  const model = MonacoEditor.createModel(
    `analyzer function foo(a: mutable x, b: literal y) 
    
    end`,
    "nattlua"
  );

  const editor = createEditor();
  editor.setModel(model);

  const lsp = lua.global.get("lsp");

  const recompile = () => {
    let response: DidChangeTextDocumentParams = {
      textDocument: {
        uri: "file:///test.nlua",
      } as DidChangeTextDocumentParams["textDocument"],
      contentChanges: [
        {
          text: editor.getValue(),
        },
      ],
    }
    
    lsp.methods["textDocument/didChange"](lsp, response);

    // clear existing markers
    const model = editor.getModel();
    MonacoEditor.setModelMarkers(model, "owner", []);
  };

  editor.onDidChangeModelContent((e) => {
    recompile();
  });

  languages.registerHoverProvider("nattlua", {
    provideHover: (model, position) => {
      let response = {
        textDocument: {
          uri: "file:///test.nlua",
          text: editor.getValue(),
        },
        position: {
          line: position.lineNumber - 1,
          character: position.column - 1,
        },
      }

      let result = lsp.methods["textDocument/hover"](lsp, response) as {
        range: Range;
        contents: string,
      }
      
      return {
        contents: [
          {
            value: result.contents,
          },
        ],
        startLineNumber: result.range.start.line + 1,
        startColumn: result.range.start.character + 1,
        endLineNumber: result.range.end.line + 1,
        endColumn: result.range.end.character + 1,
      };
    },
  });

  recompile();
  type Message<T> = {
    method: string;
    params: T;
  };

  setInterval(() => {
    let call = lsp.ReadCall() as { method: string; params: unknown };
    if (!call) return;
    if (call.method == "textDocument/publishDiagnostics") {
      const { diagnostics } = (call as Message<PublishDiagnosticsParams>)
        .params;

      const markers: MonacoEditor.IMarkerData[] = [];
      for (const diag of diagnostics) {
        markers.push({
          message: diag.message,
          startLineNumber: diag.range.start.line + 1,
          startColumn: diag.range.start.character + 1,
          endLineNumber: diag.range.end.line + 1,
          endColumn: diag.range.end.character + 1,
          severity: MarkerSeverity.Error,
        });
      }

      const model = editor.getModel();
      MonacoEditor.setModelMarkers(model, "owner", markers);
    }
  }, 100);
};

main();
