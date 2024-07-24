using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application.Storage;

class CarPicker extends WatchUi.Picker {
    function initialize (carsName) {
        var title = new WatchUi.Text({:text=>Rez.Strings.label_car_chooser_title, :locX =>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Graphics.COLOR_WHITE});
        var factory = new WordFactory(carsName);
        Picker.initialize({:pattern => [factory], :title => title});
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        Picker.onUpdate(dc);
    }
}

class CarPickerDelegate extends WatchUi.PickerDelegate {
    var _carsName;
    var _carsId;
    var _carsVIN;
    var _controller;

    function initialize (carsName, carsId, carsVIN, controller) {
        PickerDelegate.initialize();

        _carsName = carsName;
        _carsId = carsId;
        _carsVIN = carsVIN;
        _controller = controller;
        //DEBUG*/ logMessage("CarPickerDelegate: _stateMachineCounter was " + _controller._stateMachineCounter);
        _controller._stateMachineCounter = -1;
    }

    function onCancel () {
        gWaitTime = System.getTimer();
        _controller._vehicle_id = -2;
        _controller._stateMachineCounter = 1; // This is called from the stateMachine or OptionMenu. In both case, it returns to the stateMachine so we need to set it to 1 here otherwise stateMachine will not run again
        _controller._in_menu = false;
        //DEBUG*/ logMessage("CarPickerDelegate: Cancel called");
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onAccept (values) {
        var _selected = values[0];

        var size = _carsName.size();

        // 2022-10-17 logMessage("CarPickerDelegate: Have " + size + " vehicles");
        var i;
        for (i = 0; i < size; i++) {
            // 2022-10-17 logMessage("CarPickerDelegate: vehicle " + i + ": '" + _carsName[i] + "'");
            if (_selected.equals(_carsName[i])) {
                //DEBUG*/ logMessage("CarPickerDelegate: Got a match!");
                if (Storage.getValue("vehicle") != _carsId[i]) { // If it's a new car, start fresh
                    Storage.setValue("vehicle", _carsId[i]);
                    Storage.setValue("vehicleVIN", _carsVIN[i]);
                    Storage.setValue("vehicle_name", _selected);

                    // Start fresh as if we just loaded
                    _controller._waitingFirstData = 1;
                    _controller._408_count = 0;
                    _controller._check_wake = false;
                    //_controller._need_wake = false;
                    //_controller._wake_done = true;
                    _controller._wake_state = WAKE_UNKNOWN;
                    _controller._wakeWasConfirmed = false;
                    _controller._vehicle_state = (_controller._tesla.getTessieCacheMode() ? null : "online");
                    _controller._vehicle_id = _carsId[i];
                    _controller._vehicle_vin = _carsVIN[i];
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
        _controller._lastTimeStamp = 0;
        return true;
    }
}
