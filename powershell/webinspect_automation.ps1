#Written for Powershell 7
#Variables
$wiAPIurl = '10.87.1.95:8083'
$sscURL = 'http://10.87.1.12:8080/ssc'
$applicationVersionID = '10028'
$sscToken = 'NjMyMDBhZjUtYWNjZC00MmUwLThiZGUtYWI1ZDg3YmFlMDM2'

$scanURL = 'https://psi-outing-lucky-draw.azurewebsites.net/'
$crawlAuditMode = 'CrawlandAudit'
$scanName = 'psi-outing-lucky-draw'

#API Auth
$pwd = ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force
$cred = New-Object Management.Automation.PSCredential ('administrator', $pwd)

#1. Run the scan
$headers = @{
  "Accept" = "application/json"
  "Content-Type" = "application/json"
}

$body = '{
"settingsName": "Default",
"overrides": {
"scanName": "' + $scanName + '",
"startUrls": [
"' + $scanURL + '"
],
"crawlAuditMode": "' + $crawlAuditMode + '",
"startOption": "Url"
}'

$responseurl = 'http://' + $wiAPIurl + '/webinspect/scanner/scans'
$response = Invoke-RestMethod -AllowUnencryptedAuthentication -Credential $cred -Headers $headers -Method POST -Body $body -uri $responseurl
 
#Store unique ScanId
$scanId = $response.ScanId
Write-Host -ForegroundColor Green ("Scan started succesfully with Scan Id: " + $scanId)
 
#2. Get the current Status of the Scan
$StatusUrl = 'http://' + $wiAPIurl + '/webinspect/scanner/scans/' + $scanId + '/log'
$ScanCompleted = "ScanCompleted"
$ScanStopped = "ScanStopped"
$ScanInterrupted = "ScanInterrupted"
 
#Wait until the ScanStatus changed to ScanCompleted, ScanStopped or ScanInterrupted
do{
    $status = Invoke-RestMethod -AllowUnencryptedAuthentication -Credential $cred -Headers $headers -Method GET -ContentType "application/json" -uri "$StatusUrl"
    $ScanDate =  $status[$status.Length-1].Date
    $ScanMessage = $status[$status.Length-1].Message
    $ScanStatus =  $status[$status.Length-1].Type
    Write-Host ($ScanDate, $ScanMessage, $ScanStatus) -Separator " - "
    Start-Sleep -Seconds 20
}
while(($ScanStatus -ne $ScanCompleted) -and ($ScanStatus -ne $ScanStopped) -and ($ScanStatus -ne $ScanInterrupted))
 
if ($ScanStatus -eq $ScanCompleted){
    Write-Host -ForegroundColor Green ("Scan completed!") `n

    #3. Export the scan to the FPR format
    $fprurl = 'http://' + $wiAPIurl + '/webinspect/scanner/scans/' + $scanId + '.fpr '
    $path = $scanId + '.fpr'

    Write-Host ("Downloading the result file (fpr)...")
    Invoke-RestMethod -AllowUnencryptedAuthentication -Credential $cred -Method GET -OutFile $path -uri "$fprurl"
    Write-Host -ForegroundColor Green ("Result file (fpr) download done!") `n
 
    #4. Upload the Results to SSC
    $sscheaders = '@{
        "Authorization" = "FortifyToken '+ $sscToken + '"
        "ContentType" = "multipart/form-data"
        "accept" = "application/json"
    }'
    $sscheader_exp = Invoke-Expression $sscheaders
    $sscuploadurl = $sscURL + 'api/v1/projectVersions/' + $applicationVersionID + '/artifacts'

    Write-Host ("Starting Upload to SSC...")
    Invoke-RestMethod -uri $sscuploadurl -Method POST -Headers $sscheader_exp -Form @{file=(Get-Item $path)}
    Write-Host -ForegroundColor Green ("Finished! Scan Results are now availible in the Software Security Center!")
}
else {
    Write-Host -ForegroundColor Red ("Error occured after Scan was finished!")
}