param( 
    [string]$SourceSiteUrl,
    [string]$DestinationSiteUrl,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$Tenant
)

# Validate Parameters
if (-not $SourceSiteUrl -or -not $DestinationSiteUrl -or -not $ClientId -or -not $ClientSecret -or -not $Tenant) {
    Write-Error "One or more required parameters are missing. Please provide SourceSiteUrl, DestinationSiteUrl, ClientId, ClientSecret, and Tenant."
    exit 1
}

# Debug Parameters
Write-Host "Source Site URL: $SourceSiteUrl"
Write-Host "Destination Site URL: $DestinationSiteUrl"
Write-Host "Client ID: $ClientId"
Write-Host "Tenant: $Tenant"

# Import PnP PowerShell Module
Import-Module "PnP.PowerShell" -ErrorAction Stop

# Authenticate Function
function Authenticate-Site {
    param (
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$Tenant
    )
    try {
        Write-Host "Authenticating..." -ForegroundColor Yellow
        $SecureClientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        Connect-PnPOnline -ClientId $ClientId -ClientSecret $SecureClientSecret -Tenant $Tenant
        Write-Host "Authentication successful!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to authenticate. Error: $_"
        exit 1
    }
}

# Authenticate to Source Site
Authenticate-Site -ClientId $ClientId -ClientSecret $ClientSecret -Tenant $Tenant
Connect-PnPOnline -Url $SourceSiteUrl
Write-Host "Connected to Source Site: $SourceSiteUrl" -ForegroundColor Green

# Get Source Lists
try {
    $sourceLists = Get-PnPList
    Write-Host "Fetched lists from Source Site" -ForegroundColor Green
} catch {
    Write-Error "Failed to fetch lists from Source Site. Error: $_"
    exit 1
}

# Authenticate to Destination Site
Connect-PnPOnline -Url $DestinationSiteUrl
Write-Host "Connected to Destination Site: $DestinationSiteUrl" -ForegroundColor Green

# Migrate Data
foreach ($list in $sourceLists) {
    Write-Host "Processing List: $($list.Title)" -ForegroundColor Cyan
    try {
        # Check if list exists in the destination site
        $destList = Get-PnPList -Identity $list.Title -ErrorAction SilentlyContinue
        if (-not $destList) {
            Write-Host "List '$($list.Title)' does not exist in the destination site. Skipping..." -ForegroundColor Yellow
            continue
        }

        $items = Get-PnPListItem -List $list.Title
        foreach ($item in $items) {
            # Add item to the destination list
            Add-PnPListItem -List $list.Title -Values $item.FieldValues
            Write-Host "Migrated item to list: $($list.Title)" -ForegroundColor Cyan
        }
    } catch {
        Write-Error "Failed to migrate data for list: $($list.Title). Error: $_"
    }
}

# Disconnect
if (Get-PnPConnection) {
    Disconnect-PnPOnline
    Write-Host "Disconnected from SharePoint" -ForegroundColor Green
} else {
    Write-Host "No active connection to disconnect."
}

Write-Host "Migration Completed Successfully!" -ForegroundColor Green
