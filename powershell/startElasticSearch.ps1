$es_hostname = "elasticsearch";
$es_image = "jeffdayley/windows-elasticsearch:latest"
$current_ps = docker ps -a --format '{{.Names}}'

# Remove the old container if running
if ($current_ps -like $es_hostname) 
{
    Write-Host "Removing old $es_hostname container"
    $rm_out = docker rm -f $es_hostname
}

# Update the image
Write-Host "Updating the docker image $es_image"
$pull_out = docker pull $es_image | Out-String
Write-Host $pull_out

# Create the new container
$docker_image_id = docker run -d --name $es_hostname -m 3g $es_image

# Get the IP address for the container
$es_ip = docker inspect -f '{{.NetworkSettings.Networks.nat.IPAddress}}' $es_hostname

# Update the host file
$hostfile_loc = "c:\Windows\System32\Drivers\etc\hosts"
$es_found_in_hosts =  Select-String -Pattern $es_hostname -Path $hostfile_loc
if ([string]::IsNullOrEmpty($es_found_in_hosts))
{
    Write-Host "Appending to $es_hostname IP Address to $hostfile_loc file"
    Add-Content $hostfile_loc ""
    Add-Content $hostfile_loc "# Docker Container IP Addresses"
    Add-Content $hostfile_loc "$es_ip $es_hostname"       
}
else
{
    Write-Host "Updating $es_hostname IP Address in in $hostfile_loc"
    (Get-Content $hostfile_loc) -replace "\S+ $es_hostname", "$es_ip $es_hostname" | Out-File $hostfile_loc
}

# Verify that ES is up and running
$stoploop = $false
$retrycount = 1;
$sleepTime = 30;
$successfulConnection = $true
do
{
    Try 
    {
      $es_http = 'http://' + $es_hostname + ':9200'
      $es_request_result = Invoke-WebRequest -Uri $es_http
      $stoploop = $true
    }
    Catch
    {
        if($retrycount -gt 3)
        {
            $successfulConnection = $false
            $stoploop = $true
        }
        else 
        {
            Write-Host ("Could not connect to $es_hostname container. Waiting 30 seconds before trying again. (Attempt: $retrycount/3)")
            Start-Sleep -Seconds 30;
            $retrycount = $retrycount + 1;
        }
    }
}
while ($stoploop -eq $false)


if ($successfulConnection -eq $true)
{
    Write-Host "$es_hostname container up and running"
    exit 0
}
else
{
    Write-Error "Unable to connect to $es_hostname container"
    exit 1
}

