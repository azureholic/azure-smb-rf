import { useEffect, useState } from "react";
import { api } from "../api";
import type { Scenario, ScenarioDescriptor } from "../types";

const toEnum = (id: string): Scenario => {
  switch (id) {
    case "baseline":
      return "Baseline";
    case "firewall":
      return "Firewall";
    case "vpn":
      return "Vpn";
    case "full":
      return "Full";
    default:
      return "Baseline";
  }
};

export function ScenarioPicker({
  value,
  onChange,
}: {
  value: Scenario | null;
  onChange: (v: Scenario) => void;
}) {
  const [items, setItems] = useState<ScenarioDescriptor[]>([]);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    api
      .listScenarios()
      .then(setItems)
      .catch((e: Error) => setErr(e.message));
  }, []);

  return (
    <section>
      <h2>Scenario</h2>
      {err && <p className="error">{err}</p>}
      {items.map((s) => {
        const scen = toEnum(s.id);
        return (
          <div
            key={s.id}
            className={`card ${value === scen ? "selected" : ""}`}
            role="button"
            onClick={() => onChange(scen)}
          >
            <strong>
              {s.name} <span className="muted">— {s.monthlyCostEstimate}</span>
            </strong>
            <p style={{ margin: "0.25rem 0" }}>{s.summary}</p>
            <p className="muted" style={{ margin: 0 }}>
              Includes: {s.components.join(", ")}
            </p>
          </div>
        );
      })}
    </section>
  );
}
