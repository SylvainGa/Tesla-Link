using Toybox.WatchUi as Ui;

class NoGlanceView extends Ui.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        if (gUseTouch) {
            setLayout(Rez.Layouts.NoGlanceTouchLayout(dc));
        }
        else {
            setLayout(Rez.Layouts.NoGlancePressLayout(dc));
        }
    }
}
