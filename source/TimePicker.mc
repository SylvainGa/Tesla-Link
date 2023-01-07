//
// Copyright 2015-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

const FACTORY_COUNT_24_HOUR = 3;
const FACTORY_COUNT_12_HOUR = 4;
const MINUTE_FORMAT = "%02d";

//! Picker that allows the user to choose a time
class DepartureTimePicker extends WatchUi.Picker {
	var _time;
	
    //! Constructor
    public function initialize(time) {
		_time = time;

        var title = new WatchUi.Text({:text=>$.Rez.Strings.label_timePickerTitle, :locX=>WatchUi.LAYOUT_HALIGN_CENTER,
            :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});
        var factories;

        if (System.getDeviceSettings().is24Hour) {
            factories = new Array<PickerFactory or Text>[$.FACTORY_COUNT_24_HOUR];
            factories[0] = new $.NumberFactory(0, 23, 1, {});
        } else {
            factories = new Array<PickerFactory or Text>[$.FACTORY_COUNT_12_HOUR];
            factories[0] = new $.NumberFactory(1, 12, 1, {});
            factories[3] = new $.WordFactory([$.Rez.Strings.label_morning, $.Rez.Strings.label_afternoon] as Array<Symbol>);
        }

        factories[1] = new WatchUi.Text({:text=>$.Rez.Strings.label_timeSeparator, :font=>Graphics.FONT_MEDIUM,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER, :color=>Graphics.COLOR_WHITE});
        factories[2] = new $.NumberFactory(0, 59, 15, {:format=>$.MINUTE_FORMAT});

        var defaults = new Array<Number>[factories.size()];
        if (_time != null) {
            var hour = (_time / 60).toLong();
            var min = (((_time / 60.0) - hour) * 60).toLong();
			
            if (hour != null) {
            	if (defaults.size() == $.FACTORY_COUNT_12_HOUR) {
            		var ampm = "AM";
					if (hour > 12) {
            			hour -= 12;
            			ampm = "PM";
            		}
            		else if (hour == 0) {
            			hour = 12;
            		}
	                defaults[3] = (factories[3] as WordFactory).getIndex(ampm);
            	}
                defaults[0] = (factories[0] as NumberFactory).getIndex(hour);
            }

            if (min != null) {
                defaults[2] = (factories[2] as NumberFactory).getIndex(min);
            }
        }

        Picker.initialize({:title=>title, :pattern=>factories, :defaults=>defaults});
    }

    //! Update the view
    //! @param dc Device Context
    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

//! Responds to a time picker selection or cancellation
class DepartureTimePickerDelegate extends WatchUi.PickerDelegate {
	var _controller;
	
    //! Constructor
    function initialize(controller) {
    	_controller = controller;
        PickerDelegate.initialize();
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    public function onCancel() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    //! Handle a confirm event from the picker
    //! @param values The values chosen in the picker
    //! @return true if handled, false otherwise
    public function onAccept(values as Array<Number?>) as Boolean {
        var hour = values[0];
        var min = values[2];

        if ((hour != null) && (min != null)) {
			var time = hour * 60 + min;
			
            if (values.size() == $.FACTORY_COUNT_12_HOUR) {
            	time += 12 * 60;
            }

	        Application.getApp().setProperty("departure_time", time);
	        
	        _controller._adjust_departure = true;
	        _controller.stateMachine();
	
	        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
	        return true;
        }
		else {
			return false;
		}
    }
}
