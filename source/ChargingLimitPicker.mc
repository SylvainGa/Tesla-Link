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
class ChargingLimitPicker extends WatchUi.Picker {
	var _charging_limit;

    //! Constructor
    public function initialize(charging_limit) {
    	var _min_limit = 50;
    	var _max_limit = 100;
    	_charging_limit = charging_limit;

    	var startPos = [_charging_limit.toNumber() - _min_limit];
        var title = new WatchUi.Text({:text=>Rez.Strings.label_charginglimit_chooser_title, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});
        Picker.initialize({:title=>title, :pattern=>[new $.NumberFactory(_min_limit.toNumber(), _max_limit.toNumber(), 1, {})], :defaults=>startPos});
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
class ChargingLimitPickerDelegate extends WatchUi.PickerDelegate {
	var _controller;
	var _charging_limit;
	
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
        _charging_limit = values[0];
        
        Application.getApp().setProperty("charging_limit", _charging_limit);
        _controller._set_charging_limit_set = true;
        _controller.stateMachine();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
