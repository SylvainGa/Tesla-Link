using Toybox.WatchUi as Ui;
using Toybox.Application.Properties;

class NoGlanceView extends Ui.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        if (Properties.getValue("useTouch")) {
            setLayout(Rez.Layouts.NoGlanceTouchLayout(dc));
        }
        else {
            setLayout(Rez.Layouts.NoGlancePressLayout(dc));
        }
    }
}
