# Browse and edit files in a project document

Given a sync server URL and a project document ID, opens a persistent
connection to the server, syncs the project document over it, and
exposes its file tree for browsing and editing. A project is an
Automerge document with a `files` map whose keys are file paths and
whose values are text objects holding each file's own document ID.

## Usage

``` r
amsync_project(
  url,
  proj_id,
  token = NULL,
  tls = NULL,
  timeout = 5000L,
  files_key = "files"
)
```

## Arguments

- url:

  WebSocket URL of the sync server (e.g., "ws://localhost:3030/" or
  "wss://sync.automerge.org/"). Note: trailing slash may be required.

- proj_id:

  Document ID of the project.

- token:

  (optional) JWT (ID token) for authenticated servers. Sent as a Bearer
  token in the Authorization header of the WebSocket upgrade request.

- tls:

  (optional) for secure wss:// connections to servers with self-signed
  or custom CA certificates, a TLS configuration object created by
  [`nanonext::tls_config()`](https://nanonext.r-lib.org/reference/tls_config.html).

- timeout:

  Timeout in milliseconds for each receive operation. Default 5000.

- files_key:

  Key of the files map within the project document. Default `"files"`.

## Value

An environment of class `"amsync_project"` (reference semantics) with
the following fields and methods:

- `doc`:

  The live project document, kept in sync with the server.

- `conn`:

  The underlying
  [`amsync_client()`](http://shikokuchuo.net/autosync/reference/amsync_client.md)
  connection.

- `paths()`:

  Current sorted file paths.

- `doc_id(path)`:

  Resolve a path to its document ID.

- `open(path)`:

  Open the file's document over the project connection and return its
  `amsync_doc` handle. Reuses the connection and any already-open
  document.

- `edit(path = NULL)`:

  Open the file's document and run
  [`amsync_edit()`](http://shikokuchuo.net/autosync/reference/amsync_edit.md)
  with the extension inferred from the path. If `path` is `NULL` and
  interactive, shows a Shiny file picker first.

- `browse()`:

  Interactive loop: pick a file from a Shiny file picker, edit it, then
  return to the picker; repeat until **Done**.

- `refresh()`:

  Re-resolve the file tree to pick up added or removed files (the
  project document syncs live, so this just settles pending updates).

- [`close()`](https://rdrr.io/r/base/connections.html):

  Disconnect the project connection.

## Details

Opening or editing a file syncs that file's document over the **same**
connection rather than dialing the server again, so a browse session
reuses a single WebSocket throughout. Call `$close()` when finished to
disconnect.

## Examples

``` r
if (FALSE) { # interactive()
proj <- amsync_project("wss://quarto-hub.com/ws", proj_id, token = amsync_token())
proj                                   # prints the file tree
proj$browse()                          # pick a file, edit it, repeat
proj$edit("/charlie/index.qmd")        # edit a known path directly
proj$close()                           # disconnect when finished
}
```
