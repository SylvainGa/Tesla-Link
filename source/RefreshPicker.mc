// Based on datePicker
// Copyright 2015-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Picker that allows the user to choose a temperature
class RefreshPicker extends WatchUi.Picker {

    //! Constructor
    public function initialize(current) {
    	var refreshTime = current;

        var title = new WatchUi.Text({:text=>Rez.Strings.label_refresh_chooser_title, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});

		var startPos = [refreshTime.toNumber() / 500 - 1];
		Picker.initialize({:title=>title, :pattern=>[new $.NumberFactory(500, 9000, 500, {:format=>"%4d"})], :defaults=>startPos});
    }

    //! Update the view
    //! @param dc Device Context
    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

//! Responds to a temperature picker selection or cancellation
class RefreshPickerDelegate extends WatchUi.PickerDelegate {
	var _controller;
	
    //! Constructor
    function initialize(controller) {
    	_controller = controller;
        /*DEBUG*/ logMessage("RefreshPickerDelegate: initialize");
        PickerDelegate.initialize();
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    function onCancel() {
        /*DEBUG*/ logMessage("RefreshPickerDelegate: Cancel called");
        _controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    //! Handle a confirm event from the picker
    //! @param values The values chosen in the picker
    //! @return true if handled, false otherwise
    function onAccept (values) {
        var refreshTime = values[0];

        /*DEBUG*/ logMessage("RefreshPickerDelegate: onAccept called with refreshTimeselected set to " + refreshTime);

        Application.getApp().setProperty("refreshTimeInterval", refreshTime);
        _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_REFRESH, "Option" => ACTION_OPTION_NONE, "Value" => refreshTime, "Tick" => System.getTimer()});
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
