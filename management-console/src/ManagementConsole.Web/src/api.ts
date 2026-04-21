import type {
  AzureSubscription,
  DeploymentJobStatus,
  DeploymentRequest,
  ScenarioDescriptor,
} from "./types";
import { msalInstance, apiTokenRequest } from "./auth/msalConfig";
import { InteractionRequiredAuthError } from "@azure/msal-browser";

async function getAccessToken(): Promise<string> {
  const account = msalInstance.getActiveAccount() ?? msalInstance.getAllAccounts()[0];
  if (!account) throw new Error("Not signed in");
  try {
    const result = await msalInstance.acquireTokenSilent({ ...apiTokenRequest, account });
    return result.accessToken;
  } catch (e) {
    if (e instanceof InteractionRequiredAuthError) {
      // Force an interactive flow to recover from expired / revoked tokens.
      await msalInstance.acquireTokenRedirect(apiTokenRequest);
      // acquireTokenRedirect never resolves; rethrow so callers halt.
      throw e;
    }
    throw e;
  }
}

async function http<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const token = await getAccessToken();
  const res = await fetch(path, {
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
      ...(init.headers ?? {}),
    },
    ...init,
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    throw new Error(`${res.status} ${res.statusText}: ${detail}`);
  }
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T);
}

export const api = {
  me: () => http<{ name: string; oid: string; tid: string; scopes: string[] }>("/api/auth/me"),

  listSubscriptions: (tenantId?: string) =>
    http<AzureSubscription[]>(
      "/api/azure/subscriptions" +
        (tenantId ? `?tenantId=${encodeURIComponent(tenantId)}` : ""),
    ),

  listScenarios: () => http<ScenarioDescriptor[]>("/api/scenarios/"),

  createDeployment: (req: DeploymentRequest) =>
    http<{ jobId: string }>("/api/deployments/", {
      method: "POST",
      body: JSON.stringify(req),
    }),
  getDeployment: (jobId: string) =>
    http<DeploymentJobStatus>(`/api/deployments/${jobId}`),

  // SSE doesn't accept custom headers in the browser API, so we pass the
  // bearer token as a query-string parameter. The backend reads it as a
  // fallback when the Authorization header is absent.
  async streamLogs(jobId: string, onLine: (line: string) => void, onEnd: () => void) {
    const token = await getAccessToken();
    const es = new EventSource(
      `/api/deployments/${jobId}/logs?access_token=${encodeURIComponent(token)}`,
    );
    es.onmessage = (ev) => onLine(ev.data);
    es.addEventListener("end", () => {
      es.close();
      onEnd();
    });
    es.onerror = () => {
      es.close();
      onEnd();
    };
    return () => es.close();
  },
};
