// Based on datePicker
// Copyright 2015-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;


//! Picker that allows the user to choose a charging curremt
class ChargerPicker extends WatchUi.Picker {
	var _charging_amps;

    //! Constructor
    public function initialize(charging_amps, max_amps) {
    	var _min_amps = 5;
    	var _max_amps = max_amps;
    	_charging_amps = charging_amps;

    	var startPos = [_charging_amps.toNumber() - _min_amps];
        var title = new WatchUi.Text({:text=>Rez.Strings.temp_chooser_title, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});
        Picker.initialize({:title=>title, :pattern=>[new $.NumberFactory(_min_amps.toNumber(), _max_amps.toNumber(), 1, {})], :defaults=>startPos});
    }

    //! Update the view
    //! @param dc Device Context
    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

//! Responds to a charger picker selection or cancellation
class ChargerPickerDelegate extends WatchUi.PickerDelegate {
	var _controller;
	var _charging_amps;
	
    //! Constructor
    function initialize(controller) {
    	_controller = controller;
        PickerDelegate.initialize();
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    function onCancel() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    //! Handle a confirm event from the picker
    //! @param values The values chosen in the picker
    //! @return true if handled, false otherwise
    function onAccept (values) {
        _charging_amps = values[0];
        
        Application.getApp().setProperty("charging_amps", _charging_amps);
        _controller._set_charging_amps_set = true;
        _controller.stateMachine();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
