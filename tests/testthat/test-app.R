test_that("amsync_app errors in a non-interactive session", {
  local_mocked_bindings(is_interactive = function() FALSE)
  expect_error(amsync_app(), "requires an interactive session")
})

test_that("amsync_app errors when shiny or shinyreact is missing", {
  local_mocked_bindings(is_interactive = function() TRUE)
  local_mocked_bindings(requireNamespace = function(...) FALSE, .package = "base")
  expect_error(amsync_app(), "requires the 'shiny' and 'shinyreact' packages")
})

test_that("amsync_app builds the app and launches it as a gadget", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  # Mock the interactive check and the gadget launcher so the happy path runs
  # without opening a window; capture the built app instead.
  launched <- NULL
  local_mocked_bindings(is_interactive = function() TRUE)
  local_mocked_bindings(
    runGadget = function(app, ...) {
      launched <<- app
      NULL
    },
    .package = "shiny"
  )

  expect_null(amsync_app("wss://x/ws", proj_id = "DOC123"))
  expect_s3_class(launched, "shiny.appobj")
})

test_that("Exit switches to the closed screen and schedules the app to stop", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  # Stub the delayed stop so the scheduled stopApp() doesn't leak into the
  # shared event loop and disturb other tests; just record that it was queued.
  scheduled <- FALSE
  local_mocked_bindings(
    later = function(func, delay = 0, ...) {
      scheduled <<- TRUE
      invisible()
    }
  )

  app <- build_amsync_app("", "", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    expect_equal(rv$view, "connect")
    session$setInputs(exit = 1)
    expect_equal(rv$view, "closed")
    expect_true(scheduled)
  })
})

test_that("a token passed to the app starts it signed in", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  app <- build_amsync_app("", "", "jwt.tok.en", NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    expect_true(rv$authed)
    expect_equal(st$token, "jwt.tok.en")
  })
})

test_that("the app exposes the prefilled server URL and project to the client", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  # Regression: the `server` argument must not be shadowed by the app's server
  # function. output$init reads `server`/`proj_id` and would error ("cannot
  # coerce type 'closure'") if `server` resolved to the server function.
  app <- build_amsync_app("wss://x/ws", "DOC123", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    init <- output$init
    expect_equal(init$server, "wss://x/ws")
    expect_equal(init$proj_id, "DOC123")
  })
})

test_that("amsync_app rejects a malformed token", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")
  # Token validation runs after the interactive + package checks, so mock the
  # session as interactive to reach it.
  local_mocked_bindings(is_interactive = function() TRUE)
  expect_error(amsync_app(token = 123), "single non-empty string")
  expect_error(amsync_app(token = c("a", "b")), "single non-empty string")
  expect_error(amsync_app(token = ""), "single non-empty string")
})

test_that("the app connects, browses, and edits over a live server", {
  skip_on_cran()
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")
  drain_later()

  data_dir <- tempfile()
  dir.create(data_dir)
  on.exit(unlink(data_dir, recursive = TRUE))

  server <- amsync_server(data_dir = data_dir)
  server$start()
  on.exit(server$close(), add = TRUE)

  # Seed a project document whose `files` map holds one text file.
  fid <- create_document(server)
  fdoc <- get_document(server, fid)
  fdoc[["text"]] <- automerge::am_text("hello world")
  pid <- create_document(server)
  pdoc <- get_document(server, pid)
  pdoc[["files"]] <- automerge::am_map()
  files <- pdoc[["files"]]
  files[["/notes.md"]] <- automerge::am_text(fid)

  app <- build_amsync_app(
    server = server$url,
    proj_id = pid,
    token = NULL,
    tls = NULL,
    timeout = 5000L,
    files_key = "files",
    debounce = 300L
  )

  # testServer evaluates the expr with the mock session's reactives (input,
  # output, session, and the server function's locals st/rv) layered over this
  # test's environment, so the `server`/`pid` test locals are reachable here.
  shiny::testServer(app, {
    expect_equal(rv$view, "connect")
    expect_false(rv$authed)

    # Connecting builds the project (its run_now() handshake runs inside the
    # observer) and switches to the browse screen with the file tree loaded.
    session$setInputs(url = server$url, proj_id = pid)
    session$setInputs(connect = 1)
    expect_equal(rv$view, "browse")
    expect_equal(rv$paths, "/notes.md")
    expect_s3_class(st$proj, "amsync_project")

    # Opening the file loads its document and pushes its content to the editor.
    session$setInputs(file = "/notes.md")
    expect_equal(rv$selected, "/notes.md")
    expect_equal(st$base, "hello world")
    expect_s3_class(st$doc, "amsync_doc")
    expect_equal(rv$editor$value, "hello world")
    expect_equal(rv$editor$ext, ".md")
    expect_gt(rv$editor$rev, 0L)

    # Typing in the editor writes the minimal diff into the live document.
    session$setInputs(content = "hello brave world")
    expect_equal(
      automerge::am_text_content(st$doc$doc[["text"]]),
      "hello brave world"
    )

    # Disconnecting tears down the connection and returns to the connect form.
    session$setInputs(disconnect = 1)
    expect_equal(rv$view, "connect")
    expect_null(st$proj)
  })
})

test_that("Connect auto-authenticates when an OIDC client ID is provided", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  used_token <- NULL
  local_mocked_bindings(amsync_token = function(...) "fresh.jwt")
  local_mocked_bindings(
    amsync_project = function(url, proj_id, token = NULL, ...) {
      used_token <<- token
      list(paths = function() character(0))
    }
  )
  app <- build_amsync_app("", "", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    expect_false(rv$authed)
    # A non-empty issuer is used as-is (exercises the issuer branch).
    session$setInputs(
      url = "wss://x/ws",
      proj_id = "DOC123",
      client_id = "cid",
      client_secret = "sec",
      issuer = "https://issuer"
    )
    session$setInputs(connect = 1)
    expect_equal(st$token, "fresh.jwt")
    expect_true(rv$authed)
    expect_equal(used_token, "fresh.jwt") # token forwarded to amsync_project()
    expect_equal(rv$view, "browse")
  })
})

test_that("Connect connects tokenless when no OIDC client ID is given", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  token_called <- FALSE
  used_token <- "unset"
  local_mocked_bindings(amsync_token = function(...) {
    token_called <<- TRUE
    "x"
  })
  local_mocked_bindings(
    amsync_project = function(url, proj_id, token = NULL, ...) {
      used_token <<- token
      list(paths = function() character(0))
    }
  )
  app <- build_amsync_app("", "", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    session$setInputs(url = "wss://x/ws", proj_id = "DOC123") # no client_id
    session$setInputs(connect = 1)
    expect_false(token_called) # no authentication attempted
    expect_false(rv$authed)
    expect_null(used_token) # connected without a token
    expect_equal(rv$view, "browse")
  })
})

test_that("a failed auto-authentication stays on the connect screen", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  local_mocked_bindings(amsync_token = function(...) stop("denied"))
  app <- build_amsync_app("", "", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    # Blank issuer falls back to oidc_issuer() (the other branch).
    session$setInputs(url = "wss://x/ws", proj_id = "DOC123", client_id = "cid", issuer = "")
    session$setInputs(connect = 1)
    expect_false(rv$authed)
    expect_null(st$proj)
    expect_equal(rv$view, "connect")
  })
})

test_that("Connect warns and stays put when the URL or project ID is blank", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  app <- build_amsync_app("", "", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    session$setInputs(url = "", proj_id = "")
    session$setInputs(connect = 1)
    expect_equal(rv$view, "connect")
    expect_null(st$proj)
  })
})

test_that("a persistently failing Connect stays on the connect screen", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  # Stub the inter-retry pause so the retries don't sleep through the test.
  tries <- 0L
  local_mocked_bindings(retry_pause = function() invisible())
  local_mocked_bindings(amsync_project = function(...) {
    tries <<- tries + 1L
    stop("cannot connect")
  })
  app <- build_amsync_app("", "", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    session$setInputs(url = "wss://x/ws", proj_id = "DOC123")
    session$setInputs(connect = 1)
    expect_equal(tries, 6L) # initial attempt + 5 retries
    expect_equal(rv$view, "connect")
    expect_null(st$proj)
  })
})

test_that("Connect retries a transient connection failure then succeeds", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  local_mocked_bindings(retry_pause = function() invisible())
  attempt <- 0L
  local_mocked_bindings(
    amsync_project = function(url, proj_id, token = NULL, ...) {
      attempt <<- attempt + 1L
      if (attempt < 3L) stop("transient")
      list(paths = function() character(0))
    }
  )
  app <- build_amsync_app("", "", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    session$setInputs(url = "wss://x/ws", proj_id = "DOC123")
    session$setInputs(connect = 1)
    expect_equal(attempt, 3L) # failed twice, connected on the third try
    expect_equal(rv$view, "browse")
  })
})

test_that("opening a file ignores a blank path and reports open errors", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  app <- build_amsync_app("", "", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    # The observer is ignoreInit, so the first input change is swallowed; prime
    # it before the cases we want to observe.
    session$setInputs(file = "/prime.md")

    # A blank path is ignored.
    session$setInputs(file = "")
    expect_null(rv$selected)

    # A project whose open() fails: the error is caught and no file opens.
    st$proj <- list(open = function(path) stop("boom"))
    session$setInputs(file = "/notes.md")
    expect_null(rv$selected)
    expect_null(st$doc)
  })
})

test_that("Refresh re-resolves the tree and drops a vanished selection", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("shinyreact")

  app <- build_amsync_app("", "", NULL, NULL, 5000L, "files", 300L)
  shiny::testServer(app, {
    # No project held: refresh is a quiet no-op.
    session$setInputs(refresh = 1)
    expect_equal(rv$paths, character(0))

    # With a project, the tree re-resolves and a now-missing selection clears.
    refreshed <- FALSE
    st$proj <- list(
      refresh = function() refreshed <<- TRUE,
      paths = function() c("/a.md", "/b.md")
    )
    rv$selected <- "/gone.md"
    session$setInputs(refresh = 2)
    expect_true(refreshed)
    expect_equal(rv$paths, c("/a.md", "/b.md"))
    expect_null(rv$selected)
  })
})

test_that("cleanup_project closes the connection and clears state", {
  closed <- FALSE
  st <- new.env(parent = emptyenv())
  st$proj <- list(close = function() closed <<- TRUE)
  st$doc <- "handle"

  cleanup_project(st)

  expect_true(closed)
  expect_null(st$proj)
  expect_null(st$doc)

  # Idempotent: a second call (no project held) is a quiet no-op.
  expect_no_error(cleanup_project(st))
})
