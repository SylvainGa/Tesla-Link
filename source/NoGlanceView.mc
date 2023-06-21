using Toybox.WatchUi as Ui;
using Toybox.Application.Properties;

class NoGlanceView extends Ui.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        if ($.getProperty("useTouch", true, method(:validateBoolean))) {
            setLayout(Rez.Layouts.NoGlanceTouchLayout(dc));
        }
        else {
            setLayout(Rez.Layouts.NoGlancePressLayout(dc));
        }
    }
}
