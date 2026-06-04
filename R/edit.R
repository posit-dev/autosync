# Edit a synced Automerge text object in a live Shiny code editor

#' Run the live editor for an open document handle
#'
#' Implements the `$edit()` method on the `amsync_doc` handle returned by
#' [amsync_client()]'s `$open_doc()`: opens the document's text object at `at`
#' in a live React CodeMirror editor (rendered with \pkg{shinyreact}) that stays
#' in sync with the live document in both directions, blocks until the editor
#' closes, then prints a one-line summary. The user-facing description and
#' caveats live on [amsync_client()].
#'
#' @param doc An `amsync_doc` handle backed by an active connection.
#' @param at Character path to the text object within the document. A single
#'   string addresses a top-level key; a character vector navigates nested
#'   objects with `[[`. Default `"text"`.
#' @param ext File extension used to pick the editor's syntax-highlighting
#'   language, or `NULL` for plain text.
#' @param debounce Milliseconds to wait after the last keystroke before pushing.
#'
#' @return Invisibly returns `doc`.
#'
#' @importFrom automerge am_text_content am_text_update
#' @noRd
edit_doc <- function(doc, at = "text", ext = NULL, debounce = 300L) {
  if (!isTRUE(doc$active)) {
    stop("`doc` is not active; reopen it with `$open_doc()`")
  }
  if (!is.character(at) || !length(at) || anyNA(at) || any(!nzchar(at))) {
    stop("`at` must be a non-empty character path")
  }
  if (
    !is.numeric(debounce) || length(debounce) != 1L || is.na(debounce) ||
      debounce < 0
  ) {
    stop("`debounce` must be a single non-negative number of milliseconds")
  }

  # Validate the target is a text object before launching the editor.
  navigate_to_text(doc$doc, at)

  final <- edit_in_shiny(doc, at, ext = ext, debounce = debounce)

  message(sprintf(
    "Closed editor for %s (%d chars).",
    paste(at, collapse = "/"),
    nchar(final %||% "", type = "bytes")
  ))
  invisible(doc)
}

#' Navigate a document to a text object via a character path
#'
#' @param doc An Automerge document (or forked document).
#' @param at Character vector path navigated with `[[`.
#'
#' @return The `am_text` object at the path.
#'
#' @noRd
navigate_to_text <- function(doc, at) {
  node <- doc
  for (key in at) {
    node <- node[[key]]
    if (is.null(node)) {
      stop("No object found at path: ", paste(at, collapse = "/"))
    }
  }
  if (!inherits(node, "am_text")) {
    stop(
      "Path ", paste(at, collapse = "/"), " is not a text object (got ",
      paste(class(node), collapse = "/"), ")"
    )
  }
  node
}

#' Write an editor value into the live document
#'
#' Normalises `value`'s trailing-newline state to match `base`, then, if it
#' differs from the document's current content, applies the minimal diff and
#' pushes. Returns the content now agreed between editor and document, which the
#' caller tracks to distinguish its own writes from later remote changes.
#'
#' @param target The live `am_text` object.
#' @param value The editor's current contents.
#' @param base The text the editor opened with (for trailing-newline state).
#' @param push A zero-argument function that pushes local changes to the server.
#'
#' @return The (normalised) content now in the document.
#'
#' @noRd
sync_editor_to_doc <- function(target, value, base, push) {
  value <- match_trailing_newline(enc2utf8(value), base)
  if (!identical(value, am_text_content(target))) {
    am_text_update(target, value)
    push()
  }
  value
}

#' Detect a remote change to reflect into the editor
#'
#' @param target The live `am_text` object.
#' @param shown The content currently reflected in the editor.
#'
#' @return The document's current content if it differs from `shown` (the
#'   editor should be updated to it), otherwise `NULL`.
#'
#' @noRd
poll_doc_to_editor <- function(target, shown) {
  current <- am_text_content(target)
  if (identical(current, shown)) NULL else current
}

#' Wire the bidirectional editor <-> live-document sync onto a Shiny session
#'
#' Installs the two observers shared by [edit_in_shiny()] and [amsync_app()]'s
#' browse screen: an outgoing one that writes debounced editor changes into the
#' live document and pushes them, and an incoming one that polls the document
#' and reflects remote changes back into the editor. Both read the open
#' document and its tracking state from `st` -- a plain environment, not a
#' reactive one, so editing never re-fires the observers through a reactive
#' dependency on the document.
#'
#' `st$shown` is the content the editor and document last agreed on; it lets
#' each side ignore the echo of its own write: an outgoing edit sets it to what
#' we wrote, and the poll skips while the document still matches it.
#'
#' The editor is the React CodeMirror component, reached over Shiny: the
#' outgoing observer reads its value from `input$content`, and the incoming poll
#' hands new content to `set_editor()`, which pushes it to the client (bumping
#' the `editor_doc` revision the editor watches). Keeping the push pluggable
#' lets the same sync drive the browse screen and the standalone `$edit()` view.
#'
#' @param input The Shiny session's `input`.
#' @param st An environment exposing `$doc` (an `amsync_doc` handle or `NULL`
#'   when nothing is open), `$at` (the text object's path), `$base` (the open
#'   content, for trailing-newline state), and a mutable `$shown`.
#' @param set_editor A function of one argument (the new content) that pushes it
#'   into the client editor.
#' @param poll_ms How often (ms) to poll the live document for remote changes.
#'
#' @return Invisibly `NULL`.
#'
#' @importFrom automerge am_text_content am_text_update
#' @noRd
install_editor_sync <- function(input, st, set_editor, poll_ms = 250L) {
  # Outgoing: debounced editor changes -> minimal diff -> push.
  shiny::observeEvent(
    input$content,
    {
      if (is.null(st$doc) || !isTRUE(st$doc$active)) {
        return()
      }
      target <- navigate_to_text(st$doc$doc, st$at)
      st$shown <- sync_editor_to_doc(
        target,
        input$content %||% "",
        st$base,
        st$doc$push
      )
    },
    ignoreInit = TRUE
  )

  # Incoming: poll the live document; reflect remote changes into the editor.
  shiny::observe({
    shiny::invalidateLater(poll_ms)
    if (is.null(st$doc) || !isTRUE(st$doc$active)) {
      return()
    }
    target <- navigate_to_text(st$doc$doc, st$at)
    current <- poll_doc_to_editor(target, st$shown)
    if (!is.null(current)) {
      st$shown <- current
      set_editor(current)
    }
  })

  invisible()
}

#' Edit text live in a single-window React (CodeMirror) Shiny app
#'
#' Spins up a single-purpose [shinyreact::page_react()] gadget showing the React
#' CodeMirror editor (the app's `"edit"` view) populated with the text at `at`,
#' plus a **Close** button. While it runs, editor changes are streamed
#' (debounced) into the live document and pushed, and remote changes are polled
#' back into the editor. Blocks until the app exits, returning the document's
#' final content.
#'
#' @param doc An `amsync_doc` handle.
#' @param at Character path to the text object.
#' @param ext File extension used to choose the syntax-highlighting language.
#' @param debounce Milliseconds to debounce outgoing editor changes.
#'
#' @return The document's final text content (character scalar).
#'
#' @noRd
edit_in_shiny <- function(doc, at, ext = NULL, debounce = 300L) {
  if (
    !requireNamespace("shiny", quietly = TRUE) ||
      !requireNamespace("shinyreact", quietly = TRUE)
  ) {
    stop(
      "Editing a document requires the 'shiny' and 'shinyreact' packages.\n",
      'Install shiny with install.packages("shiny") and shinyreact with ',
      'pak::pak("posit-dev/shinyreact").'
    )
  }

  base <- am_text_content(navigate_to_text(doc$doc, at))

  ui <- shinyreact::page_react(amsync_react_dep(), title = "amsync")

  server <- function(input, output, session) {
    # Editor state lives in a plain environment read by the sync observers
    # without a reactive dependency on the document; install_editor_sync() wires
    # the bidirectional editor <-> document sync onto it (and explains `shown`).
    st <- new.env(parent = emptyenv())
    st$doc <- doc
    st$at <- at
    st$base <- base
    st$shown <- base
    st$editor_rev <- 0L

    rv <- shiny::reactiveValues(editor = NULL)

    # Push content to the React editor by bumping the revision it watches.
    set_editor <- function(value) {
      st$editor_rev <- st$editor_rev + 1L
      rv$editor <- list(
        path = paste(at, collapse = "/"),
        value = value,
        ext = if (is.null(ext)) "" else ext,
        rev = st$editor_rev,
        debounce = as.integer(debounce)
      )
    }

    # Drive the React app straight to the standalone editor view.
    output$view <- shinyreact::reactive_output("edit")
    output$editor_doc <- shinyreact::reactive_output(rv$editor)

    install_editor_sync(input, st, set_editor)
    set_editor(base) # load the initial content

    # Stop exactly once; the Close button or window-close ends the session.
    # Closing the editor returns to the file picker (in a browse loop), so it
    # is already obvious the editor has ended -- no closing message needed here.
    done <- FALSE
    finish <- function() {
      if (done) {
        return()
      }
      done <<- TRUE
      shiny::stopApp(am_text_content(navigate_to_text(doc$doc, at)))
    }
    shiny::observeEvent(input$close, finish())
    session$onSessionEnded(function() finish())
  }

  shiny::runGadget(shiny::shinyApp(ui, server), stopOnCancel = FALSE)
}

#' Preserve the base string's trailing-newline state
#'
#' If `base` did not end in a newline, strip any trailing newline(s) the
#' editor appended; otherwise leave `edited` unchanged.
#'
#' @noRd
match_trailing_newline <- function(edited, base) {
  base_has_nl <- grepl("\n$", base)
  if (!base_has_nl) {
    edited <- sub("\n+$", "", edited)
  }
  edited
}
