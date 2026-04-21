using ManagementConsole.ApiService.Models;
using ManagementConsole.ApiService.Services;
using Microsoft.AspNetCore.Mvc;

namespace ManagementConsole.ApiService;

public static class DeploymentEndpoints
{
    public static IEndpointRouteBuilder MapDeploymentEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/deployments").WithTags("deployments").RequireAuthorization();

        g.MapPost("/", ([FromBody] DeploymentRequest req, DeploymentService svc) =>
        {
            if (string.IsNullOrWhiteSpace(req.SubscriptionId) || string.IsNullOrWhiteSpace(req.Owner))
                return Results.BadRequest(new { error = "SubscriptionId and Owner are required" });

            if (req.Scenario is Scenario.Vpn or Scenario.Full && string.IsNullOrWhiteSpace(req.OnPremisesAddressSpace))
                return Results.BadRequest(new { error = "OnPremisesAddressSpace is required for VPN / Full scenarios" });

            var jobId = svc.StartDeployment(req);
            return Results.Accepted($"/api/deployments/{jobId}", new { jobId });
        });

        g.MapGet("/", (DeploymentService svc) => Results.Ok(svc.ListJobs()));

        g.MapGet("/{jobId}", (string jobId, DeploymentService svc) =>
        {
            var job = svc.GetJob(jobId);
            return job is null
                ? Results.NotFound()
                : Results.Ok(new DeploymentJobStatus(
                    job.Id, job.State, job.ExitCode, job.StartedUtc, job.FinishedUtc,
                    job.Request.Iac, job.Request.Scenario));
        });

        // Server-Sent Events stream of log lines for a job.
        g.MapGet("/{jobId}/logs", async (string jobId, DeploymentService svc, HttpContext http, CancellationToken ct) =>
        {
            var job = svc.GetJob(jobId);
            if (job is null) { http.Response.StatusCode = 404; return; }

            http.Response.Headers.ContentType = "text/event-stream";
            http.Response.Headers.CacheControl = "no-cache";
            http.Response.Headers["X-Accel-Buffering"] = "no";

            var reader = job.Logs.Reader;
            await foreach (var line in reader.ReadAllAsync(ct))
            {
                await http.Response.WriteAsync($"data: {line}\n\n", ct);
                await http.Response.Body.FlushAsync(ct);
            }

            await http.Response.WriteAsync($"event: end\ndata: {job.State}:{job.ExitCode}\n\n", ct);
            await http.Response.Body.FlushAsync(ct);
        });

        return app;
    }
}
