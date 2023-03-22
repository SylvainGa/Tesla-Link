using Toybox.WatchUi as Ui;
using Toybox.System;

class OptionMenuDelegate extends Ui.Menu2InputDelegate {
    var _controller;
	
    function initialize(controller) {
        Ui.MenuInputDelegate.initialize();
        _controller = controller;
        _controller._stateMachineCounter = -1;
        logMessage("OptionMenuDelegate: initialize");
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    function onBack() {
        _controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onSelect(selected_item) {
        var item = selected_item.getId();

        if (item == :reset) {
            Settings.setToken(null);
            Settings.setRefreshToken(null, 0, 0);
            Application.getApp().setProperty("vehicle", null);
			Application.getApp().setProperty("ResetNeeded", true);
        } else if (item == :honk) {
            _controller._honk_horn = true;
            _controller.actionMachine();
        } else if (item == :select_car) {
            _controller._tesla.getVehicleId(method(:onReceiveVehicles));
        } else if (item == :open_port) {
            _controller._open_port = true;
            _controller.actionMachine();
        } else if (item == :open_frunk) {
            _controller._open_frunk = true;
            _controller.actionMachine();
        } else if (item == :open_trunk) {
            _controller._open_trunk = true;
            _controller.actionMachine();
        } else if (item == :toggle_view) {
            var view = Application.getApp().getProperty("image_view");
            if (view) {
                Application.getApp().setProperty("image_view", false);
            } else {
                Application.getApp().setProperty("image_view", true);
            }
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
        } else if (item == :set_temperature) {
            var driver_temp = Application.getApp().getProperty("driver_temp");
            var max_temp = _controller._data._vehicle_data.get("climate_state").get("max_avail_temp");
            var min_temp = _controller._data._vehicle_data.get("climate_state").get("min_avail_temp");
            
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
	        var seats = new [rear_seats_avail != null ? 7 : 3];

	        seats[0] = Rez.Strings.label_seat_driver;
	        seats[1] = Rez.Strings.label_seat_passenger;
	        if (rear_seats_avail != null) {
		        seats[2] = Rez.Strings.label_seat_rear_left;
		        seats[3] = Rez.Strings.label_seat_rear_center;
		        seats[4] = Rez.Strings.label_seat_rear_right;
		        seats[5] = Rez.Strings.label_seat_front;
		        seats[6] = Rez.Strings.label_seat_rear;
	        }
	        else {
		        seats[2] = Rez.Strings.label_seat_front;
	        }

	        Ui.switchToView(new SeatPicker(seats), new SeatPickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :defrost) {
            _controller._set_climate_defrost = true;
            _controller.actionMachine();
        } else if (item == :set_steering_wheel_heat) {
            _controller._set_steering_wheel_heat = true;
            _controller.actionMachine();
        } else if (item == :vent) {
            _controller._vent = true;
            _controller.actionMachine();
        } else if (item == :toggle_charge) {
            _controller._toggle_charging_set = true;
            _controller.actionMachine();
        } else if (item == :adjust_departure) {
			if (_controller._data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
	            _controller._adjust_departure = true;
	            _controller.actionMachine();
            }
            else {
				Ui.switchToView(new DepartureTimePicker(_controller._data._vehicle_data.get("charge_state").get("scheduled_departure_time_minutes")), new DepartureTimePickerDelegate(_controller), Ui.SLIDE_IMMEDIATE);
            }
        } else if (item == :toggle_sentry) {
            _controller._sentry_mode = true;
            _controller.actionMachine();
        } else if (item == :wake) {
            _controller._need_wake = true;
            _controller._wake_done = false;
            _controller.actionMachine();
        } else if (item == :refresh) {
            var refreshTimeInterval = Application.getApp().getProperty("refreshTimeInterval");
            Ui.switchToView(new RefreshPicker(refreshTimeInterval), new RefreshPickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :data_screen) {
            _controller._view_datascreen = true;
            _controller.actionMachine();
        } else if (item == :homelink) {
            _controller._homelink = true;
            _controller.actionMachine();
        } else if (item == :remote_boombox) {
            _controller._remote_boombox = true;
            _controller.actionMachine();
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
            _controller._handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
        }
    }
}
