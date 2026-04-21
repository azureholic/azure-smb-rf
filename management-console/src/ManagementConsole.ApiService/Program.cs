// Minimal API host for the SMB Ready Foundation management console.
// - Entra ID JWT bearer auth protects the /api surface.
// - Azure endpoints use Azure CLI + interactive browser credentials (cross-tenant).
// - Deployment endpoints shell out to terraform / azd for the selected IaC track.
using ManagementConsole.ApiService;
using ManagementConsole.ApiService.Services;
using ManagementConsole.ServiceDefaults;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;

var builder = WebApplication.CreateBuilder(args);
builder.AddServiceDefaults();

// Entra config is pushed in by the AppHost (Entra__TenantId / Entra__ClientId / Entra__Scope).
// Microsoft.Identity.Web expects AzureAd:* - project those keys at startup.
var entraTenant = builder.Configuration["Entra:TenantId"] ?? throw new InvalidOperationException("Entra:TenantId not configured");
var entraClientId = builder.Configuration["Entra:ClientId"] ?? throw new InvalidOperationException("Entra:ClientId not configured");
var entraScope = builder.Configuration["Entra:Scope"] ?? "access_as_user";
builder.Configuration["AzureAd:Instance"] = "https://login.microsoftonline.com/";
builder.Configuration["AzureAd:TenantId"] = entraTenant;
builder.Configuration["AzureAd:ClientId"] = entraClientId;
// Accept both the GUID client ID and the api://<guid> URI as valid audiences.
builder.Configuration["AzureAd:Audience"] = $"api://{entraClientId}";

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

// EventSource can't send custom headers; allow ?access_token= on the SSE
// log stream route only. Other routes still require Authorization header.
builder.Services.Configure<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme, options =>
{
    options.Events ??= new JwtBearerEvents();
    var existing = options.Events.OnMessageReceived;
    options.Events.OnMessageReceived = async ctx =>
    {
        if (existing is not null) await existing(ctx);
        if (string.IsNullOrEmpty(ctx.Token) &&
            ctx.Request.Path.StartsWithSegments("/api/deployments") &&
            ctx.Request.Path.Value!.EndsWith("/logs", StringComparison.Ordinal) &&
            ctx.Request.Query.TryGetValue("access_token", out var qs))
        {
            ctx.Token = qs.ToString();
        }
    };
});

// Require the delegated scope exposed by the API app registration.
var scopeName = entraScope.Contains('/') ? entraScope[(entraScope.LastIndexOf('/') + 1)..] : entraScope;
builder.Services.AddAuthorizationBuilder()
    .SetDefaultPolicy(new Microsoft.AspNetCore.Authorization.AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .RequireClaim("http://schemas.microsoft.com/identity/claims/scope", scopeName)
        .Build());

builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .WithOrigins("http://localhost:5173", "https://localhost:5173")
    .AllowAnyHeader()
    .AllowAnyMethod()));

builder.Services.AddSingleton<AzureAuthService>();
builder.Services.AddSingleton<ScenarioCatalog>();
builder.Services.AddSingleton<DeploymentService>();

var app = builder.Build();
app.MapDefaultEndpoints();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

// Route groups ------------------------------------------------------------
app.MapAuthEndpoints();
app.MapAzureEndpoints();
app.MapScenarioEndpoints();
app.MapDeploymentEndpoints();

app.Run();
