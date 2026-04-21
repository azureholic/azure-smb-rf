import React from "react";
import ReactDOM from "react-dom/client";
import { MsalProvider } from "@azure/msal-react";
import { EventType } from "@azure/msal-browser";
import { App } from "./App";
import { msalInstance } from "./auth/msalConfig";
import "./styles.css";

// Required MSAL bootstrap: initialize, handle the redirect promise, then render.
await msalInstance.initialize();
const accounts = msalInstance.getAllAccounts();
if (accounts.length > 0 && !msalInstance.getActiveAccount()) {
  msalInstance.setActiveAccount(accounts[0]);
}
msalInstance.addEventCallback((event) => {
  if (event.eventType === EventType.LOGIN_SUCCESS && event.payload && "account" in event.payload) {
    msalInstance.setActiveAccount(event.payload.account);
  }
});
await msalInstance.handleRedirectPromise();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <MsalProvider instance={msalInstance}>
      <App />
    </MsalProvider>
  </React.StrictMode>,
);
