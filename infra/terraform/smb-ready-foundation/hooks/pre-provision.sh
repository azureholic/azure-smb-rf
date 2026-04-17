#!/usr/bin/env bash
# =============================================================================
# SMB Ready Foundation — Terraform pre-provision hook
# =============================================================================
# Runs before `azd provision`. Jobs:
#   1. Parameter validation (owner, CIDRs)
#   2. Azure preflight (auth, required RPs)
#   3. Enable azd alpha.terraform (idempotent)
#   4. Bootstrap the state backend (calls scripts/bootstrap-tf-backend.sh)
#   5. Write terraform.auto.tfvars.json from azd env (incl. budget_start_date
#      pinned to first-of-month UTC to avoid azurerm time drift)
#   6. Delete any stale budget with the same name (Azure API limitation —
#      cannot update start_date post-creation)
#   7. Clean faulted firewall / VPN Gateway from prior failed runs
#   8. terraform init -reconfigure with the bootstrapped backend
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IAC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=./_lib.sh
. "$SCRIPT_DIR/_lib.sh"

# ---- env resolution ----------------------------------------------------------
SCENARIO="${SCENARIO:-baseline}"
OWNER="${OWNER:-}"
AZURE_LOCATION="${AZURE_LOCATION:-swedencentral}"
ENVIRONMENT_NAME="${ENVIRONMENT:-prod}"   # TF variable is `environment`
HUB_CIDR="${HUB_VNET_ADDRESS_SPACE:-10.0.0.0/23}"
SPOKE_CIDR="${SPOKE_VNET_ADDRESS_SPACE:-10.0.2.0/23}"
ON_PREM_CIDR="${ON_PREMISES_ADDRESS_SPACE:-}"
LAW_CAP="${LOG_ANALYTICS_DAILY_CAP_GB:-0.5}"
BUDGET_AMOUNT="${BUDGET_AMOUNT:-100}"
BUDGET_ALERT_EMAIL="${BUDGET_ALERT_EMAIL:-}"

eval "$(resolve_scenario_flags "$SCENARIO")"

printf '\n========================================\n'
printf '  SMB Ready Foundation (Terraform) — Pre-Provision\n'
printf '  Scenario: %s\n' "$SCENARIO"
printf '========================================\n\n'

# ---- 1. Parameter validation -------------------------------------------------
log_step 1 'Validating parameters'
if [[ -z "$OWNER" ]]; then
  OWNER="$(az ad signed-in-user show --query mail -o tsv 2>/dev/null || true)"
  [[ -z "$OWNER" ]] && OWNER="$(az ad signed-in-user show --query userPrincipalName -o tsv 2>/dev/null || true)"
  if [[ -z "$OWNER" ]]; then
    log_error "OWNER not set and could not auto-detect. Run: azd env set OWNER your@email.com"
    exit 1
  fi
  log_substep "Auto-detected owner: $OWNER"
fi

if [[ "$DEPLOY_VPN" == "true" && -z "$ON_PREM_CIDR" ]]; then
  log_error "ON_PREMISES_ADDRESS_SPACE required for VPN scenarios. Run: azd env set ON_PREMISES_ADDRESS_SPACE 192.168.0.0/16"
  exit 1
fi

# ---- 2. CIDR validation ------------------------------------------------------
log_step 2 'Validating CIDR address spaces'
is_valid_cidr "$HUB_CIDR"   || { log_error "Invalid hub CIDR: $HUB_CIDR"; exit 1; }
is_valid_cidr "$SPOKE_CIDR" || { log_error "Invalid spoke CIDR: $SPOKE_CIDR"; exit 1; }
if cidr_overlaps "$HUB_CIDR" "$SPOKE_CIDR"; then
  log_error "Hub ($HUB_CIDR) and spoke ($SPOKE_CIDR) overlap"; exit 1
fi
if [[ -n "$ON_PREM_CIDR" ]]; then
  is_valid_cidr "$ON_PREM_CIDR" || { log_error "Invalid on-prem CIDR: $ON_PREM_CIDR"; exit 1; }
  cidr_overlaps "$HUB_CIDR"   "$ON_PREM_CIDR" && { log_error "Hub and on-prem overlap"; exit 1; }
  cidr_overlaps "$SPOKE_CIDR" "$ON_PREM_CIDR" && { log_error "Spoke and on-prem overlap"; exit 1; }
fi
log_substep 'All CIDRs valid and non-overlapping'

# ---- 3. Azure preflight ------------------------------------------------------
log_step 3 'Azure preflight'
SUB_ID="$(az account show --query id -o tsv 2>/dev/null || true)"
[[ -z "$SUB_ID" ]] && { log_error 'Not authenticated. Run: az login'; exit 1; }
log_substep "Subscription: $SUB_ID"

for rp in Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.KeyVault \
          Microsoft.OperationalInsights Microsoft.RecoveryServices Microsoft.Automation \
          Microsoft.Insights Microsoft.Authorization Microsoft.Management \
          Microsoft.PolicyInsights Microsoft.Migrate Microsoft.Security Microsoft.Consumption; do
  state="$(az provider show -n "$rp" --query registrationState -o tsv 2>/dev/null || echo NotRegistered)"
  if [[ "$state" != "Registered" ]]; then
    log_substep "Registering $rp (state: $state)..."
    az provider register -n "$rp" --wait >/dev/null || true
  fi
done

# ---- 4. Enable azd alpha.terraform ------------------------------------------
log_step 4 'Enabling azd alpha.terraform feature'
azd config set alpha.terraform on >/dev/null

# ---- 5. Bootstrap state backend ---------------------------------------------
log_step 5 'Bootstrapping Terraform state backend'
AZURE_LOCATION="$AZURE_LOCATION" AZURE_ENV_NAME="${AZURE_ENV_NAME:-smb-ready-foundation}" \
  bash "$IAC_DIR/scripts/bootstrap-tf-backend.sh"

# ---- 6. Write auto.tfvars.json ----------------------------------------------
log_step 6 'Writing terraform.auto.tfvars.json'
BUDGET_START_DATE="$(date -u +%Y-%m-01)"

# Build allowed_vm_skus JSON array from azd env if set (comma-separated).
if [[ -n "${ALLOWED_VM_SKUS:-}" ]]; then
  ALLOWED_VM_SKUS_JSON="$(printf '%s' "$ALLOWED_VM_SKUS" | awk -v RS=, 'BEGIN{printf "["} NR>1{printf ","} {gsub(/[[:space:]]/,""); printf "\"%s\"", $0} END{printf "]"}')"
else
  ALLOWED_VM_SKUS_JSON='null'  # Terraform uses the variable default.
fi

cat > "$IAC_DIR/terraform.auto.tfvars.json" <<JSON
{
  "subscription_id": "$SUB_ID",
  "location": "$AZURE_LOCATION",
  "environment": "$ENVIRONMENT_NAME",
  "owner": "$OWNER",
  "hub_vnet_address_space": "$HUB_CIDR",
  "spoke_vnet_address_space": "$SPOKE_CIDR",
  "on_premises_address_space": "$ON_PREM_CIDR",
  "log_analytics_daily_cap_gb": $LAW_CAP,
  "budget_amount": $BUDGET_AMOUNT,
  "budget_alert_email": "$BUDGET_ALERT_EMAIL",
  "budget_start_date": "$BUDGET_START_DATE",
  "deploy_firewall": $DEPLOY_FIREWALL,
  "deploy_vpn": $DEPLOY_VPN
}
JSON
log_substep "budget_start_date=$BUDGET_START_DATE, deploy_firewall=$DEPLOY_FIREWALL, deploy_vpn=$DEPLOY_VPN"

# ---- 7. Delete stale budget --------------------------------------------------
log_step 7 'Cleaning stale resources'
if az consumption budget show --budget-name 'budget-smb-monthly' >/dev/null 2>&1; then
  log_substep 'Deleting existing budget-smb-monthly (start_date is immutable)'
  az consumption budget delete --budget-name 'budget-smb-monthly' >/dev/null 2>&1 || true
else
  log_substep 'No stale budget'
fi

REGION_SHORT='swc'
[[ "$AZURE_LOCATION" == 'germanywestcentral' ]] && REGION_SHORT='gwc'
HUB_RG="rg-hub-smb-$REGION_SHORT"

if az group exists --name "$HUB_RG" 2>/dev/null | grep -q true; then
  FW_STATE="$(az network firewall show -g "$HUB_RG" -n "fw-hub-smb-$REGION_SHORT" --query provisioningState -o tsv 2>/dev/null || true)"
  if [[ "$FW_STATE" == 'Failed' ]]; then
    log_substep 'Deleting faulted firewall'
    az network firewall delete -g "$HUB_RG" -n "fw-hub-smb-$REGION_SHORT" >/dev/null 2>&1 || true
    az network firewall policy delete -g "$HUB_RG" -n "fwpol-hub-smb-$REGION_SHORT" >/dev/null 2>&1 || true
  fi
  VPN_STATE="$(az network vnet-gateway show -g "$HUB_RG" -n "vpng-hub-smb-$REGION_SHORT" --query provisioningState -o tsv 2>/dev/null || true)"
  if [[ "$VPN_STATE" == 'Failed' ]]; then
    log_substep 'Deleting faulted VPN gateway'
    az network vnet-gateway delete -g "$HUB_RG" -n "vpng-hub-smb-$REGION_SHORT" --no-wait >/dev/null 2>&1 || true
  fi
fi

# ---- 8. terraform init with backend config ---------------------------------
log_step 8 'terraform init -reconfigure'
BACKEND_FILE="$IAC_DIR/.azure/${AZURE_ENV_NAME:-smb-ready-foundation}/backend.hcl"
(
  cd "$IAC_DIR"
  terraform init -reconfigure -backend-config="$BACKEND_FILE" -input=false >/dev/null
)
log_substep 'Ready for azd provision'

printf '\n==> Pre-provision complete.\n\n'
