<# 
PowerShell script that takes in a configuration file 
and executes the specified Postman collections using the Newman CLI
#>

param (
    [parameter(Mandatory = $true)] $PostmanAPIKey,
    [parameter(Mandatory = $false)] $PostmanSettingsFilePath = "Configuration/dev.postman_settings.json",
    [parameter(Mandatory = $false)] $DownloadDirectoryName = "Downloads"
)

# Get the PowerShell version
$powerShellVersion = $PSVersionTable.PSVersion
Write-Host "Running script using PowerShell version: $($powershellVersion)"

# Read the Postman settings file
Write-Host "Reading Postman settings from $($PostmanSettingsFilePath)"
$postmanSettings = Get-Content $PostmanSettingsFilePath | ConvertFrom-Json

# Download the environment to use for collections
$environmentFilePath = "$($DownloadDirectoryName)/environment.json"
Write-Host "Using environment: $($postmanSettings.environment.name)"

Invoke-WebRequest `
    -URI "https://api.getpostman.com/environments/$($postmanSettings.environment.UID)" `
    -Headers @{'X-Api-Key' = $PostmanAPIKey } `
    -OutFile $environmentFilePath

if ($powerShellVersion.Major -lt 9) {
    # Iterate through collection and run
    foreach ($collections in $postmanSettings.collections) {
        #execute sequential collections
        foreach ($sequentialCollection in $collections.collections) {
            Write-Host "Running collection: $($sequentialCollection.name)"

            $collectionFilePath = "$($DownloadDirectoryName)/$($sequentialCollection.name)_collection.json"
            $reportFilePath = "$($DownloadDirectoryName)/Reports/$($sequentialCollection.name)_JUnitReport.xml"

            Invoke-WebRequest `
                -URI "https://api.getpostman.com/collections/$($sequentialCollection.UID)" `
                -Headers @{'X-Api-Key' = $PostmanAPIKey } `
                -OutFile $collectionFilePath

            newman run $collectionFilePath `
                -e $environmentFilePath `
                -r 'cli,junitfull' `
                --reporter-junitfull-export $reportFilePath `
                --verbose
        }
    }
}
else {
    $postmanSettings.collections | ForEach-Object -Parallel { 
        #execute sequential collections
        foreach ($sequentialCollection in $_.collections) {
            $postmanApiKey = $using:PostmanAPIKey
            $downloadDirectoryName = $using:DownloadDirectoryName
            $environmentFilePath = $using:environmentFilePath

            Write-Host "Running collection: $($sequentialCollection.name)"
    
            $collectionFilePath = "$($downloadDirectoryName)/$($sequentialCollection.name)_collection.json"
            $reportFilePath = "$($downloadDirectoryName)/Reports/$($sequentialCollection.name)_JUnitReport.xml"
            
            Invoke-WebRequest `
                -URI "https://api.getpostman.com/collections/$($sequentialCollection.UID)" `
                -Headers @{'X-Api-Key' = $postmanApiKey } `
                -OutFile $collectionFilePath
    
            newman run $collectionFilePath `
                -e $environmentFilePath `
                -r 'cli,junitfull' `
                --reporter-junitfull-export $reportFilePath `
                --verbose
        }
    } -ThrottleLimit 5
}