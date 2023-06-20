using Toybox.WatchUi as Ui;
using Toybox.Graphics;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

class MediaControlView extends Ui.View {
    var _useTouch;
    var _delegate;
    var _fontHeight;
    var _bm_prev_song;
    var _bm_next_song;
    var _bm_volume_down;
    var _bm_volume_up;
    var _bm_pause_song;
    var _bm_play_song;

    function initialize(delegate) {
        View.initialize();

        _delegate = delegate;
        _useTouch = $.getBoolProperty("useTouch", true);

        // Preload these as they are battery drainer
        _bm_prev_song = Ui.loadResource(Rez.Drawables.prev_song_icon);
        _bm_next_song = Ui.loadResource(Rez.Drawables.next_song_icon);
        _bm_volume_down = Ui.loadResource(Rez.Drawables.volume_down_icon);
        _bm_volume_up = Ui.loadResource(Rez.Drawables.volume_up_icon);
        _bm_play_song = Ui.loadResource(Rez.Drawables.play_song_icon);
    }

    function onLayout(dc) {
        if (_useTouch) {
            setLayout(Rez.Layouts.TouchMediaControlLayout(dc));
        }
        else {
            setLayout(Rez.Layouts.ButtonMediaControlLayout(dc));
        }

        _fontHeight = Graphics.getFontHeight(Graphics.FONT_TINY);
    }

    function onUpdate(dc) {
        /*DEBUG*/ logMessage("MediaControlView:onUpdate");

		var width = dc.getWidth();
		var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        View.onUpdate(dc);

        var bm_width = _bm_prev_song.getWidth();
        var bm_height = _bm_prev_song.getHeight();

        var now_playing_title = Storage.getValue("now_playing_title");
        if (now_playing_title != null) {
			dc.drawText(width / 2, 0, Graphics.FONT_TINY, now_playing_title, Graphics.TEXT_JUSTIFY_CENTER);
        }

        if (_useTouch) {
            var image_x_left = width / 4 - bm_width / 2;
            var image_x_right = (width / 4) * 3 - bm_width / 2;
            var image_y_top = height / 4 - bm_height / 2 + _fontHeight;
            var image_y_bottom = (height / 4) * 3 - bm_height / 2 + _fontHeight;

            dc.drawBitmap(image_x_left, image_y_top, _bm_prev_song);
            dc.drawBitmap(image_x_right, image_y_top, _bm_next_song);
            dc.drawBitmap(image_x_left, image_y_bottom, _bm_volume_down);
            dc.drawBitmap(image_x_right, image_y_bottom, _bm_volume_up);

            var player_state = Storage.getValue("media_playback_status");
            dc.drawBitmap(width / 2 - bm_width / 2, height / 2 - bm_height / 2 + _fontHeight, (player_state == null || player_state.equals("Stopped")) ? _bm_play_song : _bm_pause_song);
        }
        else {
            var image_x_left = width / 4 - bm_width / 2;
            var image_x_right = (width / 4) * 3 - bm_width / 2;
            var image_y_top = height / 3 - bm_height / 2 + _fontHeight;

            if (_delegate._showVolume) {
                dc.drawBitmap(image_x_left, image_y_top, _bm_volume_down);
                dc.drawBitmap(image_x_right, image_y_top, _bm_volume_up);
            }
            else {
                dc.drawBitmap(image_x_left, image_y_top, _bm_prev_song);
                dc.drawBitmap(image_x_right, image_y_top, _bm_next_song);
            }

            var player_state = Storage.getValue("media_playback_status");
            dc.drawBitmap(width / 4 - bm_width / 2, height / 4 * 3 - bm_height / 2, (player_state == null || player_state.equals("Stopped")) ? _bm_play_song : _bm_pause_song);
        }
    }
}
