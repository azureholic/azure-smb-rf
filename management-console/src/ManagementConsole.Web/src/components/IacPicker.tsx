import type { IacTool } from "../types";

export function IacPicker({
  value,
  onChange,
}: {
  value: IacTool | null;
  onChange: (v: IacTool) => void;
}) {
  const options: { id: IacTool; title: string; desc: string }[] = [
    { id: "Terraform", title: "Terraform", desc: "azurerm provider, state via Azure Storage." },
    { id: "Bicep", title: "Bicep", desc: "Deployed through azd + Azure CLI." },
  ];
  return (
    <section>
      <h2>Infrastructure as Code</h2>
      <div className="row">
        {options.map((o) => (
          <div
            key={o.id}
            className={`card ${value === o.id ? "selected" : ""}`}
            role="button"
            onClick={() => onChange(o.id)}
          >
            <strong>{o.title}</strong>
            <p className="muted" style={{ margin: "0.25rem 0 0" }}>{o.desc}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
