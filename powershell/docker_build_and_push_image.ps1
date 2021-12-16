# Written for PowerShell 7
param (
    [string]$AppVersion = 'latest'
)

# Variables
$dockerRemoteApiUrl = 'http://10.87.1.236:2375'
$archiveFile = "swagger-petstore.tar"

# Build a Docker image
Write-Host -ForegroundColor Green ("Build docker image is starting...")

# The base64EncodedCredentials is the base64 encoded value of username, password and serveraddress
# Please see the following reference https://docs.docker.com/engine/api/v1.41/#section/Authentication
$base64EncodedCredentials = "eyJ1c2VybmFtZSI6ImFkbWluIiwgInBhc3N3b3JkIjogIlBAc3N3MHJkITIzNCIsICJzZXJ2ZXJhZGRyZXNzIjogIjEwLjg3LjEuNjA6ODA4MyJ9"

$headers = @{
    "Content-Type" = "application/x-tar"
    "X-Registry-Config" = $base64EncodedCredentials
}

$imageName1 = "swagger-petstore:" + $AppVersion
$imageName2 = "swagger-petstore:latest"

$queryParams = "t=" + $imageName1

if ($AppVersion -ne 'latest') {
    # Add the current version to be the latest version as well
    $queryParams = $queryParams + "&t=" + $imageName2
}

$dockerBuildUrl = $dockerRemoteApiUrl + "/build?" + $queryParams

# Invoke Docker REST API to build an image
$response = Invoke-RestMethod -AllowUnencryptedAuthentication -Headers $headers -Method POST -InFile $archiveFile -Uri $dockerBuildUrl 

Write-Host $response
Write-Host -ForegroundColor Green ("Build docker image is finished")

# Push docker image to Nexus Repository
Write-Host -ForegroundColor Green ("Push docker image to internal registry is starting...")

$headers = @{
    "X-Registry-Auth" = $base64EncodedCredentials
}

$dockerPushUrlImage1 = $dockerRemoteApiUrl + "/images/" + $imageName1 + "/push"

# Invoke Docker REST API to push an image to Nexus Repository
$response1 = Invoke-RestMethod -AllowUnencryptedAuthentication -Headers $headers -Method POST -Uri $dockerPushUrlImage1 

Write-Host $response1

if ($AppVersion -ne 'latest') {
    # Push the latest version (if apply)
    $dockerPushUrlImage2 = $dockerRemoteApiUrl + "/images/" + $imageName2 + "/push"

    $response2 = Invoke-RestMethod -AllowUnencryptedAuthentication -Headers $headers -Method POST -Uri $dockerPushUrlImage2 

    Write-Host $response2
}

Write-Host -ForegroundColor Green ("Push docker image to internal registry is finished")