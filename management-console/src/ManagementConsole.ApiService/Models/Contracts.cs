namespace ManagementConsole.ApiService.Models;

public enum IacTool
{
    Terraform,
    Bicep
}

public enum Scenario
{
    Baseline,
    Firewall,
    Vpn,
    Full
}

/// <summary>Shape of the UI wizard's answer set. All IaC tracks map from this.</summary>
public sealed record DeploymentRequest
{
    public required IacTool Iac { get; init; }
    public required Scenario Scenario { get; init; }
    public required string SubscriptionId { get; init; }
    public required string TenantId { get; init; }
    public required string Owner { get; init; }
    public string Location { get; init; } = "swedencentral";
    public string Environment { get; init; } = "prod";
    public string HubVnetAddressSpace { get; init; } = "10.0.0.0/16";
    public string SpokeVnetAddressSpace { get; init; } = "10.1.0.0/16";
    public string? OnPremisesAddressSpace { get; init; }
    public double LogAnalyticsDailyCapGb { get; init; } = 0.5;
    public int BudgetAmount { get; init; } = 500;
    public string? BudgetAlertEmail { get; init; }
}

public sealed record AzureSubscription(string Id, string Name, string TenantId, string State);

public sealed record ScenarioDescriptor(
    string Id,
    string Name,
    string Summary,
    string MonthlyCostEstimate,
    IReadOnlyList<string> Components);

public sealed record DeploymentJobStatus(
    string JobId,
    string State,
    int ExitCode,
    DateTimeOffset StartedUtc,
    DateTimeOffset? FinishedUtc,
    IacTool Iac,
    Scenario Scenario);
