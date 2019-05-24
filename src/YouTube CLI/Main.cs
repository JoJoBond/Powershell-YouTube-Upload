using Google.Apis.Auth.OAuth2;
using Google.Apis.Services;
using Google.Apis.Upload;
using Google.Apis.YouTube.v3;
using Google.Apis.YouTube.v3.Data;

using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Threading;
using System.Threading.Tasks;
using System.Xml;


namespace YouTube
{
    internal enum FSM_ArgParser
    {
        Mode,
        Operation,

        /* Playlist + Add */
        VideoIDs,

        /* Playlist + Remove */
        PlaylistID,

        /* Video/Playlist + Add */
        Title,
        Description,
        PrivacyStatus,

        /* Video + Add */
        Tags,
        CategoryID,
        PublicStatsViewable,
        Dimension,
        Definition,
        LocationDescription,
        Location_Latitude,
        Location_Longitude,
        RecordingDate,
        DisableComment,
        DisableRating,
        DisableVideoRespond,
        File,

        /* Video + Remove */
        VideoID
    }

    internal enum Modes
    {
        None,
        Video,
        Playlist
    }

    internal enum Operations
    {
        None,
        Add,
        Remove
    }

    internal class YouTubeCLI
    {
        private static Dictionary<FSM_ArgParser, object> Configuration = new Dictionary<FSM_ArgParser, object>();
        private static FSM_ArgParser? CurrState = null;
        private static long FileSize = -1;
        private static string VideoID = null;
        private static string PlaylistID = null;

        [STAThread]
        static int Main(string[] args)
        {
            Thread.CurrentThread.CurrentUICulture = System.Globalization.CultureInfo.InvariantCulture;

            Console.WriteLine("YouTube CLI");
            Console.WriteLine("===========");

            {
                string ParseRes = ParseArgs(args);
                if (ParseRes != null)
                {
                    Console.Error.WriteLine(ParseRes);
                    return -1;
                }
            };

            switch ((Modes)Configuration[FSM_ArgParser.Mode])
            {
                case Modes.Playlist:
                    if ((Operations)Configuration[FSM_ArgParser.Operation] == Operations.Add)
                    {
                        try
                        {
                            new YouTubeCLI().AddPlaylist().Wait();
                        }
                        catch (AggregateException ex)
                        {
                            foreach (Exception e in ex.InnerExceptions)
                            {
                                Console.Error.WriteLine("Error: " + e.Message);
                                return -1;
                            }
                        }
						Console.WriteLine("Creation successful");
						Console.Write("PlaylistID: {0}", PlaylistID);
                    }
                    else if ((Operations)Configuration[FSM_ArgParser.Operation] == Operations.Remove)
                    {
                        try
                        {
                            new YouTubeCLI().RemovePlaylist().Wait();
                        }
                        catch (AggregateException ex)
                        {
                            foreach (Exception e in ex.InnerExceptions)
                            {
                                Console.Error.WriteLine("Error: " + e.Message);
                                return -1;
                            }
                        }

                        Console.Write("Playlist deletion successful");
                    }

                    break;

                case Modes.Video:

                    if ((Operations)Configuration[FSM_ArgParser.Operation] == Operations.Add)
                    {
                        try
                        {
                            new YouTubeCLI().AddVideo().Wait();
                            Console.WriteLine("Upload successful");
                            Console.Write("VideoID: {0}", VideoID);
                        }
                        catch (AggregateException ex)
                        {
                            foreach (Exception e in ex.InnerExceptions)
                            {
                                Console.Error.WriteLine("Error: " + e.Message);
                            }
                            if (!string.IsNullOrWhiteSpace(VideoID))
                                Console.Write("VideoID: {0}", VideoID);
                            return -1;
                        }
                    }
                    else if ((Operations)Configuration[FSM_ArgParser.Operation] == Operations.Remove)
                    {
                        try
                        {
                            new YouTubeCLI().RemoveVideo().Wait();
                        }
                        catch (AggregateException ex)
                        {
                            foreach (Exception e in ex.InnerExceptions)
                            {
                                Console.Error.WriteLine("Error: " + e.Message);
                                return -1;
                            }
                        }

                        Console.Write("Video deletion successful");
                    }

                    break;
            }

            return 0;
        }

        internal static string ParseArgs(string[] args)
        {
            for (long i = 0; i < args.LongLength; i++)
            {
                if (CurrState == null)
                {
                    FSM_ArgParser NextState;
                    if (!Enum.TryParse(args[i].TrimStart('-'), out NextState))
                    {
                        return "Unexpected argument:" + args[i];
                    }
                    else
                    {
                        CurrState = NextState;
                    }
                }
                else
                {
                    switch (CurrState)
                    {
                        case FSM_ArgParser.Mode:
                            Modes Mode = Modes.None;
                            if (Enum.TryParse(args[i], out Mode))
                                Configuration[(FSM_ArgParser)CurrState] = Mode;
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.Operation:
                            Operations Operation = Operations.None;
                            if (Enum.TryParse(args[i], out Operation))
                                Configuration[(FSM_ArgParser)CurrState] = Operation;
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.VideoIDs:
                            List<string> VideoIDs = new List<string>(args[i].Split('/'));
                            foreach(string VideoID in VideoIDs)
                                if (VideoID.Length < 11)
                                    return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            Configuration[(FSM_ArgParser)CurrState] = VideoIDs;
                            break;
                        case FSM_ArgParser.PlaylistID:
                            Configuration[(FSM_ArgParser)CurrState] = args[i];
                            break;
                        case FSM_ArgParser.Title:
                            Configuration[(FSM_ArgParser)CurrState] = args[i];
                            break;
                        case FSM_ArgParser.Description:
                            Configuration[(FSM_ArgParser)CurrState] = args[i];
                            break;
                        case FSM_ArgParser.Tags:
                            Configuration[(FSM_ArgParser)CurrState] = new List<string>(args[i].Split(','));
                            break;
                        case FSM_ArgParser.CategoryID:
                            int CategoryID;
                            if (int.TryParse(args[i], System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out CategoryID))
                                Configuration[(FSM_ArgParser)CurrState] = CategoryID.ToString();
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.PrivacyStatus:
                            if (args[i] == "unlisted" || args[i] == "private" || args[i] == "public")
                                Configuration[(FSM_ArgParser)CurrState] = args[i];
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.PublicStatsViewable:
                            bool PublicStatsViewable;
                            if (bool.TryParse(args[i], out PublicStatsViewable))
                                Configuration[(FSM_ArgParser)CurrState] = PublicStatsViewable;
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.Dimension:
                            if (args[i].ToUpper() == "2D" || args[i].ToUpper() == "3D")
                                Configuration[(FSM_ArgParser)CurrState] = args[i].ToUpper();
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.Definition:
                            if (args[i].ToLower() == "hd" || args[i].ToLower() == "sd")
                                Configuration[(FSM_ArgParser)CurrState] = args[i].ToLower();
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.LocationDescription:
                            Configuration[(FSM_ArgParser)CurrState] = args[i];
                            break;
                        case FSM_ArgParser.Location_Latitude:
                            double Location_Latitude;
                            if (double.TryParse(args[i], System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out Location_Latitude))
                                Configuration[(FSM_ArgParser)CurrState] = Location_Latitude;
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.Location_Longitude:
                            double Location_Longitude;
                            if (double.TryParse(args[i], System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out Location_Longitude))
                                Configuration[(FSM_ArgParser)CurrState] = Location_Longitude;
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.RecordingDate:
                            DateTime RecordingDate;
                            if (DateTime.TryParse(args[i], out RecordingDate))
                                Configuration[(FSM_ArgParser)CurrState] = RecordingDate;
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.DisableComment:
                            bool DisableComment;
                            if (bool.TryParse(args[i], out DisableComment))
                                Configuration[(FSM_ArgParser)CurrState] = DisableComment;
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.DisableRating:
                            bool DisableRating;
                            if (bool.TryParse(args[i], out DisableRating))
                                Configuration[(FSM_ArgParser)CurrState] = DisableRating;
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.DisableVideoRespond:
                            bool DisableVideoRespond;
                            if (bool.TryParse(args[i], out DisableVideoRespond))
                                Configuration[(FSM_ArgParser)CurrState] = DisableVideoRespond;
                            else
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            break;
                        case FSM_ArgParser.File:
                            Configuration[(FSM_ArgParser)CurrState] = Path.GetFullPath(args[i]);
                            break;
                        case FSM_ArgParser.VideoID:
                            if (args[i].Length < 11)
                                return "Unexpected value for " + CurrState.ToString() + ": " + args[i];
                            else
                                Configuration[(FSM_ArgParser)CurrState] = args[i];
                            break;
                        default:
                            return "Unexpected FSM_state: " + CurrState.ToString();
                    }
                    CurrState = null;
                }
            }

            if (!Configuration.ContainsKey(FSM_ArgParser.Mode) || (Modes)Configuration[FSM_ArgParser.Mode] == Modes.None)
                return FSM_ArgParser.Mode.ToString() + " must be specified.";

            if (!Configuration.ContainsKey(FSM_ArgParser.Operation) || (Operations)Configuration[FSM_ArgParser.Operation] == Operations.None)
                return FSM_ArgParser.Operation.ToString() + " must be specified.";

            switch((Modes)Configuration[FSM_ArgParser.Mode])
            {
                case Modes.Playlist:
                    if ((Operations)Configuration[FSM_ArgParser.Operation] == Operations.Add)
                    {
                        if (!Configuration.ContainsKey(FSM_ArgParser.Title))
                            return FSM_ArgParser.Title.ToString() + " must be specified.";

                        if (!Configuration.ContainsKey(FSM_ArgParser.VideoIDs))
                            return FSM_ArgParser.VideoIDs.ToString() + " must be specified.";
                    }
                    else if ((Operations)Configuration[FSM_ArgParser.Operation] == Operations.Remove)
                    {
                        if (!Configuration.ContainsKey(FSM_ArgParser.PlaylistID))
                            return FSM_ArgParser.PlaylistID.ToString() + " must be specified.";
                    }
                    else
                        return FSM_ArgParser.Operation.ToString() + " must be specified.";

                    break;

                case Modes.Video:

                    if ((Operations)Configuration[FSM_ArgParser.Operation] == Operations.Add)
                    {
                        if (!Configuration.ContainsKey(FSM_ArgParser.Title))
                            return FSM_ArgParser.Title.ToString() + " must be specified.";

                        if (!Configuration.ContainsKey(FSM_ArgParser.CategoryID))
                            return FSM_ArgParser.CategoryID.ToString() + " must be specified.";

                        if (!Configuration.ContainsKey(FSM_ArgParser.File))
                            return FSM_ArgParser.File.ToString() + " must be specified.";


                        FileInfo Fi = new FileInfo(Configuration[FSM_ArgParser.File] as string);
                        if (!Fi.Exists)
                            return "Video file does not exist under given file path.";

                        FileSize = Fi.Length;
                    }
                    else if ((Operations)Configuration[FSM_ArgParser.Operation] == Operations.Remove)
                    {
                        if (!Configuration.ContainsKey(FSM_ArgParser.VideoID))
                            return FSM_ArgParser.VideoID.ToString() + " must be specified.";
                    }
                    else
                        return FSM_ArgParser.Operation.ToString() + " must be specified.";

                    break;

                default:
                    return FSM_ArgParser.Mode.ToString() + " must be specified.";
            }

            return null;
        }

        internal async Task RemovePlaylist()
        {
            Console.WriteLine("Logging in.");

            UserCredential credential;
            try
            {
                using (FileStream stream = new FileStream(Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory + @"\client_secrets.json"), FileMode.Open, FileAccess.Read))
                {
                    credential = await GoogleWebAuthorizationBroker.AuthorizeAsync(
                        GoogleClientSecrets.Load(stream).Secrets,
                        new[] { YouTubeService.Scope.Youtube, YouTubeService.Scope.YoutubeUpload },
                        "user",
                        CancellationToken.None
                    );

                    stream.Close();
                    stream.Dispose();
                }
            }
            catch (Exception e)
            {
                Console.Error.WriteLine("Error: " + e.Message);
                throw new Exception("Error: " + e.Message);
            }

            Console.WriteLine("Login OK.");

            YouTubeService youtubeService = new YouTubeService(new BaseClientService.Initializer()
            {
                HttpClientInitializer = credential,
                ApplicationName = "Google.Apis.Auth"
            });

            string Unbekannt = await youtubeService.Playlists.Delete(Configuration[FSM_ArgParser.PlaylistID] as string).ExecuteAsync();
        }

        internal async Task RemoveVideo()
        {
            Console.WriteLine("Logging in.");

            UserCredential credential;
            try
            {
                using (FileStream stream = new FileStream(Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory + @"\client_secrets.json"), FileMode.Open, FileAccess.Read))
                {
                    credential = await GoogleWebAuthorizationBroker.AuthorizeAsync(
                        GoogleClientSecrets.Load(stream).Secrets,
                        new[] { YouTubeService.Scope.Youtube, YouTubeService.Scope.YoutubeUpload },
                        "user",
                        CancellationToken.None
                    );

                    stream.Close();
                    stream.Dispose();
                }
            }
            catch (Exception e)
            {
                Console.Error.WriteLine("Error: " + e.Message);
                throw new Exception("Error: " + e.Message);
            }

            Console.WriteLine("Login OK.");

            YouTubeService youtubeService = new YouTubeService(new BaseClientService.Initializer()
            {
                HttpClientInitializer = credential,
                ApplicationName = "Google.Apis.Auth"
            });

            string Unbekannt = await youtubeService.Videos.Delete(Configuration[FSM_ArgParser.VideoID] as string).ExecuteAsync();
        }

        internal async Task AddPlaylist()
        {
            Console.WriteLine("Logging in.");

            UserCredential credential;
            try
            {
                using (FileStream stream = new FileStream(Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory + @"\client_secrets.json"), FileMode.Open, FileAccess.Read))
                {
                    credential = await GoogleWebAuthorizationBroker.AuthorizeAsync(
                        GoogleClientSecrets.Load(stream).Secrets,
                        new[] { YouTubeService.Scope.Youtube, YouTubeService.Scope.YoutubeUpload },
                        "user",
                        CancellationToken.None
                    );

                    stream.Close();
                    stream.Dispose();
                }
            }
            catch (Exception e)
            {
                Console.Error.WriteLine("Error: " + e.Message);
                throw new Exception("Error: " + e.Message);
            }

            Console.WriteLine("Login OK.");

            YouTubeService youtubeService = new YouTubeService(new BaseClientService.Initializer()
            {
                HttpClientInitializer = credential,
                ApplicationName = "Google.Apis.Auth"
            });

            string Parts = "snippet";

            Playlist playlist = new Playlist();
            playlist.Snippet = new PlaylistSnippet();

            playlist.Snippet.Title = Configuration[FSM_ArgParser.Title] as string;
            if (Configuration.ContainsKey(FSM_ArgParser.Description))
                playlist.Snippet.Description = Configuration[FSM_ArgParser.Description] as string;

            if (Configuration.ContainsKey(FSM_ArgParser.PrivacyStatus))
            {
                Parts += ",status";
                playlist.Status = new PlaylistStatus();
                playlist.Status.PrivacyStatus = Configuration[FSM_ArgParser.PrivacyStatus] as string;
            }

            playlist = await youtubeService.Playlists.Insert(playlist, Parts).ExecuteAsync();
            
            foreach(string VideoID in Configuration[FSM_ArgParser.VideoIDs] as List<string>)
            {
                PlaylistItem playlistItem = new PlaylistItem();
                playlistItem.Snippet = new PlaylistItemSnippet();
                playlistItem.Snippet.PlaylistId = playlist.Id;
                playlistItem.Snippet.ResourceId = new ResourceId();
                playlistItem.Snippet.ResourceId.Kind = "youtube#video";
                playlistItem.Snippet.ResourceId.VideoId = VideoID;
                playlistItem = await youtubeService.PlaylistItems.Insert(playlistItem, "snippet").ExecuteAsync();
            }

            PlaylistID = playlist.Id;
        }

        internal async Task AddVideo()
        {
            Console.WriteLine("Logging in.");
            
            UserCredential credential;
            try
            {
                using (FileStream stream = new FileStream(Path.GetFullPath(AppDomain.CurrentDomain.BaseDirectory + @"\client_secrets.json"), FileMode.Open, FileAccess.Read))
                {
                    credential = await GoogleWebAuthorizationBroker.AuthorizeAsync(
                        GoogleClientSecrets.Load(stream).Secrets,
                        new[] { YouTubeService.Scope.Youtube, YouTubeService.Scope.YoutubeUpload },
                        "user",
                        CancellationToken.None
                    );

                    stream.Close();
                    stream.Dispose();
                }
            }
            catch (Exception e)
            {
                Console.Error.WriteLine("Error: " + e.Message);
                throw new Exception("Error: " + e.Message);
            }

            Console.WriteLine("Login OK.");

            YouTubeService youtubeService = new YouTubeService(new BaseClientService.Initializer()
            {
                HttpClientInitializer = credential,
                ApplicationName = "Google.Apis.Auth"
            });

            string Parts = "snippet";

            Video video = new Video();
            video.Snippet = new VideoSnippet();

            video.Snippet.Title = Configuration[FSM_ArgParser.Title] as string;

            if (Configuration.ContainsKey(FSM_ArgParser.Description))
                video.Snippet.Description = Configuration[FSM_ArgParser.Description] as string;

            if (Configuration.ContainsKey(FSM_ArgParser.Tags))
                video.Snippet.Tags = Configuration[FSM_ArgParser.Tags] as List<string>;

            video.Snippet.CategoryId = Configuration[FSM_ArgParser.CategoryID] as string;


            if (Configuration.ContainsKey(FSM_ArgParser.PrivacyStatus) || 
                Configuration.ContainsKey(FSM_ArgParser.PublicStatsViewable))
            {
                Parts += ",status";
                video.Status = new VideoStatus();

                if (Configuration.ContainsKey(FSM_ArgParser.PrivacyStatus))
                    video.Status.PrivacyStatus = Configuration[FSM_ArgParser.PrivacyStatus] as string;

                if (Configuration.ContainsKey(FSM_ArgParser.PublicStatsViewable))
                    video.Status.PublicStatsViewable = (bool)Configuration[FSM_ArgParser.PublicStatsViewable];
            }


            if (Configuration.ContainsKey(FSM_ArgParser.Dimension) || 
                Configuration.ContainsKey(FSM_ArgParser.Definition))
            {
                Parts += ",contentDetails";
                video.ContentDetails = new VideoContentDetails();

                if (Configuration.ContainsKey(FSM_ArgParser.Dimension))
                    video.ContentDetails.Dimension = Configuration[FSM_ArgParser.Dimension] as string;

                if (Configuration.ContainsKey(FSM_ArgParser.Definition))
                    video.ContentDetails.Definition = Configuration[FSM_ArgParser.Definition] as string;
            }


            if (Configuration.ContainsKey(FSM_ArgParser.LocationDescription) || 
                Configuration.ContainsKey(FSM_ArgParser.Location_Latitude) || 
                Configuration.ContainsKey(FSM_ArgParser.Location_Longitude) || 
                Configuration.ContainsKey(FSM_ArgParser.RecordingDate))
            {
                Parts += ",recordingDetails";
                video.RecordingDetails = new VideoRecordingDetails();

                if (Configuration.ContainsKey(FSM_ArgParser.LocationDescription))
                    video.RecordingDetails.LocationDescription = Configuration[FSM_ArgParser.LocationDescription] as string;

                if (Configuration.ContainsKey(FSM_ArgParser.RecordingDate))
                    video.RecordingDetails.RecordingDate = (DateTime)Configuration[FSM_ArgParser.RecordingDate];

                if (Configuration.ContainsKey(FSM_ArgParser.Location_Latitude) ||
                Configuration.ContainsKey(FSM_ArgParser.Location_Longitude))
                {
                    video.RecordingDetails.Location = new GeoPoint();
                    if (Configuration.ContainsKey(FSM_ArgParser.Location_Latitude))
                        video.RecordingDetails.Location.Latitude = (double)Configuration[FSM_ArgParser.Location_Latitude];

                    if (Configuration.ContainsKey(FSM_ArgParser.Location_Longitude))
                        video.RecordingDetails.Location.Longitude = (double)Configuration[FSM_ArgParser.Location_Longitude];
                }
            }

            string filePath = Configuration[FSM_ArgParser.File] as string;

            Console.WriteLine("Selected file: {0} ", filePath);
            Console.WriteLine("File size: {0} ", FileSize);

            int Chunksize = (int)((FileSize / 100) / ResumableUpload<Video>.MinimumChunkSize) * ResumableUpload<Video>.MinimumChunkSize;
            if (FileSize < ResumableUpload<Video>.MinimumChunkSize)
                Chunksize = ResumableUpload<Video>.MinimumChunkSize;
            else if (FileSize > (ResumableUpload<Video>.MinimumChunkSize * 4 * 40))
                Chunksize = ResumableUpload<Video>.MinimumChunkSize * 4 * 40;

            using (FileStream fileStream = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.Read, Chunksize / 8))
            {
                Console.WriteLine("Starting upload.");

                VideosResource.InsertMediaUpload videosInsertRequest = youtubeService.Videos.Insert(video, Parts, fileStream, "video/*");

                videosInsertRequest.ChunkSize = Chunksize;

                videosInsertRequest.ProgressChanged += videosInsertRequest_ProgressChanged;
                TimeMbps = DateTime.Now;
                DataMbps = 0;

                try
                {
                    videosInsertRequest.Upload();
                }
                catch
                {
                }

                const int max_resumes = 25;
                int resumes = 0;
                while((videosInsertRequest.GetProgress().Status != UploadStatus.Completed) && resumes < max_resumes)
                {
                    resumes++;
                    try
                    {
                        videosInsertRequest.Resume();
                    }
                    catch
                    {
                    }
                }

                VideoID = videosInsertRequest.ResponseBody.Id;

                if (videosInsertRequest.GetProgress().Status != UploadStatus.Completed)
                {
                    Console.Error.Write("Upload failed.");
                    throw new Exception("Upload failed.");
                }

                fileStream.Close();
                fileStream.Dispose();
            }

            if (Configuration.ContainsKey(FSM_ArgParser.DisableComment) || Configuration.ContainsKey(FSM_ArgParser.DisableRating) || Configuration.ContainsKey(FSM_ArgParser.DisableVideoRespond))
            {
                Console.WriteLine(
                    "Warning: DisableComment, DisableRating and DisableVideoRespond are no longer functional due to the decrepation of the YouTube v2 API.\n" +
                    "Google refuses to include these options into the YouTube v3 API.\n" +
                    "Please use the YouTube web UI to manipulate these options."
                );
            }
        }

        private static DateTime TimeMbps;
        private static long DataMbps;

        internal static void videosInsertRequest_ProgressChanged(IUploadProgress progress)
        {
            switch (progress.Status)
            {
                case UploadStatus.Uploading:
                    DateTime Now = DateTime.Now;
                    TimeSpan DeltaT = Now - TimeMbps;
                    long DeltaD = progress.BytesSent - DataMbps;
                    string Mbps = (((double)DeltaD * 8.0d / 1000.0d / 1000.0d) / (double)DeltaT.TotalSeconds).ToString(System.Globalization.CultureInfo.InvariantCulture) + " Mbps";
                    TimeMbps = Now;
                    DataMbps = progress.BytesSent;
                    Console.WriteLine("Percent complete: {0}  \t|\tBytes sent: {1}\t|\t{2}", (double)progress.BytesSent / (double)FileSize * 100.0d, progress.BytesSent, Mbps);
                    break;

                case UploadStatus.Failed:
                    Console.Error.WriteLine("An error prevented the upload from completing.\n{0}", progress.Exception);
                    break;
            }
        }
    }
}