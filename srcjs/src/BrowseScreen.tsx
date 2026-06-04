// Browse screen: a sidebar with the file tree and Refresh / Disconnect actions,
// and a main pane holding the live editor (or a prompt when nothing is open).

import { useShinyEvent, useShinyOutputValue } from "./shiny";
import { FileTreeView } from "./FileTree";
import { FileIcon } from "./FileIcon";
import { Editor } from "./Editor";

export function BrowseScreen() {
  const paths = useShinyOutputValue<string[]>("paths", []) ?? [];
  const selected = useShinyOutputValue<string | null>("selected", null) ?? null;
  const refresh = useShinyEvent("refresh");
  const disconnect = useShinyEvent("disconnect");

  return (
    <div className="amsync-browse">
      <aside className="amsync-sidebar">
        <div className="amsync-sidebar-title">Files</div>
        <div className="amsync-tree-wrap">
          {paths.length === 0 ? (
            <div className="amsync-empty">No files in project.</div>
          ) : (
            <FileTreeView paths={paths} />
          )}
        </div>
        <div className="amsync-sidebar-actions">
          <button
            type="button"
            className="amsync-btn amsync-btn-sm amsync-btn-outline amsync-fill"
            onClick={refresh}
          >
            Refresh
          </button>
          <button
            type="button"
            className="amsync-btn amsync-btn-sm amsync-btn-danger amsync-fill"
            onClick={disconnect}
          >
            Disconnect
          </button>
        </div>
      </aside>
      <main className="amsync-main">
        {selected ? (
          <div className="amsync-editor-card">
            <div className="amsync-editor-header">
              <span className="amsync-editor-title">
                <FileIcon path={selected} className="amsync-file-icon" />
                <span className="amsync-editor-path">{selected}</span>
              </span>
              <span className="amsync-editor-live">live</span>
            </div>
            <Editor />
          </div>
        ) : (
          <div className="amsync-placeholder">
            Select a file from the sidebar to edit.
          </div>
        )}
      </main>
    </div>
  );
}
