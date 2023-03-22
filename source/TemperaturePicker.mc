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
class TemperaturePicker extends WatchUi.Picker {
	var _temperature;

    //! Constructor
    public function initialize(temperature, max_temp, min_temp) {
    	_temperature = temperature;

        var title = new WatchUi.Text({:text=>Rez.Strings.label_temp_chooser_title, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});

        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
 	    	var startPos = [temperature.toNumber() - min_temp.toNumber()];
	        Picker.initialize({:title=>title, :pattern=>[new $.NumberFactory(min_temp.toNumber(), max_temp.toNumber(), 1, {:format=>"%2d"})], :defaults=>startPos});
        }
        else {
 	    	var startPos = [(temperature.toFloat() - min_temp.toFloat()) / 0.5];
	        Picker.initialize({:title=>title, :pattern=>[new $.FloatFactory(min_temp.toFloat(), max_temp.toFloat(), 0.5, {:format=>"%2.1f"})], :defaults=>startPos});
        }
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
class TemperaturePickerDelegate extends WatchUi.PickerDelegate {
	var _controller;
	var _temperature;
	
    //! Constructor
    function initialize(controller) {
    	_controller = controller;
        _controller._stateMachineCounter = -1;
        PickerDelegate.initialize();
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    function onCancel() {
        _controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    //! Handle a confirm event from the picker
    //! @param values The values chosen in the picker
    //! @return true if handled, false otherwise
    function onAccept (values) {
        _temperature = values[0];

        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
			_temperature = (_temperature - 32.0) * 5.0 / 9.0;	
        }
        
        Application.getApp().setProperty("driver_temp", _temperature);
        _controller._set_climate_set = true;
        _controller.actionMachine();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
