// File tree powered by @pierre/trees (trees.software). The R project connection
// owns the file list; we receive the flat `paths` vector via `output$paths` and
// the path-first model builds the visual tree. Selecting a file row reports its
// canonical path back through `input$file`, which round-trips exactly to
// amsync_project()'s `$open(path)`.

import type { CSSProperties } from "react";
import { themeToTreeStyles } from "@pierre/trees";
import { FileTree, useFileTree, useFileTreeSelection } from "@pierre/trees/react";

import { React, fireShinyEvent } from "./shiny";

// Light theme matching the app chrome; the tree renders in a shadow root, so we
// drive its colours through the documented --trees-theme-* custom properties.
const TREE_THEME = themeToTreeStyles({
  type: "light",
  bg: "#f6f8fa",
  fg: "#1f2328",
}) as CSSProperties;

export function FileTreeView({ paths }: { paths: string[] }) {
  // useFileTree() builds one stable model for the component lifetime; later path
  // changes (connect / refresh) are pushed via resetPaths(), not by re-creating.
  const { model } = useFileTree({
    paths,
    search: true,
    density: "compact",
    initialExpansion: "open",
  });

  const mounted = React.useRef(false);
  React.useEffect(() => {
    if (!mounted.current) {
      mounted.current = true;
      return;
    }
    model.resetPaths(paths, { initialExpandedPaths: undefined });
  }, [model, paths]);

  // Selection is purely user-driven (clicks/keyboard); a single selected path
  // that is a known file opens it. Directories and multi-select are ignored.
  const fileSet = React.useMemo(() => new Set(paths), [paths]);
  const selection = useFileTreeSelection(model);
  React.useEffect(() => {
    if (selection.length === 1 && fileSet.has(selection[0])) {
      fireShinyEvent("file", selection[0]);
    }
  }, [selection, fileSet]);

  return <FileTree model={model} className="amsync-tree" style={TREE_THEME} />;
}
