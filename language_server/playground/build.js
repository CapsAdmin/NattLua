require("esbuild")
  .build({
    format: "iife",
    platform: "node",
    entryPoints: ["index.ts"],
    loader: "expose-loader",
    bundle: true,
    outfile: "out.js",
    loader: {
      ".ttf": "dataurl",
    },
  })
  .catch(() => process.exit(1));
