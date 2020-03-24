[string[]]$global:pipelineTasksSet=@("ClearProjectDirectories","RemoveNugetImportTargets","RemoveProjectLicenseFile","RemoveProjectInvalidItems",
"UpdateProjectAutoGeneratedBindingRedirects","UpdateAppendTargetFrameworkToOutputPath","UpdateGeneratedAssemblyInfo","UpdateProjectTargetFramework",
"UpdateOutputPath","RemoveProjectReferences","UpdateAssemblyInfoVersion","UpdateProjectCopyRight","AddPackageReferenceNoWarning","UpdateProjectNoWarn",
"AddAssemblyBindingRedirects","SetProjectRestoreLockedMode")
function Start-PipelineTasks {
    [CmdletBinding()]
    [CmdLetTag(("#Azure","AzureDevOps"))]
    param (
        [parameter(Mandatory,ValueFromPipeline)]
        [System.IO.FileInfo]$ProjectFile,
        [ValidateScript({$_ -in $global:pipelineTasksSet})]
        [parameter()]
        [ArgumentCompleter({
            [OutputType([System.Management.Automation.CompletionResult])]  # zero to many
            param(
                [string] $CommandName,
                [string] $ParameterName,
                [string] $WordToComplete,
                [System.Management.Automation.Language.CommandAst] $CommandAst,
                [System.Collections.IDictionary] $FakeBoundParameters
            )
            $global:pipelineTasksSet
        })]
        [string[]]$Task=$global:pipelineTasksSet,
        [ValidateSet("4.5.2","4.6.1","4.7.1","4.7.2","4.8")]
        [string]$TargetFramework="4.7.2",
        [string]$OutputPath,
        [version]$AssemblyInfoVersion,
        [string]$CopyRight,
        [hashtable]$PackageReferenceNoWarning,
        [string[]]$ProjectNoWarning,
        [pscustomobject[]]$AssemblyBindingRedirectPackage
    )
    
    begin {
        $PSCmdlet|Write-PSCmdLetBegin
    }
    
    process {
        
        Invoke-Script{
            Push-Location $ProjectFile.DirectoryName
            Write-HostFormatted "Analyzing $($ProjectFile.BaseName)" -Section -ForegroundColor Yellow -Stream Verbose
            if ("ClearProjectDirectories" -in $Task){
                Clear-ProjectDirectories 
            }
            
            if ("RemoveNugetImportTargets" -in $Task){
                Remove-NugetImportsTargets $ProjectFile|Out-Null
            }
            
            
            if ("RemoveProjectLicenseFile" -in $Task){
                Remove-ProjectLicenseFile -FilePath $ProjectFile.FullName|Out-Null    
            }
            
            if ("RemoveProjectInvalidItems" -in $Task){
                Remove-ProjectInvalidItems $ProjectFile|Out-Null    
            }
    
            [xml]$project = Get-XmlContent $ProjectFile.FullName
            if ("UpdateProjectAutoGeneratedBindingRedirects" -in $Task){
                Update-ProjectAutoGenerateBindingRedirects $project $true    
            }
            
            if ("UpdateAppendTargetFrameworkToOutputPath" -in $Task){
                Update-AppendTargetFrameworkToOutputPath $project    
            }
            
            if ("UpdateGeneratedAssemblyInfo" -in $Task){
                Update-GenerateAssemblyInfo  $project
            }
            
            if ("UpdateProjectTargetFramework" -in $Task){
                Update-ProjectTargetFramework $TargetFramework $project
            }
            
            if ("UpdateOutputPath" -in $Task -and $OutputPath){
                Update-OutputPath $project $ProjectFile.FullName $OutputPath
            }
            
            if ("UpdateProjectCopyRight" -in $Task){
                Update-ProjectCopyRight $project $CopyRight 
            }
            if ("SetProjectRestoreLockedMode" -in $Task){
                Set-ProjectRestoreLockedMode $project
            }
            
            if ("AddPackageReferenceNoWarning" -in $Task -and $PackageReferenceNoWarning.Keys){
                $PackageReferenceNoWarning.Keys|ForEach-Object{
                    $noWarn=$PackageReferenceNoWarning[$_]
                    Add-PackageReferenceNoWarning $project $noWarn $_
                }
            }
            if ("UpdateProjectNoWarn" -in $Task -and $ProjectNoWarning){
                Update-ProjectNoWarn $project -NoWarn $ProjectNoWarning
            }

            $project | Save-Xml $ProjectFile.FullName|Out-Null
    
            if ("RemoveProjectReferences" -in $Task){
                Remove-ProjectReferences $ProjectFile.FullName -InvalidHintPath|Out-Null    
            }
            
            if ("AddAssemblyBindingRedirects" -in $Task -and $AssemblyBindingRedirectPackage){
                (Get-ChildItem $ProjectFile.DirectoryName)|Where-Object{
                    $name=$_.Name
                    "app*.config","Web*.config"|Where-Object{$name -like $_}
                }|ForEach-Object{
                    $AssemblyBindingRedirectPackage|Add-AssemblyBindingRedirect -ConfigFile $_ -PublicToken (Get-XpandPublicKeyToken)
                }
            }
            
            if ("UpdateAssemblyInfoVersion" -in $Task){
                Update-AssemblyInfoVersion $AssemblyInfoVersion "$($ProjectFile.DirectoryName)\Properties\AssemblyInfo.cs"    
            }
 
            
            Pop-Location
        }

    }
    
    end {
        
    }
}