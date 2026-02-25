import {
  ExtensionContext, languages, Range, TextDocument,
  TextEdit, window, workspace, DecorationOptions,
  OutputChannel
} from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  NotificationType,
  ErrorAction,
  CloseAction,
  ErrorHandler
} from "vscode-languageclient/node";
import { resolveVariables } from "./vscode-variables";
import { ChildProcessWithoutNullStreams, spawn } from "child_process";
import { chdir } from "process";
import { resolve } from "path";
import * as fs from "fs";

let client: LanguageClient;
let server: ChildProcessWithoutNullStreams;
const documentSelector = [{ scheme: 'file', language: 'nattlua' }];

export async function activate(context: ExtensionContext) {
  const config = workspace.getConfiguration("nattlua");
  let LSPOutput = window.createOutputChannel("NattLua LSP Channel");
  let serverOutput = window.createOutputChannel("NattLua Server");
  let clientOutput: OutputChannel

  const executable = resolveVariables(config.get<string>("executable") || "nattlua");
  const workingDirectory = resolveVariables(config.get<string>("workingDirectory") || "${workspaceFolder}");
  const args = (config.get<string[]>("arguments") || []).map(arg => resolveVariables(arg))

  if (!fs.existsSync(workingDirectory)) {
    window.showWarningMessage(`NattLua: Working directory '${workingDirectory}' not found. Defaulting to workspace root.`);
  }

  const errorHandler: ErrorHandler = {
    error: (error, message, count) => {
      LSPOutput.appendLine(`LSP Error: ${message} (${count}) - ${error.message}`);
      if (count <= 3) return { action: ErrorAction.Continue };
      return { action: ErrorAction.Shutdown };
    },
    closed: () => {
      LSPOutput.appendLine("LSP connection closed.");
      return { action: CloseAction.Restart };
    }
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector,
    synchronize: {
      configurationSection: "nattlua",
    },
    errorHandler: errorHandler,
  };

  client = new LanguageClient(
    "nattlua",
    "NattLua Client",
    async () => {
      try {
        server = spawn(executable, args, { cwd: workingDirectory, shell: true });
        server.on("error", (err) => {
          serverOutput.appendLine("SERVER SPAWN ERROR: " + err.toString());
          window.showErrorMessage(`Failed to start NattLua server: ${err.message}. Make sure '${executable}' is installed and in your PATH.`);
        });

        const reader = server.stderr  // using STDERR explicitly to have a clean communication channel
        reader.setEncoding("utf8");
        reader.on("data", (str) => LSPOutput.appendLine(">>\n" + str));

        const output = server.stdout
        output.setEncoding("utf8");
        output.on("data", (str: string) => serverOutput.append(str));

        const writer = server.stdin

        {
          const originalWrite = writer._write;
          writer._write = function (chunk: any, encoding: BufferEncoding, callback: (error?: Error | null) => void): void {
            LSPOutput.appendLine("<<\n" + chunk.toString());
            originalWrite.call(this, chunk, encoding, callback);
          };
        }

        context.subscriptions.push({
          dispose: () => {
            if (server) server.kill("SIGTERM");
          },
        })

        return {
          reader,
          writer
        };
      } catch (e) {
        window.showErrorMessage(`NattLua Critical Error: ${e}`);
        throw e;
      }
    },
    clientOptions
  );

  clientOutput = client.outputChannel
  if (!clientOutput) {
    // fallback if it's not immediately available
    clientOutput = LSPOutput;
  }

  const highlightDecorationType = window.createTextEditorDecorationType({
    backgroundColor: 'rgba(255, 255, 0, 0.2)',
  });
  client.onNotification(new NotificationType<{
    uri: string;
    decorations: {
      range: {
        start: { line: number, character: number };
        end: { line: number, character: number };
      };
      renderOptions: {
        backgroundColor: string;
        border?: string;
      };
    }[];
  }>('nattlua/textDecoration'), (params) => {

    clientOutput.appendLine(`Received decoration notification for: ${params.uri}`);
    const uri = params.uri;
    const decorations = params.decorations;

    const editor = window.visibleTextEditors.find(
      editor => editor.document.uri.toString() === uri
    );

    if (editor) {
      const decorationOptions = decorations.map(dec => {
        return {
          range: new Range(
            dec.range.start.line, dec.range.start.character,
            dec.range.end.line, dec.range.end.character
          ),
          renderOptions: {
            dark: {
              before: {
                backgroundColor: dec.renderOptions.backgroundColor,
                border: dec.renderOptions.border,
              }
            },
            light: {
              before: {
                backgroundColor: dec.renderOptions.backgroundColor,
                border: dec.renderOptions.border,
              }
            }
          },
        };
      });

      editor.setDecorations(highlightDecorationType, decorationOptions);
    }
  });

  clientOutput.appendLine(`Starting NattLua server with command: ${executable} ${args.join(" ")}`);
  try {
    await client.start();
    clientOutput.appendLine(`NattLua server started successfully`);
  } catch (err: any) {
    clientOutput.appendLine(`NattLua failed to start: ${err.message}`);
    window.showErrorMessage(`Failed to start NattLua Language Client. Check the output channels for details.`);
  }
}

export async function deactivate(): Promise<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
