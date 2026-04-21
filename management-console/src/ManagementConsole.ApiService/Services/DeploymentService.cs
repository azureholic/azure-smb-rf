using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text.Json;
using System.Threading.Channels;
using ManagementConsole.ApiService.Models;

namespace ManagementConsole.ApiService.Services;

/// <summary>
/// Orchestrates Terraform / azd (Bicep) deployments of infra/{iac}/smb-ready-foundation.
/// Streams stdout/stderr to in-memory channels so the frontend can tail them.
/// </summary>
public sealed class DeploymentService
{
    private readonly IConfiguration _config;
    private readonly ILogger<DeploymentService> _log;
    private readonly ConcurrentDictionary<string, DeploymentJob> _jobs = new();

    public DeploymentService(IConfiguration config, ILogger<DeploymentService> log)
    {
        _config = config;
        _log = log;
    }

    public string StartDeployment(DeploymentRequest req)
    {
        var repoRoot = _config["Repo:Root"] ?? Directory.GetCurrentDirectory();
        var jobId = Guid.NewGuid().ToString("n")[..12];
        var job = new DeploymentJob(jobId, req, DateTimeOffset.UtcNow);
        _jobs[jobId] = job;

        _ = Task.Run(() => RunAsync(job, repoRoot, job.Cts.Token));
        return jobId;
    }

    public DeploymentJob? GetJob(string jobId) => _jobs.TryGetValue(jobId, out var j) ? j : null;

    public IEnumerable<DeploymentJobStatus> ListJobs() =>
        _jobs.Values.Select(j => new DeploymentJobStatus(
            j.Id, j.State, j.ExitCode, j.StartedUtc, j.FinishedUtc, j.Request.Iac, j.Request.Scenario));

    private async Task RunAsync(DeploymentJob job, string repoRoot, CancellationToken ct)
    {
        try
        {
            job.State = "Running";
            var projectDir = Path.Combine(
                repoRoot, "infra",
                job.Request.Iac == IacTool.Terraform ? "terraform" : "bicep",
                "smb-ready-foundation");

            if (!Directory.Exists(projectDir))
            {
                await job.WriteLineAsync($"[error] Project dir not found: {projectDir}", ct);
                job.ExitCode = 127;
                job.State = "Failed";
                return;
            }

            await (job.Request.Iac == IacTool.Terraform
                ? RunTerraformAsync(job, projectDir, ct)
                : RunBicepAsync(job, projectDir, ct));

            job.State = job.ExitCode == 0 ? "Succeeded" : "Failed";
        }
        catch (OperationCanceledException)
        {
            job.State = "Cancelled";
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Deployment job {JobId} crashed", job.Id);
            await job.WriteLineAsync($"[fatal] {ex.Message}", CancellationToken.None);
            job.State = "Failed";
            job.ExitCode = -1;
        }
        finally
        {
            job.FinishedUtc = DateTimeOffset.UtcNow;
            job.Logs.Writer.TryComplete();
        }
    }

    private async Task RunTerraformAsync(DeploymentJob job, string projectDir, CancellationToken ct)
    {
        // Inline tfvars file scoped to this job.
        var tfvars = new Dictionary<string, object?>
        {
            ["subscription_id"] = job.Request.SubscriptionId,
            ["location"] = job.Request.Location,
            ["environment"] = job.Request.Environment,
            ["owner"] = job.Request.Owner,
            ["hub_vnet_address_space"] = job.Request.HubVnetAddressSpace,
            ["spoke_vnet_address_space"] = job.Request.SpokeVnetAddressSpace,
            ["on_premises_address_space"] = job.Request.OnPremisesAddressSpace ?? string.Empty,
            ["log_analytics_daily_cap_gb"] = job.Request.LogAnalyticsDailyCapGb,
            ["budget_amount"] = job.Request.BudgetAmount,
            ["budget_alert_email"] = job.Request.BudgetAlertEmail ?? job.Request.Owner,
            ["budget_start_date"] = $"{DateTime.UtcNow:yyyy-MM}-01",
            ["deploy_firewall"] = job.Request.Scenario is Scenario.Firewall or Scenario.Full,
            ["deploy_vpn"] = job.Request.Scenario is Scenario.Vpn or Scenario.Full,
        };
        var tfvarsPath = Path.Combine(projectDir, $".job-{job.Id}.auto.tfvars.json");
        await File.WriteAllTextAsync(tfvarsPath, JsonSerializer.Serialize(tfvars, new JsonSerializerOptions { WriteIndented = true }), ct);

        var env = new Dictionary<string, string?>
        {
            ["ARM_SUBSCRIPTION_ID"] = job.Request.SubscriptionId,
            ["ARM_TENANT_ID"] = job.Request.TenantId,
            ["ARM_USE_CLI"] = "true",
        };

        if (await Exec(job, "terraform", ["init", "-input=false"], projectDir, env, ct) != 0) return;
        if (await Exec(job, "terraform", ["plan", "-input=false", "-out=tfplan"], projectDir, env, ct) != 0) return;
        await Exec(job, "terraform", ["apply", "-input=false", "-auto-approve", "tfplan"], projectDir, env, ct);
    }

    private async Task RunBicepAsync(DeploymentJob job, string projectDir, CancellationToken ct)
    {
        // Prefer azd up (azure.yaml is present). Pass scenario + params via env vars.
        var env = new Dictionary<string, string?>
        {
            ["AZURE_SUBSCRIPTION_ID"] = job.Request.SubscriptionId,
            ["AZURE_TENANT_ID"] = job.Request.TenantId,
            ["AZURE_LOCATION"] = job.Request.Location,
            ["AZURE_ENV_NAME"] = $"smb-rf-{job.Request.Environment}-{job.Id}",
            ["SCENARIO"] = job.Request.Scenario.ToString().ToLowerInvariant(),
            ["OWNER"] = job.Request.Owner,
            ["HUB_VNET_ADDRESS_SPACE"] = job.Request.HubVnetAddressSpace,
            ["SPOKE_VNET_ADDRESS_SPACE"] = job.Request.SpokeVnetAddressSpace,
            ["ON_PREMISES_ADDRESS_SPACE"] = job.Request.OnPremisesAddressSpace ?? string.Empty,
            ["LOG_ANALYTICS_DAILY_CAP_GB"] = job.Request.LogAnalyticsDailyCapGb.ToString(System.Globalization.CultureInfo.InvariantCulture),
            ["BUDGET_AMOUNT"] = job.Request.BudgetAmount.ToString(System.Globalization.CultureInfo.InvariantCulture),
            ["BUDGET_ALERT_EMAIL"] = job.Request.BudgetAlertEmail ?? job.Request.Owner,
        };

        await Exec(job, "azd", ["up", "--no-prompt"], projectDir, env, ct);
    }

    private static async Task<int> Exec(
        DeploymentJob job,
        string file,
        string[] args,
        string workingDir,
        IDictionary<string, string?> env,
        CancellationToken ct)
    {
        await job.WriteLineAsync($"$ {file} {string.Join(' ', args)}", ct);

        var psi = new ProcessStartInfo
        {
            FileName = file,
            WorkingDirectory = workingDir,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        foreach (var a in args) psi.ArgumentList.Add(a);
        foreach (var kv in env) if (kv.Value is not null) psi.Environment[kv.Key] = kv.Value;

        using var proc = new Process { StartInfo = psi, EnableRaisingEvents = true };
        proc.OutputDataReceived += (_, e) => { if (e.Data is not null) job.Logs.Writer.TryWrite(e.Data); };
        proc.ErrorDataReceived += (_, e) => { if (e.Data is not null) job.Logs.Writer.TryWrite($"[stderr] {e.Data}"); };

        proc.Start();
        proc.BeginOutputReadLine();
        proc.BeginErrorReadLine();

        using var reg = ct.Register(() => { try { if (!proc.HasExited) proc.Kill(entireProcessTree: true); } catch { } });
        await proc.WaitForExitAsync(ct);
        job.ExitCode = proc.ExitCode;
        await job.WriteLineAsync($"-> exit {proc.ExitCode}", ct);
        return proc.ExitCode;
    }
}

public sealed class DeploymentJob
{
    public DeploymentJob(string id, DeploymentRequest request, DateTimeOffset startedUtc)
    {
        Id = id;
        Request = request;
        StartedUtc = startedUtc;
    }

    public string Id { get; }
    public DeploymentRequest Request { get; }
    public DateTimeOffset StartedUtc { get; }
    public DateTimeOffset? FinishedUtc { get; set; }
    public string State { get; set; } = "Pending";
    public int ExitCode { get; set; }
    public Channel<string> Logs { get; } = Channel.CreateUnbounded<string>(new UnboundedChannelOptions { SingleReader = false });
    public CancellationTokenSource Cts { get; } = new();

    public async Task WriteLineAsync(string line, CancellationToken ct) =>
        await Logs.Writer.WriteAsync(line, ct);
}
