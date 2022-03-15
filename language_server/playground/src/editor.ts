import { editor } from "monaco-editor";

export const createEditor = () => {
    const editorInstance = editor.create(document.getElementById("container"), {
      minimap: { enabled: false },
      scrollBeyondLastLine: false,
      theme: "vs-dark",
    });
  
    window.addEventListener("resize", () => {
      editorInstance.layout();
    });
  
    return editorInstance;
  };