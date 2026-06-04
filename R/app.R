# Single-window Shiny entry point: connect, browse, and edit in one app

#' Launch the autosync browser app
#'
#' Opens a single Shiny app that carries the whole workflow from start to finish
#' without any other R commands. It has two screens served in one window:
#'
#' * **Connect** -- enter a sync-server URL and a project document ID, and
#'   optionally authenticate. The **Authenticate** button runs the same OIDC
#'   browser flow as [amsync_token()]; client ID, secret, and issuer can be set
#'   under **Advanced** (prefilled from the `OIDC_CLIENT_ID`,
#'   `OIDC_CLIENT_SECRET`, and `OIDC_ISSUER` environment variables). Passing a
#'   `token` obtained earlier from [amsync_token()] starts the app already
#'   signed in, skipping that step. Leaving the sign-in untouched connects
#'   without a token, for open servers.
#' * **Browse & edit** -- once connected, the project's file tree appears in a
#'   sidebar; selecting a file opens its document in a live CodeMirror editor
#'   that stays in sync with the server in both directions, just like a document
#'   handle's `$edit()` method. **Disconnect** returns to the connect screen;
#'   closing the window ends the session.
#'
#' This is a front door to [amsync_project()]: it builds the same connection and
#' reuses it for every file opened during the session.
#'
#' @inheritParams amsync_project
#' @param server Initial sync-server URL to prefill in the connect form.
#'   Default `""`.
#' @param proj_id Initial project document ID to prefill. Default `""`.
#' @param token (optional) A JWT obtained earlier from [amsync_token()]. When
#'   supplied, the app starts already signed in; you can still re-authenticate
#'   from the form. Default `NULL` (sign in from the form, or connect with no
#'   token).
#' @param debounce Milliseconds to debounce outgoing editor changes, passed
#'   through to the live editor. Default 300.
#'
#' @return Invisibly `NULL`, when the app window is closed.
#'
#' @details
#' The interface is a React frontend rendered with the \pkg{shinyreact} package:
#' the file tree uses the \pkg{@pierre/trees} component and the editor uses
#' CodeMirror 6, while R keeps owning the live Automerge documents and all
#' syncing. Requires the \pkg{shiny} and \pkg{shinyreact} packages and an
#' interactive session.
#'
#' @examplesIf interactive()
#' # Start with empty fields and fill them in the form:
#' amsync_app()
#'
#' # Or prefill the server and project so only sign-in/Connect remain:
#' amsync_app("wss://quarto-hub.com/ws", proj_id = "4F63WJPDzbHkkfKa66h1Qrr1sC5U")
#'
#' # Reuse a token obtained earlier, so the app starts signed in:
#' token <- amsync_token()
#' amsync_app("wss://quarto-hub.com/ws", proj_id = "4F63WJPD...", token = token)
#'
#' @importFrom automerge am_text_content
#' @export
amsync_app <- function(
  server = "",
  proj_id = "",
  token = NULL,
  tls = NULL,
  timeout = 5000L,
  files_key = "files",
  debounce = 300L
) {
  if (!is_interactive()) {
    stop("`amsync_app()` requires an interactive session")
  }
  if (
    !requireNamespace("shiny", quietly = TRUE) ||
      !requireNamespace("shinyreact", quietly = TRUE)
  ) {
    stop(
      "amsync_app() requires the 'shiny' and 'shinyreact' packages.\n",
      'Install shiny with install.packages("shiny") and shinyreact with ',
      'pak::pak("posit-dev/shinyreact").'
    )
  }
  if (
    !is.null(token) &&
      (!is.character(token) || length(token) != 1L || is.na(token) ||
        !nzchar(token))
  ) {
    stop("`token` must be a single non-empty string (from `amsync_token()`), or NULL")
  }

  app <- build_amsync_app(server, proj_id, token, tls, timeout, files_key, debounce)
  shiny::runGadget(app, stopOnCancel = FALSE)
  invisible(NULL)
}

#' Build the autosync browser Shiny app object
#'
#' Splits the app's UI and server out of [amsync_app()] so the same app can be
#' launched as a gadget there and driven by `shiny::testServer()` in tests. The
#' parameters mirror [amsync_app()].
#'
#' The UI is the React frontend (`inst/www/amsync.js`) mounted by
#' [shinyreact::page_react()]; the server publishes the screen state, file tree,
#' sign-in state, and open-file content as `reactive_output()`s the client
#' reads, and reacts to the client's `input$*` events. R owns the Automerge
#' documents throughout via [amsync_project()] and [install_editor_sync()].
#'
#' @return A [shiny::shinyApp()] object.
#'
#' @noRd
build_amsync_app <- function(
  server,
  proj_id,
  token,
  tls,
  timeout,
  files_key,
  debounce
) {
  ui <- shinyreact::page_react(amsync_react_dep(), title = "amsync")

  # Named `app_server` rather than `server` so it does not shadow the `server`
  # argument (the prefill URL), which the connect screen reads when rendering.
  app_server <- function(input, output, session) {
    # Connection and editor state lives in a plain environment, not a reactive
    # one, so the sync observers can read the live document without taking a
    # reactive dependency on it (which would re-fire them on every edit). Only
    # the screen, file tree, selection, and pushed editor content are reactive.
    # install_editor_sync() reads $doc/$at/$base/$shown from here, just as it
    # does in edit_in_shiny().
    st <- new.env(parent = emptyenv())
    st$proj <- NULL # the amsync_project connection, once connected
    st$token <- token # JWT, pre-supplied or from the Authenticate flow
    st$doc <- NULL # the currently-open amsync_doc handle
    st$at <- "text" # path to the text object within a file document
    st$base <- "" # the open file's content (for trailing-newline state)
    st$shown <- "" # content the editor and document last agreed on
    st$editor_path <- "" # the open file's path (header + editor payload)
    st$editor_ext <- "" # the open file's extension (syntax highlighting)
    st$editor_rev <- 0L # revision the React editor watches for server pushes

    rv <- shiny::reactiveValues(
      view = "connect", # "connect", "browse", or "closed"
      authed = !is.null(token), # whether a token has been obtained
      paths = character(0), # file paths shown in the tree
      selected = NULL, # the open file path, or NULL for none
      editor = NULL # the editor_doc payload pushed to the client
    )

    # Push content to the React CodeMirror editor by bumping the revision it
    # watches; carries the open path/extension and the debounce so the editor
    # can pick its language and outgoing debounce.
    set_editor <- function(value) {
      st$editor_rev <- st$editor_rev + 1L
      rv$editor <- list(
        path = st$editor_path,
        value = value,
        ext = st$editor_ext,
        rev = st$editor_rev,
        debounce = as.integer(debounce)
      )
    }

    # --- Outputs the React client reads ---

    output$view <- shinyreact::reactive_output(rv$view)
    output$authed <- shinyreact::reactive_output(isTRUE(rv$authed))
    # as.list() so a length-1 path set still serialises as a JSON array (Shiny's
    # auto_unbox would otherwise collapse it to a scalar the tree can't use).
    output$paths <- shinyreact::reactive_output(as.list(rv$paths))
    output$selected <- shinyreact::reactive_output(rv$selected)
    output$editor_doc <- shinyreact::reactive_output(rv$editor)
    output$init <- shinyreact::reactive_output(list(
      server = server,
      proj_id = proj_id,
      client_id = Sys.getenv("OIDC_CLIENT_ID"),
      client_secret = Sys.getenv("OIDC_CLIENT_SECRET"),
      issuer = oidc_issuer()
    ))

    # --- Connect screen: authenticate (if details given) and start browsing ---

    shiny::observeEvent(input$connect, {
      url_in <- trimws(input$url %||% "")
      proj_in <- trimws(input$proj_id %||% "")
      if (!nzchar(url_in) || !nzchar(proj_in)) {
        notify(session, "warning", "Enter both a server URL and a project ID.")
        return()
      }

      # Authenticate as part of connecting: when an OIDC client ID is provided
      # (and we don't already hold a token) run the sign-in flow first, otherwise
      # connect tokenless for open servers. amsync_token() drives the shared
      # event loop with run_now() (reentrant-safe) while it waits for the OAuth
      # callback; the browser opening is the user's feedback.
      if (is.null(st$token)) {
        client_id <- trimws(input$client_id %||% "")
        if (nzchar(client_id)) {
          issuer <- trimws(input$issuer %||% "")
          token <- tryCatch(
            amsync_token(
              client_id = client_id,
              client_secret = input$client_secret %||% "",
              issuer = if (nzchar(issuer)) issuer else oidc_issuer()
            ),
            error = function(e) {
              notify(session, "error", paste("Authentication failed:", conditionMessage(e)))
              NULL
            }
          )
          if (is.null(token)) {
            return() # auth failed; stay on the connect screen
          }
          st$token <- token
          rv$authed <- TRUE
        }
      }

      proj <- tryCatch(
        amsync_project(
          url_in,
          proj_in,
          token = st$token,
          tls = tls,
          timeout = timeout,
          files_key = files_key
        ),
        error = function(e) {
          notify(session, "error", paste("Connection failed:", conditionMessage(e)))
          NULL
        }
      )
      if (is.null(proj)) {
        return()
      }
      st$proj <- proj
      st$doc <- NULL
      rv$paths <- proj$paths()
      rv$selected <- NULL
      rv$view <- "browse"
    })

    # --- Browse screen: open the selected file in the editor ---

    shiny::observeEvent(
      input$file,
      {
        path <- input$file
        if (is.null(path) || !nzchar(path)) {
          return()
        }
        opened <- tryCatch(
          {
            doc <- st$proj$open(path)
            base <- am_text_content(navigate_to_text(doc$doc, st$at))
            list(doc = doc, base = base)
          },
          error = function(e) {
            notify(session, "error", paste("Could not open file:", conditionMessage(e)))
            NULL
          }
        )
        if (is.null(opened)) {
          return()
        }
        st$doc <- opened$doc
        st$base <- opened$base
        st$shown <- opened$base
        st$editor_path <- path
        st$editor_ext <- file_ext_dot(path)
        rv$selected <- path
        set_editor(opened$base)
      },
      ignoreInit = TRUE
    )

    # Bidirectional editor <-> document sync, shared with the $edit() gadget;
    # reads the open document and tracking state from `st`, and pushes remote
    # changes back to the client editor through set_editor().
    install_editor_sync(input, st, set_editor)

    # --- Browse screen: refresh the file tree (picks up added/removed files) ---

    shiny::observeEvent(input$refresh, {
      if (is.null(st$proj)) {
        return()
      }
      st$proj$refresh()
      # Re-resolve the tree; drop the selection if its file is gone.
      paths <- st$proj$paths()
      if (!is.null(rv$selected) && !(rv$selected %in% paths)) {
        rv$selected <- NULL
      }
      rv$paths <- paths
    })

    # --- Browse screen: disconnect and return to the connect form ---

    shiny::observeEvent(input$disconnect, {
      cleanup_project(st)
      rv$selected <- NULL
      rv$view <- "connect"
    })

    # --- Connect screen: exit and end the app ---

    # Show a brief closing message (the "Session ended" screen), then stop the
    # gadget. The short delay lets the message render and unblocks the calling
    # R session.
    shiny::observeEvent(input$exit, {
      cleanup_project(st)
      rv$view <- "closed"
      later(function() shiny::stopApp(), delay = 0.75)
    })

    # Closing the window ends the session; disconnect so we never leak a socket.
    session$onSessionEnded(function() cleanup_project(st))
  }

  shiny::shinyApp(ui, app_server)
}

#' HTML dependency for the autosync React frontend bundle
#'
#' Wraps [shinyreact::page_react_dep()] over the built `inst/www/amsync.{js,css}`
#' bundle so it loads (after the shinyreact page dependency) on any
#' [shinyreact::page_react()] page. Versioned by the JS file's mtime, so a
#' rebuild busts the browser cache.
#'
#' @return An [htmltools::htmlDependency].
#'
#' @noRd
amsync_react_dep <- function() {
  shinyreact::page_react_dep(
    src_dir = system.file("www", package = "autosync"),
    js_file = "amsync.js",
    css_file = "amsync.css",
    name = "autosync"
  )
}

#' Send a transient notification to the React client
#'
#' Replaces `shiny::showNotification()` (whose default UI is absent on a bare
#' `page_react()` page) with a `send_message()` the React `Toast` handles.
#'
#' @param session The Shiny session.
#' @param type One of "message", "warning", or "error".
#' @param text The message text.
#'
#' @return Invisibly `NULL`.
#'
#' @noRd
notify <- function(session, type, text) {
  shinyreact::send_message(session, "notify", list(type = type, text = text))
  invisible()
}

#' Close a project connection held in app state, if any
#'
#' @param st The app's state environment.
#'
#' @return Invisibly `NULL`.
#'
#' @noRd
cleanup_project <- function(st) {
  if (!is.null(st$proj)) {
    try(st$proj$close(), silent = TRUE)
    st$proj <- NULL
  }
  st$doc <- NULL
  invisible()
}
