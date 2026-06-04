// Live CodeMirror 6 editor. The R server owns the Automerge document; this editor
// is a plain text view whose value flows over Shiny:
//   * outgoing: real local edits -> `input$content` (debounced), where
//     install_editor_sync() writes the minimal diff into the live document. We
//     send imperatively via window.Shiny only from genuine edits — a hook like
//     useSetShinyInput would broadcast its default ("") on mount and clobber the
//     open document before the user types anything.
//   * incoming: `output$editor_doc` ({ path, value, ext, rev }) is pushed on open
//     and on every remote change. We re-apply it only when `rev` advances, in a
//     transaction tagged `fromServer` so the update listener ignores it (no echo
//     back to R), reconfiguring the language when the extension changes.

import { basicSetup } from "codemirror";
import { Annotation, Compartment, EditorState } from "@codemirror/state";
import { EditorView, keymap } from "@codemirror/view";
import { indentWithTab } from "@codemirror/commands";
import { indentUnit } from "@codemirror/language";

import { React, useShinyOutputValue } from "./shiny";
import { languageForExt } from "./languages";

interface EditorDoc {
  path: string;
  value: string;
  ext: string;
  rev: number;
  debounce: number;
}

// Marks transactions originating from the server so the update listener does not
// echo them back to R as a local edit.
const fromServer = Annotation.define<boolean>();

export function Editor() {
  const hostRef = React.useRef<HTMLDivElement>(null);
  const viewRef = React.useRef<EditorView | null>(null);
  const language = React.useRef(new Compartment());
  const lastRev = React.useRef<number>(-1);

  const doc = useShinyOutputValue<EditorDoc>("editor_doc");

  // Debounce config lives in a ref so the (once-created) update listener always
  // reads the current value without re-creating the editor view.
  const debounceRef = React.useRef(300);
  debounceRef.current = doc?.debounce ?? 300;
  const sendTimer = React.useRef<number | null>(null);

  // Create the editor view once.
  React.useEffect(() => {
    const view = new EditorView({
      parent: hostRef.current ?? undefined,
      state: EditorState.create({
        doc: "",
        extensions: [
          // basicSetup bundles syntax highlighting (defaultHighlightStyle) plus
          // line numbers, history, code folding, search (Ctrl-F), autocompletion,
          // bracket matching/closing, active-line + selection-match highlighting.
          basicSetup,
          keymap.of([indentWithTab]),
          indentUnit.of("  "),
          EditorState.tabSize.of(2),
          language.current.of([]),
          EditorView.lineWrapping,
          EditorView.updateListener.of((u) => {
            if (!u.docChanged) return;
            // Skip server-applied changes so we never echo them back to R.
            if (u.transactions.some((t) => t.annotation(fromServer))) return;
            const text = u.state.doc.toString();
            if (sendTimer.current != null) window.clearTimeout(sendTimer.current);
            sendTimer.current = window.setTimeout(() => {
              sendTimer.current = null;
              window.Shiny?.setInputValue?.("content", text);
            }, debounceRef.current);
          }),
        ],
      }),
    });
    viewRef.current = view;
    return () => {
      if (sendTimer.current != null) window.clearTimeout(sendTimer.current);
      view.destroy();
      viewRef.current = null;
    };
  }, []);

  // Apply server-pushed content/extension whenever the revision advances.
  React.useEffect(() => {
    const view = viewRef.current;
    if (!view || !doc || doc.rev === lastRev.current) return;
    lastRev.current = doc.rev;
    const current = view.state.doc.toString();
    const effects = [language.current.reconfigure(languageForExt(doc.ext))];
    view.dispatch({
      changes:
        current === doc.value
          ? undefined
          : { from: 0, to: current.length, insert: doc.value },
      effects,
      annotations: fromServer.of(true),
    });
  }, [doc]);

  return <div className="amsync-editor" ref={hostRef} />;
}
