using Toybox.WatchUi;
using Toybox.Graphics;

class ClimateModePicker extends WatchUi.Picker {
    function initialize (modes) {
        var title = new WatchUi.Text({:text=>Rez.Strings.label_climate_which, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});
        var factory = new WordFactory(modes);
        Picker.initialize({:pattern => [factory], :title => title});
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class ClimateModePickerDelegate extends WatchUi.PickerDelegate {
    var _controller;

    function initialize (controller) {
        _controller = controller;
        logMessage("ClimateModePickerDelegate: initialize");
        PickerDelegate.initialize();
    }

    function onCancel () {
        logMessage("ClimateModePickerDelegate: Cancel called");
        _controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept (values) {
        var selected = values[0];
		Application.getApp().setProperty("climate_mode_chosen", selected);

        logMessage("ClimateModePickerDelegate: onAccept called with selected set to " + selected);

        _controller._climate_mode = true;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _controller.actionMachine();
        return true;
    }
}
