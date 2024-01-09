using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;
using Toybox.Application.Storage;
using Toybox.Application.Properties;
using Toybox.Complications;

(:background, :can_glance)
class MyServiceDelegate extends System.ServiceDelegate {
    var _data;
    hidden var _serverAPILocation;
    hidden var _tessieToken;
    hidden var _batteryRangeType;
    hidden var _warnWhenPhoneNotConnected;

    function initialize() {
        System.ServiceDelegate.initialize();

        _data = {};

        onSettingsChanged();
    }

	function onSettingsChanged() {
        _serverAPILocation = $.getProperty("tessieAPILocation", "api.tessie.com", method(:validateString));
        _tessieToken = $.getProperty("tessieToken", "", method(:validateString));
        _batteryRangeType = $.getProperty("batteryRangeType", 0, method(:validateNumber));
        _warnWhenPhoneNotConnected = $.getProperty("WarnWhenPhoneNotConnected", false, method(:validateBoolean));
	}

    // This fires on our temporal event - we're going to go off and get the vehicle data, only if we have a token and vehicle ID
    function onTemporalEvent() {
        if (Storage.getValue("runBG") == false) { // We're in our Main View. it will refresh 'status' there by itself
            //DEBUG 2023-10-02*/ logMessage("onTemporalEvent: In main view, skipping reading data");
            Background.exit(null);
        }

        var vehicle = Storage.getValue("vehicle_vin");
        if (_serverAPILocation != null && _tessieToken.equals("") == false && vehicle != null) {
            //DEBUG*/ logMessage("onTemporalEvent getting data");
            Communications.makeWebRequest(
                "https://" + _serverAPILocation + "/" + vehicle + "/state?use_cache=false", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "accept" => "application/json",
                        "Authorization" => "Bearer " + _tessieToken
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                },
                method(:onReceiveVehicleData)
            );
        }
        else {
            //DEBUG 2023-10-02*/ logMessage("onTemporalEvent with token at " + (token == null ? token : token.substring(0, 10)) + " vehicle at " + vehicle);
            _data.put("responseCode", 401);

            $.sendComplication(_data);

            Background.exit(_data);
        }
    }

    function onReceiveVehicleData(responseCode, responseData) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled
        //DEBUG 2023-10-02*/ logMessage("onReceiveVehicleData: " + responseCode);
        //DEBUG*/ logMessage("onReceiveVehicleData: responseData=" + responseData);

        /*DEBUG*/ var myStats = System.getSystemStats();
        /*DEBUG*/ logMessage("Total memory: " + myStats.totalMemory + " Used memory: " + myStats.usedMemory + " Free memory: " + myStats.freeMemory);

        _data.put("responseCode", responseCode);

        var timestamp;
        try {
            var clock_time = System.getClockTime();
            var hours = clock_time.hour;
            var minutes = clock_time.min.format("%02d");
            var suffix = "";
            if (System.getDeviceSettings().is24Hour == false) {
                suffix = "am";
                if (hours == 0) {
                    hours = 12;
                }
                else if (hours > 12) {
                    suffix = "pm";
                    hours -= 12;
                }
            }

            timestamp = " @ " + hours + ":" + minutes + suffix;
        }
        catch (e) {
            timestamp = "";
        }
        _data.put("timestamp", timestamp);

        // Read what we need from the data received (if any) (typecheck since ERA reported Unexpected Type Error for 'response')
        if (responseCode == 200 && responseData != null && responseData instanceof Lang.Dictionary) {
            if (responseData.get("charge_state") != null && responseData.get("climate_state") != null && responseData.get("drive_state") != null) {
                var battery_level = $.validateNumber(responseData.get("charge_state").get("battery_level"), 0);
                var which_battery_type = _batteryRangeType;
                var bat_range_str = [ "battery_range", "est_battery_range", "ideal_battery_range"];

                _data.put("battery_level", battery_level);
                _data.put("battery_range", $.validateNumber(responseData.get("charge_state").get(bat_range_str[which_battery_type]), 0));
                _data.put("charging_state", $.validateString(responseData.get("charge_state").get("charging_state"), ""));
                _data.put("inside_temp", $.validateNumber(responseData.get("climate_state").get("inside_temp"), 0));
                _data.put("shift_state", (responseData.get("drive_state").get("shift_state") == null ? "P" : $.validateString(responseData.get("drive_state").get("shift_state"), "")));
                _data.put("sentry", $.validateBoolean(responseData.get("vehicle_state").get("sentry_mode"), false));
                _data.put("preconditioning", $.validateBoolean(responseData.get("charge_state").get("preconditioning_enabled"), false));
                _data.put("vehicleAwake", "awake"); // Hard code that we're awake if we get a 200
            }
            else {
                var state = responseData.get("state");
                if (state != null) {
                    _data.put("vehicleAwake", state); // Get the vehicle state
                }
            }
        }
        else if (responseCode == -104 && _warnWhenPhoneNotConnected) {
            if (!System.getDeviceSettings().phoneConnected) {
                // var ignore = Storage.getValue("PhoneLostDontAsk");
                // if (ignore == null) {
                    /*DEBUG 2023-10-02*/ logMessage("onReceiveVehicleData: Not connected to phone?");
                    Background.requestApplicationWake(App.loadResource(Rez.Strings.label_AskIfForgotPhone));
                // }
            }
        }
        //DEBUG*/ logMessageAndData("onReceiveVehicleData exiting with data=", _data);
        $.sendComplication(_data);

        Background.exit(_data);
    }
}
