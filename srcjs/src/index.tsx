// Entry point: mount the React app into the #root div provided by
// shinyreact::page_react(). React/ReactDOM come from the shared window.shinyreact
// instance (see shiny.ts), not a bundled copy.

import "./styles.css";
import { ReactDOM } from "./shiny";
import { App } from "./App";

const root = document.getElementById("root");
if (root) {
  ReactDOM.createRoot(root).render(<App />);
}
