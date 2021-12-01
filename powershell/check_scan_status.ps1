# Written for Powershell 7
# Varibales
$scanCentralCtrlUrl = 'http://10.87.1.12:8090/scancentral-ctrl'
$fortifyHome = '/home/fortify'
$completedStatus = 'COMPLETED'

$scanToken = Get-Content "./scantoken.txt"

$isRunning = $True

Write-Host -ForegroundColor Green ("Retrieving scan status with token: $scanToken")

while ($isRunning){
    $output = Invoke-Expression -Command "$fortifyHome/bin/scancentral -url $scanCentralCtrlUrl status -token $scanToken"  | Out-String
	
	Write-Output $output
	
	$jobState = $output -match '.*The job state is:  (.*)'
	if ($jobState) {
		$jobState = $matches[1]		
	}
	
	$uploadState = $output -match '.*SSC upload state is:  (.*)'
	if ($uploadState) {
		$uploadState = $matches[1]		
	}
	
	if ($jobState -eq $completedStatus -and $uploadState -eq $completedStatus) {
		$isRunning = $False
	} else {
		Start-Sleep -Seconds 5
	}
}