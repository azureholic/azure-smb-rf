import { PublicClientApplication, type Configuration } from "@azure/msal-browser";

const tenantId = import.meta.env.VITE_ENTRA_TENANT_ID as string | undefined;
const clientId = import.meta.env.VITE_ENTRA_SPA_CLIENT_ID as string | undefined;
const apiScope = import.meta.env.VITE_ENTRA_API_SCOPE as string | undefined;

if (!tenantId || !clientId || !apiScope) {
  // eslint-disable-next-line no-console
  console.error(
    "Missing VITE_ENTRA_* env vars. Run scripts/Create-AppRegistrations.ps1 -WriteUserSecrets and restart the AppHost.",
  );
}

const msalConfig: Configuration = {
  auth: {
    clientId: clientId ?? "",
    authority: `https://login.microsoftonline.com/${tenantId ?? "common"}`,
    redirectUri: window.location.origin,
    postLogoutRedirectUri: window.location.origin,
    navigateToLoginRequestUrl: true,
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false,
  },
};

export const msalInstance = new PublicClientApplication(msalConfig);

export const loginRequest = {
  scopes: apiScope ? [apiScope] : [],
};

export const apiTokenRequest = {
  scopes: apiScope ? [apiScope] : [],
};
