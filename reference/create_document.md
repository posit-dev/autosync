# Create a new document on the server

Creates a new empty Automerge document and registers it with the server.

## Usage

``` r
create_document(server, doc_id = NULL)
```

## Arguments

- server:

  An autosync_server object.

- doc_id:

  Optional document ID. If NULL, generates a new ID.

## Value

Document ID string.

## Examples

``` r
if (FALSE) { # interactive()
server <- sync_server()
doc_id <- create_document(server)
server$close()
}
```
