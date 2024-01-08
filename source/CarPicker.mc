using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application.Storage;

class CarPicker extends WatchUi.Picker {
    function initialize (vehiclesName) {
        var title = new WatchUi.Text({:text=>Rez.Strings.label_car_chooser_title, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});
        var factory = new WordFactory(vehiclesName);
        Picker.initialize({:pattern => [factory], :title => title});
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class CarPickerDelegate extends WatchUi.PickerDelegate {
    var _vehiclesName;
    var _vehiclesVin;
    var _controller;

    function initialize (vehiclesName, vehiclesVin, controller) {
        PickerDelegate.initialize();

        _vehiclesName = vehiclesName;
        _vehiclesVin = vehiclesVin;
        _controller = controller;
        //DEBUG*/ logMessage("CarPickerDelegate: _stateMachineCounter was " + _controller._stateMachineCounter);
        _controller._stateMachineCounter = -1;
    }

    function onCancel () {
        _controller._vehicle_vin = null;
        gWaitTime = System.getTimer();
        //DEBUG*/ logMessage("CarPickerDelegate: Cancel called");
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _controller._stateMachineCounter = 1; // This is called from the stateMachine or OptionMenu. In both case, it returns to the stateMachine so we need to set it to 1 here otherwise stateMachine will not run again
		_controller._in_menu = false;
        return true;
    }

    function onAccept (values) {
        var _selected = values[0];

        var size = _vehiclesName.size();

        // 2022-10-17 logMessage("CarPickerDelegate: Have " + size + " vehicles");
        var i;
        for (i = 0; i < size; i++) {
            // 2022-10-17 logMessage("CarPickerDelegate: vehicle " + i + ": '" + _vehiclesName[i] + "'");
            if (_selected.equals(_vehiclesName[i])) {
                //DEBUG*/ logMessage("CarPickerDelegate: Got a match!");
                if (Storage.getValue("vehicle_vin") == null || Storage.getValue("vehicle").equals(_vehiclesVin[i])) { // If it's a new car, start fresh
                    Storage.setValue("vehicle_vin", _vehiclesVin[i]);
                    Storage.setValue("vehicle_name", _selected);

                    // Start fresh as if we just loaded
                    _controller._waitingFirstData = 1;
                    _controller._408_count = 0;
                    _controller._check_wake = false;
                    _controller._need_wake = false;
                    _controller._wake_done = true;
                    _controller._wakeWasConfirmed = false;
            		_controller._data._vehicle_state = null;
                    _controller._vehicle_vin = _vehiclesVin[i];
                }
                break;
            }
        }
        //DEBUG*/ if (i == size) { logMessage("CarPickerDelegate: No match?!?"); }

        gWaitTime = System.getTimer();
        _controller._handler.invoke([3, _controller._408_count, WatchUi.loadResource(Rez.Strings.label_requesting_data)]);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.requestUpdate();
        _controller._stateMachineCounter = 1; // This is called from the stateMachine or OptionMenu. In both case, it returns to the stateMachine so we need to set it to 1 here otherwise stateMachine will not run again
		_controller._in_menu = false;
        return true;
    }
}
