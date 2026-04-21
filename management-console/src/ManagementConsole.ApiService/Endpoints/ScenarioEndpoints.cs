using ManagementConsole.ApiService.Services;

namespace ManagementConsole.ApiService;

public static class ScenarioEndpoints
{
    public static IEndpointRouteBuilder MapScenarioEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/scenarios").WithTags("scenarios").RequireAuthorization();
        g.MapGet("/", (ScenarioCatalog catalog) => Results.Ok(catalog.All));
        return app;
    }
}
