class Tesla {
    hidden var _token;
    hidden var _notify;

    function initialize(token) {
        if (token != null) {
            _token = "Bearer " + token;
        }
    }

    hidden function genericGet(url, notify) {
        Communications.makeWebRequest(
            url, null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    (:background)
    hidden function genericPost(url, notify) {
        Communications.makeWebRequest(
            url,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    function getVehicleId(notify) {
        genericGet("https://owner-api.teslamotors.com/api/1/vehicles", notify);
    }

    (:background)
    function getVehicle(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString();
        genericGet(url, notify);
    }

    (:background)
    function getVehicleData(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/vehicle_data";
        genericGet(url, notify);
    }

    (:background)
    function getVehicleState(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/data_request/vehicle_state";
        genericGet(url, notify);
    }

    (:background)
    function getClimateState(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/data_request/climate_state";
        genericGet(url, notify);
    }

    (:background)
    function getChargeState(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/data_request/charge_state";
        genericGet(url, notify);
    }

    function wakeVehicle(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/wake_up";
        genericPost(url, notify);
    }

    function climateOn(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/auto_conditioning_start";
        genericPost(url, notify);
    }

    function climateOff(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/auto_conditioning_stop";
        genericPost(url, notify);
    }

    function climateSet(vehicle, notify, temperature) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/set_temps";
        Communications.makeWebRequest(
            url,
            {
                "driver_temp" => temperature,
                "passenger_temp" => temperature,
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    function honkHorn(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/honk_horn";
        genericPost(url, notify);
    }
    
    //Opens vehicle charge port. Also unlocks the charge port if it is locked.
    function openPort(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/charge_port_door_open";
        genericPost(url, notify);
    }

    function doorUnlock(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/door_unlock";
        genericPost(url, notify);
    }

    function doorLock(vehicle, notify) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/door_lock";
        genericPost(url, notify);
    }

    function openTrunk(vehicle, notify, which) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/actuate_trunk";
        Communications.makeWebRequest(
            url,
            {
                "which_trunk" => which
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    function vent(vehicle, notify, which, lat, lon) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/window_control";
        Communications.makeWebRequest(
            url,
            {
                "command" => which,
                "lat" => lat,
                "lon" => lon
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    function climateDefrost(vehicle, notify, defrost_mode) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/set_preconditioning_max";

        Communications.makeWebRequest(
            url,
            {
                "on" => defrost_mode != 2
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }
    
    function climateSeatHeat(vehicle, notify, seat_chosen, heat_chosen) {
		var url;
		var options;
		
		if (heat_chosen >= 0) {
	        url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/remote_seat_heater_request";
	        options = 
            {
                "heater" => seat_chosen,
                "level" => heat_chosen
            };
		} else {
	        url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/remote_auto_seat_climate_request";
	        options = 
            {
                "auto_seat_position" => seat_chosen + 1,
                "auto_climate_on" => true
            };
		}
        Communications.makeWebRequest(
            url,
            options,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }
    
    function climateSteeringWheel(vehicle, notify, steering_wheel_mode) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/remote_steering_wheel_heater_request";

        Communications.makeWebRequest(
            url,
            {
                "on" => !steering_wheel_mode
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }
    
    function setChargingLimit(vehicle, notify, charging_limit) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/set_charge_limit";
        Communications.makeWebRequest(
            url,
            {
                "percent" => charging_limit
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    function setChargingAmps(vehicle, notify, charging_amps) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/set_charging_amps";
        Communications.makeWebRequest(
            url,
            {
                "charging_amps" => charging_amps
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    function toggleCharging(vehicle, notify, charging) {
        var url;
        
        if (charging) {
        	url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/charge_stop";
        }
        else {
        	url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/charge_start";
        }
        genericPost(url, notify);
    }

    function setDeparture(vehicle, notify, departureTime, enable) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/set_scheduled_departure";

        Communications.makeWebRequest(
            url,
            {
                "enable" => enable,
                "departure_time" => departureTime,
                "preconditioning_enabled" => enable,
                "preconditioning_weekdays_only" => false,
                "off_peak_charging_enabled" => false,
                "off_peak_charging_weekdays_only" => false,
                "end_off_peak_time" => 360
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    function SentryMode(vehicle, notify, value) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/set_sentry_mode";

        Communications.makeWebRequest(
            url,
            {
                "on" => value
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    function homelink(vehicle, notify, lat, lon) {
        var url = "https://owner-api.teslamotors.com/api/1/vehicles/" + vehicle.toString() + "/command/trigger_homelink";
        Communications.makeWebRequest(
            url,
            {
                "lat" => lat,
                "lon" => lon
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }
}