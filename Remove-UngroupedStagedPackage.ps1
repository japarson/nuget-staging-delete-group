[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageId,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [switch]$Symbols
)

$ErrorActionPreference = 'Stop'
$kind = 'package'
if ($Symbols) {
    $kind = 'symbols'
}

$uri = 'https://www.nuget.org/api/v3/staging/' + $kind + '/' + [Uri]::EscapeDataString($PackageId) + '/' + [Uri]::EscapeDataString($Version)
$secureKey = Read-Host 'API key for the staging owner, with staging permission for this package' -AsSecureString
$headers = @{ 'X-NuGet-ApiKey' = [System.Net.NetworkCredential]::new('', $secureKey).Password }

try {
    $preview = Invoke-RestMethod -Uri ($uri + '/status') -Headers $headers -MaximumRedirection 0
    if ($preview.id -ine $PackageId -or $preview.version -ine $Version -or $preview.kind -ne $kind) {
        throw 'Unexpected status response. Check the package ID and normalized version.'
    }
    if ($null -ne $preview.group) {
        throw 'This package belongs to a staging group. This script only deletes ungrouped artifacts.'
    }

    $preview | Select-Object id, version, kind, status | Format-List
    Write-Warning 'Only this private staged artifact will be deleted. Published versions are preserved.'
    if (-not $Symbols) {
        Write-Warning 'Any staged symbols are retained in Waiting for parent. Use -Symbols separately to delete them.'
    }
    if ((Read-Host "Type DELETE $PackageId/$Version to confirm") -cne "DELETE $PackageId/$Version") {
        throw 'Deletion cancelled. No DELETE request was sent.'
    }

    $response = Invoke-WebRequest -Uri $uri -Method Delete -Headers $headers -MaximumRedirection 0 -UseBasicParsing
    if ([int]$response.StatusCode -ne 204) {
        throw "Unexpected HTTP status: $($response.StatusCode)"
    }

    Write-Output "HTTP 204: deleted staged $kind $PackageId/$Version."
}
finally {
    $headers.Clear()
    $secureKey.Dispose()
}
