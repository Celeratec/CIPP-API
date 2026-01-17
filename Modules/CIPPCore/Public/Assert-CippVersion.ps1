function Assert-CippVersion {
    <#
    .SYNOPSIS
    Compare the local version of CIPP with the latest version.

    .DESCRIPTION
    Retrieves the local version of CIPP and compares it with the latest version in GitHub.
    Also retrieves version information for all registered backend function apps.

    .PARAMETER CIPPVersion
    Local version of CIPP frontend

    #>
    Param($CIPPVersion)
    $APIVersion = (Get-Content 'version_latest.txt' -Raw).trim()

    $RemoteAPIVersion = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/KelvinTegelaar/CIPP-API/master/version_latest.txt').trim()
    $RemoteCIPPVersion = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/KelvinTegelaar/CIPP/main/public/version.json').version

    # Get all backend function app versions from the Version table
    $VersionTable = Get-CippTable -tablename 'Version'
    $AllVersions = Get-CIPPAzDataTableEntity @VersionTable -Filter "PartitionKey eq 'Version' and RowKey ne 'frontend'"
    
    # Build backend versions array with sync status
    $BackendVersions = @()
    $MainAppName = $env:WEBSITE_SITE_NAME
    
    foreach ($ver in $AllVersions) {
        $isOutOfSync = $false
        $isMainApp = ($ver.RowKey -eq $MainAppName)
        
        # Check if this version differs from the main API version
        if ($ver.Version -and $APIVersion) {
            try {
                $isOutOfSync = ([semver]$ver.Version -ne [semver]$APIVersion)
            } catch {
                $isOutOfSync = ($ver.Version -ne $APIVersion)
            }
        }
        
        # Determine friendly name
        $friendlyName = if ($isMainApp) {
            'Main API'
        } elseif ($ver.RowKey -match '-proc$') {
            'Processor'
        } elseif ($ver.RowKey -match '-standards$') {
            'Standards'
        } elseif ($ver.RowKey -match '-auditlog$') {
            'Audit Log'
        } elseif ($ver.RowKey -match '-usertasks$') {
            'User Tasks'
        } else {
            $ver.RowKey
        }
        
        $BackendVersions += [PSCustomObject]@{
            Name        = $ver.RowKey
            FriendlyName = $friendlyName
            Version     = $ver.Version
            IsMainApp   = $isMainApp
            OutOfSync   = $isOutOfSync
            LastUpdated = $ver.Timestamp
        }
    }
    
    # Sort: Main app first, then alphabetically by friendly name
    $BackendVersions = $BackendVersions | Sort-Object { -not $_.IsMainApp }, FriendlyName

    [PSCustomObject]@{
        LocalCIPPVersion     = $CIPPVersion
        RemoteCIPPVersion    = $RemoteCIPPVersion
        LocalCIPPAPIVersion  = $APIVersion
        RemoteCIPPAPIVersion = $RemoteAPIVersion
        OutOfDateCIPP        = ([semver]$RemoteCIPPVersion -gt [semver]$CIPPVersion)
        OutOfDateCIPPAPI     = ([semver]$RemoteAPIVersion -gt [semver]$APIVersion)
        BackendVersions      = @($BackendVersions)
    }
}
