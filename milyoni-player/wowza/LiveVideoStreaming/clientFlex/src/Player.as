package
{
	import com.meychi.ascrypt.TEA;
	
	import flash.events.*;
	import flash.external.ExternalInterface;
	import flash.geom.*;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.Responder;
	import flash.system.Capabilities;
	import flash.system.Security;
	import flash.utils.clearInterval;
	import flash.utils.setInterval;
	import flash.utils.setTimeout;
	
	import mx.controls.Button;
	import mx.controls.HSlider;
	import mx.controls.Image;
	import mx.controls.Text;
	import mx.controls.TextInput;
	import mx.core.Application;
	import mx.core.UIComponent;
	import mx.events.FlexEvent;
	import mx.events.SliderEvent;

	public class Player extends Application
	{	
		Security.LOCAL_TRUSTED;
		
		public var movieName:String = "myStream";
		public var serverName:String = "rtmp://localhost/live";
		private var sharedSecret:String = "#ed%h0#w@1";
		private var nc:NetConnection = null;
		[Bindable]
		public var isConnected:Boolean = false;
		private var nsPlay:NetStream = null;
		private var duration:Number = 0;
		private var progressTimer:Number = 0;
		private var isPlaying:Boolean = false;	
		private var videoObj:Video;
		private var isProgressUpdate:Boolean = false;
		private var fullscreenCapable:Boolean = false;
		private var hardwareScaleCapable:Boolean = false;
		public var doRewind:Button;
		public var doFastRev:Button;
		public var doFastFwd:Button;
		public var doPlay:Button;
		public var connectButton:Button;
		public var doSlowMotion:Button;
		public var doFullscreen:Button;
		public var slider:HSlider;
		private var t:SoundTransform = new SoundTransform();
		private var params:Object = new Object();
		public var volumeLevel:HSlider;
		public var isScrubbing:Boolean;
		public var videoContainer:UIComponent;
		private var loc:String;
		public var connectStr:TextInput;
		public var streamStr:TextInput;
		public var logo:Image;
		public var fpsText:Text;
		public var playerVersion:Text;
		public var prompt:Text;
		private var saveVideoObjX:Number;
		private var saveVideoObjY:Number;
		private var saveVideoObjW:Number;
		private var saveVideoObjH:Number;
		private var saveStageW:Number;
		private var saveStageH:Number;
		private var adjVideoObjW:Number;
		private var adjVideoObjH:Number;
		private var videoSizeTimer:Number = 0;
		private var videoLastW:Number = 0;
		private var videoLastH:Number = 0;
		private var debugInterval:Number = 0;
		private var bufferTime:Number = 3;
				
		public function Player()
		{
			addEventListener(FlexEvent.APPLICATION_COMPLETE,mainInit);
			addEventListener(FullScreenEvent.FULL_SCREEN, enterLeaveFullscreen );
		}
		
		private function mainInit(event:FlexEvent):void
		{	
			stage.align="TL";
			stage.scaleMode="noScale";
			
			// get movie name from parameter is defined
			if (loaderInfo.parameters.zmovieName != undefined)
				movieName = loaderInfo.parameters.zmovieName;
				
			if (loaderInfo.parameters.zserverName != undefined)
				serverName = loaderInfo.parameters.zserverName;
			
			videoObj = new Video();
			videoContainer.addChild(videoObj);
			videoObj.width = 400;
			videoObj.height = 300;
			saveVideoObjX = videoObj.x;
			saveVideoObjY = videoObj.y;
			adjVideoObjW = (saveVideoObjW = videoObj.width);
			adjVideoObjH = (saveVideoObjH = videoObj.height);
		
			volumeLevel.addEventListener(SliderEvent.CHANGE,adjustVolume);
			doFullscreen.addEventListener(MouseEvent.CLICK,enterFullscreen);
			
			streamStr.text = movieName;
			connectStr.text = serverName;
			connectButton.addEventListener(MouseEvent.CLICK,connectLivePlayer);
			
			fullscreenCapable = testVersion(9, 0, 28, 0);
			hardwareScaleCapable = testVersion(9, 0, 60, 0);
			
			if (ExternalInterface.available && Application.application.url.search( /http*:/ ) == 0)
			{
				loc = ExternalInterface.call("function(){return window.location.href;}");
				trace("This player served from: " + loc); // you can do client-side hotlink denial here
			}
			
			var h264Capable:Boolean = testVersion(9, 0, 115, 0);
			playerVersion.text = (h264Capable?"H.264 Ready (":"No H.264 (")+Capabilities.version+")";
			
			if (!h264Capable)
				playerVersion.styleName="alert";				
		}
		
		private function ncOnStatus(infoObject:NetStatusEvent):void
		{
			trace("nc.onStatus: "+infoObject.info.code+" ("+infoObject.info.description+")");
			for (var prop:String in infoObject)
			{
				trace("\t"+prop+":\t"+infoObject.info[prop]);
			}
			
			// once we are connected to the server create the nsPlay NetStream object
			if (infoObject.info.code == "NetConnection.Connect.Success")
			{
				if (infoObject.info.secureToken != undefined) //<--- SecureToken change here - respond with decoded secureToken
				{
					var secureResult:Object = new Object();
					secureResult.onResult = function(isSuccessful:Boolean):void
					{
						trace("secureTokenResponse: "+isSuccessful);
					}
					nc.call("secureTokenResponse", new Responder(secureResult.onResult), TEA.decrypt(infoObject.info.secureToken, sharedSecret));		
				}
				
				isConnected = true;
				playLiveStream();
				videoLastW = 0;
				videoLastH = 0;
				videoSizeTimer = setInterval(updateVideoSize, 500);
			}
			else if (infoObject.info.code == "NetConnection.Connect.Failed")
				prompt.text = "Connection failed: Try rtmp://[server-ip-address]/simplevideostreaming";
			else if (infoObject.info.code == "NetConnection.Connect.Rejected")
				if(infoObject.info.ex) 
					if (infoObject.info.ex.code == 302) {
					setTimeout(function():void{
						trace("Redirect to: " + arguments[0]);
						nc.connect(arguments[0]);
					},100,infoObject.info.ex.redirect);	
				}
				else
				{
					prompt.text = infoObject.info.description;
				}
		}
				
		private function connectLivePlayer(event:MouseEvent):void
		{
			if (nc == null)
			{
				//enablePlayControls(true);
				nc = new NetConnection();
				nc.addEventListener(NetStatusEvent.NET_STATUS, ncOnStatus);
				nc.connect(connectStr.text);
						
				// uncomment this to monitor frame rate and buffer length
				// debugInterval = setInterval(updateStreamValues, 500);
				
				connectButton.label = "Stop";
			}
			else
			{
				videoObj.attachNetStream(null);
				videoObj.clear();
				videoObj.visible = false;
				duration = 0;
				
				nc.close();
				nc = null;
		
				if (debugInterval > 0)
					clearInterval(debugInterval);
				debugInterval = 0;
				
				connectButton.label = "Play";
				prompt.text = "";
				isConnected = false;
			}
		}	
	
		// function to monitor the frame rate and buffer length
		private function updateStreamValues():void
		{
			var newVal:String = "";
			if (nsPlay != null)
				newVal = (Math.round(nsPlay.currentFPS*1000)/1000)+" fps/"+(Math.round(nsPlay.bufferLength*1000)/1000)+" secs";
			fpsText.text = newVal;
		}
		
		private function nsOnStatus(infoObject:NetStatusEvent):void
		{
			trace("onStatus: ");
			for (var propName:String in infoObject.info)
			{
				trace("  "+propName + " = " + infoObject.info[propName]);
			}
			
			if (infoObject.info.code == "NetStream.Play.Start")
				isProgressUpdate = true;
			else if (infoObject.info.code == "NetStream.Play.StreamNotFound" || infoObject.info.code == "NetStream.Play.Failed")
				prompt.text = infoObject.info.description;
		}
		
		// create the nsPlay NetStream object
		private function playLiveStream():void
		{
			nsPlay = new NetStream(nc);
			nsPlay.addEventListener(NetStatusEvent.NET_STATUS, nsOnStatus);
			
			var nsPlayClientObj:Object = new Object();
			nsPlay.client = nsPlayClientObj;
			
			nsPlayClientObj.onMetaData = function(infoObject:Object):void
			{
				trace("onMetaData");
				
				// print debug information about the metaData
				for (var propName:String in infoObject)
				{
					trace("  "+propName + " = " + infoObject[propName]);
				}
			};	
			// print debug information when we play status changes
			nsPlayClientObj.onPlayStatus = function(infoObject:Object):void
			{
				trace("onPlayStatus");
				for (var prop:String in infoObject)
				{
					trace("\t"+prop+":\t"+infoObject[prop]);
				}
			};
			
			// set the buffer time and attach the video and audio
			nsPlay.bufferTime = bufferTime;
			
			// subscribe to the named stream
			nsPlay.play(streamStr.text);	
			
			videoObj.attachNetStream(nsPlay);
		}
	
	
		private function updateVideoSize():void
		{
			trace("updateVideoSize: "+stage["displayState"]);
			
			// when we finally get a valid video width/height resize the video frame to make it proportional
			if (videoObj.videoWidth != videoLastW || videoObj.videoHeight != videoLastH)
			{
				videoLastW = videoObj.videoWidth;
				videoLastH = videoObj.videoHeight;
		
				var videoAspectRatio:Number = videoLastW/videoLastH;
				var frameAspectRatio:Number = saveVideoObjW/saveVideoObjH;
				
				adjVideoObjW = saveVideoObjW;
				adjVideoObjH = saveVideoObjH;
				if (videoAspectRatio > frameAspectRatio)
					adjVideoObjH = saveVideoObjW/videoAspectRatio;
				else
					adjVideoObjW = saveVideoObjH*videoAspectRatio;
				
				videoObj.width = adjVideoObjW;
				videoObj.height = adjVideoObjH;
				videoContainer.width = videoObj.width;
				videoContainer.height = videoObj.height;
				videoObj.visible = true;
			}
			else
				clearInterval(videoSizeTimer);
		}
	
		// show/hide the controls when we enter/leave fullscreen
		private function hideAllControls(doHide:Boolean):void
		{
			fpsText.visible = !doHide;
			logo.visible = !doHide;
			connectButton.visible = !doHide;
			doFullscreen.visible = !doHide;
			slider.visible = !doHide;
			playerVersion.visible = !doHide;
		}
		
		private function enterLeaveFullscreen(fsEvent:FullScreenEvent):void
		{
			trace("enterLeaveFullscreen: "+fsEvent.fullScreen);
			
			hideAllControls(fsEvent.fullScreen);
			if (!fsEvent.fullScreen)
			{
				// reset back to original state
				stage.scaleMode = "noScale";
				trace("adjVideoObjW 1: " + adjVideoObjW);
				trace("adjVideoObjH 1: " + adjVideoObjH);				
				videoObj.width = adjVideoObjW;
				videoObj.height = adjVideoObjH;
				videoObj.y = saveVideoObjY + saveVideoObjH - adjVideoObjH;
				videoObj.x = (saveStageW - adjVideoObjW)/2;
			}
		}
		
		private function enterFullscreen(event:MouseEvent):void
		{
			trace("enterFullscreen: "+hardwareScaleCapable);
			if (hardwareScaleCapable)
			{
				// best settings for hardware scaling
				videoObj.smoothing = false;
				videoObj.deblocking = 0;
				
				// grab the portion of the stage that is just the video frame
				stage["fullScreenSourceRect"] = new Rectangle(
					videoObj.x, videoObj.y, 
					videoObj.width, videoObj.height);
			}
			else
			{
				stage.scaleMode = "noBorder";
				
				var videoAspectRatio:Number = videoObj.width/videoObj.height;
				var stageAspectRatio:Number = saveStageW/saveStageH;
				var screenAspectRatio:Number = Capabilities.screenResolutionX/Capabilities.screenResolutionY;
				
				// calculate the width and height of the scaled stage
				var stageObjW:Number = saveStageW;
				var stageObjH:Number = saveStageH;
				if (stageAspectRatio > screenAspectRatio)
					stageObjW = saveStageH*screenAspectRatio;
				else
					stageObjH = saveStageW/screenAspectRatio;
		
				// calculate the width and height of the video frame scaled against the new stage size
				var fsVideoObjW:Number = stageObjW;
				var fsVideoObjH:Number = stageObjH;
				if (videoAspectRatio > screenAspectRatio)
					fsVideoObjH = stageObjW/videoAspectRatio;
				else
					fsVideoObjW = stageObjH*videoAspectRatio;
				
				// scale the video object
				videoObj.width = fsVideoObjW;
				videoObj.height = fsVideoObjH;
				videoObj.x = (stageObjW-fsVideoObjW)/2.0;
				videoObj.y = (stageObjH-fsVideoObjH)/2.0;
			}
			stage["displayState"] = "fullScreen";	
		}
		
		private function playStream():void
		{
			var timecode:Number = nsPlay.time;
			isProgressUpdate = false;
			
			if (!isPlaying)
				nsPlay.resume();
			nsPlay.seek(timecode);
			isPlaying = true;	
		}
		
		private function doPlayToggle(event:MouseEvent):void
		{			
			if (!isPlaying)
			{
				playStream();
				doPlay.label = "pause";
			}
			else
			{
				doPlay.label = "play";
				isProgressUpdate = false;
				isPlaying = false;
				nsPlay.pause();
			}
		}
			
		public function streamRewind(event:Event):void
		{
			if (nsPlay==null) return;
			slider.value=0;
			nsPlay.seek(0);
		}
			
		public function adjustVolume(event:SliderEvent):void
		{
			if (nsPlay==null) return;
			
			var vol:Number;
			
			if (event==null)
			{
				vol = volumeLevel.value	
			} else {
				vol = event.value;
			}
			
			t.volume = vol;
			try{	
			nsPlay.soundTransform = t;
			}
			catch(e:Error)
			{
			 	trace(e.message);
			}
		}
			
		public function movieSeek(event:Event):void
		{
			if (nsPlay == null) return;
			
			if (doPlay.styleName=="pauseButton")
			{
				nsPlay.resume();
			}			
			nsPlay.seek(slider.value);			
		}
			
		private function testVersion(v0:Number, v1:Number, v2:Number, v3:Number):Boolean
		{
			var version:String = Capabilities.version;
			var index:Number = version.indexOf(" ");
			version = version.substr(index+1);
			var verParts:Array = version.split(",");
			
			var i:Number;
			
			var ret:Boolean = true;
			while(true)
			{
				if (Number(verParts[0]) < v0)
				{
					ret = false;
					break;
				}
				else if (Number(verParts[0]) > v0)
					break;
					
				if (Number(verParts[1]) < v1)
				{
					ret = false;
					break;
				}
				else if (Number(verParts[1]) > v1)
					break;
					
				if (Number(verParts[2]) < v2)
				{
					ret = false;
					break;
				}
				else if (Number(verParts[2]) > v2)
					break;
					
				if (Number(verParts[3]) < v3)
				{
					ret = false;
					break;
				}
				break;
			}
			trace("testVersion: "+Capabilities.version+">="+v0+","+v1+","+v2+","+v3+": "+ret);	
			return ret;
		}			
	}
}