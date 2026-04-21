import { useState } from "react";
import {
  AuthenticatedTemplate,
  UnauthenticatedTemplate,
  useMsal,
} from "@azure/msal-react";
import { api } from "./api";
import { LoginPage } from "./components/LoginPage";
import { SubscriptionPicker } from "./components/SubscriptionPicker";
import { IacPicker } from "./components/IacPicker";
import { ScenarioPicker } from "./components/ScenarioPicker";
import { ParametersWizard, isValid } from "./components/ParametersWizard";
import { DeploymentRunner } from "./components/DeploymentRunner";
import type { DeploymentRequest } from "./types";

type Step = "iac" | "subscription" | "scenario" | "params" | "running";

function Shell() {
  const { instance, accounts } = useMsal();
  const account = accounts[0];
  const [step, setStep] = useState<Step>("iac");
  const [jobId, setJobId] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [req, setReq] = useState<Partial<DeploymentRequest>>({
    location: "swedencentral",
    environment: "prod",
    hubVnetAddressSpace: "10.0.0.0/16",
    spokeVnetAddressSpace: "10.1.0.0/16",
    logAnalyticsDailyCapGb: 0.5,
    budgetAmount: 500,
  });

  async function start() {
    if (!isValid(req)) return;
    setErr(null);
    try {
      const res = await api.createDeployment(req);
      setJobId(res.jobId);
      setStep("running");
    } catch (e) {
      setErr((e as Error).message);
    }
  }

  function reset() {
    setJobId(null);
    setStep("iac");
    setReq({
      location: "swedencentral",
      environment: "prod",
      hubVnetAddressSpace: "10.0.0.0/16",
      spokeVnetAddressSpace: "10.1.0.0/16",
      logAnalyticsDailyCapGb: 0.5,
      budgetAmount: 500,
    });
  }

  const steps: { id: Step; label: string }[] = [
    { id: "iac", label: "1. IaC" },
    { id: "subscription", label: "2. Subscription" },
    { id: "scenario", label: "3. Scenario" },
    { id: "params", label: "4. Parameters" },
    { id: "running", label: "5. Deploy" },
  ];

  return (
    <div className="app">
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <h1>SMB RF Console</h1>
        <div className="muted">
          {account?.username ?? account?.name} ·{" "}
          <button
            className="secondary"
            onClick={() => instance.logoutRedirect({ postLogoutRedirectUri: window.location.origin })}
          >
            Sign out
          </button>
        </div>
      </div>

      <div className="stepper">
        {steps.map((s, i) => {
          const idx = steps.findIndex((x) => x.id === step);
          const cls = i < idx ? "step done" : i === idx ? "step active" : "step";
          return (
            <span key={s.id} className={cls}>
              {s.label}
            </span>
          );
        })}
      </div>

      {step === "iac" && (
        <>
          <IacPicker
            value={(req.iac as DeploymentRequest["iac"]) ?? null}
            onChange={(v) => setReq({ ...req, iac: v })}
          />
          <div className="actions">
            <button disabled={!req.iac} onClick={() => setStep("subscription")}>
              Next
            </button>
          </div>
        </>
      )}

      {step === "subscription" && (
        <>
          <SubscriptionPicker
            value={
              req.subscriptionId && req.tenantId
                ? { subscriptionId: req.subscriptionId, tenantId: req.tenantId }
                : null
            }
            onChange={(v) =>
              setReq({ ...req, subscriptionId: v.subscriptionId, tenantId: v.tenantId })
            }
          />
          <div className="actions">
            <button className="secondary" onClick={() => setStep("iac")}>Back</button>
            <button
              disabled={!req.subscriptionId}
              onClick={() => setStep("scenario")}
            >
              Next
            </button>
          </div>
        </>
      )}

      {step === "scenario" && (
        <>
          <ScenarioPicker
            value={(req.scenario as DeploymentRequest["scenario"]) ?? null}
            onChange={(v) => setReq({ ...req, scenario: v })}
          />
          <div className="actions">
            <button className="secondary" onClick={() => setStep("subscription")}>Back</button>
            <button disabled={!req.scenario} onClick={() => setStep("params")}>
              Next
            </button>
          </div>
        </>
      )}

      {step === "params" && (
        <>
          <ParametersWizard value={req} onChange={setReq} />
          {err && <p className="error">{err}</p>}
          <div className="actions">
            <button className="secondary" onClick={() => setStep("scenario")}>Back</button>
            <button disabled={!isValid(req)} onClick={start}>
              Run deployment
            </button>
          </div>
        </>
      )}

      {step === "running" && jobId && (
        <DeploymentRunner jobId={jobId} onReset={reset} />
      )}
    </div>
  );
}

export function App() {
  return (
    <>
      <AuthenticatedTemplate>
        <Shell />
      </AuthenticatedTemplate>
      <UnauthenticatedTemplate>
        <LoginPage />
      </UnauthenticatedTemplate>
    </>
  );
}
