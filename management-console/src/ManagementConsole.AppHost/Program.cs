// Aspire App Host for the SMB Ready Foundation management console.
// Wires the ASP.NET Core API and the React (Vite) frontend and pushes Entra
// ID settings (populated by scripts/Create-AppRegistrations.ps1) to each.
using Microsoft.Extensions.Hosting;

var builder = DistributedApplication.CreateBuilder(args);

// Entra ID configuration. Produced by scripts/Create-AppRegistrations.ps1 and
// stored in user-secrets on the AppHost (see README). All three values are
// required; fail fast so misconfiguration surfaces on startup.
var tenantId = builder.Configuration["Entra:TenantId"] ?? string.Empty;
var apiClientId = builder.Configuration["Entra:Api:ClientId"] ?? string.Empty;
var apiScope = builder.Configuration["Entra:Api:Scope"] ?? string.Empty; // api://<guid>/access_as_user
var spaClientId = builder.Configuration["Entra:Spa:ClientId"] ?? string.Empty;

var api = builder.AddProject<Projects.ManagementConsole_ApiService>("api")
    .WithEnvironment("Entra__TenantId", tenantId)
    .WithEnvironment("Entra__ClientId", apiClientId)
    .WithEnvironment("Entra__Scope", apiScope)
    // Root of the IaC projects so the backend can locate terraform/bicep.
    .WithEnvironment("Repo__Root", Path.GetFullPath(Path.Combine(builder.AppHostDirectory, "..", "..", "..")));

// React (Vite) frontend. Aspire.Hosting.JavaScript installs npm deps
// automatically and proxies /api to the backend (vite.config.ts).
builder.AddViteApp("web", "../ManagementConsole.Web", "dev")
    .WithNpm()
    .WithReference(api)
    .WaitFor(api)
    .WithEnvironment("VITE_ENTRA_TENANT_ID", tenantId)
    .WithEnvironment("VITE_ENTRA_SPA_CLIENT_ID", spaClientId)
    .WithEnvironment("VITE_ENTRA_API_SCOPE", apiScope)
    .WithExternalHttpEndpoints();

builder.Build().Run();
