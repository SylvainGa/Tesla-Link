using Toybox.WatchUi as Ui;

class OptionMenuDelegate extends Ui.MenuInputDelegate {
    var _controller;
	
    function initialize(controller) {
        Ui.MenuInputDelegate.initialize();
        _controller = controller;
    }

    function onMenuItem(item) {
        if (item == :reset) {
            Settings.setToken(null);
            Application.getApp().setProperty("vehicle", null);
        } else if (item == :honk) {
            _controller._honk_horn = true;
            _controller.stateMachine();
        } else if (item == :select_car) {
            _controller._tesla.getVehicleId(method(:onReceiveVehicles));
        } else if (item == :open_port) {
            _controller._open_port = true;
            _controller.stateMachine();
        } else if (item == :open_frunk) {
            _controller._open_frunk = true;
            _controller.stateMachine();
        } else if (item == :open_trunk) {
            _controller._open_trunk = true;
            _controller.stateMachine();
        } else if (item == :toggle_view) {
            var view = Application.getApp().getProperty("image_view");
            if (view) {
                Application.getApp().setProperty("image_view", false);
            } else {
                Application.getApp().setProperty("image_view", true);
            }
        } else if (item == :swap_frunk_for_port) {
            var swap = Application.getApp().getProperty("swap_frunk_for_port");
            if (swap == 0) {
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
            
            if (Application.getApp().getProperty("imperial")) {
            	driver_temp = driver_temp * 9.0 / 5.0 + 32.0;
            	max_temp = max_temp * 9.0 / 5.0 + 32.0;
            	min_temp = min_temp * 9.0 / 5.0 + 32.0;
            }

            Ui.pushView(new TemperaturePicker(driver_temp, max_temp, min_temp), new TemperaturePickerDelegate(_controller), Ui.SLIDE_UP);
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
            
            Ui.pushView(new ChargerPicker(charging_amps, max_amps), new ChargerPickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :set_charging_limit) {
        	var charging_limit = _controller._data._vehicle_data.get("charge_state").get("charge_limit_soc");
            
            Ui.pushView(new ChargingLimitPicker(charging_limit), new ChargingLimitPickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :set_seat_heat) {
	        var heat = 0;
            Ui.pushView(new SeatHeatPicker(heat), new SeatHeatPickerDelegate(_controller), Ui.SLIDE_UP);

			var rear_seats_avail = _controller._data._vehicle_data.get("climate_state").get("seat_heater_rear_left");
	        var seats = new [rear_seats_avail != null ? 7 : 3];

	        seats[0] = Rez.Strings.seat_driver;
	        seats[1] = Rez.Strings.seat_passenger;
	        if (rear_seats_avail != null) {
		        seats[2] = Rez.Strings.seat_rear_left;
		        seats[3] = Rez.Strings.seat_rear_center;
		        seats[4] = Rez.Strings.seat_rear_right;
		        seats[5] = Rez.Strings.seat_front;
		        seats[6] = Rez.Strings.seat_rear;
	        }
	        else {
		        seats[2] = Rez.Strings.seat_front;
	        }

	        Ui.pushView(new SeatPicker(seats), new SeatPickerDelegate(_controller), Ui.SLIDE_UP);
        } else if (item == :defrost) {
            _controller._set_climate_defrost = true;
            _controller.stateMachine();
        } else if (item == :set_steering_wheel_heat) {
            _controller._set_steering_wheel_heat = true;
            _controller.stateMachine();
        } else if (item == :vent) {
            _controller._vent = true;
            _controller.stateMachine();
        } else if (item == :toggle_charge) {
            _controller._toggle_charging_set = true;
            _controller.stateMachine();
        } else if (item == :adjust_departure) {
			if (_controller._data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
	            _controller._adjust_departure = true;
	            _controller.stateMachine();
            }
            else {
				Ui.pushView(new DepartureTimePicker(_controller._data._vehicle_data.get("charge_state").get("scheduled_departure_time_minutes")), new DepartureTimePickerDelegate(_controller), WatchUi.SLIDE_IMMEDIATE);
            }
        }
    }

    function onReceiveVehicles(responseCode, data) {
        if (responseCode == 200) {
            var vehicles = data.get("response");
            var vins = new [vehicles.size()];
            for (var i = 0; i < vehicles.size(); i++) {
                vins[i] = vehicles[i].get("display_name");
            }
            Ui.pushView(new CarPicker(vins), new CarPickerDelegate(_controller), Ui.SLIDE_UP);
        } else {
            _controller._handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString());
        }
    }
}
