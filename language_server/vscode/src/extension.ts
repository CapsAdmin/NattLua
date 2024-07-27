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
import { unwatchFile, watchFile } from "fs"
import { chdir } from "process";

let client: LanguageClient;
const config = workspace.getConfiguration("nattlua");
let server: ChildProcessWithoutNullStreams;

const kill = () => {
  if (server) {
    server.kill("SIGKILL");
  }
  server = undefined;
};


export async function activate(context: ExtensionContext) {
  let serverOutput = window.createOutputChannel("Nattlua Server");

  const executable = resolveVariables(config.get<string>("executable"));
  const workingDirectory = resolveVariables(config.get<string>("workingDirectory"));
  const path = resolveVariables(config.get<string>("path"));
  const args = config.get<string[]>("arguments")
  for (let i = 0; i < args.length; i++) {
    args[i] = resolveVariables(args[i]);
  }

  const selector = [{ scheme: 'file', language: 'nattlua' }];

  const clientOptions: LanguageClientOptions = {
    documentSelector: selector,
    synchronize: {
      configurationSection: "nattlua",
    },
  };

  client = new LanguageClient(
    "nattlua",
    "NattLua Client",
    async () => {


      if (server) {
        kill();
      }

      const spawnArgs = [path, ...args];

      client.outputChannel.appendLine("spawn: " + JSON.stringify({
        executable,
        workingDirectory,
        args: spawnArgs,
      }, null, 2));

      watchFile(path, () => {
        client.outputChannel.appendLine(path + " changed, reloading");
        kill();
        unwatchFile(path);
      });

      chdir(workingDirectory);
      server = spawn(executable, spawnArgs, { cwd: workingDirectory });

      context.subscriptions.push({
        dispose: () => {
          kill();
        },
      });

      server.stdout.setEncoding("utf8");
      server.stderr.setEncoding("utf8");

      server.stdout.on("data", (str: string) => {
        serverOutput.append(str);
      });
      server.stderr.on("data", (str) => {
        serverOutput.append(str);
      });

      server.on("error", (err) => {
        serverOutput.appendLine("ERROR: " + err.toString());
        kill();
      });

      process.on("exit", () => {
        kill();
      });

      return {
        reader: server.stderr, // using STDERR explicitly to have a clean communication channel
        writer: server.stdin
      };

    },
    clientOptions
  );

  languages.registerDocumentFormattingEditProvider(selector, {
    async provideDocumentFormattingEdits(document: TextDocument) {
      try {
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
      } catch (err) {
        serverOutput.appendLine(`NattLua Format error : ${err.message}`);
      }
      return [];
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
