<#
    THIS CODE REQUIRES POWWERSHELL 7.x.(latest)
    https://github.com/PowerShell/PowerShell/releases/tag/v7.3.4
#>

$global:AuthObject = $null

function connect-restapi {
    [CmdletBinding()]
    param ()
    begin {
        # CHECK TO SEE IF OAUTH2 CREDS FILE EXISTS IF NOT CREATE ONE
        $exists = Test-Path -Path ".\oauth2.xml" -PathType Leaf
        if($exists) {
            $oauth2 = Import-CliXml ".\oauth2.xml"
        } else {
            $oauth2 = Get-Credential -Message "Please specify your oauth2 credentials."
            $oauth2 | Export-CliXml ".\oauth2.xml"
        }

        # BASE64 ENCODE USERNAME AND PASSWORD AND CREATE THE REQUEST BODY
        $base64AuthInfo = [Convert]::ToBase64String(
            [Text.Encoding]::ASCII.GetBytes(
                (
                    "{0}:{1}" -f $oauth2.username,
                    (ConvertFrom-SecureString -SecureString $oauth2.password -AsPlainText)
                )
            )
        )
        $body = "grant_type=client_credentials&scope=read" 
    }
    process {
        #AUTHENTICATE TO THE AVAMAR API 
        $auth = Invoke-RestMethod `
        -Uri "https://apis-us0.druva.com/token" `
        -Method POST `
        -ContentType 'application/x-www-form-urlencoded' `
        -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} `
        -Body $body `
        -SkipCertificateCheck

        #BUILD THE AUTHOBJECT FOR SUBESEQUENT REST API CALLS
        $object = @{
            server ="https://apis-us0.druva.com/phoenix"
            token= @{
                authorization="Bearer $($auth.access_token)"
            } #END TOKEN
        } # END

        # SET THE AUTHOBJECT VALUES
        $global:AuthObject = $object
        $global:AuthObject | Format-List
    }
}

function get-org {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$false)]
        [string]$Org
    )
    begin {}
    process {
         # GET CONFIGURED ORGS
         $Endpoint = "organization/v1/orgs"
         $Query = Invoke-RestMethod `
         -Uri "$($AuthObject.server)/$($Endpoint)" `
         -Method GET `
         -ContentType 'application/json' `
         -Headers ($AuthObject.token) `
         -SkipCertificateCheck
         
         # RETURN THE DESIRED ORG
         return $Query.orgs | where-object {$_.organizationName -eq $Org};
    }
}

function get-backupjobs {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [int]$Org,
        [Parameter( Mandatory=$false)]
        [array]$Filters

    )
    begin {}
    process {
        $Results = @()
        # GET CONFIGURED ORGS
        $Endpoint = "vmware/v1/orgs/$($Org)/reports/jobs/backups"
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join '&') -replace '\s','%20' -replace '"','%22'
            $Uri = "$($Endpoint)?$($Join)"
        }
        
        Write-Host "[APEX]: $($Uri)" -ForegroundColor Yellow
        # INITIAL QUERY
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/$($Uri)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        $Results += $Query.jobs

        if($Query.nextPageToken -ne "") {
            # MULTIPLE PAGES, CAPTURE RESULTS
            # REBUILD THE QUERY PARAMS WITHOUT DATE PARAMS
            [array]$Temp = @()
            $Filters | foreach-object {
                if($_ -notmatch '\w{2,4}Time') {
                    $Temp += $_
                }
            }
            
            $PageNo = 1
            do {

                if($PageNo -eq 1) {
                    $Token = $Query.nextPageToken
                } else {
                    $Token = $Page.nextPageToken
                }
                
                [array]$Uri = $Temp
                # ADD IN THE NEXT PAGE TOKEN
                $Uri += "pageToken=$($Token)"
                # ADD IN THE DATE PARAMS
                $Filters | foreach-object {
                    if($_ -match '\w{2,4}Time') {
                        $Uri += $_
                    }
                }

                Write-Host "[APEX]: $(($Uri -join '&') -replace '\s','%20' -replace '"','%22')"
                $Page = Invoke-RestMethod `
                -Uri "$($AuthObject.server)/$($Endpoint)?$(($Uri -join '&') -replace '\s','%20' -replace '"','%22')" `
                -Method GET `
                -ContentType 'application/json' `
                -Headers ($AuthObject.token) `
                -SkipCertificateCheck
                $Results += $Page.jobs
                $PageNo ++
                
            } until($Page.nextPageToken -eq "")

        }
        
        # RETURN THE RESULTS
        return $Results
    }
}

function get-alerts {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [int]$Org,
        [Parameter( Mandatory=$false)]
        [array]$Filters

    )
    begin {}
    process {
        $Results = @()
        # GET CONFIGURED ORGS
        $Endpoint = "alerts/v1/orgs/$($Org)/alerts/jobs/backupFailures"
        if($Filters.Length -gt 0) {
            $Join = ($Filters -join '&') -replace '\s','%20' -replace '"','%22'
            $Uri = "$($Endpoint)?$($Join)"
        }
        
        Write-Host "[APEX]: $($Uri)" -ForegroundColor Yellow
        # INITIAL QUERY
        $Query = Invoke-RestMethod `
        -Uri "$($AuthObject.server)/$($Uri)" `
        -Method GET `
        -ContentType 'application/json' `
        -Headers ($AuthObject.token) `
        -SkipCertificateCheck
        $Results = $Query.alerts 
        
        if($Query.nextPageToken -ne "") {
            # MULTIPLE PAGES, CAPTURE RESULTS
            # REBUILD THE QUERY PARAMS WITHOUT DATE PARAMS
            [array]$Temp = @()
            $Filters | foreach-object {
                if($_ -notmatch '\w{3}GeneratedOn') {
                    $Temp += $_
                }
            }
            $PageNo = 1
            do {
 
                if($PageNo -eq 1) {
                    $Token = $Query.nextPageToken
                } else {
                    $Token = $Page.nextPageToken
                }

                [array]$Uri = $Temp
                # ADD IN THE NEXT PAGE TOKEN
                $Uri += "pageToken=$($Token)"
                # ADD IN THE DATE PARAMS
                $Filters | foreach-object {
                    if($_ -match '\w{3}GeneratedOn') {
                        $Uri += $_
                    }
                }

                $Page = Invoke-RestMethod `
                -Uri "$($AuthObject.server)/$($Endpoint)?$(($Uri -join '&') -replace '\s','%20' -replace '"','%22')" `
                -Method GET `
                -ContentType 'application/json' `
                -Headers ($AuthObject.token) `
                -SkipCertificateCheck
                $Results += $Page.alerts
                $PageNo ++

            } until($Page.nextPageToken -eq "")

        }
        
        # RETURN THE RESULTS
        return $Results
    }
}