using Toybox.WatchUi as Ui;
using Toybox.System;

class OptionMenuDelegate extends Ui.Menu2InputDelegate {
    var _controller;
    var _previous_stateMachineCounter;

    function initialize(controller) {
        Ui.MenuInputDelegate.initialize();
        _controller = controller;
        _previous_stateMachineCounter = (_controller._stateMachineCounter > 1 ? 1 : _controller._stateMachineCounter); // Drop the wait to 0.1 second is it's over, otherwise keep the value already there
        _controller._stateMachineCounter = -1;
        //DEBUG*/ logMessage("OptionMenuDelegate: initialize, _stateMachineCounter was " + _previous_stateMachineCounter);
        //logMessage("OptionMenuDelegate: initialize");
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    function onBack() {
        // Unless we missed data, restore _stateMachineCounter
        _controller._stateMachineCounter = (_controller._stateMachineCounter != -2 ? _previous_stateMachineCounter : 1);
        //DEBUG*/ logMessage("OptionMenuDelegate:onBack, returning _stateMachineCounter to " + _controller._stateMachineCounter);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onSelect(selected_item) {
        var item = selected_item.getId();

        //DEBUG*/ logMessage("OptionMenuDelegate:onSelect for " + selected_item.getLabel());
        if (item == :reset) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_RESET, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _controller._stateMachineCounter = (_controller._stateMachineCounter != -2 ? _previous_stateMachineCounter : 1); // Unless we missed data, restore _stateMachineCounter
        } else if (item == :honk) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_HONK, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :select_car) {
            /*var vinsName = new [2];
            var vinsId = new [2];
            vinsName[0] = "Tesla";
            vinsId[0] = 123456;
            vinsName[1] = "Tesla Model 3";
            vinsId[1] = 654321;
            Ui.switchToView(new CarPicker(vinsName), new CarPickerDelegate(vinsName, vinsId, _controller), Ui.SLIDE_UP);
            //*/_controller._tesla.getVehicleId(method(:onReceiveVehicles));
        } else if (item == :open_port) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_PORT, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :open_frunk) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_FRUNK, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
       } else if (item == :open_trunk) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_TRUNK, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :toggle_view) {
            var view = Application.getApp().getProperty("image_view");
            if (view) {
                Application.getApp().setProperty("image_view", false);
            } else {
                Application.getApp().setProperty("image_view", true);
            }
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _controller._stateMachineCounter = (_controller._stateMachineCounter != -2 ? _previous_stateMachineCounter : 1); // Unless we missed data, restore _stateMachineCounter
        } else if (item == :swap_frunk_for_port) {
            var swap = Application.getApp().getProperty("swap_frunk_for_port");
            if (swap == 0 || swap == null) {
                Application.getApp().setProperty("swap_frunk_for_port", 1);
			}
			else if (swap == 1) {
				Application.getApp().setProperty("swap_frunk_for_port", 2);
			}
			else if (swap == 2) {
				Application.getApp().setProperty("swap_frunk_for_port", 3);
			}
			else {
                Application.getApp().setProperty("swap_frunk_for_port", 0);
	        }
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            _controller._stateMachineCounter = (_controller._stateMachineCounter != -2 ? _previous_stateMachineCounter : 1); // Unless we missed data, restore _stateMachineCounter
        } else if (item == :set_temperature) {
            var driver_temp = _controller._data._vehicle_data.get("climate_state").get("driver_temp_setting");
            var max_temp =    _controller._data._vehicle_data.get("climate_state").get("max_avail_temp");
            var min_temp =    _controller._data._vehicle_data.get("climate_state").get("min_avail_temp");
            
            if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            	driver_temp = driver_temp * 9.0 / 5.0 + 32.0;
            	max_temp = max_temp * 9.0 / 5.0 + 32.0;
            	min_temp = min_temp * 9.0 / 5.0 + 32.0;
            }

            Ui.switchToView(new TemperaturePicker(driver_temp, max_temp, min_temp), new TemperaturePickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :set_charging_amps) {
        	var max_amps = _controller._data._vehicle_data.get("charge_state").get("charge_current_request_max");
            var charging_amps = _controller._data._vehicle_data.get("charge_state").get("charge_current_request");
            if (charging_amps == null) {
            	if (max_amps == null) {
            		charging_amps = 32;
            	}
            	else {
            		charging_amps = max_amps;
            	}
            }
            
            Ui.switchToView(new ChargerPicker(charging_amps, max_amps), new ChargerPickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :set_charging_limit) {
        	var charging_limit = _controller._data._vehicle_data.get("charge_state").get("charge_limit_soc");
            
            Ui.switchToView(new ChargingLimitPicker(charging_limit), new ChargingLimitPickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :set_seat_heat) {
			var rear_seats_avail = _controller._data._vehicle_data.get("climate_state").get("seat_heater_rear_left");
	        var seats = new [rear_seats_avail != null ? 8 : 3];

	        seats[0] = Rez.Strings.label_seat_driver;
	        seats[1] = Rez.Strings.label_seat_passenger;
	        if (rear_seats_avail != null) {
		        seats[2] = Rez.Strings.label_seat_rear_left;
		        seats[3] = Rez.Strings.label_seat_rear_center;
		        seats[4] = Rez.Strings.label_seat_rear_right;
		        seats[5] = Rez.Strings.label_seat_front;
		        seats[6] = Rez.Strings.label_seat_rear;
		        seats[7] = Rez.Strings.label_seat_all;
	        }
	        else {
		        seats[2] = Rez.Strings.label_seat_front;
	        }

	        Ui.switchToView(new SeatPicker(seats), new SeatPickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :defrost) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_CLIMATE_DEFROST, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :set_steering_wheel_heat) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_SET_STEERING_WHEEL_HEAT, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :vent) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_VENT, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :toggle_charge) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_TOGGLE_CHARGE, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :adjust_departure) {
            var time = _controller._data._vehicle_data.get("charge_state").get("scheduled_departure_time_minutes");
			if (_controller._data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
                _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_ADJUST_DEPARTURE, "Option" => ACTION_OPTION_NONE, "Value" => time, "Tick" => System.getTimer()});
                WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            }
            else {
				Ui.switchToView(new DepartureTimePicker(time), new DepartureTimePickerDelegate(_controller), Ui.SLIDE_IMMEDIATE);
            }
        } else if (item == :toggle_sentry) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_TOGGLE_SENTRY, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :wake) {
            _controller._need_wake = true;
            _controller._wake_done = false;
            _controller._stateMachineCounter = (_controller._stateMachineCounter != -2 ? _previous_stateMachineCounter : 1); // Unless we missed data, restore _stateMachineCounter
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :refresh) {
            var refreshTimeInterval = Application.getApp().getProperty("refreshTimeInterval");
            Ui.switchToView(new RefreshPicker(refreshTimeInterval), new RefreshPickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :data_screen) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_DATA_SCREEN, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :homelink) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_HOMELINK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :remote_boombox) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_REMOTE_BOOMBOX, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (item == :climate_mode) {
	        var modes = new [4];

	        modes[0] = Rez.Strings.label_climate_off;
	        modes[1] = Rez.Strings.label_climate_on;
	        modes[2] = Rez.Strings.label_climate_dog;
	        modes[3] = Rez.Strings.label_climate_camp;

	        Ui.switchToView(new ClimateModePicker(modes), new ClimateModePickerDelegate(_controller), Ui.SLIDE_UP);
        }

        return true;
    }

    function onReceiveVehicles(responseCode, data) {
        if (responseCode == 200) {
            var vehicles = data.get("response");
            var size = vehicles.size();
            var vinsName = new [size];
            var vinsId = new [size];
            for (var i = 0; i < size; i++) {
                vinsName[i] = vehicles[i].get("display_name");
                vinsId[i] = vehicles[i].get("id");
            }
            Ui.switchToView(new CarPicker(vinsName), new CarPickerDelegate(vinsName, vinsId, _controller), Ui.SLIDE_UP);
        } else {
            _controller._handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString()]);
        }

        // Unless we missed data, restore _stateMachineCounter
        _controller._stateMachineCounter = (_controller._stateMachineCounter != -2 ? _previous_stateMachineCounter : 1);
    }
}
