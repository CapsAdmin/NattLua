import { editor, editor as MonacoEditor, IRange, languages, MarkerSeverity, Uri } from "monaco-editor"
import { PublishDiagnosticsParams, Range, DidChangeTextDocumentParams, Position, URI } from "vscode-languageserver"
import { createEditor } from "./editor"
import { loadLuaInterop } from "./lua"
import { registerSyntax } from "./syntax"
import randomExamples from "./random.json"
import { assortedExamples } from "./examples"

const getRandomExample = () => {
	return randomExamples[Math.floor(Math.random() * randomExamples.length)]
}

const pathFromURI = (uri: Uri) => {
	return "./test.nlua" //uri.fsPath + ".nlua"
}

const main = async () => {
	//const { syntax_runtime, syntax_typesystem, lsp, prettyPrint } = await loadLuaWasmoon()
	const { syntax_runtime, syntax_typesystem, lsp, prettyPrint } = await loadLuaInterop()

	await registerSyntax(syntax_runtime, syntax_typesystem)

	const editor = createEditor()
	const tab = MonacoEditor.createModel("local x = 1337", "nattlua")

	const select = document.getElementById("examples") as HTMLSelectElement

	select.addEventListener("change", () => {
		tab.setValue(select.value)
	})

	const callMethodOnServer = (method: string, params: any) => {
		console.log("lsp.methods['", method, "'](", params, ")")
		let [response] = lsp.methods[method](JSON.stringify(params))
		console.log("\tgot", response)
		return response
	}

	const onMessageFromServer = (method: string, callback: (params: any) => void) => {
		lsp.On(method, (params) => {
			params = JSON.parse(params)
			console.log("received", method, params)
			callback(params)
		})
	}

	const recompile = () => {
		let request: DidChangeTextDocumentParams = {
			textDocument: {
				uri: "./test.nlua",
			} as DidChangeTextDocumentParams["textDocument"],
			contentChanges: [
				{
					text: tab.getValue(),
				},
			],
		}

		MonacoEditor.setModelMarkers(tab, "owner", [])
		callMethodOnServer("textDocument/didChange", request)
	}


	for (const [name, code] of Object.entries(assortedExamples)) {
		let str: string
		if (typeof code === "string") {
			str = code
		} else {
			str = (await code).default
		}

		// remove attest.expect_diagnostic() calls
		str = str.replaceAll(/attest\.expect_diagnostic\(.*\)/g, "")

		const option = new Option(name, str)
		select.options.add(option)
		if (name == "array") {
			option.selected = true
			tab.setValue(str)
		}
	}

	document.getElementById("random-example").addEventListener("click", () => {
		tab.setValue(prettyPrint(getRandomExample()))
	})

	document.getElementById("pretty-print").addEventListener("click", () => {
		tab.setValue(prettyPrint(tab.getValue()))
	})


	tab.onDidChangeContent((e) => {
		recompile()
	})

	languages.registerInlayHintsProvider("nattlua", {
		provideInlayHints(model, range) {
			let request = {
				textDocument: {
					uri: pathFromURI(model.uri),
					text: model.getValue(),
				},
				range: {
					start: {
						line: range.getStartPosition().lineNumber,
						character: range.getStartPosition().column,
					},
					end: {
						line: range.getEndPosition().lineNumber,
						character: range.getEndPosition().column,
					},
				}
			}

			let response = callMethodOnServer("textDocument/inlayHint", request)
			if (!Array.isArray(response)) {
				return {
					hints: [],
					dispose: () => { },

				}
			}

			return {
				hints: response.map((hint) => {
					return {
						label: hint.label,
						position: {
							lineNumber: hint.position.line + 1,
							column: hint.position.character + 1,
						},
						kind: hint.kind,
					}
				}),
				dispose: () => { },
			}
		},
	})

	languages.registerRenameProvider("nattlua", {
		provideRenameEdits: (model, position, newName, token) => {
			let request = {
				textDocument: {
					uri: pathFromURI(model.uri),
					text: model.getValue(),
				},
				position: {
					line: position.lineNumber - 1,
					character: position.column - 1,
				},
				newName,
			}

			let response = callMethodOnServer("textDocument/rename", request) as {
				changes: {
					[uri: string]: Array<{
						range: { start: Position; end: Position }
						newText: string
					}>
				}
			}

			let edits: Awaited<ReturnType<languages.RenameProvider["provideRenameEdits"]>>["edits"] = []
			for (const [uri, changes] of Object.entries(response.changes)) {
				for (const change of changes) {
					edits.push({
						resource: model.uri,
						versionId: model.getVersionId(),
						textEdit: {
							range: {
								startLineNumber: change.range.start.line + 1,
								startColumn: change.range.start.character + 1,
								endLineNumber: change.range.end.line + 1,
								endColumn: change.range.end.character + 1,
							},
							text: change.newText,
						},
					})
				}
			}

			console.log(edits)

			return {
				edits,
			}
		},
	})

	languages.registerHoverProvider("nattlua", {
		provideHover: (model, position) => {
			let request = {
				textDocument: {
					uri: pathFromURI(model.uri),
					text: model.getValue(),
				},
				position: {
					line: position.lineNumber - 1,
					character: position.column - 1,
				},
			}

			let response = callMethodOnServer("textDocument/hover", request) as
				| undefined
				| {
					range: Range
					contents: string
				}

			if (!response || !response.range) return {
				contents: [],
				range: {
					startLineNumber: 1,
					startColumn: 1,
					endLineNumber: 1,
					endColumn: 1,
				}
			}

			// TODO: how to highlight non letters?

			return {
				contents: [
					{
						value: response.contents,
					},
				],
				range: {
					// these start at 1, but according to LSP they should be zero indexed
					startLineNumber: response.range.start.line + 1,
					startColumn: response.range.start.character + 1,
					endLineNumber: response.range.end.line + 1,
					endColumn: response.range.end.character + 1,
				},
			}
		},
	})

	onMessageFromServer("textDocument/publishDiagnostics", (params) => {
		const { diagnostics } = params as PublishDiagnosticsParams
		const markers: MonacoEditor.IMarkerData[] = []
		for (const diag of diagnostics) {
			let severity: number = diag.severity

			if (severity == 1) {
				severity = MarkerSeverity.Error
			} else if (severity == 2) {
				severity = MarkerSeverity.Warning
			} else if (severity == 3) {
				severity = MarkerSeverity.Info
			} else {
				severity = MarkerSeverity.Hint
			}

			markers.push({
				message: diag.message,
				startLineNumber: diag.range.start.line + 1,
				startColumn: diag.range.start.character + 1,
				endLineNumber: diag.range.end.line + 1,
				endColumn: diag.range.end.character + 1,
				severity: severity,
			})
		}

		MonacoEditor.setModelMarkers(tab, "owner", markers)
	})

	editor.setModel(tab)

	callMethodOnServer("initialized", {})

	recompile()
}

main()
