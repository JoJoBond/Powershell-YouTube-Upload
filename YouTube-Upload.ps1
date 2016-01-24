function YouTube-Upload
{
    <#
    .SYNOPSIS
    Uploads a video to YouTube.
    .DESCRIPTION
    Uploada a video to YouTube via the YouTube API v3 and sets privacy various parameters.
    .EXAMPLE
    YouTube-Upload -VideoFile "my_video.mp4" -Titel "My Video" -CategoryId 1 -Privacy 'public'
    .PARAMETER VideoFile
    Path to the video that shall be uploaded.
    .PARAMETER Title
    Title of the video.
    .PARAMETER Description
    Description of the video.
    .PARAMETER Tags
    A list of tags for the video.
    .PARAMETER CategoryId
    Sets the video category via an ID.
    For possible IDs check:
    https://developers.google.com/youtube/v3/docs/videoCategories/list
    .PARAMETER Privacy
    Sets the video privacy settings.
    Valid values are 'private', 'public' and 'unlisted'.
    .PARAMETER HideStatistics
    Hides the video statistics (view count, etc.) for the video.
    .PARAMETER Is3D
    Markes the uploaded video as three dimensional recording.
    .PARAMETER IsHD
    Markes the uploaded video as high definition recording.
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
    .PARAMETER DisableDeprecationWarning
    Disables the warning when using features of the deprecated YouTube API v2
    .PARAMETER EnableProgressBar
    Displays a progress bar using 'Write-Progress'
    .OUTPUTS
    YouTube video ID of the uploaded video
    .NOTES
    It is necessary to supply a client_secrets.json file that should be located in the same folder as the .ps1 file.
    When using the v2 API it is also necessary to supply a api_v2_devkey.txt file that should be located in the same folder as the .ps1 file.
    You should generate your own developer keys and client secret files, but could also use filed provided by other projects.
    E.g. https://code.google.com/p/youtube-upload/ and https://github.com/tokland/youtube-upload
    .LINK

    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,  Position= 0)]
        [ValidateScript({Test-Path $_})]
        [string]$VideoFile,
        [Parameter(Mandatory=$True,  Position= 1)]
        [string]$Title,
        [Parameter(Mandatory=$False, Position= 2)]
        [string]$Description = "", 
        [Parameter(Mandatory=$False, Position= 3)]
        [string[]]$Tags,
        [Parameter(Mandatory=$True,  Position= 4)]
        [int]$CategoryId,
        [Parameter(Mandatory=$True,  Position= 5)]
        [ValidateSet("private","public","unlisted")]
        [string]$Privacy,
        [Parameter(Mandatory=$False, Position= 6)]
        [switch]$HideStatistics,
        [Parameter(Mandatory=$False, Position= 7)]
        [switch]$Is3D,
        [Parameter(Mandatory=$False, Position= 8)]
        [switch]$IsHD,
        [Parameter(Mandatory=$False, Position= 9)]
        [string]$LocationDescription,
        [Parameter(Mandatory=$False, Position=10)]
        [System.Drawing.PointF]$LocationCoordinates,
        [Parameter(Mandatory=$False, Position=11)]
        [ValidateScript({[datetime]::ParseExact($_, "yyyy-MM-dd", $null)})]
        [string]$RecordingDate,
        [Parameter(Mandatory=$False, Position=12)]
        [switch]$DisableComments,
        [Parameter(Mandatory=$False, Position=13)]
        [switch]$DisableRating,
        [Parameter(Mandatory=$False, Position=14)]
        [switch]$DisableVideoResponds,
        [Parameter(Mandatory=$False, Position=15)]
        [switch]$DisableDeprecationWarning,
        [Parameter(Mandatory=$False, Position=16)]
        [switch]$EnableProgressBar
    )

    try
    {
        Add-Type -LiteralPath "$PSScriptRoot\Google.Apis.YouTube.v3.Merged.dll";
    }
    catch
    {
        throw "Failed to load v3 API library";
    }
    
    if(-not (Test-Path "$PSScriptRoot\client_secrets.json"))
    {
        throw "Client secrets file (client_secrets.json) not found";
    }

    $filestream = New-Object IO.FileStream "$PSScriptRoot\client_secrets.json", "Open", "Read";

    $scope = (New-Object System.Collections.Generic.List[String]);
    $scope.Add([Google.Apis.YouTube.v3.YouTubeService+Scope]::Youtube);
    $scope.Add([Google.Apis.YouTube.v3.YouTubeService+Scope]::YoutubeUpload);
    $scope.Add([Google.Apis.YouTube.v3.YouTubeService+Scope]::YoutubeReadonly);

    $store = New-Object Google.Apis.Util.Store.FileDataStore "Google.Apis.Auth";
    
    try
    {
        $creds = [Google.Apis.Auth.OAuth2.GoogleWebAuthorizationBroker]::AuthorizeAsync(
            [Google.Apis.Auth.OAuth2.ClientSecrets](([Google.Apis.Auth.OAuth2.GoogleClientSecrets]::Load($filestream)).Secrets),
            [System.Collections.Generic.IEnumerable[string]]$scope,
            [string]"user",
            [System.Threading.CancellationToken]::None,
            [Google.Apis.Util.Store.IDataStore]$store
        );
        $creds.Wait();
    }
    catch
    {
        throw "OAuth2 authorization request failed";
        $creds.Dispose();
    }
    finally
    {
        $filestream.Dispose();
    }
    
    $BCS_Init = New-Object Google.Apis.Services.BaseClientService+Initializer;

    $BCS_Init.HttpClientInitializer = $creds.Result;
    $BCS_Init.ApplicationName = "Google.Apis.Auth";

    $ytService = New-Object Google.Apis.YouTube.v3.YouTubeService $BCS_Init;

    $vid = New-Object Google.Apis.YouTube.v3.Data.Video;
    $vid.Snippet = New-Object Google.Apis.YouTube.v3.Data.VideoSnippet;
    $vid.Snippet.Title = $Title;
    $vid.Snippet.Description = $Description;
    $vid.Snippet.Tags = New-Object System.Collections.Generic.List[String];
    $Tags | foreach {
        $vid.Snippet.Tags.Add($_);  
    };
    $vid.Snippet.CategoryId = $CategoryId.ToString();
    $vid.Status = New-Object Google.Apis.YouTube.v3.Data.VideoStatus;
    $vid.Status.PrivacyStatus = $Privacy;
    $vid.Status.PublicStatsViewable = (-not $HideStatistics.IsPresent);
    $vid.ContentDetails = New-Object Google.Apis.YouTube.v3.Data.VideoContentDetails;
    if ($Is3D.IsPresent)
    {
        $vid.ContentDetails.Dimension = "3D";  
    }
    if ($IsHD.IsPresent)
    {
        $vid.ContentDetails.Definition = "hd"; 
    }
    $vid.RecordingDetails = New-Object Google.Apis.YouTube.v3.Data.VideoRecordingDetails;
    $vid.RecordingDetails.LocationDescription = $LocationDescription;
    $vid.RecordingDetails.Location = New-Object Google.Apis.YouTube.v3.Data.GeoPoint
    $vid.RecordingDetails.Location.Latitude = $LocationCoordinates.X;
    $vid.RecordingDetails.Location.Longitude = $LocationCoordinates.Y;
    $vid.RecordingDetails.RecordingDate = [datetime]::ParseExact($RecordingDate, "yyyy-MM-dd", $null);

    $filesize = (Get-Item $VideoFile).length;
    $filestream = New-Object IO.FileStream $VideoFile, "Open", "Read";

    $vidInsReq = $ytService.Videos.Insert($vid, "snippet,status,contentDetails,recordingDetails", $filestream, "video/*");
    
    
    if ($EnableProgressBar.IsPresent)
    {
        #TODO: Make this more dynamic
        if ($vidInsReq.ChunkSize -ge $filesize)
        {
            $vidInsReq.ChunkSize = [Google.Apis.Upload.ResumableUpload[Google.Apis.YouTube.v3.Data.Video]]::MinimumChunkSize;
        }
        Write-Progress -Activity "Uploading to YouTube" -Status $VideoFile -PercentComplete 0.0;
    }
    try
    {
        $vidInsAsy = $vidInsReq.UploadAsync();
        while (-not $vidInsAsy.IsCompleted)
        {
            if ($EnableProgressBar.IsPresent)
            {
                $prog = $vidInsReq.GetProgress();
                if ($prog.Status -eq "Uploading")
                {
                    $progperc = 100.0 * [decimal]($prog.BytesSent) / [decimal]$filesize;
                    Write-Progress -Activity "Uploading to YouTube" -Status $VideoFile -PercentComplete $progperc;
                }
            }
            Start-Sleep -Milliseconds 500;
        }
        $yt_video_id = $vidInsReq.ResponseBody.Id;
    }
    catch
    {
        throw "Failed to upload video via v3 API";
        $creds.Dispose();
    }
    finally
    {
        $filestream.Dispose();
        $vidInsAsy.Dispose();
        $ytService.Dispose();
    }
    
    if ($EnableProgressBar.IsPresent)
    {
        Write-Progress -Activity "Uploading to YouTube" -Status $VideoFile -PercentComplete 100.0;
    }
    
    if ($DisableComments.IsPresent -or $DisableRating.IsPresent -or $DisableVideoResponds.IsPresent)
    {
        if (-not $DisableDeprecationWarning.IsPresent)
        {
            Write-Warning "The switches 'DisableComments', 'DisableRating' and 'DisableVideoResponds' use the deprecated YouTube API v2 and might not work consistently.";
        }

        if(-not (Test-Path "$PSScriptRoot\api_v2_devkey.txt"))
        {
            throw "API v2 developer key (api_v2_devkey.txt) not found";
        }

        $devkey = Get-Content "$PSScriptRoot\api_v2_devkey.txt" -Raw;

        try
        {
            $yt_get = Invoke-WebRequest "http://gdata.youtube.com/feeds/api/users/default/uploads/$yt_video_id" -Headers @{
                "Authorization"="$($creds.Result.Token.TokenType) $($creds.Result.Token.AccessToken)";
                "GData-Version"="2";
                "X-GData-Key"="key=$devkey"
            }

            $yt_get_xml = [xml]$yt_get.Content;

            $yt_get_xml.entry.accessControl | foreach {
                if (($_.action -eq "comment") -and $DisableComments.IsPresent)
                {
                    $_.permission = "denied"
                }
                if (($_.action -eq "rate") -and $DisableRating.IsPresent)
                {
                    $_.permission = "denied"
                }
                if (($_.action -eq "videoRespond") -and $DisableVideoResponds.IsPresent)
                {
                    $_.permission = "denied"
                }
            }

            $yt_put = Invoke-WebRequest "http://gdata.youtube.com/feeds/api/users/default/uploads/$yt_video_id" -Method "PUT" -Headers @{
                "Authorization"="$($creds.Result.Token.TokenType) $($creds.Result.Token.AccessToken)";
                "GData-Version"="2";
                "X-GData-Key"="key=$devkey"
            } -Body $yt_get_xml.OuterXml -ContentType "application/atom+xml" -SessionVariable test -InformationVariable info
        }
        catch
        {
            throw "Failed to update video settings via v2 API";
        }
        finally
        {
            $yt_get.Dispose();
            $yt_put.Dispose();
            $creds.Dispose();
        }
    }
}