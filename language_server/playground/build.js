const fs = require("fs")
const path = require("path")

const getAllFiles = function (dirPath, arrayOfFiles) {
	files = fs.readdirSync(dirPath)

	arrayOfFiles = arrayOfFiles || []

	files.forEach(function (file) {
		if (fs.statSync(dirPath + "/" + file).isDirectory()) {
			arrayOfFiles = getAllFiles(dirPath + "/" + file, arrayOfFiles)
		} else {
			arrayOfFiles.push(path.join(__dirname, dirPath, "/", file))
		}
	})

	return arrayOfFiles
}

let tests = []

for (let path of getAllFiles("../../test/nattlua/analyzer/")) {
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

require("esbuild")
	.build({
		format: "iife",
		platform: "node",
		entryPoints: ["src/index.ts"],
		loader: "expose-loader",
		bundle: true,
		outfile: "public/out.js",
		loader: {
			".ttf": "dataurl",
			".lua": "text",
			".nlua": "text",
		},
	})
	.catch(() => process.exit(1))
