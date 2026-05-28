# Obtain an OIDC token interactively

Performs the OAuth 2.0 Authorization Code flow with PKCE to obtain a JWT
(ID token) from an OIDC provider. Opens the system browser for the user
to authenticate, and returns the ID token for use with
[`amsync_fetch()`](http://shikokuchuo.net/autosync/reference/amsync_fetch.md).

## Usage

``` r
amsync_token(
  client_id = Sys.getenv("OIDC_CLIENT_ID"),
  client_secret = Sys.getenv("OIDC_CLIENT_SECRET"),
  issuer = oidc_issuer(),
  scopes = "openid email",
  redirect_uri = "http://127.0.0.1:0",
  timeout = 120
)
```

## Arguments

- client_id:

  The OIDC client ID (application ID). Defaults to the `OIDC_CLIENT_ID`
  environment variable.

- client_secret:

  The OIDC client secret. Required by Google (Desktop app) and "Web
  application" client types; leave unset for native / public clients,
  which authenticate via PKCE alone. Defaults to the
  `OIDC_CLIENT_SECRET` environment variable.

- issuer:

  The OIDC issuer URL. Defaults to the `OIDC_ISSUER` environment
  variable, falling back to Google (`"https://accounts.google.com"`).

- scopes:

  Space-separated OAuth scopes to request. Default `"openid email"`.

- redirect_uri:

  Local redirect URI for the OAuth callback. Default
  `"http://127.0.0.1:0"` uses the loopback IP literal (recommended over
  `localhost` by RFC 8252 section 8.3, since `localhost` resolution can
  be reconfigured via DNS or the hosts file) with an OS-assigned
  ephemeral port, which works with OIDC clients registered as "Desktop
  app" / loopback-IP types that accept any port. Supply an explicit port
  (e.g. `"http://127.0.0.1:8080"`) when your OIDC provider requires the
  redirect URI to match a pre-registered value.

- timeout:

  Seconds to wait for the user to complete authentication. Default 120.

## Value

A JWT (ID token) as a character string.

## Details

For Google, register the OAuth client as a "Desktop app" and set both
`OIDC_CLIENT_ID` and `OIDC_CLIENT_SECRET`. Google's Desktop app secret
is required in the token exchange but, unlike a "Web application"
secret, is not treated as confidential: Google states that for installed
apps "the client secret is obviously not treated as a secret"
(<https://developers.google.com/identity/protocols/oauth2#installed>),
consistent with the OAuth 2.0 for Native Apps standard (RFC 8252 section
8.5, <https://datatracker.ietf.org/doc/html/rfc8252#section-8.5>).
Providers that support native / public clients (Microsoft Entra, Okta,
Auth0, etc.) need only `client_id`, authenticating via PKCE alone.

## Examples

``` r
if (FALSE) { # interactive()
# Uses OIDC_CLIENT_ID and OIDC_CLIENT_SECRET env vars by default
token <- amsync_token()

# Or supply credentials directly
token <- amsync_token(
  client_id = "YOUR_CLIENT_ID.apps.googleusercontent.com",
  client_secret = "YOUR_CLIENT_SECRET"
)

# Use with amsync_fetch
doc <- amsync_fetch(server$url, "myDocId", token = token, tls = tls)
}
```
