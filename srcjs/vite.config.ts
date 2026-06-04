import path from "node:path";
import { fileURLToPath } from "node:url";

import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// React/ReactDOM are externalized and pulled from window.shinyreact at runtime so
// this bundle shares the single React instance that owns the shinyreact hooks
// (two React copies would break hooks with "invalid hook call"). @pierre/trees and
// CodeMirror are bundled in.
export default defineConfig({
  define: {
    "process.env.NODE_ENV": JSON.stringify("production"),
  },
  plugins: [react()],
  build: {
    outDir: path.resolve(__dirname, "../inst/www"),
    emptyOutDir: false,
    cssCodeSplit: false,
    // Target a level with native class private methods/fields. The default
    // ('modules', which includes Safari 14) makes esbuild down-level @pierre/trees'
    // private methods to WeakSet brand-checks, which minification then mangles
    // into a runtime "X.has is not a function" crash. The gadget only ever runs
    // in a modern browser, so es2022 is safe.
    target: "es2022",
    lib: {
      entry: path.resolve(__dirname, "src/index.tsx"),
      formats: ["iife"],
      name: "autosyncFrontend",
      fileName: () => "amsync.js",
    },
    rollupOptions: {
      external: ["react", "react-dom", "react-dom/client"],
      output: {
        assetFileNames: "amsync.[ext]",
        globals: {
          react: "window.shinyreact.React",
          "react-dom": "window.shinyreact.ReactDOM",
          "react-dom/client": "window.shinyreact.ReactDOM",
        },
      },
    },
  },
});
