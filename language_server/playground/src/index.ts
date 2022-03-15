import { editor as MonacoEditor, languages, MarkerSeverity } from "monaco-editor"
import { PublishDiagnosticsParams, Range, DidChangeTextDocumentParams } from "vscode-languageserver"
import { createEditor } from "./editor"
import { loadLua, prettyPrint } from "./lua"
import { registerSyntax } from "./syntax"
import randomExamples from "./random.json"

const getRandomExample = () => {
	return randomExamples[Math.floor(Math.random() * randomExamples.length)]
}

const main = async () => {
	const lua = await loadLua()
	await registerSyntax(lua)

	const editor = createEditor()
	const tab = MonacoEditor.createModel(getRandomExample(), "nattlua")

	document.getElementById("random-example").addEventListener("click", () => {
		tab.setValue(getRandomExample())
	})

	document.getElementById("pretty-print").addEventListener("click", () => {
		tab.setValue(prettyPrint(lua, tab.getValue()))
	})

	const lsp = lua.global.get("lsp")

	const recompile = () => {
		let response: DidChangeTextDocumentParams = {
			textDocument: {
				uri: "file:///test.nlua",
			} as DidChangeTextDocumentParams["textDocument"],
			contentChanges: [
				{
					text: tab.getValue(),
				},
			],
		}

		lsp.methods["textDocument/didChange"](lsp, response)

		MonacoEditor.setModelMarkers(tab, "owner", [])
	}

	editor.onDidChangeModelContent((e) => {
		recompile()
	})

	languages.registerHoverProvider("nattlua", {
		provideHover: (model, position) => {
			let response = {
				textDocument: {
					uri: "file:///test.nlua",
					text: model.getValue(),
				},
				position: {
					line: position.lineNumber - 1,
					character: position.column - 1,
				},
			}

			let result = lsp.methods["textDocument/hover"](lsp, response) as {
				range: Range
				contents: string
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
			}
		},
	})

	lsp.On("textDocument/publishDiagnostics", (params) => {
		const { diagnostics } = params as PublishDiagnosticsParams
		const markers: MonacoEditor.IMarkerData[] = []
		for (const diag of diagnostics) {
			markers.push({
				message: diag.message,
				startLineNumber: diag.range.start.line + 1,
				startColumn: diag.range.start.character + 1,
				endLineNumber: diag.range.end.line + 1,
				endColumn: diag.range.end.character + 1,
				severity: MarkerSeverity.Error,
			})
		}

		const model = editor.getModel()
		MonacoEditor.setModelMarkers(model, "owner", markers)
	})

	editor.setModel(tab)
}

main()
