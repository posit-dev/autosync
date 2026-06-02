# autosync (development version)

* `amsync_project()` browses a project document's file tree from just a server
  URL and project ID, and edits files by path. `$browse()` and `$edit()` pick a
  file from a Shiny app, then hand off to `amsync_edit()`.
* `amsync_edit()` opens a synced text object in a Shiny app with a
  `bslib::input_code_editor()` component, merging your edits back into the live
  document on **Save** while preserving concurrent remote edits. Requires the
  `shiny` and `bslib` packages.

# autosync 0.0.1

* Initial version.
