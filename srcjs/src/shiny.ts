// Typed facade over the global `window.shinyreact` runtime. shinyreact's bundle
// (loaded by `page_react()` before this one) owns the single React 19 instance and
// the Shiny <-> React hooks; we read everything from it rather than importing the
// `react` package at runtime (which is externalized to `window.shinyreact.React`
// by vite — see vite.config.ts). Capturing at module load is safe because both
// dependency scripts use `defer` and shinyreact is injected first.

type SetInputPriority = "deferred" | "immediate" | "event";
interface SetInputOptions {
  debounceMs?: number;
  priority?: SetInputPriority;
  type?: string;
}

type OutputStatus = "pending" | "ready" | "recalculating" | "error";

interface ShinyReactGlobal {
  React: typeof import("react");
  ReactDOM: typeof import("react-dom/client");
  useShinyInput: <T>(
    id: string,
    defaultValue: T,
    opts?: SetInputOptions,
  ) => [T, (value: T) => void];
  useShinyInputValue: <T>(id: string) => T | undefined;
  useSetShinyInput: <T>(
    id: string,
    defaultValue: T,
    opts?: SetInputOptions,
  ) => (value: T) => void;
  useShinyOutputValue: <T>(id: string, defaultValue?: T) => T | undefined;
  useShinyOutputStatus: (id: string) => OutputStatus;
  useShinyMessageHandler: <T = unknown>(
    type: string,
    handler: (data: T) => void,
  ) => void;
  useShinyInitialized: () => boolean;
  useShinyBusy: () => boolean;
}

declare global {
  interface Window {
    shinyreact: ShinyReactGlobal;
    // Shiny's client global; used for imperative input sends where a hook's
    // mount-time default broadcast would be harmful (see Editor.tsx).
    Shiny?: {
      setInputValue?: (
        id: string,
        value: unknown,
        opts?: { priority?: SetInputPriority },
      ) => void;
    };
  }
}

const sr = window.shinyreact;

export const React = sr.React;
export const ReactDOM = sr.ReactDOM;
export const useShinyInput = sr.useShinyInput;
export const useShinyInputValue = sr.useShinyInputValue;
export const useSetShinyInput = sr.useSetShinyInput;
export const useShinyOutputValue = sr.useShinyOutputValue;
export const useShinyOutputStatus = sr.useShinyOutputStatus;
export const useShinyMessageHandler = sr.useShinyMessageHandler;
export const useShinyInitialized = sr.useShinyInitialized;

/**
 * Imperatively fire a Shiny "event" input (for action buttons / row clicks).
 *
 * Deliberately NOT via `useShinyInput`/`useSetShinyInput`: those register the
 * input and re-broadcast its retained registry value to Shiny on every mount.
 * With "event" priority that re-fires the matching `observeEvent()` whenever the
 * component re-mounts — e.g. returning to the connect screen after Disconnect
 * would auto-trigger the last Authenticate/Connect click. Sending directly means
 * the input only ever changes on a real click, so nothing fires on mount.
 */
export function fireShinyEvent(id: string, value: unknown = Date.now()): void {
  window.Shiny?.setInputValue?.(id, value, { priority: "event" });
}

/** Stable click handler that fires `input$id` as an event (see fireShinyEvent). */
export function useShinyEvent(id: string): () => void {
  return React.useCallback(() => fireShinyEvent(id), [id]);
}
