# SMB RF Management Console

A .NET Aspire orchestrated console for driving deployments of the
`smb-ready-foundation` landing zone (Bicep or Terraform, scenarios Baseline /
Firewall / VPN / Full).

## Topology

```text
management-console/
  ManagementConsole.sln
  global.json               # pins .NET SDK 10
  scripts/
    Create-AppRegistrations.ps1   # Entra ID app regs (SPA + API)
  src/
    ManagementConsole.AppHost/           # Aspire 13.2.2 host (api + web)
    ManagementConsole.ServiceDefaults/   # OTEL, health, resilience, discovery
    ManagementConsole.ApiService/        # ASP.NET Core Minimal API + MSAL JWT
    ManagementConsole.Web/               # React + Vite + MSAL.js SPA
```

## Prerequisites

The devcontainer includes the `dotnet` feature pinned at 10.0 with the Aspire
workload. **Rebuild the dev container** (Command Palette →
`Dev Containers: Rebuild Container`) so `dotnet` becomes available, then:

```bash
az login                           # optionally: az login --tenant <id>
```

## Step 1 — Create Entra ID app registrations

Creates two app registrations (SPA + API) with the SPA preauthorized against
the API's `access_as_user` delegated scope, and writes the result to AppHost
user-secrets.

```powershell
pwsh management-console/scripts/Create-AppRegistrations.ps1 -WriteUserSecrets
```

Outputs `management-console/.entra/app-registrations.json` and sets these
secrets on the AppHost:

| Key                     | Purpose                                |
| ----------------------- | -------------------------------------- |
| `Entra:TenantId`        | Tenant of both app registrations       |
| `Entra:Api:ClientId`    | API app (audience for the JWT)         |
| `Entra:Api:Scope`       | `api://<api-guid>/access_as_user`      |
| `Entra:Spa:ClientId`    | SPA app (MSAL browser client)          |

The AppHost forwards these to the API (`Entra__*`) and to the SPA as Vite env
vars (`VITE_ENTRA_TENANT_ID`, `VITE_ENTRA_SPA_CLIENT_ID`, `VITE_ENTRA_API_SCOPE`).

## Step 2 — Run

```bash
cd management-console
dotnet restore
dotnet run --project src/ManagementConsole.AppHost
```

The Aspire dashboard launches two resources:

| Resource | URL (default)          | Purpose                                  |
| -------- | ---------------------- | ---------------------------------------- |
| `api`    | https://localhost:5180 | ASP.NET Core API (JWT bearer)            |
| `web`    | http://localhost:5173  | React SPA (MSAL.js) proxying `/api`      |

## Auth flow

1. SPA redirects to Entra ID via `msalInstance.loginRedirect()`.
2. `acquireTokenSilent` obtains an access token for the API scope.
3. Every `fetch` to `/api/*` attaches `Authorization: Bearer <token>`.
4. ASP.NET Core validates the token via `Microsoft.Identity.Web` and enforces
   that the `scp` claim contains `access_as_user`.
5. SSE (`/api/deployments/{id}/logs`) passes the token via `?access_token=`
   since the EventSource API can't send custom headers.

## Wizard flow

1. **IaC** — Terraform or Bicep.
2. **Subscription** — lists subs visible to the backend's Azure CLI credential.
3. **Scenario** — Baseline / Firewall / VPN / Full.
4. **Parameters** — owner, env, location, CIDRs, budget, Log Analytics cap.
5. **Deploy** — streams live stdout/stderr via SSE.

## Backend behaviour

- **Terraform**: writes `.job-{id}.auto.tfvars.json` in
  `infra/terraform/smb-ready-foundation/`, runs `terraform init → plan → apply`.
- **Bicep**: runs `azd up --no-prompt` in `infra/bicep/smb-ready-foundation/`.

## API surface

| Method / Path                           | Description                  |
| --------------------------------------- | ---------------------------- |
| `GET  /api/auth/me`                     | Echo caller's JWT identity   |
| `GET  /api/azure/subscriptions`         | List subs (`?tenantId=` opt) |
| `GET  /api/scenarios/`                  | Scenario catalog             |
| `POST /api/deployments/`                | Start a deployment           |
| `GET  /api/deployments/`                | List jobs                    |
| `GET  /api/deployments/{jobId}`         | Job status                   |
| `GET  /api/deployments/{jobId}/logs`    | SSE log stream               |

All routes require a valid Entra ID JWT with the API's `access_as_user` scope.
