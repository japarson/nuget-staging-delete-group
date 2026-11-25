[CmdletBinding()]
param(
    [string]$GroupId
)

$ErrorActionPreference = 'Stop'
$stagingUri = 'https://www.nuget.org/api/v3/staging'
$pageSize = 500
if ([string]::IsNullOrEmpty($env:NUGET_API_KEY)) {
    $secureKey = Read-Host 'API key for the staging owner, with permission to view staged packages and symbols' -AsSecureString
}
else {
    $secureKey = ConvertTo-SecureString -String $env:NUGET_API_KEY -AsPlainText -Force
}
$headers = @{ 'X-NuGet-ApiKey' = [System.Net.NetworkCredential]::new('', $secureKey).Password }

function Get-StagedArtifacts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    $page = 1
    $artifacts = [System.Collections.Generic.List[object]]::new()
    do {
        $pageUri = $Uri + '?page=' + $page + '&pageSize=' + $pageSize
        $response = Invoke-RestMethod -Uri $pageUri -Headers $Headers -MaximumRedirection 0
        if ($null -eq $response -or
            $null -eq $response.PSObject.Properties['items'] -or
            $null -eq $response.PSObject.Properties['page'] -or
            $null -eq $response.PSObject.Properties['pageSize'] -or
            $null -eq $response.PSObject.Properties['totalCount']) {
            throw 'Unexpected response when listing staged artifacts.'
        }

        $pageItems = @($response.items)
        if ([int]$response.page -ne $page -or [int]$response.pageSize -ne $pageSize) {
            throw 'Unexpected pagination values when listing staged artifacts.'
        }

        foreach ($item in $pageItems) {
            $artifacts.Add($item)
        }

        $totalCount = [int]$response.totalCount
        if ($totalCount -lt 0) {
            throw 'Unexpected total artifact count when listing staged artifacts.'
        }
        if ($artifacts.Count -lt $totalCount -and $pageItems.Count -eq 0) {
            throw 'The staging API returned an empty page before all artifacts were listed.'
        }

        $page++
    } while ($artifacts.Count -lt $totalCount)

    $artifacts.ToArray()
}

try {
    if ([string]::IsNullOrEmpty($GroupId)) {
        $packages = @(Get-StagedArtifacts -Uri ($stagingUri + '/package') -Headers $headers)
        $symbols = @(Get-StagedArtifacts -Uri ($stagingUri + '/symbols') -Headers $headers)
        $artifacts = @($packages) + @($symbols)
        if ($artifacts.Count -eq 0) {
            Write-Output 'No ungrouped staged packages or symbols found.'
            return
        }
    }
    else {
        $groupUri = $stagingUri + '/groups/' + [Uri]::EscapeDataString($GroupId)
        $artifacts = @(Get-StagedArtifacts -Uri $groupUri -Headers $headers)
        if ($artifacts.Count -eq 0) {
            Write-Output "No staged packages or symbols found in group '$GroupId'."
            return
        }
    }

    $artifacts
}
finally {
    $headers.Clear()
    $secureKey.Dispose()
}
