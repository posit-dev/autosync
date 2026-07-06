# Generate a new document ID

Creates a new unique document ID compatible with automerge-repo. The ID
is a 16-byte random value encoded with Base58Check.

## Usage

``` r
generate_document_id()
```

## Value

Character string (Base58Check encoded).

## Examples

``` r
generate_document_id()
#> [1] "2Ppwc81Sq4m1UTZLv2WAzp2iaMXx"
```
