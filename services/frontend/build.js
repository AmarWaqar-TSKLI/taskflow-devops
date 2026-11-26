const fs = require("fs");
const path = require("path");
const esbuild = require("esbuild");

async function build() {
  const distDir = path.join(__dirname, "dist");
  fs.mkdirSync(distDir, { recursive: true });

  await esbuild.build({
    entryPoints: [path.join(__dirname, "src", "main.js")],
    bundle: true,
    minify: true,
    sourcemap: false,
    platform: "browser",
    target: ["es2020"],
    outfile: path.join(distDir, "bundle.js"),
  });

  fs.copyFileSync(
    path.join(__dirname, "index.html"),
    path.join(distDir, "index.html"),
  );
  fs.copyFileSync(
    path.join(__dirname, "styles.css"),
    path.join(distDir, "styles.css"),
  );
}

build().catch((err) => {
  console.error(err);
  process.exit(1);
});
