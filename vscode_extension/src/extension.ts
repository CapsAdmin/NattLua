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
import { resolve } from "path";
import * as fs from "fs";

let client: LanguageClient;
let server: ChildProcessWithoutNullStreams;
const documentSelector = [{ scheme: 'file', language: 'nattlua' }];
const MAX_SERVER_RESTARTS = 5;
const SERVER_RESTART_WINDOW_MS = 60_000;
const SERVER_RESTART_DELAY_MS = 1_000;

export async function activate(context: ExtensionContext) {
  const config = workspace.getConfiguration("nattlua");
  let LSPOutput = window.createOutputChannel("NattLua LSP Channel");
  let LSPCallsOutput = window.createOutputChannel("NattLua LSP Calls");
  let serverOutput = window.createOutputChannel("NattLua Server");
  let clientOutput: OutputChannel;
  let isDeactivating = false;
  let restartTimestamps: number[] = [];
  let restartTimer: NodeJS.Timeout | undefined;
  let startPromise: Promise<void> | undefined;
  const syncedVisibleDocuments = new Set<string>();
  const pendingCalls = new Map<string, {
    direction: "client->server" | "server->client";
    method?: string;
    startedAt: number;
    sequence: number;
    pendingAtSend: number;
    cancelRequested?: boolean;
  }>();
  let requestSequence = 0;

  type ParsedLspMessage = {
    headers: Record<string, string>;
    body: string;
    size: number;
  };

  const createMessageParser = (onMessage: (message: ParsedLspMessage) => void) => {
    let buffer = "";

    return (chunk: string) => {
      buffer += chunk;

      while (true) {
        const headerEnd = buffer.indexOf("\r\n\r\n");

        if (headerEnd === -1) {
          return;
        }

        const headerText = buffer.slice(0, headerEnd);
        const headers: Record<string, string> = {};

        for (const line of headerText.split("\r\n")) {
          const separatorIndex = line.indexOf(":");

          if (separatorIndex === -1) {
            continue;
          }

          const key = line.slice(0, separatorIndex).trim().toLowerCase();
          const value = line.slice(separatorIndex + 1).trim();
          headers[key] = value;
        }

        const contentLength = Number(headers["content-length"] || 0);
        const messageEnd = headerEnd + 4 + contentLength;

        if (buffer.length < messageEnd) {
          return;
        }

        const body = buffer.slice(headerEnd + 4, messageEnd);
        buffer = buffer.slice(messageEnd);
        onMessage({ headers, body, size: Buffer.byteLength(body, "utf8") });
      }
    };
  };

  const logLspCall = (direction: "client->server" | "server->client", message: ParsedLspMessage) => {
    if (message.size === 0 || message.body.trim() === "") {
      return;
    }

    let payload: any;

    try {
      payload = JSON.parse(message.body);
    } catch {
      LSPCallsOutput.appendLine(`[PARSE] ${direction} invalid-json bytes=${message.size}`);
      return;
    }

    const hasId = payload.id !== undefined && payload.id !== null;
    const hasMethod = typeof payload.method === "string";
    const idKey = hasId ? String(payload.id) : undefined;

    if (hasMethod && hasId) {
      const pendingAtSend = Array.from(pendingCalls.values()).filter((entry) => entry.direction === direction).length;
      requestSequence += 1;
      pendingCalls.set(idKey!, {
        direction,
        method: payload.method,
        startedAt: Date.now(),
        sequence: requestSequence,
        pendingAtSend,
      });
      LSPCallsOutput.appendLine(`[REQ] ${direction} seq=${requestSequence} id=${idKey} method=${payload.method} bytes=${message.size} pending=${pendingAtSend}`);
      return;
    }

    if (hasMethod) {
      if (payload.method === "$/cancelRequest") {
        const cancelledId = payload.params?.id !== undefined && payload.params?.id !== null
          ? String(payload.params.id)
          : undefined;
        const pending = cancelledId ? pendingCalls.get(cancelledId) : undefined;

        if (pending) {
          pending.cancelRequested = true;
        }

        const method = pending?.method ? ` method=${pending.method}` : "";
        LSPCallsOutput.appendLine(`[CANCEL] ${direction} id=${cancelledId ?? "?"}${method} bytes=${message.size}`);
        return;
      }

      LSPCallsOutput.appendLine(`[NOTIFY] ${direction} method=${payload.method} bytes=${message.size}`);
      return;
    }

    if (hasId) {
      const pending = pendingCalls.get(idKey!);
      const elapsed = pending && pending.direction !== direction ? `${Date.now() - pending.startedAt}ms` : "?ms";
      const method = pending?.method ? ` method=${pending.method}` : "";
      const seq = pending ? ` seq=${pending.sequence}` : "";
      const pendingAtSend = pending ? ` pendingAtSend=${pending.pendingAtSend}` : "";
      const cancelRequested = pending?.cancelRequested ? ` cancelRequested=true` : "";
      pendingCalls.delete(idKey!);
      if (payload.error?.code === -32800) {
        LSPCallsOutput.appendLine(`[CANCELLED] ${direction} id=${idKey}${seq}${method} bytes=${message.size} e2e=${elapsed}${pendingAtSend}${cancelRequested}`);
      } else if (payload.error) {
        const errorCode = payload.error?.code !== undefined ? ` code=${payload.error.code}` : "";
        LSPCallsOutput.appendLine(`[ERROR] ${direction} id=${idKey}${seq}${method} bytes=${message.size} e2e=${elapsed}${pendingAtSend}${cancelRequested}${errorCode}`);
      } else {
        LSPCallsOutput.appendLine(`[RESP] ${direction} id=${idKey}${seq}${method} bytes=${message.size} e2e=${elapsed}${pendingAtSend}${cancelRequested}`);
      }
      return;
    }

    LSPCallsOutput.appendLine(`[MSG] ${direction} bytes=${message.size}`);
  };

  const parseClientToServer = createMessageParser((message) => {
    logLspCall("client->server", message);
  });

  const parseServerToClient = createMessageParser((message) => {
    logLspCall("server->client", message);
  });

  const isVisibleDocument = (document: TextDocument) => {
    return window.visibleTextEditors.some(editor => editor.document.uri.toString() === document.uri.toString());
  };

  const isSyncCandidate = (document: TextDocument) => {
    return document.uri.scheme === 'file' && document.languageId === 'nattlua';
  };

  const sendDidOpen = (document: TextDocument) => {
    if (!client || !client.isRunning()) {
      return;
    }

    const uri = document.uri.toString();
    client.sendNotification('textDocument/didOpen', {
      textDocument: {
        uri,
        languageId: document.languageId,
        version: document.version,
        text: document.getText(),
      },
    });
    syncedVisibleDocuments.add(uri);
  };

  const sendDidClose = (document: TextDocument) => {
    if (!client || !client.isRunning()) {
      return;
    }

    const uri = document.uri.toString();
    client.sendNotification('textDocument/didClose', {
      textDocument: { uri },
    });
    syncedVisibleDocuments.delete(uri);
  };

  const reconcileVisibleDocumentSync = () => {
    if (!client || !client.isRunning()) {
      return;
    }

    const visibleDocuments = window.visibleTextEditors
      .map(editor => editor.document)
      .filter(isSyncCandidate);
    const nextVisibleUris = new Set(visibleDocuments.map(document => document.uri.toString()));

    for (const document of visibleDocuments) {
      const uri = document.uri.toString();
      if (!syncedVisibleDocuments.has(uri)) {
        sendDidOpen(document);
      }
    }

    for (const uri of Array.from(syncedVisibleDocuments)) {
      if (!nextVisibleUris.has(uri)) {
        const document = workspace.textDocuments.find(document => document.uri.toString() === uri);
        if (document && isSyncCandidate(document)) {
          sendDidClose(document);
        } else {
          syncedVisibleDocuments.delete(uri);
        }
      }
    }
  };

  const sendVisibleEditors = () => {
    if (!client || !client.isRunning()) {
      return;
    }

    const uris = window.visibleTextEditors
      .filter(editor => editor.document.uri.scheme === 'file' && editor.document.languageId === 'nattlua')
      .map(editor => editor.document.uri.toString());

    client.sendNotification('nattlua/visibleEditors', { uris });
  };

  const executable = resolveVariables(config.get<string>("executable") || "nattlua");
  const workingDirectory = resolveVariables(config.get<string>("workingDirectory") || "${workspaceFolder}");
  const args = (config.get<string[]>("arguments") || []).map(arg => resolveVariables(arg));

  if (!fs.existsSync(workingDirectory)) {
    window.showWarningMessage(`NattLua: Working directory '${workingDirectory}' not found. Defaulting to workspace root.`);
  }

  const pruneRestartTimestamps = () => {
    const cutoff = Date.now() - SERVER_RESTART_WINDOW_MS;
    restartTimestamps = restartTimestamps.filter(timestamp => timestamp >= cutoff);
  };

  const scheduleRestart = (reason: string) => {
    if (isDeactivating) {
      return;
    }

    pruneRestartTimestamps();

    if (restartTimestamps.length >= MAX_SERVER_RESTARTS) {
      const message = `NattLua server restart limit reached (${MAX_SERVER_RESTARTS} retries in ${SERVER_RESTART_WINDOW_MS / 1000} seconds).`;
      LSPOutput.appendLine(message);
      window.showErrorMessage(message);
      return;
    }

    restartTimestamps.push(Date.now());

    if (restartTimer) {
      clearTimeout(restartTimer);
    }

    LSPOutput.appendLine(`Scheduling NattLua server restart (${restartTimestamps.length}/${MAX_SERVER_RESTARTS}) due to: ${reason}`);
    restartTimer = setTimeout(() => {
      restartTimer = undefined;
      void startClient(`restart: ${reason}`);
    }, SERVER_RESTART_DELAY_MS);
  };

  const startClient = async (reason: string) => {
    if (isDeactivating || client.isRunning()) {
      return;
    }

    if (startPromise) {
      return startPromise;
    }

    startPromise = (async () => {
      clientOutput.appendLine(`Starting NattLua server (${reason}) with command: ${executable} ${args.join(" ")}`);

      try {
        await client.start();
        clientOutput.appendLine(`NattLua server started successfully (${reason})`);
        reconcileVisibleDocumentSync();
        sendVisibleEditors();
      } catch (err: any) {
        const message = err?.message || String(err);
        clientOutput.appendLine(`NattLua failed to start (${reason}): ${message}`);
        scheduleRestart(`start failure: ${message}`);
      } finally {
        startPromise = undefined;
      }
    })();

    return startPromise;
  };

  const errorHandler: ErrorHandler = {
    error: (error, message, count) => {
      LSPOutput.appendLine(`LSP Error: ${message} (${count}) - ${error.message}`);
      if ((count ?? 0) <= 3) return { action: ErrorAction.Continue };
      return { action: ErrorAction.Shutdown };
    },
    closed: () => {
      LSPOutput.appendLine("LSP connection closed.");
      scheduleRestart("connection closed");
      return { action: CloseAction.DoNotRestart };
    }
  };

  const clientOptions: LanguageClientOptions = {
    documentSelector,
    synchronize: {
      configurationSection: "nattlua",
    },
    middleware: {
      didOpen: (document, next) => {
        const visible = isVisibleDocument(document);

        if (!visible) {
          return Promise.resolve();
        }

        syncedVisibleDocuments.add(document.uri.toString());
        return next(document);
      },
      didChange: (event, next) => {
        if (!syncedVisibleDocuments.has(event.document.uri.toString())) {
          return Promise.resolve();
        }

        return next(event);
      },
      didSave: (document, next) => {
        if (!syncedVisibleDocuments.has(document.uri.toString())) {
          return Promise.resolve();
        }

        return next(document);
      },
      didClose: (document, next) => {
        const uri = document.uri.toString();
        if (!syncedVisibleDocuments.has(uri)) {
          return Promise.resolve();
        }

        syncedVisibleDocuments.delete(uri);
        return next(document);
      },
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
        server.on("exit", (code, signal) => {
          serverOutput.appendLine(`SERVER EXIT: code=${code ?? "null"} signal=${signal ?? "null"}`);
        });

        const reader = server.stderr;  // using STDERR explicitly to have a clean communication channel
        reader.setEncoding("utf8");
        reader.on("data", (str) => {
          LSPOutput.appendLine(">>\n" + str);
          parseServerToClient(str);
        });

        const output = server.stdout;
        output.setEncoding("utf8");
        output.on("data", (str: string) => serverOutput.append(str));

        const writer = server.stdin;

        {
          const originalWrite = writer._write;
          writer._write = function (chunk: any, encoding: BufferEncoding, callback: (error?: Error | null) => void): void {
            const text = chunk.toString();
            LSPOutput.appendLine("<<\n" + text);
            parseClientToServer(text);
            originalWrite.call(this, chunk, encoding, callback);
          };
        }

        context.subscriptions.push({
          dispose: () => {
            if (server && !server.killed) server.kill("SIGTERM");
          },
        });

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

  context.subscriptions.push({
    dispose: () => {
      isDeactivating = true;

      if (restartTimer) {
        clearTimeout(restartTimer);
        restartTimer = undefined;
      }
    },
  });

  context.subscriptions.push(window.onDidChangeVisibleTextEditors(() => {
    reconcileVisibleDocumentSync();
    sendVisibleEditors();
  }));

  context.subscriptions.push(window.onDidChangeActiveTextEditor(() => {
    reconcileVisibleDocumentSync();
    sendVisibleEditors();
  }));

  await startClient("initial start");
}

export async function deactivate(): Promise<void | undefined> {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
