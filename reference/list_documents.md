# List all document IDs

Returns the IDs of all documents currently loaded in the server.

## Usage

``` r
list_documents(server)
```

## Arguments

- server:

  An autosync_server object.

## Value

Character vector of document IDs.

## Examples

``` r
if (FALSE) { # interactive()
server <- sync_server()
create_document(server)
list_documents(server)
server$close()
}
```
