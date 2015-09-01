﻿$Script:ApiClient = $null
$Script:Debug = $false

function Initialize-TestRailSession
{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [Uri]
        $Uri,

        [Parameter(Mandatory=$true, Position=1)]
        [String]
        $User,

        [Parameter(Mandatory=$true, Position=2)]
        [Alias("ApiKey")]
        [String]
        $Password
    )

    $Script:ApiClient = New-Object Gurock.TestRail.APIClient -ArgumentList $Uri
    $Script:ApiClient.User = $User
    $Script:ApiClient.Password = $Password
}

function ConvertTo-UnixTimestamp
{
    param
    (
        [Parameter(Mandatory=$true)]
        [DateTime]
        $DateTime,

        [Parameter(Mandatory=$false)]
        [switch]
        $UTC
    )

    $Kind = [DateTimeKind]::Local

    if ( $UTC.IsPresent )
    {
        $Kind = [DateTimeKind]::Utc
    }

    [int](( $DateTime - (New-Object DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, $Kind) ).TotalSeconds)
}

function ConvertFrom-UnixTimestamp
{
    param
    (
        [Parameter(Mandatory=$true, ParameterSetName="Timestamp")]
        [int]
        $Timestamp,

        [Parameter(Mandatory=$true, ParameterSetName="TimestampMS")]
        [long]
        $TimestampMS,

        [Parameter(Mandatory=$false)]
        [switch]
        $UTC
    )

    $Kind = [DateTimeKind]::Local

    if ( $UTC.IsPresent )
    {
        $Kind = [DateTimeKind]::Utc
    }

    switch ( $PSCmdlet.ParameterSetName )
    {
        "Timestamp" {
            (New-Object DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, $Kind).AddSeconds($Timestamp)
        }

        "TimestampMS" {
            (New-Object DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, $Kind).AddMilliseconds($TimestampMS)
        }
    }
}

function Set-TestRailDebug
{
    param
    (
        [Parameter(Mandatory=$true)]
        [bool]
        $Enabled
    )

    $Script:Debug = $Enabled
}

function Get-TestRailDebug
{
    $Script:Debug
}

function Request-TestRailUri
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String]
        $Uri,

        [Parameter(Mandatory=$false)]
        [System.Collections.Specialized.NameValueCollection]
        $Parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    )

    if ( $Script:ApiClient -eq $null )
    {
        throw New-Object Exception -ArgumentList "You must call Initialize-TestRailSession first"
    }

    $RealUri = $Uri
    if ( -not [String]::IsNullOrEmpty($Parameters.ToString()) )
    {
        $RealUri += [String]::Format("&{0}", $Parameters.ToString())
    }

    if ( $Script:Debug -eq $true )
    {
        Write-Warning ([String]::Format("Uri: [{0}]", $RealUri))
    }

    $Result = $Script:ApiClient.SendGet($RealUri)

    New-ObjectHash -Object $Result
}

function Submit-TestRailUri
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String]
        $Uri,

        [Parameter(Mandatory=$false)]
        [HashTable]
        $Parameters = @{}
    )

    if ( $Script:ApiClient -eq $null )
    {
        throw New-Object Exception -ArgumentList "You must call Initialize-TestRailSession first"
    }

    $Result = $Script:ApiClient.SendPost($Uri, $Parameters)

    New-ObjectHash -Object $Result
}

function Add-UriParameters
{
    param (
        [Parameter(Mandatory=$true)]
        [System.Collections.Specialized.NameValueCollection]
        $Parameters,
        
        [Parameter(Mandatory=$true)]
        [HashTable]
        $Hash
    )

    if ( $Parameters -eq $null )
    {
        $Parameters = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    }

    $Hash.Keys |% {
        $Key = $_;

        if ( $Hash.$_ -is [Array] )
            { $Key = $_; $Hash.$Key |% { $Parameters.Add( $Key, $_ ) } }
        else
            { $Parameters.Add( $Key, $Hash.$Key ) }
    }
}

function Get-TestRailApiClient
{
    $Script:ApiClient
}

function New-ObjectHash
{
    param
    (
        [Parameter(Mandatory=$true)]
        [object]
        $Object
    )

    if ( $Object -is [Newtonsoft.Json.Linq.JArray] )
    {
        $Object |% { New-ObjectHash -Object $_ }
    }
    elseif ( $Object -is [Newtonsoft.Json.Linq.JObject] )
    {
        $Hash = New-Object PSObject
        $Object.Properties() |% { Add-Member -InputObject $Hash -MemberType NoteProperty -Name $_.Name -Value $_.Value.ToString() -PassThru:$false }
        $Hash
    }
    else
    {
        throw New-Object ArgumentException -ArgumentList ("Object must be a JObject or JArray but it is a " + $Object.GetType().Name)
    }
}