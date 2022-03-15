import { LuaEngine, LuaFactory } from "wasmoon";
import { editor, languages, MarkerSeverity } from "monaco-editor";

const syntax = {
  defaultToken: "",
  tokenPostfix: ".nl",

  keywords: [
    "and",
    "break",
    "do",
    "else",
    "elseif",
    "end",
    "false",
    "for",
    "function",
    "goto",
    "if",
    "in",
    "local",
    "nil",
    "not",
    "or",
    "repeat",
    "return",
    "then",
    "true",
    "until",
    "while",
    "record",
    "enum",
    "functiontype",
    "const",
    "as",
    "is",
    "global",
  ],

  typeKeywords: ["any", "boolean", "number", "string"],

  brackets: [
    { token: "delimiter.bracket", open: "{", close: "}" },
    { token: "delimiter.array", open: "[", close: "]" },
    { token: "delimiter.parenthesis", open: "(", close: ")" },
  ],

  operators: [
    "+",
    "-",
    "*",
    "/",
    "%",
    "^",
    "#",
    "==",
    "~=",
    "<=",
    ">=",
    "<",
    ">",
    "=",
    ";",
    ":",
    ",",
    ".",
    "..",
    "...",
  ],

  // we include these common regular expressions
  symbols: /[=><!~?:&|+\-*\/\^%]+/,
  escapes:
    /\\(?:[abfnrtv\\"']|x[0-9A-Fa-f]{1,4}|u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8})/,

  // The main tokenizer for our languages
  tokenizer: {
    root: [
      // identifiers and keywords
      [
        /[a-zA-Z_]\w*/,
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
};
const syntaxBrackets = {
  comments: {
    lineComment: "--",
    blockComment: ["--[[", "]]"],
  },
  brackets: [
    ["{", "}"],
    ["[", "]"],
    ["(", ")"],
  ],
  autoClosingPairs: [
    { open: "{", close: "}" },
    { open: "[", close: "]" },
    { open: "(", close: ")" },
    { open: '"', close: '"' },
    { open: "'", close: "'" },
  ],
  surroundingPairs: [
    { open: "{", close: "}" },
    { open: "[", close: "]" },
    { open: "(", close: ")" },
    { open: '"', close: '"' },
    { open: "'", close: "'" },
  ],
};

languages.register({ id: "nattlua" });
languages.setMonarchTokensProvider("nattlua", syntax as any);
languages.setLanguageConfiguration("nattlua", syntaxBrackets as any);

var obj = editor.create(document.getElementById("container"), {
  value: `local x = 0
-- x is 0 here

if math.random() > 0.5 then
    -- x is 0 here
    x = 1
    -- x is 1 here
else
    -- x is 0 here
    x = 2
    -- x is 2 here
end

local y = x`,
  language: "nattlua",
  theme: "vs-dark",
});

window.addEventListener("resize", () => {
  obj.layout();
});

obj.onDidChangeCursorSelection((e) => {
  //console.log(JSON.stringify(e));
});

const loadCode = async (lua: LuaEngine, path: string, moduleName: string) => {
  const res = await fetch(path);
  if (res.status !== 200) {
    throw new Error(`Failed to load ${path}: ${res.statusText}`);
  }
  const code = await res.text();

  await lua.doString(
    `assert(load([==========[ package.preload["${moduleName}"] = function() ${code} end ]==========], "${moduleName}"))()`
  );
};

const main = async () => {
  const factory = new LuaFactory();
  const lua = await factory.createEngine({
    openStandardLibs: true,
  });

  await loadCode(lua, "build_output.lua", "nattlua");
  await loadCode(lua, "language_server.lua", "language_server");

  await lua.doString(`
    _G.ls = require("language_server")
`);

  const ls = lua.global.get("ls");

  obj.onDidChangeCursorPosition((e) => {
    ls.Compile(obj.getValue());

    const markers: editor.IMarkerData[] = [];
    while (true) {
      let diag = ls.ReadDiagnostic() as {
        severity: string;
        msg: string;
        range: {
          start: {
            line: number;
            character: number;
          };
          end: {
            line: number;
            character: number;
          };
        };
      };
      if (!diag) break;

      markers.push({
        message: diag.msg,
        startLineNumber: diag.range.start.line + 1,
        startColumn: diag.range.start.character + 1,
        endLineNumber: diag.range.end.line + 1,
        endColumn: diag.range.end.character + 1,
        severity: MarkerSeverity.Error,
      });
    }
    const model = obj.getModel();
    editor.setModelMarkers(model, "owner", markers);
  });

  ls.Compile(obj.getValue());

  languages.registerHoverProvider("nattlua", {
    provideHover: (model, position) => {
      let data = ls.OnHover(position);
      return {
        contents: [
          {
            value: data.contents,
          },
        ],
        startLineNumber: data.range.start.line,
        startColumn: data.range.start.character,
        endLineNumber: data.range.end.line,
        endColumn: data.range.end.character,
      };
    },
  });
};

main();
