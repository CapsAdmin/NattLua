import {
  ExtensionContext, languages, Range, TextDocument,
  TextEdit, window, workspace, DecorationOptions,
  OutputChannel
} from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  NotificationType
} from "vscode-languageclient/node";
import { resolveVariables } from "./vscode-variables";
import { ChildProcessWithoutNullStreams, spawn } from "child_process";
import { chdir } from "process";
import { resolve } from "path";

let client: LanguageClient;
let server: ChildProcessWithoutNullStreams;
const documentSelector = [{ scheme: 'file', language: 'nattlua' }];
const isRightDocument = (document: TextDocument) => documentSelector.some(selector => selector.language === document.languageId && selector.scheme === document.uri.scheme)

export async function activate(context: ExtensionContext) {
  const config = workspace.getConfiguration("nattlua");
  let LSPOutput = window.createOutputChannel("NattLua LSP Channel");
  let serverOutput = window.createOutputChannel("NattLua Server");
  let clientOutput: OutputChannel

  const executable = resolveVariables(config.get<string>("executable"));
  const workingDirectory = resolveVariables(config.get<string>("workingDirectory"));
  const args = [resolveVariables(config.get<string>("path")), ...config.get<string[]>("arguments").map(arg => resolveVariables(arg))]

  const clientOptions: LanguageClientOptions = {
    documentSelector,
    synchronize: {
      configurationSection: "nattlua",
    },
  };

  client = new LanguageClient(
    "nattlua",
    "NattLua Client",
    async () => {

      chdir(workingDirectory);
      server = spawn(executable, args, { cwd: workingDirectory });
      server.on("error", (err) => {
        serverOutput.appendLine("ERROR: " + err.toString());
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
          server.kill("SIGKILL");
        },
      })

      return {
        reader,
        writer
      };

    },
    clientOptions
  );

  let oldErrorHandler = client.error;
  client.error = (error, message, count) => {
    oldErrorHandler(error, message, count);
    if (server) {
      server.kill("SIGKILL");
    }
    LSPOutput.appendLine("Client stopped");
  }

  clientOutput = client.outputChannel
  if (!clientOutput) throw new Error("Failed to create output channel");

  languages.registerDocumentFormattingEditProvider(documentSelector, {
    async provideDocumentFormattingEdits(document) {
      try {
        const timeout = new Promise<never>((_, reject) => {
          setTimeout(() => {
            reject(new Error('Formatting timeout: operation took longer than 500 ms'));
          }, 500);
        });

        const formatOperation = async () => {
          const range = document.validateRange(
            new Range(0, 0, Infinity, Infinity)
          );
          const params = await client.sendRequest<{ code: string }>(
            "nattlua/format",
            {
              code: document.getText(),
              textDocument: {
                uri: document.uri.toString(),
              }
            }
          );
          return [
            new TextEdit(
              range,
              Buffer.from(params.code, "base64").toString("utf8")
            ),
          ];
        };

        return await Promise.race([formatOperation(), timeout]);
      } catch (err) {
        // Handle both timeout and formatting errors
        const errorMessage = err instanceof Error ? err.message : String(err);
        clientOutput.appendLine(`NattLua Format error: ${errorMessage}`);
        return [];
      }
    },
  });
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
  await client.start();

  clientOutput.appendLine(`NattLua server started successfully`);
}

export async function deactivate(): Promise<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
