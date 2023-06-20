using Toybox.WatchUi as Ui;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

class MediaControlView extends Ui.View {
    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        if (Properties.getValue("useTouch")) {
            setLayout(Rez.Layouts.TouchMediaControlLayout(dc));
        }
        else {
            setLayout(Rez.Layouts.ButtonMediaControlLayout(dc));
        }
    }

    function onUpdate(dc) {
        /*DEBUG*/ logMessage("MediaControlView:onUpdate");

		var width = dc.getWidth();
		var height = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        View.onUpdate(dc);

        var bm = Ui.loadResource(Rez.Drawables.prev_song_icon); // All icon are the same size, use this one to get the size so we can position it on screen
        var bm_width = bm.getWidth();
        var bm_height = bm.getHeight();

        var image_x_left = width / 4 - bm_width / 2;
        var image_y_top = height / 4 - bm_height / 2;
        var image_x_right = (width / 4) * 3 - bm_width / 2;
        var image_y_bottom = (height / 4) * 3 - bm_height / 2;

        dc.drawBitmap(image_x_left, image_y_top, bm);
        dc.drawBitmap(image_x_right, image_y_top, Ui.loadResource(Rez.Drawables.next_song_icon));
        dc.drawBitmap(image_x_left, image_y_bottom, Ui.loadResource(Rez.Drawables.volume_down_icon));
        dc.drawBitmap(image_x_right, image_y_bottom, Ui.loadResource(Rez.Drawables.volume_up_icon));

        var player_state = Storage.getValue("media_playback_status");
        bm = Ui.loadResource((player_state == null || player_state.equals("Stopped")) ? Rez.Drawables.play_song_icon : Rez.Drawables.pause_song_icon);
        dc.drawBitmap(width / 2 - bm_width / 2, height / 2 - bm_height / 2, bm);
    }
}
