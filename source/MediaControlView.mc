using Toybox.WatchUi as Ui;
using Toybox.Graphics;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

class MediaControlView extends Ui.View {
    var _useTouch;
    var _showVolume;
    var _fontHeight;
    var _bm_prev_song;
    var _bm_next_song;
    var _bm_volume_down;
    var _bm_volume_up;
    var _bm_pause_song;
    var _bm_play_song;
    var _text;

    function initialize() {
        View.initialize();

        _useTouch = $.getProperty("useTouch", true, method(:validateBoolean));
        _showVolume = true;

        // Preload these as they are battery drainer
        _bm_prev_song = Ui.loadResource(Rez.Drawables.prev_song_icon);
        _bm_next_song = Ui.loadResource(Rez.Drawables.next_song_icon);
        _bm_volume_down = Ui.loadResource(Rez.Drawables.volume_down_icon);
        _bm_volume_up = Ui.loadResource(Rez.Drawables.volume_up_icon);
        _bm_pause_song = Ui.loadResource(Rez.Drawables.pause_song_icon);
        _bm_play_song = Ui.loadResource(Rez.Drawables.play_song_icon);
    }

    function onLayout(dc) {
        _fontHeight = Graphics.getFontHeight(Graphics.FONT_TINY);
    }

	function onReceive(args) {
        /*DEBUG*/ logMessage("MediaControlView:onReceive with args=" + args);
        _text = args;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        /*DEBUG*/ logMessage("MediaControlView:onUpdate");

		var width = dc.getWidth();
		var height = dc.getHeight();

        dc.clear();
        View.onUpdate(dc);

        var bm_width = _bm_prev_song.getWidth();
        var bm_height = _bm_prev_song.getHeight();

        var now_playing_title = Storage.getValue("now_playing_title");
        var player_state = Storage.getValue("media_playback_status");
        var bm_player = (player_state == null || player_state.equals("Stopped")) ? _bm_play_song : _bm_pause_song;
        var media_volume = Storage.getValue("media_volume");

        if (_useTouch) {
            var image_x_left = width / 4 - bm_width / 2;
            var image_x_right = (width / 4) * 3 - bm_width / 2;
            var image_y_top = height / 4 - bm_height / 2 + _fontHeight;
            var image_y_bottom = (height / 4) * 3 - bm_height / 2 + _fontHeight - height / 10;

            dc.drawBitmap(image_x_left, image_y_top, _bm_prev_song);
            dc.drawBitmap(image_x_right, image_y_top, _bm_next_song);
            dc.drawBitmap(image_x_left, image_y_bottom, _bm_volume_down);
            dc.drawBitmap(image_x_right, image_y_bottom, _bm_volume_up);
            dc.drawBitmap(width / 2 - bm_width / 2, height / 2 - bm_height / 2 + _fontHeight - height / 20, bm_player);

            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
			dc.drawText(width / 2, image_y_bottom + bm_height / 2, Graphics.FONT_TINY, media_volume, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        else {
            var image_x_left = width / 4 - bm_width / 2;
            var image_x_right = (width / 4) * 3 - bm_width / 2;
            var image_y_top = height / 3 - bm_height / 2 + _fontHeight;

            if (_showVolume) {
                dc.drawBitmap(image_x_left, image_y_top, _bm_volume_down);
                dc.drawBitmap(image_x_right, image_y_top, _bm_volume_up);

                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
                dc.drawText(width / 2, image_y_top + bm_height / 2, Graphics.FONT_TINY, media_volume, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
            else {
                dc.drawBitmap(image_x_left, image_y_top, _bm_prev_song);
                dc.drawBitmap(image_x_right, image_y_top, _bm_next_song);
            }

            dc.drawBitmap(width / 4 - bm_width / 2, height / 4 * 3 - bm_height / 2, bm_player);
        }

        if (now_playing_title != null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
			dc.drawText(width / 2, height / 10, Graphics.FONT_TINY, now_playing_title, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_text != null) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
			dc.drawText(width / 2, height - _fontHeight, Graphics.FONT_TINY, _text, Graphics.TEXT_JUSTIFY_CENTER);
            _text = null;
        }
    }
}
