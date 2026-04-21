using ManagementConsole.ApiService.Models;

namespace ManagementConsole.ApiService.Services;

/// <summary>
/// Canonical catalog of deployment scenarios surfaced to the wizard.
/// Cost estimates mirror the header of infra/bicep/smb-ready-foundation/main.bicep.
/// </summary>
public sealed class ScenarioCatalog
{
    public IReadOnlyList<ScenarioDescriptor> All { get; } =
    [
        new(
            Id: "baseline",
            Name: "Baseline",
            Summary: "NAT Gateway only - cloud-native, no hybrid connectivity.",
            MonthlyCostEstimate: "~$48/mo",
            Components: ["Hub VNet", "Spoke VNet", "NAT Gateway", "Log Analytics", "Budget alerts"]),
        new(
            Id: "firewall",
            Name: "Firewall",
            Summary: "Adds Azure Firewall + UDR for centralised egress filtering.",
            MonthlyCostEstimate: "~$336/mo",
            Components: ["Baseline", "Azure Firewall", "Route Tables", "Hub<->Spoke peering"]),
        new(
            Id: "vpn",
            Name: "VPN",
            Summary: "Adds VPN Gateway (VpnGw1AZ) for hybrid connectivity.",
            MonthlyCostEstimate: "~$187/mo",
            Components: ["Baseline", "VPN Gateway", "Gateway Subnet", "Hub<->Spoke peering"]),
        new(
            Id: "full",
            Name: "Full",
            Summary: "Firewall + VPN + UDR for complete security and hybrid.",
            MonthlyCostEstimate: "~$476/mo",
            Components: ["Baseline", "Azure Firewall", "VPN Gateway", "Route Tables", "Peering"]),
    ];

    public ScenarioDescriptor? Find(string id) =>
        All.FirstOrDefault(s => string.Equals(s.Id, id, StringComparison.OrdinalIgnoreCase));
}
