# AGENTS.md

Guidance for AI coding agents working **on** the autosync package. autosync is a WebSocket sync server for Automerge CRDT documents, implementing the `automerge-repo` protocol — R serves as a synchronization hub for Automerge clients in R, JavaScript, Rust, and other languages.

Claude Code users: add `.claude/CLAUDE.md` containing `@../AGENTS.md` to import this file (`.claude/` is gitignored).

## Commands

```r
devtools::test()          # run the full testthat suite
devtools::document()      # roxygen2 -> man/, NAMESPACE
devtools::check()         # R CMD check
devtools::install()       # install locally
```

Single test file: `testthat::test_file("tests/testthat/test-server.R")`.

```bash
# Rebuild the React frontend bundle (after editing anything under srcjs/)
npm --prefix srcjs ci      # first time / lockfile changes
npm --prefix srcjs run build   # -> inst/www/amsync.{js,css}
```

`shinyreact` (Suggests; only for the interactive `amsync_app()` / `$edit()` UI)
is installed from posit-dev/shinyreact (see `Remotes` in DESCRIPTION).

## Related packages

Interactive project browsing and live editing (`project_open()`, `project_app()`, `project_edit()`) live in the sibling `shinysync` package (`../shinysync`), which depends on autosync; autosync itself has no `shiny`/`bslib` dependency.

## Architecture

### Core Components

**Server (R/server.R)**: `sync_server()` creates a WebSocket server using nanonext's `http_server()`. The server maintains state in environments for:
- `documents` - Loaded Automerge documents keyed by document ID
- `sync_states` - Per-client, per-document sync states (nested: `sync_states[[client_id]][[doc_id]]`)
- `connections` - WebSocket connection objects keyed by both temp ID and client ID
- `doc_peers` - Document-to-peer mapping for broadcasting

**Handlers (R/handlers.R)**: Message routing via `handle_message()` which dispatches to type-specific handlers:
- `handle_join` - Protocol handshake, validates version "1", authentication
- `handle_sync` - Document synchronization using Automerge sync protocol
- `handle_ephemeral` - Transient message forwarding (point-to-point or broadcast)
- `broadcast_sync` - Propagates changes to all peers subscribed to a document

**Auth (R/auth.R)**: Optional OAuth2 authentication via `auth_config()`. Validates Google OAuth2 tokens, supports email/domain allowlists and custom validators. TLS is mandatory when auth is enabled. Uses `later::later()` for auth timeout enforcement. `sync_token()` obtains an ID token interactively by delegating the Authorization Code + PKCE flow to httr2 (`oauth_server_metadata()` for discovery, `oauth_flow_auth_code()` for the browser handshake and token exchange).

**Client (R/client.R)**: `sync_fetch()` implements the client-side protocol for fetching documents from any automerge-repo server. `sync_client()` opens a persistent connection whose `$open_doc()` returns `autosync_doc` handles sharing one socket; a handle's `$edit()` opens a live editor.

**Project (R/project.R)**: `amsync_project()` browses a project document's `files` map (path -> file doc ID) over a single connection, opening files on demand.

**Interactive UI (R/app.R, R/edit.R)**: `amsync_app()` is a single-window gadget (connect / browse / edit) and `$edit()` is the standalone live editor. Both render a **React frontend via shinyreact** (not bslib) and keep R as the sole owner of the Automerge documents — the browser is pure UI. `install_editor_sync()` (edit.R) wires the bidirectional editor<->document sync: an outgoing observer reads `input$content` and writes the minimal diff into the live doc; an incoming poll reflects remote changes back via a pluggable `set_editor()` callback (which bumps the `editor_doc` reactive_output revision the React CodeMirror editor watches).

**Storage (R/storage.R)**: Persistence layer using `.automerge` files in a configurable data directory.

### Key Patterns

**Dual connection indexing**: Pre-handshake connections are keyed by temp WebSocket ID (`ws$id` as character); post-handshake, the same connection object is also indexed by the client's `senderId` from the join message. Both must be cleaned up on disconnect.

**Storage ID semantics**: `NULL` = auto-generate persistent ID, `NA` = ephemeral server (no storage ID in peer response), string = explicit storage ID.

**Environment-based state**: All server state uses environments (pass-by-reference), not lists. This is intentional for mutability.

### Protocol Details

The full protocol specification is at `dev/RFC-automerge-repo-sync-protocol.md` — consult it before changing message handling.

Messages are CBOR-encoded binary frames. Key message types:
- `join`/`peer` - Connection handshake with peer IDs and metadata
- `request`/`sync` - Document sync with Automerge sync state data
- `ephemeral` - Non-persisted messages for real-time features
- `error`/`doc-unavailable` - Error handling

Document IDs are Base58Check-encoded 16-byte random values. Peer IDs are Base64-encoded.

### Key Imports

- `automerge` - CRDT operations (am_create, am_sync_encode/decode, am_save/load)
- `nanonext` - WebSocket server and async I/O
- `secretbase` - CBOR encoding (cborenc/cbordec) and Base58/Base64
- `later` - Event loop integration (run_now for async recv)

### JS frontend (`srcjs/` -> `inst/www/`)

The `amsync_app()` / `$edit()` UI is a React app built with Vite.

- **Source**: `srcjs/src/` (TypeScript/TSX). `index.tsx` mounts `<App/>` into the
  `#root` div that `shinyreact::page_react()` provides. `App.tsx` routes on
  `output$view`. Components: `ConnectScreen`, `BrowseScreen`, `FileTree` (the
  `@pierre/trees` / trees.software file tree), `Editor` (CodeMirror 6), `Toast`
  (notifications via `send_message`). `shiny.ts` is a typed facade over the
  global `window.shinyreact` hooks; `languages.ts` maps file extensions to
  CodeMirror language modes.
- **Build**: `npm --prefix srcjs run build` emits a self-contained IIFE to
  `inst/www/amsync.js` + `amsync.css`. React/ReactDOM are **externalized** to
  `window.shinyreact.{React,ReactDOM}` (vite.config.ts) so the bundle shares
  shinyreact's single React 19 instance — never bundle a second React (it breaks
  hooks). `@pierre/trees` and CodeMirror are bundled in.
- **Shipping**: the built `inst/www/*` is committed so the installed package
  needs no Node; `srcjs/` is `.Rbuildignore`d. Rebuild and commit after editing
  any `srcjs/` source.
- **R<->JS contract**: R reads `input$*` (url, proj_id, client_id/secret/issuer,
  authenticate, connect, file, content, refresh, disconnect, exit, close) and
  publishes `reactive_output`s (`view`, `init`, `authed`, `paths`, `selected`,
  `editor_doc`). `paths` is emitted via `as.list()` so a length-1 vector still
  serialises as a JSON array.

## Testing

Tests use port 0 (OS-assigned) by default, retrieving the actual URL via `server$url`. Test files cover server, client, handlers, storage, and integration scenarios.

- **Handler tests** use mock WebSocket objects (`create_mock_ws()` and `create_test_state()` in test-handlers.R) to test message handling without network I/O
- **Auth tests** use `local_mocked_bindings()` to mock Google token validation and snapshot tests for error messages
- **Integration tests** use `skip_on_cran()` for network-dependent scenarios
- **Cleanup**: Tests use `on.exit()` consistently and `tempfile()` for isolated storage directories

## Packaging notes

- roxygen2 with markdown; `NAMESPACE` is generated — never hand-edit.
- `AGENTS.md`, `.claude/`, and `.posit/` are in `.Rbuildignore` and don't ship to CRAN.
