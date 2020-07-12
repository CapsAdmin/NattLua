
import { spawn } from 'child_process';
import { Socket } from 'net';
import { ExtensionContext, window, workspace } from 'vscode';
import { LanguageClient, LanguageClientOptions } from "vscode-languageclient";

function getConfig<T>(option: string, defaultValue?: any): T {
    const config = workspace.getConfiguration('generic-lsp');
    return config.get<T>(option, defaultValue);
}

export function activate(context: ExtensionContext) {
    let output = window.createOutputChannel('Generic LSP');
    output.show(true)

    const path = getConfig<string>('path');
    const args = getConfig<string[]>('arguments');
    const port = getConfig<number>('port');
    const ip = getConfig<string>('ip');

    const extensions = getConfig<string[]>('extensions');


    const clientOptions: LanguageClientOptions = {
        documentSelector: extensions,
        synchronize: {
            configurationSection: "generic-lsp",
        },
    };

    const lspClient = new LanguageClient('Generic Language Server', () => {
        return new Promise((resolve, reject) => {
            const server = spawn(path, args, {
                cwd: workspace.rootPath,
            })

            output.appendLine("RUNNING: " + path + " " + args.join(" "))

            server.stdout.on("data", (str) => output.appendLine(str))
            server.stderr.on("data", (str) => output.appendLine(str))

            server.on("error", (err) => output.appendLine("error: " + err.toString()))

            process.on("exit", () => server.kill())

            let client = new Socket()

            client.on("connect", () => {
                resolve({
                    reader: client,
                    writer: client
                })
            })

            let retry = () => {
                try {
                    client.connect(port, ip)
                } catch (e) {
                    setTimeout(() => {
                        retry()
                    }, 1000);
                }
            }

            client.on('error', e => {
                output.appendLine(`Generic LSP Connection error : ${e.message}`)
                setTimeout(() => {
                    retry()
                }, 1000);
            })

            retry();
        })
    }, clientOptions);

    output.appendLine(`Generic LSP RUN: ${path} ${args.join(" ")}`)
    output.appendLine(`Generic LSP CONNECT: ${ip} ${port}`)
    output.appendLine(`Generic LSP EXTENSIONS: ${extensions.join(" ")}`)

    const disposable = lspClient.start();
}
