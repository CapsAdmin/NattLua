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
  .catch(() => process.exit(1));
