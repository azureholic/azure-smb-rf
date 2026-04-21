import type { DeploymentRequest, Scenario } from "../types";

export function ParametersWizard({
  value,
  onChange,
}: {
  value: Partial<DeploymentRequest>;
  onChange: (v: Partial<DeploymentRequest>) => void;
}) {
  const needsVpn = value.scenario === "Vpn" || value.scenario === "Full";
  const set = <K extends keyof DeploymentRequest>(k: K, v: DeploymentRequest[K]) =>
    onChange({ ...value, [k]: v });

  return (
    <section>
      <h2>Parameters</h2>
      <div className="row">
        <div>
          <label>Owner (email / team) *</label>
          <input
            value={value.owner ?? ""}
            onChange={(e) => set("owner", e.target.value)}
            placeholder="platform-team@contoso.com"
          />
        </div>
        <div>
          <label>Environment</label>
          <select
            value={value.environment ?? "prod"}
            onChange={(e) => set("environment", e.target.value)}
          >
            <option value="dev">dev</option>
            <option value="staging">staging</option>
            <option value="prod">prod</option>
          </select>
        </div>
        <div>
          <label>Location</label>
          <select
            value={value.location ?? "swedencentral"}
            onChange={(e) => set("location", e.target.value)}
          >
            <option value="swedencentral">swedencentral</option>
            <option value="germanywestcentral">germanywestcentral</option>
          </select>
        </div>
        <div>
          <label>Hub VNet CIDR</label>
          <input
            value={value.hubVnetAddressSpace ?? "10.0.0.0/16"}
            onChange={(e) => set("hubVnetAddressSpace", e.target.value)}
          />
        </div>
        <div>
          <label>Spoke VNet CIDR</label>
          <input
            value={value.spokeVnetAddressSpace ?? "10.1.0.0/16"}
            onChange={(e) => set("spokeVnetAddressSpace", e.target.value)}
          />
        </div>
        <div>
          <label>On-prem CIDR {needsVpn ? "*" : "(unused)"} </label>
          <input
            disabled={!needsVpn}
            value={value.onPremisesAddressSpace ?? ""}
            onChange={(e) => set("onPremisesAddressSpace", e.target.value)}
            placeholder="192.168.0.0/16"
          />
        </div>
        <div>
          <label>Log Analytics daily cap (GB)</label>
          <input
            type="number"
            step={0.1}
            min={0.023}
            max={100}
            value={value.logAnalyticsDailyCapGb ?? 0.5}
            onChange={(e) => set("logAnalyticsDailyCapGb", Number(e.target.value))}
          />
        </div>
        <div>
          <label>Monthly budget (USD)</label>
          <input
            type="number"
            min={100}
            max={10000}
            value={value.budgetAmount ?? 500}
            onChange={(e) => set("budgetAmount", Number(e.target.value))}
          />
        </div>
        <div>
          <label>Budget alert email (defaults to Owner)</label>
          <input
            value={value.budgetAlertEmail ?? ""}
            onChange={(e) => set("budgetAlertEmail", e.target.value)}
          />
        </div>
      </div>
      <p className="muted">
        Scenario: <strong>{value.scenario ?? "-"}</strong> · IaC:{" "}
        <strong>{value.iac ?? "-"}</strong> · Subscription:{" "}
        <strong>{value.subscriptionId ?? "-"}</strong>
      </p>
    </section>
  );
}

export function isValid(v: Partial<DeploymentRequest>): v is DeploymentRequest {
  const needsVpn = v.scenario === "Vpn" || (v.scenario as Scenario) === "Full";
  return Boolean(
    v.iac &&
      v.scenario &&
      v.subscriptionId &&
      v.tenantId &&
      v.owner &&
      v.location &&
      v.environment &&
      v.hubVnetAddressSpace &&
      v.spokeVnetAddressSpace &&
      (!needsVpn || (v.onPremisesAddressSpace && v.onPremisesAddressSpace.length > 0)),
  );
}
