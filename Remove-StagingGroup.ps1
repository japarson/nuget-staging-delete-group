[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GroupId
)

$ErrorActionPreference = 'Stop'
$uri = 'https://www.nuget.org/api/v3/staging/groups/' + [Uri]::EscapeDataString($GroupId)
$secureKey = Read-Host 'API key owned by the staging organization, with staging permission for every package in the group' -AsSecureString
$headers = @{ 'X-NuGet-ApiKey' = [System.Net.NetworkCredential]::new('', $secureKey).Password }

try {
    $preview = Invoke-RestMethod -Uri $uri -Headers $headers -MaximumRedirection 0
    $preview.group | Format-List
    Write-Warning 'This deletes the group and ALL its private staged parent and symbol packages. Published versions are preserved.'
    if ((Read-Host "Type DELETE $GroupId to confirm") -cne "DELETE $GroupId") {
        throw 'Deletion cancelled. No DELETE request was sent.'
    }

    $response = Invoke-WebRequest -Uri $uri -Method Delete -Headers $headers -MaximumRedirection 0 -UseBasicParsing
    if ([int]$response.StatusCode -ne 204) {
        throw "Unexpected HTTP status: $($response.StatusCode)"
    }

    Write-Output 'HTTP 204: staging group deleted.'
}
finally {
    $headers.Clear()
    $secureKey.Dispose()
}
