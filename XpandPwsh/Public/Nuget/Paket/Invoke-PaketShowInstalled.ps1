
function Invoke-PaketShowInstalled {
    [CmdletBinding()]
    param (
        [parameter(ParameterSetName="Project")]
        [string]$Project,
        [switch]$OnlyDirect
    )
    
    begin {
        
    }
    
    process {
        (Get-PaketDependenciesPath -strict)|ForEach-Object{
            Write-Host "DependencyFile: $($_.FullName)" -f Blue
            $xtraArgs = @( );
            if (!$OnlyDirect) {
                $xtraArgs += "--all"
            }
            Push-Location (Get-Item $_).DirectoryName
            $pakets=Invoke-Script {
                if ($Project){
                    dotnet paket show-installed-packages --project $Project --silent @xtraArgs
                }
                else{
                    dotnet paket show-installed-packages @xtraArgs
                }
            }
            Pop-Location
            $pakets| ForEach-Object {
                $parts = $_.split(" ")
                [PSCustomObject]@{
                    Group   = $parts[0]
                    Id      = $parts[1]
                    Version = $parts[3]
                }
            }
        }
        
    }
    
    end {
        
    }
}

function Invoke-PaketCommand {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Script
    )
    & $Script
    Approve-LastExitCode
}