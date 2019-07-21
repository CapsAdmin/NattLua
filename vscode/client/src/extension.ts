import * as vscode from 'vscode';
import { Socket } from 'net'
import * as vscodelc from 'vscode-languageclient';
import { spawn } from 'child_process';

function getConfig<T>(option: string, defaultValue?: any): T {
    const config = vscode.workspace.getConfiguration('generic-lsp');
    return config.get<T>(option, defaultValue);
}

export function activate(context: vscode.ExtensionContext) {
    const path = getConfig<string>('path');
    const args = getConfig<string[]>('arguments');
    const port = getConfig<number>('port');
    const ip = getConfig<string>('ip');

    const extensions = getConfig<string[]>('extensions');

    const clientOptions: vscodelc.LanguageClientOptions = {
        documentSelector: extensions,
        synchronize: {
            configurationSection: "generic-lsp",
        },
    };

    const lspClient = new vscodelc.LanguageClient('Generic Language Server', () => {
        return new Promise((resolve, reject) => {
            //const server = spawn(path, args, { stdio: [process.stdin, data => console.log(data), data => console.log(data)] })

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
                } catch(e) {
                    setTimeout(() => {
                        retry()
                    }, 1000);
                }
            }

            client.on('error', e => {
                console.log(`Generic LSP Connection error : ${e.message}`)
                setTimeout(() => {
                    retry()
                }, 1000);
            })

            retry();
        })
    }, clientOptions);

    console.log(`Generic LSP RUN: ${path} ${args.join(" ")}`)
    console.log(`Generic LSP CONNECT: ${ip} ${port}`)
    console.log(`Generic LSP EXTENSIONS: ${extensions.join(" ")}`)

    const disposable = lspClient.start();
}
