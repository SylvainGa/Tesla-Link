using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;

enum /* WEB REQUEST CONTEXT */ {
	CONTEXT_BACKGROUND = 0,
	CONTEXT_APP = 1
}

(:background, :can_glance)
class MyServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        System.ServiceDelegate.initialize();
    }

    // This fires on our temporal event - we're going to go off and get the vehicle data, only if we have a token and vehicle ID
    (:bkgnd32kb)
    function onTemporalEvent() {
        var token = Application.getApp().getProperty("token");
        var vehicle = Application.getApp().getProperty("vehicle");
        if (token != null && vehicle != null) {
            //DEBUG*/ logMessage("onTemporalEvent getting data");
            Communications.makeWebRequest(
                "https://" + Application.getApp().getProperty("serverAPILocation") + "/api/1/vehicles/" + Application.getApp().getProperty("vehicle").toString() + "/vehicle_data", null,
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

    // This fires on our temporal event - we're going to go off and get the vehicle data, only if we have a token and vehicle ID
    (:bkgnd64kb)
    function onTemporalEvent() {
        var token = Application.getApp().getProperty("token");
        var vehicle = Application.getApp().getProperty("vehicle");
        if (token != null && vehicle != null) {
            /*DEBUG*/ logMessage("onTemporalEvent getting data");
            Communications.makeWebRequest(
                "https://" + Application.getApp().getProperty("serverAPILocation") + "/api/1/vehicles/" + Application.getApp().getProperty("vehicle").toString() + "/vehicle_data", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token,
                        "User-Agent" => "Tesla-Link for Garmin"
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                    :context => CONTEXT_BACKGROUND
                },
                method(:onReceiveVehicleData)
            );
        }
        else {
            /*DEBUG*/ logMessage("onTemporalEvent with token at " + (token == null ? token : token.substring(0, 10)) + " vehicle at " + vehicle);
            Background.exit({"responseCode" => 401, "status" => "401|N/A|N/A|0|0|N/A|N/A||" + Application.loadResource(Rez.Strings.label_launch_widget)});
        }
    }

    (:bkgnd32kb)
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

        var status = Application.getApp().getProperty("status");
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
        var suffix;
        try {
            var clock_time = System.getClockTime();
            suffix = " @ " + clock_time.hour.format("%d")+ ":" + clock_time.min.format("%02d");
        }
        catch (e) {
            suffix = "";
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

            suffix = suffix + "|";
        }
        else if (responseCode == 401) {
            suffix = suffix + "|" + Application.loadResource(Rez.Strings.label_launch_widget);
        }
        else if (responseCode == 408) {
            suffix = suffix + "|" + Application.loadResource(Rez.Strings.label_asleep);
        }
        else {
            suffix = suffix + "|" + Application.loadResource(Rez.Strings.label_error) + responseCode.toString();
        }

        status = responseCode + "|" + battery_level + "|" + charging_state + "|" + battery_range.toNumber() + "|" + suffix;
        data.put("status", status);

        //DEBUG*/ logMessage("onReceiveVehicleData exiting with data=" + data);
        Background.exit(data);
    }

    (:bkgnd64kb)
    function onReceiveVehicleData(responseCode, responseData, context) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled
        /*DEBUG*/ logMessage("onReceiveVehicleData: responseCode = " + responseCode);
        //DEBUG*/ logMessage("onReceiveVehicleData: responseData = " + responseData);

        var data;
        if (context == CONTEXT_BACKGROUND) {
            /*DEBUG*/ logMessage("onReceiveVehicleData called from Background");
            data = Background.getBackgroundData();
            if (data == null) {
                data = {};
            }
            else {
                /*DEBUG*/ logMessage("onReceiveVehicleData already has background data! -> '" + data + "'");
            }
        }
        else {
            /*DEBUG*/ logMessage("onReceiveVehicleData called from App");
        }

        var battery_level;
        var charging_state;
        var battery_range;
        var inside_temp;
        var sentry;
        var preconditioning;

        var status = Application.getApp().getProperty("status");
        if (status != null && status.equals("") == false) {
            var array = to_array(status, "|");
            if (array.size() == 9) {
                //responseCode = array[0].toNumber();
                battery_level = array[1];
                charging_state = array[2];
                battery_range = array[3];
                inside_temp = array[4];
                sentry = array[5];
                preconditioning = array[6];
                //suffix = array[7];
                //text = array[8];
            }
        }
        if (battery_level == null) {
            battery_level = "N/A";
            charging_state = "N/A";
            battery_range = "0";
            inside_temp = "0";
            sentry = "N/A";
            preconditioning = "N/A";
        }

        // Deal with appropriately - we care about awake (200), non authenticated (401) or asleep (408)
        var suffix;
        try {
            var clock_time = System.getClockTime();
            suffix = " @ " + clock_time.hour.format("%d")+ ":" + clock_time.min.format("%02d");
        }
        catch (e) {
            suffix = "";
        }

        if (responseCode == 200 && responseData != null) {
			var response = responseData.get("response");
            battery_level = response.get("charge_state").get("battery_level");
            battery_range = response.get("charge_state").get("battery_range");
            charging_state = response.get("charge_state").get("charging_state");
            inside_temp = response.get("climate_state").get("inside_temp");
            sentry = response.get("vehicle_state").get("sentry_mode");
            preconditioning = response.get("charge_state").get("preconditioning_enabled");

            suffix = suffix + "|";
        }
        else if (responseCode == 401) {
            var refreshToken = Application.getApp().getProperty("refreshToken");
            if (refreshToken != null && refreshToken.length() != 0) {
                suffix = suffix + "|" + Application.loadResource(Rez.Strings.label_waiting_data);
            }
            else {
                suffix = suffix + "|" + Application.loadResource(Rez.Strings.label_launch_widget);
            }
        }
        else if (responseCode == 408) {
            suffix = suffix + "|";
        }
        else {
            suffix = suffix + "|" + Application.loadResource(Rez.Strings.label_error) + responseCode.toString();
        }

        status = responseCode + "|" + battery_level + "|" + charging_state + "|" + battery_range.toNumber() + "|" + inside_temp + "|" + sentry + "|" + preconditioning + "|" + suffix;

        if (context == CONTEXT_BACKGROUND) {
            data.put("status", status);
            data.put("responseCode", responseCode);

            /*DEBUG*/ logMessage("onReceiveVehicleData exiting with data=" + data);
            Background.exit(data);
        }
        else {
            /*DEBUG*/ logMessage("onReceiveVehicleData exiting with status=" + status);
            Application.getApp().setProperty("status", status);
            Ui.requestUpdate();
        }
    }

    (:bkgnd64kb)
    function GetVehicleData() {
        var token = Application.getApp().getProperty("token");
        var vehicle = Application.getApp().getProperty("vehicle");
        if (token != null && vehicle != null) {
            /*DEBUG*/ logMessage("GetVehicleData getting data");
            Communications.makeWebRequest(
                "https://" + Application.getApp().getProperty("serverAPILocation") + "/api/1/vehicles/" + Application.getApp().getProperty("vehicle").toString() + "/vehicle_data", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token,
                        "User-Agent" => "Tesla-Link for Garmin"
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                    :context => CONTEXT_APP
                },
                method(:onReceiveVehicleData)
            );
        }
    }
}
