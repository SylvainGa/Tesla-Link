using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;

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
    var _controller;

    function initialize (carsName, carsId, controller) {
        _carsName = carsName;
        _carsId = carsId;
        _controller = controller;
        PickerDelegate.initialize();
    }

    function onCancel () {
        if (_controller._vehicle_id == -1) {
            _controller._vehicle_id = -3;
        }
        else {
            _controller._vehicle_id = -2;
        }
        _controller.stateMachine();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onAccept (values) {
        var _selected = values[0];
//        _controller._tesla.getVehicleId(method(:onReceiveVehicles));

        var size = _carsName.size();

// 2022-10-17 logMessage("CarPickerDelegate: Have " + size + " vehicles");
        var i;
        for (i = 0; i < size; i++) {
// 2022-10-17 logMessage("CarPickerDelegate: vehicle " + i + ": '" + _carsName[i] + "'");
            if (_selected.equals(_carsName[i])) {
// 2022-10-17 logMessage("CarPickerDelegate: Got a match!");
                if (Application.getApp().getProperty("vehicle") != _carsId[i]) { // If it's a new car, start fresh
                    Application.getApp().setProperty("vehicle", _carsId[i]);
                    Application.getApp().setProperty("vehicle_name", _selected);

                    // Start fresh as if we just loaded
                    _controller._firstTime = true;
                    _controller._408_count = 0;
                    _controller._check_wake = false;
                    _controller._need_wake = false;
                    _controller._wake_done = true;
                    _controller._wakeTime = System.getTimer();
            		_controller._vehicle_state = "online";
                    _controller._vehicle_id = _carsId[i];
                }
                break;
            }
        }
        if (i == size) {
// 2022-10-17 logMessage("CarPickerDelegate: No match?!?");
        }

        _controller.stateMachine();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
