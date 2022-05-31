import * as path from "path";
import {
  workspace,
  ExtensionContext,
  window,
  OutputChannel,
  languages,
  TextDocument,
  TextEdit,
  Range,
} from "vscode";

import {
  LanguageClient,
  LanguageClientOptions,
  Trace,
} from "vscode-languageclient/node";

import { ChildProcessWithoutNullStreams, spawn } from "child_process";
import { Socket } from "net";

let client: LanguageClient;
let server: ChildProcessWithoutNullStreams;

const kill = () => {
  if (server) {
    server.kill("SIGKILL");
  }
  server = undefined;
};

function restartServer(
  path: string,
  args: string[],
  output: OutputChannel,
  context: ExtensionContext,
  done: (host: string, port: number) => void
) {
  if (server) {
    kill();
  }

  output.appendLine("RUNNING: " + path + " " + args.join(" "));
  server = spawn(path, args, {
    cwd: workspace.rootPath,
  });

  context.subscriptions.push({
    dispose: () => {
      kill();
    },
  });

  let init = false;

  server.stdout.setEncoding("utf8");
  server.stdout.on("data", (str: string) => {
    output.append(str);

    const match = [...str.matchAll(/HOST: ([\d.]*):([\d]+)/gm)][0];
    if (match[0]) {
      const host = match[1];
      const port = parseInt(match[2], 10);

      if (!init) {
        init = true;
        done(host, port);
      }
    }
  });
  server.stderr.on("data", (str) => {
    output.appendLine("STDERROR: " + str);
    kill();
  });

  server.on("error", (err) => {
    output.appendLine("ERROR: " + err.toString());
    kill();
  });

  process.on("exit", (code) => {
    output.appendLine("EXIT: " + code.toString());
    kill();
  });
}

function getConfig<T>(option: string, defaultValue?: any): T {
  const config = workspace.getConfiguration("nattlua");
  return config.get<T>(option, defaultValue);
}

export function activate(context: ExtensionContext) {
  let output = window.createOutputChannel("Nattlua");

  const path = getConfig<string>("path");
  const args = getConfig<string[]>("arguments");

  const extensions = getConfig<string[]>("extensions");

  const clientOptions: LanguageClientOptions = {
    documentSelector: extensions,
    synchronize: {
      configurationSection: "nattlua",
    },
  };

  client = new LanguageClient(
    "Generic Language Server",
    () => {
      return new Promise((resolve, reject) => {
        let client = new Socket();

        client.on("connect", () => {
          output.appendLine(
            "CONNECTED: " + client.address + ":" + client.remotePort
          );
          resolve({
            reader: client,
            writer: client,
          });
        });

        let tryAgain = () => {
          try {
            restartServer(path, args, output, context, (host, port) => {
              client.connect(port, host);
            });
          } catch (e) {
            setTimeout(() => {
              tryAgain();
            }, 10000);
          }
        };

        client.on("error", (e) => {
          output.appendLine(`Nattlua Connection error : ${e.message}`);
          setTimeout(() => {
            tryAgain();
          }, 10000);
        });

        client.on("close", () => {
          output.appendLine(`Nattlua Connection closed, retrying`);
          tryAgain();
        });

        tryAgain();
      });
    },
    clientOptions
  );

  languages.registerDocumentFormattingEditProvider(extensions, {
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
        output.appendLine(`Nattlua Format error : ${err.message}`);
      }
      return [];
    },
  });

  client.trace = Trace.Verbose;

  const ref = client.start();

  context.subscriptions.push(ref);
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
