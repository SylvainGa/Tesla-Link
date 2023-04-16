using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

enum /* WEB REQUEST CONTEXT */ {
	CONTEXT_TEMPORAL_EVENT = 0,
	CONTEXT_TOKEN_REFRESH = 1
}

(:background, :can_glance, :bkgnd32kb)
class MyServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        System.ServiceDelegate.initialize();
    }

    // This fires on our temporal event - we're going to go off and get the vehicle data, only if we have a token and vehicle ID
    function onTemporalEvent() {
        var token = Storage.getValue("token");
        var vehicle = Storage.getValue("vehicle");
        if (token != null && vehicle != null) {
            //DEBUG*/ logMessage("onTemporalEvent getting data");
            Communications.makeWebRequest(
                "https://" + Properties.getValue("serverAPILocation") + "/api/1/vehicles/" + vehicle.toString() + "/vehicle_data", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token,
                        "User-Agent" => "Tesla-Link for Garmin"
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
                },
                method(:onReceiveVehicleData)
            );
        }
        else {
            //DEBUG*/ logMessage("onTemporalEvent with token at " + (token == null ? token : token.substring(0, 10)) + " vehicle at " + vehicle);
            Background.exit({"responseCode" => 401, "status" => "401|N/A|N/A|0||" + Application.loadResource(Rez.Strings.label_launch_widget)});
        }
    }

    function onReceiveVehicleData(responseCode, responseData) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled
        //DEBUG*/ logMessage("onReceiveVehicleData: responseCode = " + responseCode);
        //DEBUG*/ logMessage("onReceiveVehicleData: responseData = " + responseData);

        var data = Background.getBackgroundData();
        if (data == null) {
            data = {};
		}
        else {
            //DEBUG*/ logMessage("onReceiveVehicleData already has background data! -> '" + data + "'");
        }

        var battery_level;
        var charging_state;
        var battery_range;

        var status = Storage.getValue("status");
        if (status != null && status.equals("") == false) {
            var array = to_array(status, "|");
            if (array.size() == 6) {
                //responseCode = array[0].toNumber();
                battery_level = array[1];
                charging_state = array[2];
                battery_range = array[3];
            }
        }
        if (battery_level == null) {
            battery_level = "N/A";
            charging_state = "N/A";
            battery_range = "0";
        }

        // Deal with appropriately - we care about awake (200), non authenticated (401) or asleep (408)
        var timestamp;
        try {
            var clock_time = System.getClockTime();
            timestamp = " @ " + clock_time.hour.format("%d")+ ":" + clock_time.min.format("%02d");
        }
        catch (e) {
            timestamp = "";
        }

        if (responseCode == 200 && responseData != null) {
            var pos = responseData.find("battery_level");
            var str = responseData.substring(pos + 15, pos + 20);
            var posEnd = str.find(",");
            battery_level = str.substring(0, posEnd);

            pos = responseData.find("battery_range");
            str = responseData.substring(pos + 15, pos + 22);
            posEnd = str.find(",");
            battery_range = str.substring(0, posEnd);

            pos = responseData.find("charging_state");
            str = responseData.substring(pos + 17, pos + 37);
            posEnd = str.find("\"");
            charging_state = str.substring(0, posEnd);

            timestamp = timestamp + "|";
        }
        else if (responseCode == 401) {
            timestamp = timestamp + "|" + Application.loadResource(Rez.Strings.label_launch_widget);
        }
        else if (responseCode == 408) {
            timestamp = timestamp + "|" + Application.loadResource(Rez.Strings.label_asleep);
        }
        else {
            timestamp = timestamp + "|" + Application.loadResource(Rez.Strings.label_error) + responseCode.toString();
        }

        status = responseCode + "|" + battery_level + "|" + charging_state + "|" + battery_range.toNumber() + "|" + timestamp;
        data.put("status", status);

        //DEBUG*/ logMessage("onReceiveVehicleData exiting with data=" + data);
        Background.exit(data);
    }
}

(:background, :can_glance, :bkgnd64kb)
class MyServiceDelegate extends System.ServiceDelegate {
    var _data;

    function initialize() {
        _data = Background.getBackgroundData();
        if (_data == null) {
            /*DEBUG*/ logMessage("ServiceDelegate Initialisation fetching tokens from properties");
            _data = {};
            _data.put("token", Storage.getValue("token"));
            _data.put("refreshToken", Properties.getValue("refreshToken"));
            _data.put("TokenExpiresIn", Storage.getValue("TokenExpiresIn"));
            _data.put("TokenCreatedAt", Storage.getValue("TokenCreatedAt"));
        }
        else {
            /*DEBUG*/ logMessage("ServiceDelegate Initialisation with tokens already");
        }

        System.ServiceDelegate.initialize();
    }

    // This fires on our temporal event - we're going to go off and get the vehicle data, only if we have a token and vehicle ID
    function onTemporalEvent() {
        var token = Storage.getValue("token");
        var vehicle = Storage.getValue("vehicle");
        if (token != null && vehicle != null) {
            /*DEBUG*/ logMessage("onTemporalEvent getting data");
            Communications.makeWebRequest(
                "https://" + Properties.getValue("serverAPILocation") + "/api/1/vehicles/" + vehicle.toString() + "/vehicle_data", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token,
                        "User-Agent" => "Tesla-Link for Garmin"
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                    :context => CONTEXT_TEMPORAL_EVENT
                },
                method(:onReceiveVehicleData)
            );
        }
        else {
            /*DEBUG*/ logMessage("onTemporalEvent with token at " + (token == null ? token : token.substring(0, 10)) + " vehicle at " + vehicle);
            _data.put("responseCode", 401);
            Background.exit(_data);
        }
    }

    function onReceiveVehicleData(responseCode, responseData, context) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled
        /*DEBUG*/ logMessage("onReceiveVehicleData: responseCode = " + responseCode + ", context is " + context);
        //DEBUG*/ logMessage("onReceiveVehicleData: responseData = " + responseData);

        var timestamp;
        try {
            var clock_time = System.getClockTime();
            timestamp = " @ " + clock_time.hour.format("%d")+ ":" + clock_time.min.format("%02d");
        }
        catch (e) {
            timestamp = "";
        }
        _data.put("timestamp", timestamp);

        // Deal with appropriately - we care about awake (200), non authenticated (401) or asleep (408)
        if (responseCode == 200 && responseData != null) {
            var battery_level;
            var charging_state;
            var battery_range;
            var inside_temp;
            var status;

			var response = responseData.get("response");
            battery_level = response.get("charge_state").get("battery_level");
            battery_range = response.get("charge_state").get("battery_range");
            charging_state = response.get("charge_state").get("charging_state");
            inside_temp = response.get("climate_state").get("inside_temp");
            var drive_state = response.get("drive_state");
            if (drive_state != null && drive_state.get("shift_state") != null && drive_state.get("shift_state").equals("P") == false) {
                status = responseCode + "|" + battery_level + "|" + charging_state + "|" + battery_range.toNumber() + "|" + inside_temp + "| " + Application.loadResource(Rez.Strings.label_driving) + "||";
            }
            else {
                var sentry = (response.get("vehicle_state").get("sentry_mode").equals("true") ? Application.loadResource(Rez.Strings.label_s_on) : Application.loadResource(Rez.Strings.label_s_off));
                var preconditioning = (response.get("charge_state").get("preconditioning_enabled").equals("true") ? Application.loadResource(Rez.Strings.label_p_on) : Application.loadResource(Rez.Strings.label_p_off));
                status = responseCode + "|" + battery_level + "|" + charging_state + "|" + battery_range.toNumber() + "|" + inside_temp + "| " + sentry + "| " + preconditioning + "|";
            }

            _data.put("status", status);
            _data.put("responseCode", responseCode);

            /*DEBUG*/ logMessageAndData("onReceiveVehicleData exiting with data=", _data);
            Background.exit(_data);
            return;
        }
        else if (responseCode == 401) {
            if (context == CONTEXT_TEMPORAL_EVENT) {
                refreshAccessToken();
                return;
            }
        }
        else if (responseCode == 408) {
            testAwake();
            return;
        }

        _data.put("responseCode", responseCode);

        /*DEBUG*/ logMessageAndData("onReceiveVehicleData exiting with data=", _data);
        Background.exit(_data);
    }

    function testAwake() {
        /*DEBUG*/ logMessage("testAwake called");
        var token = _data.get("token");

        Communications.makeWebRequest(
            "https://" + Properties.getValue("serverAPILocation") + "/api/1/vehicles", null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                   "Authorization" => "Bearer " + token,
				   "User-Agent" => "Tesla-Link for Garmin"
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceiveVehicles)
        );
    }

	function onReceiveVehicles(responseCode, data) {
		/*DEBUG*/ logMessage("onReceiveVehicles: " + responseCode);
		//logMessage("onReceiveVehicles: data is " + data);

		if (responseCode == 200) {
			var vehicles = data.get("response");
			var size = vehicles.size();
			if (size > 0) {
				// Need to retrieve the right vehicle, not just the first one!
				var vehicle_index = 0;
				var vehicle_name = Storage.getValue("vehicle_name");
				if (vehicle_name != null) {
					while (vehicle_index < size) {
                        if (vehicle_name.equals(vehicles[vehicle_index].get("display_name"))) {
                            break;
                        }
                        vehicle_index++;
                    }
                }

                if (vehicle_index == size) {
                    /*DEBUG*/ logMessage("onReceiveVehicles: Not found");
                    _data.put("vehicleAwake", "Not found");
                }
                else {
                    var vehicle_state = vehicles[vehicle_index].get("state");
                    /*DEBUG*/ logMessage("onReceiveVehicles: vehicle state: " + vehicle_state);
                    _data.put("vehicleAwake", vehicle_state);
				}
			}
            else {
                _data.put("vehicleAwake", "No vehicle");
            }
        }
        else {
            _data.put("vehicleAwake", "error");
        }

        _data.put("responseCode", 408);
        /*DEBUG*/ logMessageAndData("onReceiveVehicles exiting with data=", _data);
        Background.exit(_data);
    }

    // Do NOT call from a background process since we're setting registry data in onReceiveToken
    function refreshAccessToken() {
        /*DEBUG*/ logMessage("refreshAccessToken called");
        var refreshToken = _data.get("refreshToken");
        if (refreshToken != null && refreshToken.length() != 0) {
            var url = "https://" + Properties.getValue("serverAUTHLocation") + "/oauth2/v3/token";
            Communications.makeWebRequest(
                url,
                {
                    "grant_type" => "refresh_token",
                    "client_id" => "ownerapi",
                    "refresh_token" => refreshToken,
                    "scope" => "openid email offline_access"
                },
                {
                    :method => Communications.HTTP_REQUEST_METHOD_POST,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:onReceiveToken)
            );
            return;
        }

        _data.put("responseCode", 401);
        /*DEBUG*/ logMessageAndData("refreshAccessToken exiting with data=", _data);
        Background.exit(_data);
    }

    // Do NOT call from a background process since we're setting registry data here
    function onReceiveToken(responseCode, data) {
        /*DEBUG*/ logMessage("onReceiveToken: " + responseCode);

        if (responseCode == 200) {
            var token = data["access_token"];
            var refreshToken = data["refresh_token"];
            var expires_in = data["expires_in"];
            //var state = data["state"];
            var created_at = Time.now().value();

			/*DEBUG*/ var expireAt = new Time.Moment(created_at + expires_in);
			/*DEBUG*/ var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
			/*DEBUG*/ var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
			/*DEBUG*/ logMessage("onReceiveToken: Expires at " + dateStr);

            //logMessage("onReceiveToken: state field is '" + state + "'");

            _data.put("token", token);
            _data.put("refreshToken", refreshToken);
            _data.put("TokenExpiresIn", expires_in);
            _data.put("TokenCreatedAt", created_at);

            /*DEBUG*/ logMessage("onReceiveToken getting data");
            var vehicle = Storage.getValue("vehicle");
            Communications.makeWebRequest(
                "https://" + Properties.getValue("serverAPILocation") + "/api/1/vehicles/" + vehicle.toString() + "/vehicle_data", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token,
                        "User-Agent" => "Tesla-Link for Garmin"
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                    :context => CONTEXT_TOKEN_REFRESH
                },
                method(:onReceiveVehicleData)
            );
        }
        else {
            _data.put("responseCode", 401);
            /*DEBUG*/ logMessageAndData("onReceiveToken exiting with data=", _data);
            Background.exit(_data);
        }
    }
}
