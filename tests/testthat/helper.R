# Test helpers

# Set the OIDC_CLIENT_* env vars to known values for a test, restoring the
# previous values (or unsetting them) when the test ends. `NULL` unsets a
# variable: the app falls back to these env vars when a sign-in field is left
# blank, so tests that connect with blank fields must unset them to stay
# hermetic. Cleanup uses the vendored withr standalone `defer()`
# (R/import-standalone-defer.R).
local_oidc_env <- function(client_id = NULL, client_secret = NULL) {
  nms <- c("OIDC_CLIENT_ID", "OIDC_CLIENT_SECRET")
  old <- Sys.getenv(nms, unset = NA)
  defer(
    {
      for (nm in nms) {
        if (is.na(old[[nm]])) {
          Sys.unsetenv(nm)
        } else {
          do.call(Sys.setenv, setNames(list(old[[nm]]), nm))
        }
      }
    },
    envir = parent.frame()
  )
  for (i in seq_along(nms)) {
    val <- list(client_id, client_secret)[[i]]
    if (is.null(val)) {
      Sys.unsetenv(nms[[i]])
    } else {
      do.call(Sys.setenv, setNames(list(val), nms[[i]]))
    }
  }
  invisible(old)
}

# Drain any leftover later callbacks from prior tests so they don't fire
# inside the next test's run_now and trip up nanonext's external-pointer
# bookkeeping. Bounded so a perpetually-rescheduling callback can't hang.
drain_later <- function(max_iters = 10L) {
  tryCatch(
    for (i in seq_len(max_iters)) {
      if (later::loop_empty()) {
        break
      }
      later::run_now(0.1)
    },
    error = function(e) NULL
  )
}
