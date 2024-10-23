import {
  ExtensionContext, languages, Range, TextDocument,
  TextEdit, window, workspace
} from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
} from "vscode-languageclient/node";
import { resolveVariables } from "./vscode-variables";
import { ChildProcessWithoutNullStreams, spawn } from "child_process";
import { chdir } from "process";

let client: LanguageClient;
let server: ChildProcessWithoutNullStreams;
const documentSelector = [{ scheme: 'file', language: 'nattlua' }];

export async function activate(context: ExtensionContext) {
  const config = workspace.getConfiguration("nattlua");
  let serverOutput = window.createOutputChannel("Nattlua Server");

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
      reader.on("data", (str) => serverOutput.append(str));

      const output = server.stdout
      output.setEncoding("utf8");
      output.on("data", (str: string) => serverOutput.append(str));

      const writer = server.stdin

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

  languages.registerDocumentFormattingEditProvider(documentSelector, {
    async provideDocumentFormattingEdits(document: TextDocument) {
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
            { code: document.getText(), path: document.uri.path }
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
        serverOutput.appendLine(`NattLua Format error: ${errorMessage}`);
        return [];
      }
    },
  });


  await client.start();
}

export async function deactivate(): Promise<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
