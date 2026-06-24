# Get a document from the server

Retrieves an Automerge document by its ID.

## Usage

``` r
get_document(server, doc_id)
```

## Arguments

- server:

  An autosync_server object.

- doc_id:

  Document ID string.

## Value

Automerge document object, or NULL if not found.

## Examples

``` r
if (FALSE) { # interactive()
server <- sync_server()
doc_id <- create_document(server)
get_document(server, doc_id)
server$close()
}
```
