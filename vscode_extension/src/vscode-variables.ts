import * as vscode from 'vscode';
import * as process from 'process';
import * as path from 'path';

export function resolveVariables(string: string, recursive = false) {
    const workspaces = vscode.workspace.workspaceFolders || [];
    const workspace = workspaces.length ? workspaces[0] : null;
    const activeEditor = vscode.window.activeTextEditor;
    const activeDocument = activeEditor?.document;
    const absoluteFilePath = activeDocument?.uri.fsPath || '';
    const workspaceFolderPath = workspace?.uri.fsPath || '';
    const workspaceFolderBasename = workspace?.name || '';
    let activeWorkspace = workspace;
    let relativeFilePath = absoluteFilePath;

    string = string.replace(/\${workspaceFolder}/g, workspaceFolderPath);
    string = string.replace(/\${workspaceFolderBasename}/g, workspaceFolderBasename);
    string = string.replace(/\${file}/g, absoluteFilePath);

    if (absoluteFilePath) {
        for (const workspace of workspaces) {
            if (absoluteFilePath.startsWith(workspace.uri.fsPath)) {
                activeWorkspace = workspace;
                relativeFilePath = absoluteFilePath.slice(workspace.uri.fsPath.length).replace(new RegExp(`^\\${path.sep}+`), '');
                break;
            }
        }
    }

    const parsedPath = path.parse(absoluteFilePath || '');
    const relativeFileDirname = relativeFilePath.includes(path.sep)
        ? relativeFilePath.slice(0, relativeFilePath.lastIndexOf(path.sep))
        : '';
    const fileDirname = parsedPath.dir
        ? parsedPath.dir.slice(parsedPath.dir.lastIndexOf(path.sep) + 1)
        : '';
    const cwd = parsedPath.dir || workspaceFolderPath || process.cwd();
    const lineNumber = activeEditor ? (activeEditor.selection.start.line + 1).toString() : '1';
    const selectedText = activeEditor
        ? activeEditor.document.getText(new vscode.Range(activeEditor.selection.start, activeEditor.selection.end))
        : '';

    string = string.replace(/\${fileWorkspaceFolder}/g, activeWorkspace?.uri.fsPath || workspaceFolderPath);
    string = string.replace(/\${relativeFile}/g, relativeFilePath);
    string = string.replace(/\${relativeFileDirname}/g, relativeFileDirname);
    string = string.replace(/\${fileBasename}/g, parsedPath.base || '');
    string = string.replace(/\${fileBasenameNoExtension}/g, parsedPath.name || '');
    string = string.replace(/\${fileExtname}/g, parsedPath.ext || '');
    string = string.replace(/\${fileDirname}/g, fileDirname);
    string = string.replace(/\${cwd}/g, cwd);
    string = string.replace(/\${pathSeparator}/g, path.sep);
    string = string.replace(/\${lineNumber}/g, lineNumber);
    string = string.replace(/\${selectedText}/g, selectedText);
    string = string.replace(/\${env:(.*?)}/g, function (variable) {
        return process.env[variable.match(/\${env:(.*?)}/)[1]] || '';
    });
    string = string.replace(/\${config:(.*?)}/g, function (variable) {
        return vscode.workspace.getConfiguration().get(variable.match(/\${config:(.*?)}/)[1], '');
    });

    if (recursive && string.match(/\${(workspaceFolder|workspaceFolderBasename|fileWorkspaceFolder|relativeFile|fileBasename|fileBasenameNoExtension|fileExtname|fileDirname|cwd|pathSeparator|lineNumber|selectedText|env:(.*?)|config:(.*?))}/)) {
        string = resolveVariables(string, recursive);
    }
    return string;
}