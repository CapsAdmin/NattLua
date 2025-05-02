const { execSync } = require("child_process")
const fs = require("fs")
const path = require("path")
const { finished } = require("stream/promises")
const { Readable } = require("stream")

async function downloadFile(url, outputPath, cbPreprocess) {
	const response = await fetch(url)

	if (!response.ok) {
		throw new Error(`Failed to download, status: ${response.status}`)
	}

	const directory = path.dirname(outputPath)

	fs.mkdirSync(directory, { recursive: true })
	const buf = Buffer.from(await response.arrayBuffer())
	if (cbPreprocess) {
		const code = buf.toString()
		const processedCode = cbPreprocess(code)
		fs.writeFileSync(outputPath, processedCode)
	} else {
		fs.writeFileSync(outputPath, buf)
	}
}

function getAllFiles(dirPath, arrayOfFiles) {
	files = fs.readdirSync(dirPath)

	arrayOfFiles = arrayOfFiles || []

	for (const file of files) {
		if (fs.statSync(dirPath + "/" + file).isDirectory()) {
			arrayOfFiles = getAllFiles(dirPath + "/" + file, arrayOfFiles)
		} else {
			arrayOfFiles.push(path.join(__dirname, dirPath, "/", file))
		}
	}

	return arrayOfFiles
}

let tests = []

for (let path of getAllFiles("../test/tests/nattlua/analyzer/")) {
	if (path.endsWith(".nlua")) {
		tests.push(fs.readFileSync(path).toString())
	} else {
		let data = fs.readFileSync(path).toString()
		let matches = data.matchAll(/analyze\s*\[\[(.*?)\]\]/gms)
		for (let match of matches) {
			tests.push(match[1])
		}
	}
}

fs.writeFileSync("src/random.json", JSON.stringify(tests))

async function downloadLua() {
	let baseUrl = "https://raw.githubusercontent.com/thenumbernine/js-util/e858eb39cc7a4f2f279f8742a377a53393a8e07f/"

	await downloadFile(baseUrl + "lua-5.4.7-with-ffi.wasm", "public/lua-5.4.7-with-ffi.wasm")
	await downloadFile(baseUrl + "lua-interop.js", "public/lua-interop.js")
	await downloadFile(baseUrl + "lua-5.4.7-with-ffi.js", "public/lua-5.4.7-with-ffi.js")
}

downloadLua()

execSync("cd ../ && luajit nattlua.lua build fast")

require("esbuild")
	.build({
		format: "iife",
		platform: "node",
		entryPoints: {
			app: "src/index.ts",
			"editor.worker": "monaco-editor/esm/vs/editor/editor.worker.js",
		},
		entryNames: "[name].bundle",
		loader: "expose-loader",
		bundle: true,
		outdir: "public/",
		loader: {
			".ttf": "dataurl",
			".lua": "text",
			".nlua": "text",
		},
	})
	.catch(() => process.exit(1))
