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
	var _refreshTime;

    //! Constructor
    public function initialize(current) {
    	_refreshTime = current;

        var title = new WatchUi.Text({:text=>Rez.Strings.refresh_chooser_title, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});

		var startPos = [_refreshTime.toNumber() / 500 - 1];
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
	var _refreshTime;
	
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
        _refreshTime = values[0];

        Application.getApp().setProperty("refreshTimeInterval", _refreshTime);
        _controller._set_refresh_time = true;
        _controller.stateMachine();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
