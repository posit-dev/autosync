# autosync: 'Automerge' Sync Server and Client

A WebSocket-based implementation of the 'automerge-repo' synchronization
protocol used by 'sync.automerge.org'. Acts as a sync server, enabling
'R' to serve as a synchronization hub for 'Automerge' clients in
'JavaScript', 'Rust', and other languages, and as a client for fetching,
editing, and synchronizing documents hosted on remote servers.

## Main Functions

- [`sync_server()`](https://posit-dev.github.io/autosync/dev/reference/sync_server.md):

  Create a new sync server with `$start()` and `$close()` methods

## Document Management

- [`create_document()`](https://posit-dev.github.io/autosync/dev/reference/create_document.md):

  Create a new document

- [`get_document()`](https://posit-dev.github.io/autosync/dev/reference/get_document.md):

  Retrieve a document by ID

- [`list_documents()`](https://posit-dev.github.io/autosync/dev/reference/list_documents.md):

  List all document IDs

- [`generate_document_id()`](https://posit-dev.github.io/autosync/dev/reference/generate_document_id.md):

  Generate a new document ID

## Protocol

The server implements the automerge-repo sync protocol over WebSockets.
Messages are CBOR-encoded and include:

- join/peer:

  Handshake messages for connection establishment

- request/sync:

  Document synchronization messages

- ephemeral:

  Transient messages forwarded without persistence

- error:

  Error notifications

## Example


    # Create and start a server
    server <- sync_server()
    server$start()
    server$url

    # Stop when done
    server$close()

## See also

Useful links:

- <https://posit-dev.github.io/autosync/>

- <https://github.com/posit-dev/autosync>

- Report bugs at <https://github.com/posit-dev/autosync/issues>

## Author

**Maintainer**: Charlie Gao <charlie.gao@posit.co>
([ORCID](https://orcid.org/0000-0002-0750-061X))

Authors:

- Charlie Gao <charlie.gao@posit.co>
  ([ORCID](https://orcid.org/0000-0002-0750-061X))

Other contributors:

- Posit Software, PBC ([ROR](https://ror.org/03wc8by49)) \[copyright
  holder, funder\]
