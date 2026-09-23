# Launch the autosync browser app

`sync_app()` runs one Shiny app for the whole workflow. It has two
screens:

## Usage

``` r
sync_app(
  server = "",
  proj_id = "",
  token = NULL,
  tls = NULL,
  timeout = 5000L,
  files_key = "files",
  debounce = 300L
)
```

## Arguments

- server:

  Sync-server URL to prefill in the connect form. Default `""`.

- proj_id:

  Project document ID to prefill. Default `""`.

- token:

  (optional) A JWT from an earlier
  [`sync_token()`](https://posit-dev.github.io/autosync/reference/sync_token.md)
  call. When supplied, the app starts signed in. Default `NULL`.

- tls:

  (optional) for secure wss:// connections to servers with self-signed
  or custom CA certificates, a TLS configuration object created by
  [`nanonext::tls_config()`](https://nanonext.r-lib.org/reference/tls_config.html).

- timeout:

  Timeout in milliseconds for each receive operation. Default 5000.

- files_key:

  Key of the files map within the project document. Default `"files"`.

- debounce:

  Milliseconds to debounce outgoing editor changes, passed through to
  the live editor. Default 300.

## Value

Invisibly `NULL`, when the app window is closed.

## Details

- **Connect** – enter a sync-server URL and a project document ID, then
  click **Connect**. If an OIDC client ID is available, the app signs in
  with the same browser flow as
  [`sync_token()`](https://posit-dev.github.io/autosync/reference/sync_token.md)
  first. Blank sign-in fields under **Advanced** use the
  `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, and `OIDC_ISSUER` environment
  variables. The form shows when the first two are set, but not their
  values. To skip sign-in, pass a `token` from an earlier
  [`sync_token()`](https://posit-dev.github.io/autosync/reference/sync_token.md)
  call. For open servers, leave the sign-in blank to connect without a
  token.

- **Browse & edit** – the file tree of the project appears in a sidebar.
  Select a file to open its document in a live CodeMirror editor. The
  editor syncs with the server in both directions, like the `$edit()`
  method of a document handle. **Disconnect** returns to the connect
  screen. Close the window to end the session.

The app builds one
[`sync_project()`](https://posit-dev.github.io/autosync/reference/sync_project.md)
connection and reuses it for every file opened during the session.

The interface is a React frontend rendered with the shinyreact package.
The file tree uses the @pierre/trees component, and the editor uses
CodeMirror 6. R owns the live Automerge documents and all syncing.
Requires the shiny and shinyreact packages and an interactive session.

## Examples

``` r
if (FALSE) { # interactive()
# Start with empty fields and fill them in the form:
sync_app()

# Or prefill the server and project:
sync_app("wss://quarto-hub.com/ws", proj_id = "4F63WJPDzbHkkfKa66h1Qrr1sC5U")

# Reuse a token obtained earlier, so the app starts signed in:
token <- sync_token()
sync_app("wss://quarto-hub.com/ws", proj_id = "4F63WJPD...", token = token)
}
```
