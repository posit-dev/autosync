// Connect screen: server URL + project ID, an optional OIDC sign-in flow (run in
// R by amsync_token()), and Connect / Exit. Mirrors the former bslib connect card.
// The R server prefills the fields via `output$init`; events fire R observers.

import { React, useShinyEvent, useShinyInput, useShinyOutputValue } from "./shiny";

interface Init {
  server: string;
  proj_id: string;
  client_id: string;
  client_secret: string;
  issuer: string;
}

export function ConnectScreen() {
  const init = useShinyOutputValue<Init>("init");
  const authed = useShinyOutputValue<boolean>("authed", false) ?? false;

  const [url, setUrl] = useShinyInput<string>("url", "");
  const [projId, setProjId] = useShinyInput<string>("proj_id", "");
  const [clientId, setClientId] = useShinyInput<string>("client_id", "");
  const [clientSecret, setClientSecret] = useShinyInput<string>("client_secret", "");
  const [issuer, setIssuer] = useShinyInput<string>("issuer", "");

  const authenticate = useShinyEvent("authenticate");
  const connect = useShinyEvent("connect");
  const exit = useShinyEvent("exit");

  // Seed the form once from the R-supplied prefill/defaults.
  const seeded = React.useRef(false);
  React.useEffect(() => {
    if (!init || seeded.current) return;
    seeded.current = true;
    if (init.server) setUrl(init.server);
    if (init.proj_id) setProjId(init.proj_id);
    if (init.client_id) setClientId(init.client_id);
    if (init.client_secret) setClientSecret(init.client_secret);
    if (init.issuer) setIssuer(init.issuer);
  }, [init, setUrl, setProjId, setClientId, setClientSecret, setIssuer]);

  return (
    <div className="amsync-connect">
      <div className="amsync-card">
        <div className="amsync-card-header">Connect to a project</div>
        <div className="amsync-card-body">
          <label className="amsync-field">
            <span>Server URL</span>
            <input
              type="text"
              value={url}
              placeholder="Sync server wss://"
              onChange={(e) => setUrl(e.target.value)}
            />
          </label>
          <label className="amsync-field">
            <span>Project ID</span>
            <input
              type="text"
              value={projId}
              placeholder="Base58 document ID"
              onChange={(e) => setProjId(e.target.value)}
            />
          </label>

          <div className="amsync-auth">
            <div className="amsync-auth-row">
              <button
                type="button"
                className="amsync-btn amsync-btn-outline"
                onClick={authenticate}
              >
                Authenticate
              </button>
              <span className={authed ? "amsync-status ok" : "amsync-status muted"}>
                {authed ? "✓ signed in" : "not signed in"}
              </span>
            </div>
            <details className="amsync-advanced">
              <summary>Advanced</summary>
              <div className="amsync-advanced-body">
                <label className="amsync-field">
                  <span>OIDC client ID</span>
                  <input
                    type="text"
                    value={clientId}
                    onChange={(e) => setClientId(e.target.value)}
                  />
                </label>
                <label className="amsync-field">
                  <span>OIDC client secret</span>
                  <input
                    type="password"
                    value={clientSecret}
                    onChange={(e) => setClientSecret(e.target.value)}
                  />
                </label>
                <label className="amsync-field">
                  <span>OIDC issuer</span>
                  <input
                    type="text"
                    value={issuer}
                    onChange={(e) => setIssuer(e.target.value)}
                  />
                </label>
              </div>
            </details>
          </div>
        </div>
        <div className="amsync-card-footer">
          <button
            type="button"
            className="amsync-btn amsync-btn-primary amsync-fill"
            onClick={connect}
          >
            Connect
          </button>
          <button
            type="button"
            className="amsync-btn amsync-btn-outline"
            onClick={exit}
          >
            Exit
          </button>
        </div>
      </div>
    </div>
  );
}
