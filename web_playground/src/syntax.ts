import { languages } from "monaco-editor"
import { mapsToArray } from "./util"

export const registerSyntax = async (additionalSyntax: {
	keywords: string[];
	typeKeywords: string[];
	operators: string[];
	brackets: [string, string][]
	autoClosingPairs: { open: string, close: string }[]
	surroundingPairs: { open: string, close: string }[]
}) => {

	const syntax: languages.IMonarchLanguage = {
		defaultToken: "",
		tokenPostfix: ".nl",

		brackets: [
			{ token: "delimiter.bracket", open: "{", close: "}" },
			{ token: "delimiter.array", open: "[", close: "]" },
			{ token: "delimiter.parenthesis", open: "(", close: ")" },
		],
		keywords: additionalSyntax.keywords,
		typeKeywords: additionalSyntax.typeKeywords,
		operators: additionalSyntax.operators,

		symbols: /[=><!~?:&|+\-*\/\^%]+/,

		escapes: /\\(?:[abfnrtv\\"']|x[0-9A-Fa-f]{1,4}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})/,

		// The main tokenizer for our languages
		tokenizer: {
			root: [
				// identifiers and keywords
				[
					/[a-zA-Z_@]\w*/,
					{
						cases: {
							"@typeKeywords": { token: "keyword.$0" },
							"@keywords": { token: "keyword.$0" },
							"@default": "identifier",
						},
					},
				],
				// whitespace
				{ include: "@whitespace" },

				// delimiters and operators
				[/[{}()\[\]]/, "@brackets"],
				[
					/@symbols/,
					{
						cases: {
							"@operators": "delimiter",
							"@default": "",
						},
					},
				],

				// numbers
				[/\d*\.\d+([eE][\-+]?\d+)?/, "number.float"],
				[/0[xX][0-9a-fA-F_]*[0-9a-fA-F]/, "number.hex"],
				[/\d+?/, "number"],

				// delimiter: after number because of .\d floats
				[/[;,.]/, "delimiter"],

				// strings: recover on non-terminated strings
				[/"([^"\\]|\\.)*$/, "string.invalid"], // non-teminated string
				[/'([^'\\]|\\.)*$/, "string.invalid"], // non-teminated string
				[/"/, "string", '@string."'],
				[/'/, "string", "@string.'"],
			],

			whitespace: [
				[/[ \t\r\n]+/, ""],
				[/--\[([=]*)\[/, "comment", "@comment.$1"],
				[/--.*$/, "comment"],
			],

			comment: [
				[/[^\]]+/, "comment"],
				[
					/\]([=]*)\]/,
					{
						cases: {
							"$1==$S2": { token: "comment", next: "@pop" },
							"@default": "comment",
						},
					},
				],
				[/./, "comment"],
			],

			string: [
				[/[^\\"']+/, "string"],
				[/@escapes/, "string.escape"],
				[/\\./, "string.escape.invalid"],
				[
					/["']/,
					{
						cases: {
							"$#==$S2": { token: "string", next: "@pop" },
							"@default": "string",
						},
					},
				],
			],
		},
	}

	languages.register({ id: "nattlua", extensions: [".lua", ".nl"] })
	languages.setMonarchTokensProvider("nattlua", syntax)
	languages.setLanguageConfiguration("nattlua", {
		comments: {
			lineComment: "--",
			blockComment: ["--[[", "]]"],
		},
		brackets: additionalSyntax.brackets,
		autoClosingPairs: additionalSyntax.autoClosingPairs,
		surroundingPairs: additionalSyntax.surroundingPairs,
	})
}
