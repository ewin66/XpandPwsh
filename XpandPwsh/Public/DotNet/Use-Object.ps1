function Use-Object {
    [CmdletBinding()]
    param (
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [AllowNull()]
        [Object]$InputObject,
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )   
    $killDomain
    try {
        . $ScriptBlock
    }
    catch {
        throw 
    }
    finally {
        if ($null -ne $InputObject -and $InputObject -is [System.IDisposable]) {
            $InputObject.Dispose()
        }
    }
}