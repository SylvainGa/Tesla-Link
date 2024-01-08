using Toybox.Application.Properties;

class Tesla {
    hidden var _token;
    hidden var _serverAPILocation;

    function initialize(token) {
        if (token != null) {
            _token = "Bearer " + token;
        }
        _serverAPILocation = "https://" + $.getProperty("tessieAPILocation", "api.tessie.com", method(:validateString)) + "/";
    }

    hidden function genericGet(url, notify) {
        Communications.makeWebRequest(
            url, null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "accept" => "application/json",
                    "Authorization" => _token
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    hidden function genericPost(url, notify) {
        Communications.makeWebRequest(
            url,
            {
                "dummy" => "dummy"
            },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "accept" => "application/json",
                    "Authorization" => _token,
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            notify
        );
    }

    function getVehicles(notify) {
        genericGet(_serverAPILocation + "vehicles?only_active=true", notify);
    }

    function getVehicleStatus(vehicle, notify) {
        genericGet(_serverAPILocation + vehicle + "/status", notify);
    }

    function getVehicleData(vehicle, notify) {
        genericGet(_serverAPILocation + vehicle + "/state?use_cache=true", notify);
    }

    function wakeVehicle(vehicle, notify) {
        genericGet(_serverAPILocation + vehicle + "/wake", notify);
    }

    function climateOn(vehicle, delay, wait, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/start_climate?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function climateOff(vehicle, delay, wait, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/stop_climate?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function climateSet(vehicle, delay, wait, temperature, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/set_temperatures?retry_duration=" + delay + "&wait_for_completion=" + wait + "&temperature=" + temperature, notify);
    }

    function honkHorn(vehicle, delay, wait, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/honk?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }
    
    //Opens vehicle charge port. Also unlocks the charge port if it is locked.
    function openPort(vehicle, delay, wait, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/open_charge_port?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function closePort(vehicle, delay, wait, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/close_charge_port?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function doorUnlock(vehicle, delay, wait, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/unlock?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function doorLock(vehicle, delay, wait, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/lock?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function openTrunk(vehicle, delay, wait, which, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/activate_" + (which ? "rear" : "front") + "_trunk?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function vent(vehicle, delay, wait, which, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/" + (which ? "vent" : "close") + "_windows?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function climateDefrost(vehicle, delay, wait, isDefrostOn, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/" + (isDefrostOn ? "stop" : "start") + "_max_defrost?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }
    
    function climateSeatHeat(vehicle, delay, wait, seat_chosen, heat_chosen, notify) {
        if (heat_chosen >= 0) {
            genericGet(_serverAPILocation + vehicle + "/command/set_seat_heat?retry_duration=" + delay + "&wait_for_completion=" + wait + "&seat=" + seat_chosen + "&level=" + heat_chosen, notify);
        }
    }

    function climateSteeringWheel(vehicle, delay, wait, steering_wheel_mode, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/" + (steering_wheel_mode ? "stop" : "start") + "_steering_wheel_heater?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }
    
    function setChargingLimit(vehicle, delay, wait, charging_limit, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/set_charge_limit?retry_duration=" + delay + "&wait_for_completion=" + wait + "&percent=" + charging_limit, notify);
    }

    function setChargingAmps(vehicle, delay, wait, charging_amps, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/set_charging_amps?retry_duration=" + delay + "&wait_for_completion=" + wait + "&amps=" + charging_amps, notify);
    }

    function toggleCharging(vehicle, delay, wait, charging, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/" + (charging ? "stop" : "start") + "_charging?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function setDeparture(vehicle, delay, wait, departureTime, enable, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/set_scheduled_departure" + "_charging?retry_duration=" + delay + "&wait_for_completion=" + wait + "&enable=" + enable + "&departure_time=" + departureTime + "&preconditioning_enabled=true&preconditioning_weekdays_only=false&off_peak_charging_enabled=false&off_peak_charging_weekdays_only=false");
    }

    function SentryMode(vehicle, delay, wait, value, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/" + (value ? "enable" : "disable") + "_sentry?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function homelink(vehicle, delay, wait, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/trigger_homelink?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function setClimateMode(vehicle, delay, wait, mode, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/set_climate_keeper_mode?retry_duration=" + delay + "&wait_for_completion=" + wait + "&mode=" + mode, notify);
    }

    function remoteBoombox(vehicle, delay, wait, notify) {
        genericGet(_serverAPILocation + vehicle + "/command/remote_boombox?retry_duration=" + delay + "&wait_for_completion=" + wait, notify);
    }

    function mediaTogglePlayback(vehicle, notify) {
        var url = _serverAPILocation + "/api/1/vehicles/" + vehicle.toString() + "/command/media_toggle_playback";
        genericPost(url, notify);
    }

    function mediaPrevTrack(vehicle, notify) {
        var url = _serverAPILocation + "/api/1/vehicles/" + vehicle.toString() + "/command/media_prev_track";
        genericPost(url, notify);
    }

    function mediaNextTrack(vehicle, notify) {
        var url = _serverAPILocation + "/api/1/vehicles/" + vehicle.toString() + "/command/media_next_track";
        genericPost(url, notify);
    }

    function mediaVolumeDown(vehicle, notify) {
        var url = _serverAPILocation + "/api/1/vehicles/" + vehicle.toString() + "/command/media_volume_down";
        genericPost(url, notify);
    }

    function mediaVolumeUp(vehicle, notify) {
        var url = _serverAPILocation + "/api/1/vehicles/" + vehicle.toString() + "/command/media_volume_up";
        genericPost(url, notify);
    }
}