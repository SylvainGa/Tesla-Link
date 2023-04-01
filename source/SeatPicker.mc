using Toybox.WatchUi;
using Toybox.Graphics;

class SeatPicker extends WatchUi.Picker {
    function initialize (seats) {
        var title = new WatchUi.Text({:text=>Rez.Strings.label_temp_choose_seat, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});
        var factory = new WordFactory(seats);
        Picker.initialize({:pattern => [factory], :title => title});
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class SeatPickerDelegate extends WatchUi.PickerDelegate {
    var _controller;

    function initialize (controller) {
        _controller = controller;
        /*DEBUG*/ logMessage("SeatPickerDelegate: initialize");
        PickerDelegate.initialize();
    }

    function onCancel () {
        /*DEBUG*/ logMessage("SeatPickerDelegate: Cancel called");
        _controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept (values) {
        var selected = values[0];
		Application.getApp().setProperty("seat_chosen", selected);

        /*DEBUG*/ logMessage("SeatPickerDelegate: onAccept called with selected set to " + selected);

        WatchUi.switchToView(new SeatHeatPicker(selected), new SeatHeatPickerDelegate(_controller), WatchUi.SLIDE_UP);
        return true;
    }
}
