using Toybox.WatchUi;
using Toybox.Graphics;

class SeatHeatPicker extends WatchUi.Picker {
	var _heat;
	
    public function initialize (heat) {
		_heat = [heat - 0];
        var title = new WatchUi.Text({:text=>Rez.Strings.temp_choose_heat, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});
        Picker.initialize({:title=>title, :pattern=>[new $.NumberFactory(0, 3, 1, {})], :defaults=>_heat});
    }

    public function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class SeatHeatPickerDelegate extends WatchUi.PickerDelegate {
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
		Application.getApp().setProperty("seat_heat_chosen", _selected);

		if (Application.getApp().getProperty("seat_chosen") == Rez.Strings.seat_front) {
			Application.getApp().setProperty("seat_chosen", Rez.Strings.seat_driver);
	        _controller._set_seat_heat = true;
	        _controller.stateMachine();
			Application.getApp().setProperty("seat_chosen", Rez.Strings.seat_passenger);
	        _controller._set_seat_heat = true;
	        _controller.stateMachine();
	    }
		else if (Application.getApp().getProperty("seat_chosen") == Rez.Strings.seat_rear) {
			Application.getApp().setProperty("seat_chosen", Rez.Strings.seat_rear_left);
	        _controller._set_seat_heat = true;
	        _controller.stateMachine();
			Application.getApp().setProperty("seat_chosen", Rez.Strings.seat_rear_center);
	        _controller._set_seat_heat = true;
	        _controller.stateMachine();
			Application.getApp().setProperty("seat_chosen", Rez.Strings.seat_rear_right);
	        _controller._set_seat_heat = true;
	        _controller.stateMachine();
		}
		else {
	        _controller._set_seat_heat = true;
	        _controller.stateMachine();
	    }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

