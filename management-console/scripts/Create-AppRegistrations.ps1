<#
.SYNOPSIS
    Creates Entra ID (Azure AD) app registrations for the SMB RF management
    console: an API app and a SPA (React) app, with the SPA preauthorized to
    call the API's access_as_user delegated scope.

.DESCRIPTION
    Uses az CLI (az ad app ...) so no Microsoft Graph PowerShell module is
    required. Idempotent: if apps with the same display names already exist
    they are reused and updated.

    After running, the script writes user-secrets into the AppHost project so
    `dotnet run` picks them up automatically.

.PARAMETER TenantId
    Target Entra tenant (GUID or domain). Defaults to the current az CLI tenant.

.PARAMETER ApiAppName
    Display name for the API app registration.

.PARAMETER SpaAppName
    Display name for the SPA app registration.

.PARAMETER SpaRedirectUri
    Redirect URI registered on the SPA. Match your Vite dev server.

.PARAMETER Owner
    Optional UPN to add as an app owner on both registrations.

.PARAMETER WriteUserSecrets
    When set, writes Entra settings into user-secrets for the AppHost.

.EXAMPLE
    ./Create-AppRegistrations.ps1 -Owner alice@contoso.com -WriteUserSecrets
#>
[CmdletBinding()]
param(
    [string]$TenantId,
    [string]$ApiAppName = 'smb-rf-console-api',
    [string]$SpaAppName = 'smb-rf-console-spa',
    [string[]]$SpaRedirectUri = @('http://localhost:5173', 'https://localhost:5173'),
    [string]$Owner,
    [switch]$WriteUserSecrets
)

$ErrorActionPreference = 'Stop'

function Require-Command($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Required command not found on PATH: $name"
    }
}

Require-Command 'az'

# Ensure logged in ---------------------------------------------------------
$account = az account show --only-show-errors 2>$null | ConvertFrom-Json
if (-not $account) {
    throw "Run 'az login' first (and 'az login --tenant <id>' for cross-tenant)."
}
if ($TenantId) {
    az account set --subscription $account.id --only-show-errors | Out-Null
    if ($account.tenantId -ne $TenantId) {
        Write-Warning "Current az session tenant ($($account.tenantId)) != requested $TenantId. Run 'az login --tenant $TenantId' first."
    }
} else {
    $TenantId = $account.tenantId
}

Write-Host "Tenant: $TenantId" -ForegroundColor Cyan
Write-Host "Signed-in as: $($account.user.name)" -ForegroundColor Cyan

$scopeId = [guid]::NewGuid().ToString()
$scopeName = 'access_as_user'

# --- API app --------------------------------------------------------------
Write-Host "`n=== API app: $ApiAppName ===" -ForegroundColor Green
$apiApp = az ad app list --display-name $ApiAppName --only-show-errors | ConvertFrom-Json | Select-Object -First 1
if (-not $apiApp) {
    Write-Host "Creating API app..."
    $apiApp = az ad app create `
        --display-name $ApiAppName `
        --sign-in-audience AzureADMyOrg `
        --only-show-errors | ConvertFrom-Json
} else {
    Write-Host "Reusing existing API app $($apiApp.appId)"
    # Preserve existing scope id so preauth grants remain valid.
    $existingScope = $apiApp.api.oauth2PermissionScopes | Where-Object { $_.value -eq $scopeName } | Select-Object -First 1
    if ($existingScope) { $scopeId = $existingScope.id }
}

$apiAppId = $apiApp.appId
$apiObjectId = $apiApp.id
$apiIdentifierUri = "api://$apiAppId"

# Set identifier URI (idempotent) ------------------------------------------
az ad app update --id $apiObjectId --identifier-uris $apiIdentifierUri --only-show-errors | Out-Null

# Publish the delegated scope via Graph PATCH ------------------------------
$apiManifest = [ordered]@{
    api = [ordered]@{
        requestedAccessTokenVersion = 2
        oauth2PermissionScopes      = @(
            [ordered]@{
                id                      = $scopeId
                adminConsentDescription = 'Allows the app to call the SMB RF console API on behalf of the signed-in user.'
                adminConsentDisplayName = 'Access SMB RF Console API'
                userConsentDescription  = 'Allow this app to call the SMB RF console API on your behalf.'
                userConsentDisplayName  = 'Access SMB RF Console API'
                isEnabled               = $true
                type                    = 'User'
                value                   = $scopeName
            }
        )
    }
} | ConvertTo-Json -Depth 6 -Compress

$tmp = New-TemporaryFile
try {
    Set-Content -Path $tmp -Value $apiManifest -NoNewline
    az rest --method PATCH `
        --url "https://graph.microsoft.com/v1.0/applications/$apiObjectId" `
        --headers 'Content-Type=application/json' `
        --body "@$tmp" --only-show-errors | Out-Null
} finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
}

# Ensure a service principal exists so tokens can be issued for the API ----
$apiSp = az ad sp list --filter "appId eq '$apiAppId'" --only-show-errors | ConvertFrom-Json | Select-Object -First 1
if (-not $apiSp) {
    az ad sp create --id $apiAppId --only-show-errors | Out-Null
}

if ($Owner) {
    $ownerObj = az ad user show --id $Owner --only-show-errors 2>$null | ConvertFrom-Json
    if ($ownerObj) {
        az ad app owner add --id $apiObjectId --owner-object-id $ownerObj.id --only-show-errors 2>$null | Out-Null
    }
}

# --- SPA app --------------------------------------------------------------
Write-Host "`n=== SPA app: $SpaAppName ===" -ForegroundColor Green
$spaApp = az ad app list --display-name $SpaAppName --only-show-errors | ConvertFrom-Json | Select-Object -First 1
if (-not $spaApp) {
    Write-Host "Creating SPA app..."
    $spaApp = az ad app create `
        --display-name $SpaAppName `
        --sign-in-audience AzureADMyOrg `
        --only-show-errors | ConvertFrom-Json
} else {
    Write-Host "Reusing existing SPA app $($spaApp.appId)"
}

$spaAppId = $spaApp.appId
$spaObjectId = $spaApp.id

# Configure the SPA redirect URIs + required API permission + pre-auth ----
$spaManifest = [ordered]@{
    spa                 = [ordered]@{ redirectUris = @($SpaRedirectUri) }
    web                 = [ordered]@{ redirectUris = @() }
    publicClient        = [ordered]@{ redirectUris = @() }
    requiredResourceAccess = @(
        [ordered]@{
            resourceAppId  = $apiAppId
            resourceAccess = @(
                [ordered]@{ id = $scopeId; type = 'Scope' }
            )
        }
    )
} | ConvertTo-Json -Depth 6 -Compress

$tmp2 = New-TemporaryFile
try {
    Set-Content -Path $tmp2 -Value $spaManifest -NoNewline
    az rest --method PATCH `
        --url "https://graph.microsoft.com/v1.0/applications/$spaObjectId" `
        --headers 'Content-Type=application/json' `
        --body "@$tmp2" --only-show-errors | Out-Null
} finally {
    Remove-Item $tmp2 -Force -ErrorAction SilentlyContinue
}

# Preauthorize the SPA against the API scope (skip the user consent prompt).
$preAuthManifest = [ordered]@{
    api = [ordered]@{
        requestedAccessTokenVersion = 2
        oauth2PermissionScopes      = @(
            [ordered]@{
                id                      = $scopeId
                adminConsentDescription = 'Allows the app to call the SMB RF console API on behalf of the signed-in user.'
                adminConsentDisplayName = 'Access SMB RF Console API'
                userConsentDescription  = 'Allow this app to call the SMB RF console API on your behalf.'
                userConsentDisplayName  = 'Access SMB RF Console API'
                isEnabled               = $true
                type                    = 'User'
                value                   = $scopeName
            }
        )
        preAuthorizedApplications   = @(
            [ordered]@{ appId = $spaAppId; delegatedPermissionIds = @($scopeId) }
        )
    }
} | ConvertTo-Json -Depth 6 -Compress

$tmp3 = New-TemporaryFile
try {
    Set-Content -Path $tmp3 -Value $preAuthManifest -NoNewline
    az rest --method PATCH `
        --url "https://graph.microsoft.com/v1.0/applications/$apiObjectId" `
        --headers 'Content-Type=application/json' `
        --body "@$tmp3" --only-show-errors | Out-Null
} finally {
    Remove-Item $tmp3 -Force -ErrorAction SilentlyContinue
}

$spaSp = az ad sp list --filter "appId eq '$spaAppId'" --only-show-errors | ConvertFrom-Json | Select-Object -First 1
if (-not $spaSp) {
    az ad sp create --id $spaAppId --only-show-errors | Out-Null
}

if ($Owner) {
    $ownerObj = az ad user show --id $Owner --only-show-errors 2>$null | ConvertFrom-Json
    if ($ownerObj) {
        az ad app owner add --id $spaObjectId --owner-object-id $ownerObj.id --only-show-errors 2>$null | Out-Null
    }
}

# --- Output ---------------------------------------------------------------
$result = [ordered]@{
    TenantId    = $TenantId
    Api         = [ordered]@{
        AppName       = $ApiAppName
        ClientId      = $apiAppId
        IdentifierUri = $apiIdentifierUri
        Scope         = "$apiIdentifierUri/$scopeName"
        ScopeId       = $scopeId
    }
    Spa         = [ordered]@{
        AppName      = $SpaAppName
        ClientId     = $spaAppId
        RedirectUris = $SpaRedirectUri
    }
}

$outDir = Join-Path $PSScriptRoot '..' '.entra'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir 'app-registrations.json'
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $outFile -NoNewline
Write-Host "`nWrote $outFile" -ForegroundColor Green

Write-Host ""
Write-Host "Summary" -ForegroundColor Yellow
Write-Host "  Tenant            : $TenantId"
Write-Host "  API client id     : $apiAppId"
Write-Host "  API scope         : $($result.Api.Scope)"
Write-Host "  SPA client id     : $spaAppId"
Write-Host "  SPA redirect URIs : $($SpaRedirectUri -join ', ')"

if ($WriteUserSecrets) {
    Write-Host "`nWriting user-secrets on the AppHost..." -ForegroundColor Cyan
    $appHost = Resolve-Path (Join-Path $PSScriptRoot '..' 'src' 'ManagementConsole.AppHost')
    Push-Location $appHost
    try {
        dotnet user-secrets init --project . | Out-Null
        dotnet user-secrets set 'Entra:TenantId'      $TenantId | Out-Null
        dotnet user-secrets set 'Entra:Api:ClientId'  $apiAppId | Out-Null
        dotnet user-secrets set 'Entra:Api:Scope'     $result.Api.Scope | Out-Null
        dotnet user-secrets set 'Entra:Spa:ClientId'  $spaAppId | Out-Null
        Write-Host 'User-secrets updated.' -ForegroundColor Green
    } finally {
        Pop-Location
    }
} else {
    Write-Host "`nTo wire the AppHost, run:" -ForegroundColor Yellow
    Write-Host "  ./Create-AppRegistrations.ps1 -WriteUserSecrets"
    Write-Host "or set these manually in user-secrets on ManagementConsole.AppHost:"
    Write-Host "  Entra:TenantId     = $TenantId"
    Write-Host "  Entra:Api:ClientId = $apiAppId"
    Write-Host "  Entra:Api:Scope    = $($result.Api.Scope)"
    Write-Host "  Entra:Spa:ClientId = $spaAppId"
}
