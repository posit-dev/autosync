// Map a file extension to a CodeMirror 6 language extension. Mirrors the coverage
// of the former R-side `ext_to_language()` (edit.R), now that the editor lives in
// the browser. Modern languages use the dedicated @codemirror/lang-* packages;
// the long tail uses @codemirror/legacy-modes via StreamLanguage.

import type { Extension } from "@codemirror/state";
import { StreamLanguage } from "@codemirror/language";
import { cpp } from "@codemirror/lang-cpp";
import { css } from "@codemirror/lang-css";
import { html } from "@codemirror/lang-html";
import { java } from "@codemirror/lang-java";
import { javascript } from "@codemirror/lang-javascript";
import { json } from "@codemirror/lang-json";
import { markdown } from "@codemirror/lang-markdown";
import { php } from "@codemirror/lang-php";
import { python } from "@codemirror/lang-python";
import { rust } from "@codemirror/lang-rust";
import { sass } from "@codemirror/lang-sass";
import { sql } from "@codemirror/lang-sql";
import { xml } from "@codemirror/lang-xml";
import { yaml } from "@codemirror/lang-yaml";
import { r } from "@codemirror/legacy-modes/mode/r";
import { julia } from "@codemirror/legacy-modes/mode/julia";
import { toml } from "@codemirror/legacy-modes/mode/toml";
import { properties } from "@codemirror/legacy-modes/mode/properties";
import { shell } from "@codemirror/legacy-modes/mode/shell";
import { dockerFile } from "@codemirror/legacy-modes/mode/dockerfile";
import { diff } from "@codemirror/legacy-modes/mode/diff";
import { stex } from "@codemirror/legacy-modes/mode/stex";

export function languageForExt(ext?: string | null): Extension {
  if (!ext) return [];
  const key = ext.replace(/^\./, "").toLowerCase();
  switch (key) {
    case "r":
    case "rprofile":
      return StreamLanguage.define(r);
    case "py":
      return python();
    case "jl":
      return StreamLanguage.define(julia);
    case "sql":
      return sql();
    case "js":
    case "mjs":
    case "cjs":
    case "jsx":
      return javascript({ jsx: true });
    case "ts":
      return javascript({ typescript: true });
    case "tsx":
      return javascript({ typescript: true, jsx: true });
    case "htm":
    case "html":
      return html();
    case "css":
      return css();
    case "scss":
      return sass();
    case "sass":
      return sass({ indented: true });
    case "json":
      return json();
    case "md":
    case "markdown":
    case "qmd":
    case "rmd":
      return markdown();
    case "yml":
    case "yaml":
      return yaml();
    case "svg":
    case "xml":
      return xml();
    case "toml":
      return StreamLanguage.define(toml);
    case "cfg":
    case "conf":
    case "ini":
      return StreamLanguage.define(properties);
    case "sh":
    case "zsh":
    case "bash":
      return StreamLanguage.define(shell);
    case "dockerfile":
      return StreamLanguage.define(dockerFile);
    case "tex":
    case "latex":
      return StreamLanguage.define(stex);
    case "c":
    case "h":
    case "cc":
    case "hh":
    case "cxx":
    case "hpp":
    case "cpp":
      return cpp();
    case "rs":
      return rust();
    case "java":
      return java();
    case "php":
      return php();
    case "patch":
    case "diff":
      return StreamLanguage.define(diff);
    default:
      return [];
  }
}
