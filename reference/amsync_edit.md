# Edit a synced text object in a live Shiny editor

Opens a synced Automerge text object in a Shiny app featuring a
[`bslib::input_code_editor()`](https://rstudio.github.io/bslib/reference/input_code_editor.html)
component that stays in sync with the collaborative document in both
directions:

## Usage

``` r
amsync_edit(doc, at = "text", ext = NULL, debounce = 300L)
```

## Arguments

- doc:

  An `amsync_doc` handle (open one with `amsync_client()$open_doc()`)
  backed by an active connection.

- at:

  Character path to the text object within the document. A single string
  (e.g. `"text"`) addresses a top-level key; a character vector (e.g.
  `c("files", "x")`) navigates nested objects with `[[`. Default
  `"text"`.

- ext:

  File extension (e.g. `".md"`, with or without the leading dot) used to
  pick the editor's syntax-highlighting language. `NULL` (default) uses
  plain text.

- debounce:

  Milliseconds to wait after the last keystroke before pushing the
  editor's contents to the document. Default 300. Lower values feel more
  immediate but push more often; `0` pushes on every change.

## Value

Invisibly returns `doc`.

## Details

- **Outgoing** – as you type, the editor's contents are written back
  into the live document and pushed to the server, debounced so that a
  burst of keystrokes coalesces into one update.

- **Incoming** – when the document's text changes remotely (another peer
  edits it), the editor updates automatically to show the merged result.

There is no **Save** button: every edit is applied live. Closing the app
(the **Close** button or closing the window) simply stops syncing
through the editor; the document and its connection are otherwise
untouched.

Requires the shiny and bslib packages.

Edits are applied directly to the live document rather than to a fork.
[`automerge::am_text_update()`](https://posit-dev.github.io/automerge-r/reference/am_text_update.html)
writes only the minimal diff between the editor's contents and the
document, so local and remote edits in disjoint regions are preserved.
While the app runs the connection keeps syncing, so remote changes land
on the live document and the poll loop reflects them back into the
editor shortly after they arrive.

The editor syncs whole-text snapshots, not granular operations, so it is
not a conflict-free collaborative editor: a remote edit that arrives in
the brief window between a keystroke and its debounced push can be
overwritten by the next push. A small `debounce` narrows this window.

The original's trailing-newline state is preserved: if the text did not
end in a newline, any trailing newline(s) the editor appends are
stripped before the diff is computed.

## Examples

``` r
if (FALSE) { # interactive()
server <- amsync_server()
server$start()
doc_id <- create_document(server)
sdoc <- get_document(server, doc_id)
sdoc$text <- automerge::am_text("edit me")

conn <- amsync_client(server$url)
doc <- conn$open_doc(doc_id)
amsync_edit(doc, at = "text", ext = ".md")

conn$close()
server$close()
}
```
