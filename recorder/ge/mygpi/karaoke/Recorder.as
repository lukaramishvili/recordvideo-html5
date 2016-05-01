package ge.mygpi.karaoke {
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.display.BitmapData;
	import flash.display.Bitmap;
	import flash.geom.Rectangle;
	import flash.geom.Point;
	import flash.display.MovieClip;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.media.Microphone;
	import org.bytearray.micrecorder.*;
	import org.bytearray.micrecorder.events.RecordingEvent;
	import org.bytearray.micrecorder.encoder.WaveEncoder;
	import flash.system.Security;
	import flash.utils.ByteArray;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	import flash.display.GradientType;
	import flash.media.SoundTransform;
	import flash.net.URLRequest;
	import flash.net.URLVariables;
	import flash.net.URLLoader;
	import flash.net.URLRequestMethod;
	import flash.net.URLLoaderDataFormat;
	import flash.events.HTTPStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.IOErrorEvent;
	import flash.net.URLRequestHeader;
	import flash.events.ProgressEvent;
	import flash.display.JPEGEncoderOptions;
	import flash.display.PNGEncoderOptions;
	import flash.display.LoaderInfo;
	import flash.external.ExternalInterface;
	import flash.display.Shape;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	import flash.utils.clearInterval;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.text.TextFieldAutoSize;
	import flash.text.engine.TextBaseline;
	import flash.events.KeyboardEvent;


	public class Recorder extends Sprite {
		// parameters
		private var recW: int;
		private var recH: int;
		//stage scales
		private var centerX: int = 80;
		private var heightProportion = 0.75;

		private var effectsEnabled = false;

		private var camera: Camera;
		private var camW: int = Camera.getCamera().width;
		private var camH: int = Camera.getCamera().height;
		private var video: Video;
		private var renderData: BitmapData;
		private var render: Bitmap;

		private var frames: Array;

		private var mic: Microphone;
		private var waveEncoder: WaveEncoder;
		private var audioRecorder: MicRecorder;

		private var recording: Boolean = false;

		private var audioVis: Sprite;
		private var audioVisW: int = 110;
		private var audioVisH: int = 5;

		private var overlayBg: MovieClip;

		private var saveBtn: MovieClip;

		private var preloader: MovieClip;

		private var defaultTitle = "დაასათაურე";

		private var titleInput: TextField;

		private var effectsToggle: MovieClip;

		private var httpPostDest; // = "http://localhost:8000";
		private var conn: NetConnection;
		private var stream: NetStream;

		private var autoStopTimeout: uint = 0;

		public function Recorder(argRecW, argRecH): void {
			this.httpPostDest = "http://" + ExternalInterface.call("window.location.host.toString");
			this.recW = argRecW;
			this.recH = argRecH;
			camera = Camera.getCamera();
			camera.setMode(camW, camH, 30);
			mic = Microphone.getMicrophone();
			mic.setSilenceLevel(0);
			mic.gain = 100;
			mic.setLoopBack(true);
			mic.setUseEchoSuppression(true);
			//don't play sound that's being recorded
			var st: SoundTransform = new SoundTransform(0);
			mic.soundTransform = st;
			waveEncoder = new WaveEncoder();
			audioRecorder = new MicRecorder(waveEncoder);
			Security.showSettings("2");
			video = new Video(camW, camH);
			video.attachCamera(camera);
			renderData = new BitmapData(camW, camH);
			render = new Bitmap(renderData);
			render.name = "render";
			frames = new Array();

			overlayBg = getOverlayBg();
			overlayBg.visible = false;

			audioVis = new MovieClip();
			audioVis.visible = false;

			saveBtn = getSaveBtn();
			saveBtn.visible = false;

			preloader = getPreloader();

			titleInput = getTitleInput();
			titleInput.visible = false;

			effectsToggle = getEffectsToggle();
			effectsToggle.visible = false;

			//TODO both lines
			//conn = new NetConnection();
			//stream = new NetStream(conn);


			if (camera != null && mic != null) {

				saveBtn.addEventListener(MouseEvent.CLICK, toggleRecord);
				addEventListener(Event.ENTER_FRAME, updateRender);
				//addEventListener(Event.ENTER_FRAME, drawAudioVis);
				//audioRecorder.addEventListener(RecordingEvent.RECORDING, whileRecordingAudio);


				render.x = render.y = 0;
				//render.width = this.width;
				//render.height = this.height;
				render.visible = false;
				preloader.visible = false;
				addChild(render);
				addChild(overlayBg);
				addChild(audioVis);
				addChild(titleInput);
				addChild(effectsToggle);
				//add higher, otherwise effectsToggle covers it
				addChild(saveBtn);
				//set w/h after adding children; setting w/h doesn't work on empty Sprites
				this.width = this.recW;
				this.height = this.recH;
				//preloader should be here, otherwise breaks movie boundaries
				addChild(preloader);
				
				ExternalInterface.addCallback("startFlashRecording", function(){
					startRecording();
				});
				ExternalInterface.addCallback("stopFlashRecording", function(){
					stopRecording();
				});
			} else {
				//TODO: error message to user: you must allow camera and mic access
			}
		}

		public function getSaveBtn(): MovieClip {
			var saveBtn: MovieClip = new MovieClip();
			saveBtn.buttonMode = true;
			var saveBtnRad = 7.5;
			saveBtn.x = this.centerX; //this.recW / 2 - saveBtnRad;
			saveBtn.y = 103; //this.recH - 100 - saveBtnRad * 2;
			var mat: Matrix = new Matrix();
			var colors = [0xFF0000, 0xCC0000];
			var alphas = [1, 1];
			var ratios = [0, 255];
			mat.createGradientBox(2 * saveBtnRad, 2 * saveBtnRad, 0, -saveBtnRad, -saveBtnRad);

			//white round border
			var wb: MovieClip = new MovieClip();
			wb.graphics.lineStyle(2, 0xFFFFFF);
			wb.graphics.drawCircle(0, 0, saveBtnRad + 1.6);
			wb.height = wb.height * heightProportion;
			saveBtn.addChild(wb);

			var saveBtnStart: MovieClip = new MovieClip();
			saveBtnStart.name = "save_btn_start";
			saveBtnStart.graphics.lineStyle();
			saveBtnStart.graphics.beginGradientFill(GradientType.RADIAL, colors, alphas, ratios, mat);
			saveBtnStart.graphics.drawCircle(0, 0, saveBtnRad);
			saveBtnStart.graphics.endFill();
			saveBtnStart.width = saveBtnRad * 2;
			saveBtnStart.height = saveBtnRad * 2 * heightProportion;
			saveBtn.addChild(saveBtnStart);

			var saveBtnStop: MovieClip = new MovieClip();
			saveBtnStop.name = "save_btn_stop";
			saveBtnStop.graphics.lineStyle();
			saveBtnStop.graphics.beginGradientFill(GradientType.RADIAL, colors, alphas, ratios, mat);
			saveBtnStop.graphics.drawRoundRect(0, 0, saveBtnRad * 1.2, saveBtnRad * 1.2 * heightProportion, 2, 2);
			saveBtnStop.graphics.endFill();
			saveBtnStop.x = -saveBtnRad + 3;
			saveBtnStop.y = -saveBtnRad + 4.15;
			saveBtnStop.visible = false;
			saveBtn.addChild(saveBtnStop);
			return saveBtn;
		}

		public function toggleRecord(e: MouseEvent) {
			if (this.recording) {
				stopRecording();
			} else {
				startRecording();
			}
		}

		public function drawAudioVis(e: Event) {
			audioVis.x = 25; //this.recW / 2 - audioVisW / 2;
			audioVis.y = 113; //this.recH - 20 - audioVisH; //this.recH - 20 - audioVisH;
			audioVis.graphics.beginFill(0x000000);
			audioVis.graphics.drawRect(0, 0, this.audioVisW, this.audioVisH);
			audioVis.graphics.endFill();
			audioVis.graphics.beginFill(0xFF0000);
			audioVis.graphics.drawRect(0, 0, this.audioVisW * mic.activityLevel / 100, this.audioVisH);
			audioVis.graphics.endFill();
			audioVis.width = this.audioVisW;
			audioVis.height = this.audioVisH;
			//trace("TODO: now recording (draw EQ on audioVis)");
		}

		public function getOverlayBg() {
			var bg: MovieClip = new MovieClip();
			bg.graphics.beginFill(0x00000, 0.4);
			bg.graphics.drawRect(0, 92, 160, 28);
			bg.graphics.endFill();
			bg.x = 0;
			bg.y = 0;
			return bg;
		}

		//[Embed(source="/ge/mygpi/karaoke/assets/preloader.swf", symbol="PreloaderID")]
		//private var PreloaderAsset:Class;

		public function getPreloader() {
			var preloader: MovieClip = new PreloaderID();
			var cap: TextField = new TextField();
			cap.text = "ჩაწერა სრულდება";
			cap.autoSize = TextFieldAutoSize.CENTER;
			var fmt: TextFormat = new TextFormat();
			fmt.align = TextFormatAlign.CENTER;
			fmt.size = 4;
			fmt.color = 0xFFFFFF;
			cap.setTextFormat(fmt);
			cap.x = 0 - cap.width / 2;
			cap.y = 30;
			preloader.addChild(cap);

			preloader.x = this.centerX;
			preloader.y = 50;
			return preloader;
		}

		public function getPreloaderOld() {
			var preloaderRad = 40,
				preloaderHeart = 0.2,
				rotationDegree = 20,
				pX = 10,
				pY = 10;
			var center: Point = new Point(this.centerX, 45);
			var p: MovieClip = new MovieClip();
			p.x = center.x, p.y = center.y;
			function degFromRad(r) {
				return Math.PI * (r / 180);
			}
			var addRot = 0;
			p.addEventListener(Event.ENTER_FRAME, function () {
				p.graphics.clear();
				for (var i: int = addRot, deg = degFromRad(addRot); i < addRot + 360; i += rotationDegree, deg = degFromRad(i)) {
					p.graphics.lineStyle(0.8, 0xFFFFFF, 1, false, "normal", "square", null, 0);
					p.graphics.moveTo(preloaderRad * Math.cos(deg), preloaderRad * Math.sin(deg));
					p.graphics.lineTo(preloaderRad * preloaderHeart * Math.cos(deg), preloaderRad * preloaderHeart * Math.sin(deg));
				}
				addRot += 6;
			});
			p.scaleY = 0.8;
			return p;
		}

		public static function getNoCameraLabel() {
			var titleField: TextField = new TextField();
			titleField.type = TextFieldType.DYNAMIC;
			titleField.selectable = false;
			titleField.text = "ჩასაწერად აუცილებელია ვებკამერა";
			titleField.border = true;
			titleField.autoSize = TextFieldAutoSize.CENTER;
			titleField.x = 200 - titleField.width / 2; //this.centerX - titleField.width / 2;
			titleField.y = 180; //52;
			titleField.multiline = false;
			titleField.height = 30;
			titleField.maxChars = 30;
			var fmt: TextFormat = new TextFormat();
			fmt.align = TextFormatAlign.CENTER;
			fmt.size = 17; //16ze da 20ze (180ze dzaan cotati) echreboda teqsts qvemodan nacili //4;
			fmt.color = 0xFFFFFF;
			titleField.setTextFormat(fmt);
			return titleField;
		}

		public function getTitleInput() {
			var titleField: TextField = new TextField();
			titleField.type = TextFieldType.INPUT;
			titleField.selectable = true;
			titleField.text = this.defaultTitle;
			titleField.border = true;
			var titleBorder:uint = 0x000000;
			titleField.borderColor = titleBorder;
			titleField.autoSize = TextFieldAutoSize.CENTER;
			titleField.multiline = true;
			titleField.wordWrap = true;
			titleField.x = this.centerX - titleField.width / 2;
			titleField.y = 3;//10;
			titleField.height = 16;
			titleField.maxChars = 60;
			var fmt: TextFormat = new TextFormat();
			fmt.align = TextFormatAlign.CENTER;
			fmt.size = 7;
			titleField.setTextFormat(fmt);
			var wasClicked = false;
			titleField.addEventListener(MouseEvent.CLICK, function (e: MouseEvent) {
				if (!wasClicked) {
					wasClicked = true;
					titleField.text = "";
				}
			});
			titleField.addEventListener(KeyboardEvent.KEY_DOWN, function (e: KeyboardEvent) {
				titleField.borderColor = titleBorder;
			});
			return titleField;
		}

		public function getEffectsToggle() {
			var that = this;
			var container: MovieClip = new MovieClip();
			container.buttonMode = true;
			container.mouseChildren = false;
			var ckb: TextField = new TextField();
			ckb.multiline = false;
			ckb.autoSize = TextFieldAutoSize.NONE;
			ckb.condenseWhite = true;
			ckb.height = 20;
			var tf: TextFormat = new TextFormat();
			tf.color = 0xFFFFFF;
			tf.size = 8;
			ckb.defaultTextFormat = tf;
			ckb.text = that.effectsEnabled ? "☑ ეფექტი" : "☐ ეფექტი";
			//ckb.click wouldn't work, ckb won't receive mouse events as container.mouseChildren is false
			container.addEventListener(MouseEvent.CLICK, function (e: MouseEvent) {
				that.effectsEnabled = !that.effectsEnabled;
				ckb.text = that.effectsEnabled ? "☑ ეფექტი" : "☐ ეფექტი";
			});
			container.addChild(ckb);
			container.x = 0;
			container.y = 97;
			return container;
		}

		public function startRecording() {
			this.recording = true;
			MovieClip(saveBtn.getChildByName("save_btn_start")).visible = false;
			MovieClip(saveBtn.getChildByName("save_btn_stop")).visible = true;
			audioRecorder.record();
			this.autoStopTimeout = setTimeout(stopRecording, 60000);
		}

		public function stopRecording() {
			this.recording = false;
			clearTimeout(this.autoStopTimeout);
			audioRecorder.stop();
			//MovieClip(saveBtn.getChildByName("save_btn_start")).visible = true;
			//MovieClip(saveBtn.getChildByName("save_btn_stop")).visible = false;
			saveBtn.visible = false;
			overlayBg.visible = false;
			titleInput.visible = false;
			effectsToggle.visible = false;
			audioVis.visible = false;
			preloader.visible = true;
			ExternalInterface.call("window.afterStopRecording");
			//TODO: check user auth response
			//we tell the server to create a Video in db and tell us the id
			//then we push the jpeg's and audio to that id
			this.httpGet({
				url: this.httpPostDest + "/Video/Initializeupload?refresh=" + (new Date().time),
				success: function (data) {
					var video_id: String = data;
					var framesUploaded: int = 0;
					var audioUploaded = false;
					var processVideoIfAllUploadsFinished: Function = function () {
						//if all frames and audio are uploaded, then process the video
						if (audioUploaded && framesUploaded == frames.length) {
							//tell the server that we sent all the data;
							finalizeUpload(video_id, function (data) {
								//use relative URL to navigate to the server where the swf is located
								//also if we don't wait for finalizeupload, video processing may interrupt
								// /video/finalizeupload should spawn processing separately, so that if the
								// http request gets interrupted from flash side(navigating), processing still finishes
								//
								//flash.net.navigateToURL(new URLRequest("/Video/view/" + video_id), "_self");
								ExternalInterface.call("finalizeUploadCallback", video_id.toString());
							});
						}
					}
					//upload audio
					uploadAudio(video_id, audioRecorder.output, function (data) {
						audioUploaded = true;
						processVideoIfAllUploadsFinished();
					});
					for (var fi: int = 0; fi < frames.length; fi++) {
						var f: ByteArray = frames[fi];
						this.uploadFrame(video_id, f, function (data) {
							framesUploaded++;
							processVideoIfAllUploadsFinished();
						});
					}
				} //success
			});
		}

		//uploads bytearray to an URI - retrieve raw post data (e.g. php://input) on server-side
		private function postByteArray(dest: String, data: ByteArray, callback: Function = null) {
			var that = this;
			var _request: URLRequest = new URLRequest(dest);
			var loader: URLLoader = new URLLoader();
			_request.contentType = "application/octet-stream";
			_request.method = URLRequestMethod.POST;
			_request.data = data;
			loader.addEventListener(IOErrorEvent.IO_ERROR, function (e: IOErrorEvent): void {
				trace(e.text);
			});
			loader.addEventListener(Event.COMPLETE, function (e: Event) {
				if (callback != null) {
					callback.call(that, loader.data);
				}
			});
			loader.load(_request);
		}

		//use it as jQuery get - httpGet({url, data, success });
		public function httpGet(params) {
			var that = this;
			var data = (params.data == null) ? new Object() : params.data;
			var req: URLRequest = new URLRequest(params.url);
			req.method = URLRequestMethod.GET;
			var urlVariables: URLVariables = new URLVariables();
			for (var di in data) {
				urlVariables[di] = data[di];
			}
			req.data = urlVariables;
			var loader: URLLoader = new URLLoader(req);
			loader.dataFormat = URLLoaderDataFormat.TEXT;
			loader.addEventListener(Event.COMPLETE, function (e: Event) {
				if (params.hasOwnProperty("success") && params.success != null) {
					params.success.call(that, loader.data);
				}
			});
			loader.load(req);
		}

		//returns a video_id to which to send data
		//there's no synchronous http requests in as3, so this nice method wouldn't work
		//private function initializeUpload() {
		//	return this.loadHttpGetResult(this.httpPostDest + "/video/initializeupload");
		//}

		private function uploadFrame(video_id: String, frame: ByteArray, callback: Function = null) {
			this.postByteArray(this.httpPostDest + "/Video/Uploadframe/" + video_id, frame, callback);
		}

		private function uploadAudio(video_id: String, audio_data: ByteArray, callback: Function = null) {
			this.postByteArray(this.httpPostDest + "/video/Uploadaudio/" + video_id, audio_data, callback);
		}

		private function finalizeUpload(video_id: String, callback: Function) {
			this.httpGet({
				url: this.httpPostDest + "/Video/Finalizeupload/" + video_id,
				data: {
					title: titleInput.text
				},
				success: callback
			});
		}

		private var effects: Object = {
			"tunnel": function (bmpData: BitmapData) {
				var tunnelRadius: int = 50 / 2;
				var center: Point = new Point(Math.floor(bmpData.width / 2), Math.floor(bmpData.height / 2));

				for (var i = 0; i < 360; i++) {
					var curColor: uint = bmpData.getPixel(x, y);
					for (var r = tunnelRadius; r < Math.max(bmpData.width, bmpData.height); r++) {
						var x = center.x + r * Math.cos(i);
						var y = center.y + r * Math.sin(i);
						//find a pixel at the edge of the circle around center					
						if (r == tunnelRadius) {
							curColor = bmpData.getPixel(x, y);
						} else {
							//bmpData.setPixel(x, y, curColor);
							bmpData.setPixel(x - 1, y - 1, curColor);
							bmpData.setPixel(x - 1, y, curColor);
							bmpData.setPixel(x - 1, y + 1, curColor);
							bmpData.setPixel(x, y - 1, curColor);
							bmpData.setPixel(x, y, curColor);
							bmpData.setPixel(x, y + 1, curColor);
							bmpData.setPixel(x + 1, y - 1, curColor);
							bmpData.setPixel(x + 1, y, curColor);
							bmpData.setPixel(x + 1, y + 1, curColor);
						}
					}

				}
			}
		}
		
		public function log(msg:Object){
			ExternalInterface.call("console.log", msg.toString());
		}
		
		public function alert(msg:Object){
			ExternalInterface.call("alert", msg.toString());
		}

		public function updateRender(e: Event): void {
			var videoFrame: BitmapData = new BitmapData(camW, camH);
			videoFrame.draw(video);
			if (this.effectsEnabled) {
				applyFilter(videoFrame, "tunnel");
			}
			render.bitmapData.copyPixels(videoFrame, new Rectangle(0, 0, camW, camH), new Point());
			//only show "render" after camera access was allowed, before camera access it draws white frames
			//also check for white pixels to avoid a white flicker after camera allowed but before camera gives any data
			if (camera.muted == false && render.bitmapData.getPixel(0, 0) != 0xFFFFFF) {
				render.visible = true;
			} else {
				render.visible = false;
			}
			if (this.recording) {
				//var pixelData: ByteArray = new ByteArray();
				//videoFrame.copyPixelsToByteArray(new Rectangle(0, 0, camW, camH), pixelData);
				frames.push(videoFrame.encode(videoFrame.rect, new JPEGEncoderOptions(80)));
			}
		}

		public function applyFilter(target: BitmapData, filter: String) {
			if (filter in effects) {
				var effect = effects[filter];
				effect(target);
			} else {
				throw new Error("Filter " + filter + " not supported.");
			}
		}
	}
}