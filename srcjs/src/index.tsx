// Entry point: mount the React app. shinyreact::page_react() serves a bare page
// with no mount container, so the app appends its own #root div (styles.css
// targets it). React/ReactDOM come from the shared window.shinyreact instance
// (see shiny.ts), not a bundled copy.

import "./styles.css";
import { ReactDOM } from "./shiny";
import { App } from "./App";

const root = document.body.appendChild(document.createElement("div"));
root.id = "root";
ReactDOM.createRoot(root).render(<App />);
