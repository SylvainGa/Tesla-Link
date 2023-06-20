using Toybox.WatchUi as Ui;
using Toybox.Graphics;

class MediaControlDelegate extends Ui.BehaviorDelegate {

    var _controller;
    var _useTouch;
    var _previous_stateMachineCounter;
    var _showVolume;
    var _fontHeight;

    function initialize(controller, previous_stateMachineCounter) {
        BehaviorDelegate.initialize();
        _controller = controller;
        _controller._stateMachineCounter = 1; // Make sure our vehicle data is fresh
         _previous_stateMachineCounter = previous_stateMachineCounter;
		_useTouch = controller._useTouch;
        _showVolume = true;
        _fontHeight = Graphics.getFontHeight(Graphics.FONT_TINY);
    }

    function onSelect() {
		if (_useTouch) {
			return false;
		}

        if (_showVolume) {
            /*DEBUG*/ logMessage("MediaControlDelegate:onSelect volume up");
            //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_VOLUME_UP, "Value" => 0, "Tick" => System.getTimer()});
            _controller._tesla.mediaVolumeUp(_controller._vehicle_id, method(:onCommandReturn));
        }
        else {
            /*DEBUG*/ logMessage("MediaControlDelegate:onSelect next song");
            //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_NEXT_SONG, "Value" => 0, "Tick" => System.getTimer()});
            _controller._tesla.mediaNextTrack(_controller._vehicle_id, method(:onCommandReturn));
        }
        return true;
    }

    function onNextPage() {
		if (_useTouch) {
			return false;
		}

        /*DEBUG*/ logMessage("MediaControlDelegate:onPrevPage Play toggle");
        //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_PLAY_TOGGLE, "Value" => 0, "Tick" => System.getTimer()});
        _controller._tesla.mediaTogglePlayback(_controller._vehicle_id, method(:onCommandReturn));
        return true;
    }

    function onPreviousPage() {
		if (_useTouch) {
			return false;
		}

        if (_showVolume) {
            /*DEBUG*/ logMessage("MediaControlDelegate:onNextPage volume down");
            //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_VOLUME_DOWN, "Value" => 0, "Tick" => System.getTimer()});
            _controller._tesla.mediaVolumeDown(_controller._vehicle_id, method(:onCommandReturn));
        }
        else {
            /*DEBUG*/ logMessage("MediaControlDelegate:onNextPage previous song");
            //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_PREV_SONG, "Value" => 0, "Tick" => System.getTimer()});
            _controller._tesla.mediaPrevTrack(_controller._vehicle_id, method(:onCommandReturn));
        }
        return true;
    }

    function onMenu() {
		if (_useTouch) {
			return false;
		}

        _showVolume = (_showVolume == false);
        Ui.requestUpdate();
        return true;
    }

    function onBack() {
        // Unless we missed data, restore _stateMachineCounter
        _controller._stateMachineCounter = (_controller._stateMachineCounter != -2 ? _previous_stateMachineCounter : 1);
        /*DEBUG*/ logMessage("MediaControlDelegate:onBack, returning _stateMachineCounter to " + _controller._stateMachineCounter);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

	function onTap(click) {
        var bm = Ui.loadResource(Rez.Drawables.prev_song_icon); // All icon are the same size, use this one to get the size so we can position it on screen
        var bm_width = bm.getWidth();
        var bm_height = bm.getHeight();
        var width = System.getDeviceSettings().screenWidth;
        var height = System.getDeviceSettings().screenHeight;

		var coords = click.getCoordinates();
		var x = coords[0];
		var y = coords[1];

        // Center of screen where play button is
        if (x > width / 2 - bm_width / 2 && x < width / 2 + bm_width / 2 && y > height / 2 - bm_height / 2 + _fontHeight && y < height / 2 + bm_height / 2 + _fontHeight) {
            /*DEBUG*/ logMessage("MediaControlDelegate:onTap Play toggle");
            //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_PLAY_TOGGLE, "Value" => 0, "Tick" => System.getTimer()});
            _controller._tesla.mediaTogglePlayback(_controller._vehicle_id, method(:onCommandReturn));
        }
        // Left size
        else if (x < width / 2) {
            // Top left
            if (y < height / 2 + _fontHeight) {
                /*DEBUG*/ logMessage("MediaControlDelegate:onTap previous song");
                //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_PREV_SONG, "Value" => 0, "Tick" => System.getTimer()});
                _controller._tesla.mediaPrevTrack(_controller._vehicle_id, method(:onCommandReturn));
             }
            // Bottom left
            else {
                /*DEBUG*/ logMessage("MediaControlDelegate:onTap volume down");
                //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_VOLUME_DOWN, "Value" => 0, "Tick" => System.getTimer()});
                _controller._tesla.mediaVolumeDown(_controller._vehicle_id, method(:onCommandReturn));
            }
        }
        // Top right
        else if (y < height / 2 + _fontHeight) {
            /*DEBUG*/ logMessage("MediaControlDelegate:onTap next song");
            //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_NEXT_SONG, "Value" => 0, "Tick" => System.getTimer()});
            _controller._tesla.mediaNextTrack(_controller._vehicle_id, method(:onCommandReturn));
        }
        // Bottom right
        else {
            /*DEBUG*/ logMessage("MediaControlDelegate:onTap volume up");
            //_controller._pendingActionRequests.add({"Action" => ACTION_TYPE_MEDIA_CONTROL, "Option" => ACTION_OPTION_MEDIA_VOLUME_UP, "Value" => 0, "Tick" => System.getTimer()});
            _controller._tesla.mediaVolumeUp(_controller._vehicle_id, method(:onCommandReturn));
        }

        Ui.requestUpdate();
        return true;
    }

	function onCommandReturn(responseCode, data) {
        /*DEBUG*/ logMessage("onCommandReturn: " + responseCode);
		if (responseCode == 200) {
            _controller._stateMachineCounter = 1; // Get new vehicle data right now
        }
        else {
			_controller._handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + _controller.buildErrorString(responseCode)]);
		}
	}

}