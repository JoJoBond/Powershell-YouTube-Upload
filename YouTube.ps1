function Add-YouTube-Video
{
    <#
    .SYNOPSIS
    Uploads a video to YouTube.
    .DESCRIPTION
    Uploada a video to YouTube via the YouTube API v3 and sets privacy and various other parameters.
    .EXAMPLE
    Add-YouTube-Video -File "my_video.mp4" -Titel "My Video" -CategoryID 1 -PrivacyStatus 'public'
    .PARAMETER File
    Path to the video that shall be uploaded.
    .PARAMETER Title
    Title of the video.
    .PARAMETER CategoryId
    Sets the video category via an ID.
    For possible IDs check:
    https://developers.google.com/youtube/v3/docs/videoCategories/list
    .PARAMETER Description
    Description of the video.
    .PARAMETER Tags
    A list of tags for the video.
    .PARAMETER PrivacyStatus
    Sets the video privacy settings.
    Valid values are 'private', 'public' and 'unlisted'.
    .PARAMETER PublicStatsViewable
    Hides the video statistics (view count, etc.) for the video.
    .PARAMETER Dimension
    Marks the uploaded video as '2D' or '3D' recording.
    .PARAMETER Definition
    Marks the uploaded video as 'HD' or 'SD' recording.
    .PARAMETER LocationDescription
    Textual description of where the video was recorded.
    .PARAMETER LocationCoordinates
    Coordinates from where the video was recorded.
    .PARAMETER RecordingDate
    The date the video was recorded on.
    Requires the 'yyyy-MM-dd' date format.
    .PARAMETER DisableComments
    Disables comments for this video
    Uses the deprecated YouTube API v2
    .PARAMETER DisableRating
    Disables rating for this video
    Uses the deprecated YouTube API v2
    .PARAMETER DisableVideoResponds
    Disables videos responds for this video
    Uses the deprecated YouTube API v2
    .PARAMETER EnableProgressBar
    Displays a progress bar using 'Write-Progress'
    .OUTPUTS
    YouTube video ID of the uploaded video
    .NOTES
    It is necessary to supply a client_secrets.json file that should be located in the same folder as the .exe and .ps1 file.    
    You need to generate your own client secret file.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0)]
        [ValidateScript({Test-Path $_.Replace("\\","\")})]
        [string]$File,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$Title,

        [Parameter(Mandatory=$True,Position=2)]
        [int]$CategoryID,

        [Parameter(Mandatory=$False,Position=3)]
        [string]$Description,

        [Parameter(Mandatory=$False,Position=4)]
        [string[]]$Tags,

        [ValidateSet('unlisted','private','public')] 
        [Parameter(Mandatory=$False,Position=5)]
        [string]$PrivacyStatus,

        [Parameter(Mandatory=$False,Position=6)]
        [bool]$PublicStatsViewable,
        
        [ValidateSet('2D','3D')] 
        [Parameter(Mandatory=$False,Position=7)]
        [string]$Dimension,
        
        [ValidateSet('HD','SD')] 
        [Parameter(Mandatory=$False,Position=8)]
        [string]$Definition,

        [Parameter(Mandatory=$False,Position=9)]
        [string]$LocationDescription,

        [Parameter(Mandatory=$False,Position=10)]
        [System.Numerics.Vector2]$LocationCoordinates,
                
        [Parameter(Mandatory=$False,Position=11)]
        [ValidateScript({[datetime]::ParseExact($_, 'yyyy-MM-dd', $null)})]
        [string]$RecordingDate,
        
        [Obsolete("Not possible with YouTube API v3")]
        [Parameter(Mandatory=$False,Position=12)]
        [bool]$DisableComment,

        [Obsolete("Not possible with YouTube API v3")]
        [Parameter(Mandatory=$False,Position=13)]
        [bool]$DisableRating,

        [Obsolete("Not possible with YouTube API v3")]
        [Parameter(Mandatory=$False,Position=14)]
        [bool]$DisableVideoRespond,

        [Parameter(Mandatory=$False, Position=15)]
        [switch]$EnableProgressBar
    )

    $File = (Resolve-Path $File.Replace("\\","\")).Path;

    $YouTubeCLI = (Resolve-Path ".\YoutubeCLI.exe").Path;

    $YouTubeCLI_Params = "-Mode Video -Operation Add -File ""$File"" -Title ""$Title"" -CategoryID $CategoryID";

    if($PSBoundParameters.ContainsKey('Description')) {
        $YouTubeCLI_Params += " -Description ""$Description""";
    }

    if($PSBoundParameters.ContainsKey('Tags')) {
        $YouTubeCLI_Params += " -Tags ""$($Tags -join ",")""";
    }

    if($PSBoundParameters.ContainsKey('PrivacyStatus')) {
        $YouTubeCLI_Params += " -PrivacyStatus $PrivacyStatus";
    }

    if($PSBoundParameters.ContainsKey('PublicStatsViewable')) {
        $YouTubeCLI_Params += " -PublicStatsViewable $PublicStatsViewable";
    }

    if($PSBoundParameters.ContainsKey('Dimension')) {
        $YouTubeCLI_Params += " -Dimension $Dimension";
    }

    if($PSBoundParameters.ContainsKey('Definition')) {
        $YouTubeCLI_Params += " -Definition $Definition";
    }

    if($PSBoundParameters.ContainsKey('LocationDescription')) {
        $YouTubeCLI_Params += " -LocationDescription ""$LocationDescription""";
    }

    if($PSBoundParameters.ContainsKey('LocationCoordinates')) {
        $YouTubeCLI_Params += " -Location_Latitude $($LocationCoordinates.X)";
        $YouTubeCLI_Params += " -Location_Longitude $($LocationCoordinates.Y)";
    }

    if($PSBoundParameters.ContainsKey('Location_Longitude')) {
    }

    if($PSBoundParameters.ContainsKey('RecordingDate')) {
        $YouTubeCLI_Params += " -RecordingDate $RecordingDate";
    }

    if($PSBoundParameters.ContainsKey('DisableComment')) {
        $YouTubeCLI_Params += " -DisableComment $DisableComment";
    }

    if($PSBoundParameters.ContainsKey('DisableRating')) {
        $YouTubeCLI_Params += " -DisableRating $DisableRating";
    }

    if($PSBoundParameters.ContainsKey('DisableVideoRespond')) {
        $YouTubeCLI_Params += " -DisableVideoRespond $DisableVideoRespond";
    }
    
    $MaxRetry = 5;
    $NumRetrys = 0;
	
    $VideoId = "";
    while($NumRetrys -lt $MaxRetry)
    {
        $NumRetrys = $NumRetrys + 1;

        if($EnableProgressBar)
        {
            Write-Progress -Activity "Uploading to YouTube" -Status "[Attempt: $NumRetrys] $Title" -PercentComplete 0;
        }

        $p = New-Object System.Diagnostics.Process;
        $p.StartInfo.Filename = "$YouTubeCLI";
        $p.StartInfo.Arguments = "$YouTubeCLI_Params";
        $p.StartInfo.UseShellExecute = $false;
        $p.StartInfo.RedirectStandardOutput = $true;
        $p.StartInfo.CreateNoWindow = $true;
	$p.Start() | Out-Null;

        while (-not $p.HasExited)
        {
            if ($p.StandardOutput.Peek())
            {
                $line = $p.StandardOutput.ReadLineAsync().Result;
                if ($line)
                {
                    $info = $line.Trim();
                    if ($info.StartsWith("Percent complete: "))
                    {
                        if($EnableProgressBar)
                        {
                            [int32]$progperc = [Math]::Floor([decimal](($info.Split("|")[0]).Substring(18).Replace(",",".")));
                                        
                            if ($progperc -gt $PrevProgress)
                            {
                                Write-Progress -Activity "Uploading to YouTube" -Status "[Attempt: $NumRetrys] $Title" -PercentComplete $progperc;
                                $PrevProgress = $progperc;
                            }
                        }
                    }
                    elseif ($info.StartsWith("VideoID: "))
                    {
                        $VideoId = $line.Replace("VideoID: ","").Trim();
                    }
                }
            }
        }

        if($EnableProgressBar)
        {
            Write-Progress -Activity "Uploading to YouTube" -Status "[Attempt: $NumRetrys] $Title" -PercentComplete 100 -Completed;
        }

        $p.WaitForExit();
        
        if (($p.ExitCode -ne 0) -or ($yt_video_id -eq ""))
        {
            if ($VideoId -ne "")
            {
                Start-Process -FilePath "$youtubeCLI" -ArgumentList "-Mode Video -Operation Remove -VideoID ""$yt_video_id""" -WindowStyle Hidden -Wait -PassThru;
            }

            continue;
        }
        		
        break;
    }

    if($NumRetrys -ge $MaxRetry)
    {
        throw "YouTube upload canceled after $MaxRetry attempts";
    }
	
    return $VideoId;
}

function Add-YouTube-Playlist
{
    <#
    .SYNOPSIS
    Creates a YouTube playlist
    .DESCRIPTION
    Creates a YouTube playlist via the YouTube API v3 and sets privacy and various other parameters.
    .EXAMPLE
    Add-YouTube-Playlist -VideoIDs ('oHg5SJYRHA0','boPyHl3iptQ') -Titel "Great videos!" -PrivacyStatus 'public'
    .PARAMETER VideoIDs
    List of VideoIDs that shall be added to the playlist.
    .PARAMETER Title
    Title of the playlist.
    .PARAMETER Description
    Description of the playlist.
    .PARAMETER PrivacyStatus
    Sets the playlist privacy settings.
    Valid values are 'private', 'public' and 'unlisted'.
    .OUTPUTS
    YouTube playlist ID
    .NOTES
    It is necessary to supply a client_secrets.json file that should be located in the same folder as the .exe and .ps1 file.    
    You need to generate your own client secret file.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0)]
        [ValidateScript({$_.Length -ge 1})]
        [string[]]$VideoIDs,

        [Parameter(Mandatory=$True,Position=1)]
        [string]$Title,

        [Parameter(Mandatory=$False,Position=2)]
        [string]$Description,

        [ValidateSet('unlisted','private','public')] 
        [Parameter(Mandatory=$False,Position=3)]
        [string]$PrivacyStatus
    )
    $YouTubeCLI = (Resolve-Path ".\YoutubeCLI.exe").Path;

    $YouTubeCLI_Params = "-Mode Playlist -Operation Add -VideoIDs ""$($videoids -join '/')"" -Title ""$Title""";
    
    if($PSBoundParameters.ContainsKey('Description')) {
        $YouTubeCLI_Params += " -Description ""$Description""";
    }
        
    if($PSBoundParameters.ContainsKey('PrivacyStatus')) {
        $YouTubeCLI_Params += " -PrivacyStatus $PrivacyStatus";
    }

    $p = New-Object System.Diagnostics.Process;
    $p.StartInfo.Filename = "$YouTubeCLI";
    $p.StartInfo.Arguments = "$YouTubeCLI_Params";
    $p.StartInfo.UseShellExecute = $false;
    $p.StartInfo.RedirectStandardOutput = $true;
    $p.StartInfo.CreateNoWindow = $true;
    $p.Start() | Out-Null;
    $p.WaitForExit();

    if ($p.ExitCode -ne 0)
    {
        throw "YouTube playlist creation failed";
    }
    else
    {
        $p_out = $p.StandardOutput.ReadToEnd();
        $p_out = $p_out.Split("`n");
        foreach ($line in $p_out)
        {
            if ($line.StartsWith('PlaylistID: '))
            {
                return $line.Replace("PlaylistID: ", "").Trim();
            }
        }
        throw "YouTube playlist creation failed";
    }
}

function Remove-YouTube-Video
{
    <#
    .SYNOPSIS
    Deletes a YouTube video
    .DESCRIPTION
    Deletes a YouTube video via the YouTube API v3.
    .EXAMPLE
    Remove-YouTube-Video -VideoID 'deadbeef'
    .PARAMETER VideoID
    ID the video that shall be deleted.
    .NOTES
    It is necessary to supply a client_secrets.json file that should be located in the same folder as the .exe and .ps1 file.    
    You need to generate your own client secret file.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0)]
        [string]$VideoID
    )

    $YouTubeCLI = (Resolve-Path ".\YoutubeCLI.exe").Path;

    $YouTubeCLI_Params = "-Mode Video -Operation Remove -VideoID ""$VideoID""";
    
    $p = New-Object System.Diagnostics.Process;
    $p.StartInfo.Filename = "$YouTubeCLI";
    $p.StartInfo.Arguments = "$YouTubeCLI_Params";
    $p.StartInfo.UseShellExecute = $false;
    $p.StartInfo.RedirectStandardOutput = $true;
    $p.StartInfo.CreateNoWindow = $true;
    $p.Start() | Out-Null;
    $p.WaitForExit();

    if ($p.ExitCode -ne 0)
    {
        throw "YouTube video deletion failed";
    }
}

function Remove-YouTube-Playlist
{
    <#
    .SYNOPSIS
    Deletes a YouTube playlist
    .DESCRIPTION
    Deletes a YouTube playlist via the YouTube API v3.
    .EXAMPLE
    Remove-YouTube-Playlist -PlaylistID 'deadbeef'
    .PARAMETER PlaylistID
    ID the playlist that shall be deleted.
    .NOTES
    It is necessary to supply a client_secrets.json file that should be located in the same folder as the .exe and .ps1 file.    
    You need to generate your own client secret file.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0)]
        [string]$PlaylistID
    )

    $YouTubeCLI = (Resolve-Path ".\YoutubeCLI.exe").Path;

    $YouTubeCLI_Params = "-Mode Playlist -Operation Remove -PlaylistID ""$PlaylistID""";
    
    $p = New-Object System.Diagnostics.Process;
    $p.StartInfo.Filename = "$YouTubeCLI";
    $p.StartInfo.Arguments = "$YouTubeCLI_Params";
    $p.StartInfo.UseShellExecute = $false;
    $p.StartInfo.RedirectStandardOutput = $true;
    $p.StartInfo.CreateNoWindow = $true;
    $p.Start() | Out-Null;
    $p.WaitForExit();

    if ($p.ExitCode -ne 0)
    {
        throw "YouTube playlist deletion failed";
    }
}
