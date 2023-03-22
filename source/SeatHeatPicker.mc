using Toybox.WatchUi;
using Toybox.Graphics;

class SeatHeatPicker extends WatchUi.Picker {
	var _heat;
	
    public function initialize (seat) {
		
        var title = new WatchUi.Text({:text=>Rez.Strings.label_temp_choose_heat, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});

//        Picker.initialize({:title=>title, :pattern=>[new $.NumberFactory(0, 3, 1, {})], :defaults=>_heat});
		var frontSeat = false;
		if (seat == Rez.Strings.label_seat_driver || seat == Rez.Strings.label_seat_passenger || seat == Rez.Strings.label_seat_front) {
			frontSeat = true;
		}

        var seatHeat = new [frontSeat ? 5 : 4];

        seatHeat[0] = Rez.Strings.label_seat_off;
        seatHeat[1] = Rez.Strings.label_seat_low;
        seatHeat[2] = Rez.Strings.label_seat_medium;
        seatHeat[3] = Rez.Strings.label_seat_high;
		if (frontSeat) {
	        seatHeat[4] = Rez.Strings.label_seat_auto;
	    }
    
        var factory = new WordFactory(seatHeat);
        
//        Picker.initialize({:title=>title, :pattern=>[factory], :defaults=>_heat});
        Picker.initialize({:title=>title, :pattern=>[factory]});
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
		_controller._stateMachineCounter = -1;
        PickerDelegate.initialize();
    }

    function onCancel () {
		_controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onAccept (values) {
        _selected = values[0];
		Application.getApp().setProperty("seat_heat_chosen", _selected);

		if (Application.getApp().getProperty("seat_chosen") == Rez.Strings.label_seat_front) {
			Application.getApp().setProperty("seat_chosen", Rez.Strings.label_seat_driver);
	        _controller._set_seat_heat = true;
	        _controller.actionMachine();
			Application.getApp().setProperty("seat_chosen", Rez.Strings.label_seat_passenger);
	        _controller._set_seat_heat = true;
	        _controller.actionMachine();
	    }
		else if (Application.getApp().getProperty("seat_chosen") == Rez.Strings.label_seat_rear) {
			Application.getApp().setProperty("seat_chosen", Rez.Strings.label_seat_rear_left);
	        _controller._set_seat_heat = true;
	        _controller.actionMachine();
			Application.getApp().setProperty("seat_chosen", Rez.Strings.label_seat_rear_center);
	        _controller._set_seat_heat = true;
	        _controller.actionMachine();
			Application.getApp().setProperty("seat_chosen", Rez.Strings.label_seat_rear_right);
	        _controller._set_seat_heat = true;
	        _controller.actionMachine();
		}
		else {
	        _controller._set_seat_heat = true;
	        _controller.actionMachine();
	    }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

