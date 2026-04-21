import { useMsal } from "@azure/msal-react";
import { loginRequest } from "../auth/msalConfig";

export function LoginPage() {
  const { instance, inProgress } = useMsal();
  const busy = inProgress !== "none";

  return (
    <div className="app" style={{ maxWidth: 480 }}>
      <h1>SMB RF Console</h1>
      <p className="muted">Sign in with your Microsoft Entra ID work account.</p>
      <div className="actions">
        <button
          disabled={busy}
          onClick={() => instance.loginRedirect(loginRequest).catch((e) => console.error(e))}
        >
          {busy ? "Signing in..." : "Sign in with Microsoft"}
        </button>
      </div>
      <p className="muted" style={{ marginTop: "1.5rem" }}>
        First run? Create the app registrations with{" "}
        <code>management-console/scripts/Create-AppRegistrations.ps1 -WriteUserSecrets</code>.
      </p>
    </div>
  );
}
