using System.Security.Claims;

namespace ManagementConsole.ApiService;

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/auth").WithTags("auth").RequireAuthorization();

        // Surfaces the caller identity from the Entra ID JWT so the SPA can
        // confirm auth is working end-to-end (login -> MSAL -> API bearer).
        g.MapGet("/me", (HttpContext http) =>
        {
            var user = http.User;
            return Results.Ok(new
            {
                name = user.FindFirstValue("name") ?? user.Identity?.Name,
                oid = user.FindFirstValue("http://schemas.microsoft.com/identity/claims/objectidentifier"),
                tid = user.FindFirstValue("http://schemas.microsoft.com/identity/claims/tenantid"),
                scopes = user.FindFirstValue("http://schemas.microsoft.com/identity/claims/scope")?.Split(' ') ?? [],
            });
        });

        return app;
    }
}
