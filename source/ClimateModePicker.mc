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
        /*DEBUG*/ logMessage("ClimateModePickerDelegate: initialize");
        PickerDelegate.initialize();
    }

    function onCancel () {
        /*DEBUG*/ logMessage("ClimateModePickerDelegate: Cancel called");
        _controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept (values) {
        var selected = values[0];

        /*DEBUG*/ logMessage("ClimateModePickerDelegate: onAccept called with selected set to " + selected);

        _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_CLIMATE_MODE, "Option" => ACTION_OPTION_NONE, "Value" => selected, "Tick" => System.getTimer()});
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
