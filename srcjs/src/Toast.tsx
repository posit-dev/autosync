// Transient notifications. Replaces shiny::showNotification(), whose default UI
// isn't present on a bare page_react() page. The R server pushes messages with
// send_message(session, "notify", list(type = ..., text = ...)).

import { React, useShinyMessageHandler } from "./shiny";

interface Notice {
  id: number;
  type: string;
  text: string;
}

const TIMEOUT_MS = 5000;

export function Toast() {
  const [notices, setNotices] = React.useState<Notice[]>([]);
  const counter = React.useRef(0);

  useShinyMessageHandler<{ type?: string; text?: string }>("notify", (data) => {
    const id = (counter.current += 1);
    const notice: Notice = {
      id,
      type: data.type ?? "message",
      text: data.text ?? "",
    };
    setNotices((current) => [...current, notice]);
    window.setTimeout(
      () => setNotices((current) => current.filter((n) => n.id !== id)),
      TIMEOUT_MS,
    );
  });

  if (notices.length === 0) return null;
  return (
    <div className="amsync-toasts">
      {notices.map((n) => (
        <div key={n.id} className={`amsync-toast amsync-toast-${n.type}`}>
          {n.text}
        </div>
      ))}
    </div>
  );
}
