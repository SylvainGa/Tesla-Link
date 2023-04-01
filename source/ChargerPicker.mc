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
    //! Constructor
    public function initialize(charging_amps, max_amps) {
    	var _min_amps = 5;
    	var _max_amps = max_amps;

    	var startPos = [charging_amps.toNumber() - _min_amps];
        var title = new WatchUi.Text({:text=>Rez.Strings.label_amps_chooser_title, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});
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
	
    //! Constructor
    function initialize(controller) {
    	_controller = controller;
        //DEBUG*/ logMessage("ChargerPickerDelegate: initialize");
        PickerDelegate.initialize();
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    function onCancel() {
        //DEBUG*/ logMessage("ChargerPickerDelegate: Cancel called");
        _controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    //! Handle a confirm event from the picker
    //! @param values The values chosen in the picker
    //! @return true if handled, false otherwise
    function onAccept (values) {
        var charging_amps = values[0];

        //DEBUG*/ logMessage("ChargerPickerDelegate: onAccept called with charging_amps set to " + charging_amps);

        _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_SET_CHARGING_AMPS, "Option" => ACTION_OPTION_NONE, "Value" => charging_amps, "Tick" => System.getTimer()});
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
