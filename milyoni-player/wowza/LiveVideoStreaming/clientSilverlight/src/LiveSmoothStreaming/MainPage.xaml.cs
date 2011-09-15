using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Ink;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;
using Microsoft.Web.Media.SmoothStreaming;
using System.Windows.Interop;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

namespace LiveSmoothStreaming
{
    public partial class MainPage : UserControl
    { 
        Boolean manifestChanged = true;
        Boolean manifestLoad = true;
        double playerWidth;
        double playerHeight;
        double currentWidth;
        double currentHeight;
        ulong highRate = 200000;
          
        public MainPage()
        {
            InitializeComponent();
            
            SmoothPlayer.ManifestReady += new EventHandler<EventArgs>(SmoothPlayer_ManifestReady);
            SmoothPlayer.MediaOpened += new RoutedEventHandler(SmoothPlayer_MediaOpened); //new EventHandler<EventArgs>(SmoothPlayer_MediaOpened);
            SmoothPlayer.MediaEnded += new RoutedEventHandler(SmoothPlayer_MediaEnded);
            SmoothPlayer.MediaFailed += new EventHandler<ExceptionRoutedEventArgs>(SmoothPlayer_MediaFailed);
            SmoothPlayer.SmoothStreamingErrorOccurred += new EventHandler<SmoothStreamingErrorEventArgs>(SmoothPlayer_SmoothStreamingErrorOccurred);
            SmoothPlayer.ClipError += new EventHandler<ClipEventArgs>(SmoothPlayer_ClipError);
            SmoothPlayer.DownloadTrackChanged += new EventHandler<TrackChangedEventArgs>(SmoothPlayer_TrackChanged);
            SmoothPlayer.PlaybackTrackChanged += new EventHandler<TrackChangedEventArgs>(SmoothPlayer_TrackChanged);
            App.Current.Host.Content.FullScreenChanged +=new EventHandler(Content_FullScreenChanged);
        }
       
        void UserControl_Loaded(object sender, RoutedEventArgs e)
        {
            //SmoothPlayer.SmoothStreamingSource = new Uri(ManifestURL.Text);
            SmoothPlayer.Volume = .5;
            VolumeBar.Value = 5;
        }

        void SmoothPlayer_ManifestReady(object sender, EventArgs e)
        {
            SmoothPlayer.Volume = VolumeBar.Value * .1;
            OutPut.Text = "";
            PlayButton.IsEnabled = true;
            currentWidth = this.Width;
            currentHeight = this.Height;

            if (!manifestChanged)
            {
                PlayButton.Content = "Play";
                BWCombo.IsEnabled = true;
            }

            foreach (SegmentInfo segment in SmoothPlayer.ManifestInfo.Segments)
            {
                IList<StreamInfo> streamInfoList = segment.AvailableStreams;

                foreach (StreamInfo stream in streamInfoList)
                {
                    if (stream.Type == MediaStreamType.Video)
                    {
                        List<TrackInfo> tracks = new List<TrackInfo>();

                        tracks = stream.AvailableTracks.ToList<TrackInfo>();

                        if (manifestLoad)
                        {
                            List<Bitrate> bitRates = new List<Bitrate>();

                            ulong highest = 0;
                            int selectThis = 0;

                            for (int i = 0; i < tracks.Count; i++)
                            {
                                if (tracks[i].Bitrate > highest)
                                {
                                    selectThis = i;
                                    highRate = tracks[i].Bitrate + 1;
                                }
                                bitRates.Add(new Bitrate() { bitrate = tracks[i].Bitrate + 1, display = Math.Round(Convert.ToDecimal((tracks[i].Bitrate * .001))).ToString() + "kbs" });
                            }
                            bitRates.Add(new Bitrate() { bitrate = highRate + 1, display = "Auto" });
                            try
                            {
                                BWCombo.ItemsSource = bitRates;
                            }
                            catch { }

                            if (bitRates.Count < 3)
                            {
                                BWCombo.Visibility = System.Windows.Visibility.Collapsed;
                            }
                            else
                            {
                                BWCombo.Visibility = System.Windows.Visibility.Visible;
                            }

                            BWCombo.DisplayMemberPath = "display";
                            BWCombo.SelectedIndex = bitRates.Count - 1;

                            if (manifestLoad)
                            {
                                manifestLoad = false;

                                if ((String)PlayButton.Content == "Stop")
                                {
                                    SmoothPlayer.SmoothStreamingSource = null;
                                    BWCombo.IsEnabled = true;
                                    PlayButton.Content = "Play";
                                }
                            }
                        }

                        IList<TrackInfo> allowedTracks = tracks.Where((ti) => ti.Bitrate < highRate).ToList();
                        System.Diagnostics.Debug.WriteLine(highRate.ToString());
                        stream.SelectTracks(allowedTracks, false);
                    }
                }
            }
        }

        void SmoothPlayer_MediaOpened(object sender, EventArgs e)
        { 
            double frameAspectRatio = 640 / 320;
            double videoWidth = SmoothPlayer.NaturalVideoWidth;
            double videoHeight = SmoothPlayer.NaturalVideoHeight;
            double videoAspectRatio = videoWidth / videoHeight;

            playerHeight = currentHeight;
            playerWidth = currentWidth;
            if (videoAspectRatio > frameAspectRatio)
            {
                playerHeight = currentHeight / videoAspectRatio;
            }
            else
            {
                playerWidth = currentHeight * videoAspectRatio;
            }

            SmoothPlayer.Height = playerHeight;
            SmoothPlayer.Width = playerWidth;
            if (manifestChanged)
            {
                manifestChanged = false;
                PlayButton_Click(null, null);
            }
            OutPut.Text = "";
        }

        void SmoothPlayer_MediaEnded(object sender, EventArgs e)
        {
            PlayButton_Click(null, null);
        }

        void SmoothPlayer_MediaFailed(object sender, ExceptionRoutedEventArgs e)
        {
            OutPut.Text = "Media Error: " + e.ErrorException.Message;
            reset();
        }

        void SmoothPlayer_SmoothStreamingErrorOccurred(object sender, SmoothStreamingErrorEventArgs e)
        {
            OutPut.Text = "Streaming Error: " + e.ErrorMessage;
            reset();
        }

        void SmoothPlayer_ClipError(object sender, ClipEventArgs e)
        {
            OutPut.Text = "Clip Error: " + e.Context.CurrentClipState.ToString();
        }

        void reset()
        {
            manifestChanged = true;
            manifestLoad = true;
            PlayButton.Content = "Play";
            PlayButton.IsEnabled = true;
            BWCombo.Visibility = System.Windows.Visibility.Collapsed;
            SmoothPlayer.SmoothStreamingSource = null;
            BitRate.Text = "0";
            BWCombo.IsEnabled = true;

        }

        void SmoothPlayer_TrackChanged(object sender, TrackChangedEventArgs e)
        {
            BitRate.Text = Math.Round(Convert.ToDecimal((e.NewTrack.Bitrate * .001))).ToString() + "kbs";
        }

        void PlayButton_Click(object sender, RoutedEventArgs e)
        {
            OutPut.Text = "";

            if (manifestChanged)
            {
                SmoothPlayer.SmoothStreamingSource = new Uri(ManifestURL.Text);
                return;
            }

            if ((String)PlayButton.Content=="Play")
            {
                SmoothPlayer.Play();

                PlayButton.Content = "Stop";
                fullScreenButton.Visibility = System.Windows.Visibility.Visible;
                BWCombo.IsEnabled = false;
            }
            else if ((String)PlayButton.Content=="Stop")
            {
                SmoothPlayer.Stop();
                SmoothPlayer.SmoothStreamingSource = null;
                manifestChanged = true;
                PlayButton.Content = "Play";
                fullScreenButton.Visibility = System.Windows.Visibility.Collapsed;
                BitRate.Text = "0";
                BWCombo.IsEnabled = true;
            }
        }

        void Content_FullScreenChanged(object sender, EventArgs e)
        {
            Boolean isFullScreen = Application.Current.Host.Content.IsFullScreen;

            if (!isFullScreen)
            {
                Grid.SetRowSpan(SmoothPlayer, 1);
                SmoothPlayer.Width = playerWidth;
                SmoothPlayer.Height = playerHeight;
                grid2.Visibility = System.Windows.Visibility.Visible;
                SmoothPlayer.Background = new SolidColorBrush(Colors.White);
                SmoothPlayer.HorizontalAlignment = HorizontalAlignment.Left;
                LayoutRoot.Background = new SolidColorBrush(Colors.White);
                SmoothPlayer.Margin = new Thickness(10, 12, 0, 0);

            }
        }

        void Fullscreen_Click(object sender, RoutedEventArgs e)
        {
            Application.Current.Host.Content.IsFullScreen = (Application.Current.Host.Content.IsFullScreen) ? false : true;

            if (!Application.Current.Host.Content.IsFullScreen)
            {
                Grid.SetRowSpan(SmoothPlayer, 1);
                SmoothPlayer.Width = playerWidth;
                SmoothPlayer.Height = playerHeight;
                grid2.Visibility = System.Windows.Visibility.Visible;
                SmoothPlayer.Background = new SolidColorBrush(Colors.White);
                SmoothPlayer.HorizontalAlignment = HorizontalAlignment.Left;
                LayoutRoot.Background = new SolidColorBrush(Colors.White);
                SmoothPlayer.Margin = new Thickness(10, 12, 0, 0);
            }
            else
            {
                Grid.SetRowSpan(SmoothPlayer, 2);
                SmoothPlayer.Width = this.Width;
                SmoothPlayer.Height = this.Height;
                playerWidth = SmoothPlayer.Width;
                playerHeight = SmoothPlayer.Height;
                grid2.Visibility = System.Windows.Visibility.Collapsed;
                SmoothPlayer.Background = new SolidColorBrush(Colors.Black);
                SmoothPlayer.HorizontalAlignment = HorizontalAlignment.Center;
                LayoutRoot.Background = new SolidColorBrush(Colors.Black);
                SmoothPlayer.Margin = new Thickness(0, 0, 0, 0);
            }
        }

        void VolumeBar_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
        {
            SmoothPlayer.Volume = VolumeBar.Value * .1;
        }

        private void ManifestURL_KeyDown(object sender, KeyEventArgs e)
        {
            manifestChanged = true;
            manifestLoad = true;
            PlayButton.IsEnabled = true;
        }

        public class Bitrate
        {
            public ulong bitrate { get; set; }
            public string display { get; set; }
        }
        private void BWCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            Bitrate br = (Bitrate)BWCombo.SelectedItem;
            highRate = br.bitrate;
        }
    }
}