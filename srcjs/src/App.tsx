// Top-level router. The R server drives the active screen through `output$view`
// ("connect" | "browse" | "edit" | "closed"); "edit" is the standalone live
// editor launched by the amsync_doc `$edit()` method.

import type { ReactNode } from "react";
import { useShinyEvent, useShinyInitialized, useShinyOutputValue } from "./shiny";
import { ConnectScreen } from "./ConnectScreen";
import { BrowseScreen } from "./BrowseScreen";
import { Editor } from "./Editor";
import { Toast } from "./Toast";

function EditScreen() {
  const close = useShinyEvent("close");
  return (
    <div className="amsync-editor-card amsync-edit-only">
      <div className="amsync-editor-header">
        <span className="amsync-editor-path">Edit synced text (live)</span>
        <button
          type="button"
          className="amsync-btn amsync-btn-sm amsync-btn-outline"
          onClick={close}
        >
          Close
        </button>
      </div>
      <Editor />
    </div>
  );
}

function ClosedScreen() {
  return (
    <div className="amsync-closed">
      <h5>Session ended</h5>
      <p>You can close this window.</p>
    </div>
  );
}

export function App() {
  const initialized = useShinyInitialized();
  const view = useShinyOutputValue<string>("view", "connect") ?? "connect";

  let screen: ReactNode;
  if (!initialized) {
    screen = <div className="amsync-loading">Connecting…</div>;
  } else if (view === "closed") {
    screen = <ClosedScreen />;
  } else if (view === "browse") {
    screen = <BrowseScreen />;
  } else if (view === "edit") {
    screen = <EditScreen />;
  } else {
    screen = <ConnectScreen />;
  }

  return (
    <>
      <Toast />
      {screen}
    </>
  );
}
