import * as path from "path";
import { workspace, ExtensionContext, window, OutputChannel } from "vscode";

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
  server = undefined
}

function restartServer(
  path: string,
  args: string[],
  output: OutputChannel,
  context: ExtensionContext,
  done: () => void
) {
  if (server) {
    kill()
  }

  server = spawn(path, args, {
    cwd: workspace.rootPath,
  });

  context.subscriptions.push({
    dispose: () => {
      kill()
    }
  });

  output.appendLine("RUNNING: " + path + " " + args.join(" "));
  let init = false;
  server.stdout.on("data", (str) => {
    output.appendLine(str);
    if (!init) {
      init = true;
      done();
    }
  });
  server.stderr.on("data", (str) => {
    output.appendLine("STDERROR: " + str);
    kill()
  });

  server.on("error", (err) => {
    output.appendLine("ERROR: " + err.toString());
    kill()
  });

  process.on("exit", (code) => {
    output.appendLine("EXIT: " + code.toString());
    kill()
  });
}

function getConfig<T>(option: string, defaultValue?: any): T {
  const config = workspace.getConfiguration("generic-lsp");
  return config.get<T>(option, defaultValue);
}

export function activate(context: ExtensionContext) {
  let output = window.createOutputChannel("Generic LSP");

  const path = getConfig<string>("path");
  const args = getConfig<string[]>("arguments");
  const port = getConfig<number>("port");
  const ip = getConfig<string>("ip");

  const extensions = getConfig<string[]>("extensions");

  const clientOptions: LanguageClientOptions = {
    documentSelector: extensions,
    synchronize: {
      configurationSection: "generic-lsp",
    },
  };

  client = new LanguageClient(
    "Generic Language Server",
    () => {
      return new Promise((resolve, reject) => {
        let client = new Socket();

        client.on("connect", () => {
          output.appendLine("CONNECTED");
          resolve({
            reader: client,
            writer: client,
          });
        });

        let tryAgain = () => {
          try {
            restartServer(path, args, output, context, () => {
              client.connect(port, ip);
            });
          } catch (e) {
            setTimeout(() => {
              tryAgain();
            }, 10000);
          }
        };

        client.on("error", (e) => {
          output.appendLine(`Generic LSP Connection error : ${e.message}`);
          setTimeout(() => {
            tryAgain();
          }, 10000);
        });

        client.on("close", () => {
          output.appendLine(`Generic LSP Connection closed, retrying`);
          tryAgain();
        });

        tryAgain();
      });
    },
    clientOptions
  );

  client.trace = Trace.Verbose;

  output.appendLine(`Generic LSP RUN: ${path} ${args.join(" ")}`);
  output.appendLine(`Generic LSP CONNECT: ${ip} ${port}`);
  output.appendLine(`Generic LSP EXTENSIONS: ${extensions.join(" ")}`);

  const ref = client.start();

  context.subscriptions.push(ref);
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
