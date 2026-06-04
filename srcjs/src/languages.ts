// Map a file extension to a CodeMirror 6 language extension. Mirrors the coverage
// of the former R-side `ext_to_language()` (edit.R), now that the editor lives in
// the browser. Modern languages use the dedicated @codemirror/lang-* packages;
// the long tail uses @codemirror/legacy-modes via StreamLanguage.
//
// Markdown variants (incl. Quarto .qmd / R Markdown .Rmd) are wrapped so a
// leading `--- ... ---` block is parsed as YAML front matter, and fenced code
// chunks are highlighted in their own language — including knitr/Quarto's
// `{r}` / `{python}` brace syntax.

import type { Extension } from "@codemirror/state";
import { LanguageSupport, StreamLanguage } from "@codemirror/language";
import type { Language } from "@codemirror/language";
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
import { yaml, yamlFrontmatter } from "@codemirror/lang-yaml";
import { r } from "@codemirror/legacy-modes/mode/r";
import { julia } from "@codemirror/legacy-modes/mode/julia";
import { toml } from "@codemirror/legacy-modes/mode/toml";
import { properties } from "@codemirror/legacy-modes/mode/properties";
import { shell } from "@codemirror/legacy-modes/mode/shell";
import { dockerFile } from "@codemirror/legacy-modes/mode/dockerfile";
import { diff } from "@codemirror/legacy-modes/mode/diff";
import { stex } from "@codemirror/legacy-modes/mode/stex";

// Lowercase, drop a leading dot.
function normalizeKey(s?: string | null): string {
  return s ? s.trim().replace(/^\./, "").toLowerCase() : "";
}

// Extract the language from a fenced-code info string, handling plain (```r),
// knitr (```{r}) and option-bearing (```{r setup, echo=FALSE}) forms.
function normalizeInfo(info: string): string {
  let s = info.trim();
  const brace = s.match(/^\{([^}]*)\}/);
  if (brace) s = brace[1];
  return normalizeKey(s.split(/[\s,]+/)[0] ?? "");
}

const MARKDOWN_KEYS = new Set(["md", "markdown", "qmd", "rmd"]);

// Build the language for a normalized key. Accepts both file-extension keys and
// fenced-code language names (e.g. "py" and "python"). Returns null for unknown
// keys (plain text). Markdown is the plain variant here; the front-matter
// wrapper is applied only at the top level (see languageForExt).
function buildSupport(key: string): LanguageSupport | Language | null {
  switch (key) {
    case "r":
    case "rscript":
    case "rprofile":
      return StreamLanguage.define(r);
    case "py":
    case "python":
      return python();
    case "jl":
    case "julia":
      return StreamLanguage.define(julia);
    case "sql":
      return sql();
    case "js":
    case "mjs":
    case "cjs":
    case "jsx":
    case "javascript":
    case "node":
      return javascript({ jsx: true });
    case "ts":
    case "typescript":
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
    case "yaml":
    case "yml":
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
    case "shell":
      return StreamLanguage.define(shell);
    case "dockerfile":
    case "docker":
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
    case "rust":
      return rust();
    case "java":
      return java();
    case "php":
      return php();
    case "patch":
    case "diff":
      return StreamLanguage.define(diff);
    case "md":
    case "markdown":
    case "qmd":
    case "rmd":
      return markdown();
    default:
      return null;
  }
}

function toLanguage(x: LanguageSupport | Language): Language {
  return x instanceof LanguageSupport ? x.language : x;
}

// Markdown with YAML front matter + per-chunk code highlighting.
function markdownDoc(): Extension {
  return yamlFrontmatter({
    content: markdown({
      codeLanguages: (info) => {
        const support = buildSupport(normalizeInfo(info));
        return support ? toLanguage(support) : null;
      },
    }),
  });
}

export function languageForExt(ext?: string | null): Extension {
  const key = normalizeKey(ext);
  if (MARKDOWN_KEYS.has(key)) return markdownDoc();
  return buildSupport(key) ?? [];
}
