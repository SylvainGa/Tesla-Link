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
    var _selected;

    function initialize (controller) {
        _controller = controller;
        PickerDelegate.initialize();
    }

    function onCancel () {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onAccept (values) {
        _selected = values[0];
		Application.getApp().setProperty("seat_chosen", _selected);

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);

        WatchUi.pushView(new SeatHeatPicker(_selected), new SeatHeatPickerDelegate(_controller), WatchUi.SLIDE_UP);
    }
}
