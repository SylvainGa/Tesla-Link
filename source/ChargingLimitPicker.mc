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
    //! Constructor
    public function initialize(charging_limit) {
    	var _min_limit = 50;
    	var _max_limit = 100;

    	var startPos = [charging_limit.toNumber() - _min_limit];
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
	
    //! Constructor
    function initialize(controller) {
        PickerDelegate.initialize();

    	_controller = controller;
        //DEBUG*/ logMessage("ChargingLimitPickerDelegate: initialize");
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    function onCancel() {
        //DEBUG*/ logMessage("ChargingLimitPickerDelegate: Cancel called");
        _controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    //! Handle a confirm event from the picker
    //! @param values The values chosen in the picker
    //! @return true if handled, false otherwise
    function onAccept (values) {
        var charging_limit = values[0];
        
        //DEBUG*/ logMessage("ChargingLimitPickerDelegate: onAccept called with charging_limit set to " + charging_limit);

        _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_SET_CHARGING_LIMIT, "Option" => ACTION_OPTION_NONE, "Value" => charging_limit, "Tick" => System.getTimer()});
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
