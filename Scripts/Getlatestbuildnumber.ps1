    ##Get latest build number from build queue history based on branch name and Definition, in order to get a counter for the newly created builds.
	
	param (
		# BuildDefinition/Pipeline ID
        [int]$Definition,
		# The name of source Branch
        [string]$BranchName,
		# Optional name of variable to set the counter in 
        [string]$VariableName

    )
    if ($BranchName)  { $q_branchName  = 'branchName='  + $BranchName  + '&' }
    if ($Definition)   { $q_definition   = 'definitions='   + $Definition   + '&' }

    $query_args = $q_definition + $q_branchName + "queryOrder=queueTimeDescending&api-version=5.0&"

    $collectionUri = "$Env:System_TeamFoundationCollectionUri"
    $currentBuildId = [int]"$Env:Build_BuildId"
    Write-Host "Buildid: $currentBuildId"
    $projName = "$Env:System_TeamProject"
    $userToken = ""
    $buildStatus = @("completed","inProgress")

    $baseUri = "$collectionUri$projName/_apis/build/builds"

	# Get TFS builds list rest service uri by adding parameters
    $completedBuildUri = "$($baseUri)?`$top=1&$($query_args)statusFilter=$($buildStatus[0])"
    $runningBuildsUri = "$($baseUri)?`$top=20&$($query_args)statusFilter=$($buildStatus[1])"

    Write-Host "Finished: $completedBuildUri"

    Write-Host "Running: $runningBuildsUri"

	# Bearer token for tfs service authentication 
    $token = ":$($userToken)"
       Write-Host "Token: $token"

    # Base64-encodes the Personal Access Token (PAT) appropriately
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($token))

    $latestCompletedBuild = @()
    $runningBuilds = @()
	
	# Call tfs api to get the latest builds
    $c = Invoke-RestMethod -Uri $completedBuildUri -Method 'Get' -Headers @{Authorization = 'Basic ' + $base64AuthInfo} | ForEach-Object -Process {$latestCompletedBuild += $_.value}

    $r = Invoke-RestMethod -Uri $runningBuildsUri -Method 'Get' -Headers @{Authorization = 'Basic ' + $base64AuthInfo} | ForEach-Object -Process {
        if($_.value)
        {
            foreach ($val in $_.value)
            {
                if([int]$val.id -lt $currentBuildId)
                {
                    $runningBuilds += $val
                }
            }
        }
    }

    Write-Host "Latest completed build count:" $latestCompletedBuild.Count
    Write-Host "Running builds count:" $runningBuilds.Count

    $rev = 0

	# Check if this is the first build runnign in this branch 
    if ($latestCompletedBuild.Count -eq 1)
    {
        $latestbuildNumber = $latestCompletedBuild[0].BuildNumber
        Write-Host "$latestbuildNumber"
        $major,$minor,$latestBuildRevision = $latestbuildNumber.split('.')
        $rev = $latestBuildRevision -replace '\D+'
        Write-Host "rev: $rev"
    }
    if($runningBuilds.Count -gt 0)
    {
        $rev = [int]$rev + $runningBuilds.Count;
    }

    $counter = [int]$rev + 1

	# Set the counter variable value in the pipeline 
    Write-Host "counter is: ##vso[task.setvariable variable=$VariableName;]$counter"
