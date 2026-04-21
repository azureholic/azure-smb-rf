using ManagementConsole.ApiService.Services;
using Microsoft.AspNetCore.Mvc;

namespace ManagementConsole.ApiService;

public static class AzureEndpoints
{
    public static IEndpointRouteBuilder MapAzureEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/azure").WithTags("azure").RequireAuthorization();

        // List subscriptions visible to the resolved credential (optionally per-tenant).
        g.MapGet("/subscriptions", async (
            [FromQuery] string? tenantId,
            [FromServices] AzureAuthService auth,
            CancellationToken ct) =>
        {
            try
            {
                var subs = await auth.ListSubscriptionsAsync(tenantId, ct);
                return Results.Ok(subs);
            }
            catch (Exception ex)
            {
                return Results.Problem(
                    title: "Azure auth failed",
                    detail: ex.Message,
                    statusCode: StatusCodes.Status502BadGateway);
            }
        });

        return app;
    }
}
