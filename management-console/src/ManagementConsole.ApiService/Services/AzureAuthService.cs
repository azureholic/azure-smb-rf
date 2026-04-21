using System.Collections.Concurrent;
using Azure.Core;
using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.Resources;
using ManagementConsole.ApiService.Models;

namespace ManagementConsole.ApiService.Services;

/// <summary>
/// Handles Azure authentication. Supports cross-tenant by caching per-tenant
/// credentials. Uses Azure CLI first (works out-of-the-box in the devcontainer
/// where ~/.azure is mounted), falling back to interactive browser.
/// </summary>
public sealed class AzureAuthService
{
    private readonly ConcurrentDictionary<string, TokenCredential> _credByTenant = new();

    /// <summary>Resolves a credential for the given tenant (or default chain if null).</summary>
    public TokenCredential GetCredential(string? tenantId)
    {
        var key = tenantId ?? "_default";
        return _credByTenant.GetOrAdd(key, _ =>
        {
            var opts = new DefaultAzureCredentialOptions
            {
                ExcludeEnvironmentCredential = false,
                ExcludeManagedIdentityCredential = true, // Local tool, no MI in path
                ExcludeVisualStudioCredential = true,
                ExcludeAzurePowerShellCredential = true,
                ExcludeInteractiveBrowserCredential = false,
                ExcludeAzureCliCredential = false,
                ExcludeAzureDeveloperCliCredential = false,
                TenantId = tenantId
            };
            return new DefaultAzureCredential(opts);
        });
    }

    /// <summary>Lists all subscriptions visible to the resolved credential.</summary>
    public async Task<IReadOnlyList<AzureSubscription>> ListSubscriptionsAsync(string? tenantId, CancellationToken ct)
    {
        var armClient = new ArmClient(GetCredential(tenantId));
        var subs = new List<AzureSubscription>();
        await foreach (SubscriptionResource sub in armClient.GetSubscriptions().GetAllAsync(ct))
        {
            var data = sub.Data;
            subs.Add(new AzureSubscription(
                Id: data.SubscriptionId ?? string.Empty,
                Name: data.DisplayName ?? string.Empty,
                TenantId: data.TenantId?.ToString() ?? tenantId ?? string.Empty,
                State: data.State?.ToString() ?? "Unknown"));
        }
        return subs;
    }
}
