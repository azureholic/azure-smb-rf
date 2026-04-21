import { useEffect, useState } from "react";
import { api } from "../api";
import type { AzureSubscription } from "../types";

export function SubscriptionPicker({
  value,
  onChange,
}: {
  value: { subscriptionId: string; tenantId: string } | null;
  onChange: (v: { subscriptionId: string; tenantId: string; name: string }) => void;
}) {
  const [tenantId, setTenantId] = useState("");
  const [subs, setSubs] = useState<AzureSubscription[]>([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setErr(null);
    try {
      const data = await api.listSubscriptions(tenantId || undefined);
      setSubs(data);
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <section>
      <h2>Azure subscription</h2>
      <p className="muted">
        Uses the Azure CLI credential from the container. For a different tenant
        (cross-tenant), run <code>az login --tenant &lt;id&gt;</code> in the
        terminal, then enter the Tenant ID below and refresh.
      </p>
      <div className="row">
        <div>
          <label>Tenant ID (optional)</label>
          <input
            placeholder="leave blank to use default"
            value={tenantId}
            onChange={(e) => setTenantId(e.target.value)}
          />
        </div>
        <div style={{ alignSelf: "end" }}>
          <button className="secondary" onClick={load} disabled={loading}>
            {loading ? "Loading..." : "Refresh"}
          </button>
        </div>
      </div>
      {err && <p className="error">{err}</p>}
      <label>Subscription</label>
      <select
        value={value?.subscriptionId ?? ""}
        onChange={(e) => {
          const sub = subs.find((s) => s.id === e.target.value);
          if (sub) onChange({ subscriptionId: sub.id, tenantId: sub.tenantId, name: sub.name });
        }}
      >
        <option value="" disabled>
          {subs.length ? "Select a subscription..." : "No subscriptions loaded"}
        </option>
        {subs.map((s) => (
          <option key={s.id} value={s.id}>
            {s.name} ({s.id})
          </option>
        ))}
      </select>
    </section>
  );
}
