using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;

(:background, :can_glance)
class MyServiceDelegate extends System.ServiceDelegate {

    function initialize() {
        System.ServiceDelegate.initialize();
    }

    // This fires on our temporal event - we're going to go off and get the vehicle data, only if we have a token and vehicle ID
    function onTemporalEvent() {

        /*DEBUG*/ logMessage("ServiceDelegate: onTemporalEvent");
        var token = Application.getApp().getProperty("token");
        var vehicle = Application.getApp().getProperty("vehicle");
        if (token != null && vehicle != null) {
            /*DEBUG*/ logMessage("ServiceDelegate : onTemporalEvent getting data");
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
            Background.exit({"responseCode" => 401, "status" => "0|N/A|N/A|0| |" + Application.loadResource(Rez.Strings.label_launch_widget)});
        }
    }

    (:can_glance, :bkgnd32kb)
    function onReceiveVehicleData(responseCode, responseData) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled

        var data = Background.getBackgroundData();
        if (data == null) {
            data = {};
		}
        else {
            /*DEBUG*/ logMessage("ServiceDelegate:onTemporalEvent already has background data! -> '" + data + "'");
        }
        /*DEBUG*/ logMessage("ServiceDelegate:onReceiveVehicleData: responseCode = " + responseCode);
        //DEBUG*/ logMessage("ServiceDelegate:onReceiveVehicleData: responseData = " + responseData);

        var battery_level;
        var charging_state;
        var battery_range;

        var status = Application.getApp().getProperty("status");
        if (status != null) {
            var array = to_array(status, "|");

            //responseCode = array[0].toNumber();
            battery_level = array[1];
            charging_state = array[2];
            battery_range = array[3];
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
            suffix = " ";
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
            suffix = suffix + "| ";
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

        data.put("status", responseCode + "|" + battery_level + "|" + charging_state + "|" + battery_range.toNumber() + "|" + suffix);
        data.put("responseCode", responseCode);

        Background.exit(data);
    }

    (:bkgnd64kb)
    function onReceiveVehicleData(responseCode, responseData) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled

        var data = Background.getBackgroundData();
        if (data == null) {
            data = {};
		}
        else {
            /*DEBUG*/ logMessage("ServiceDelegate:onTemporalEvent already has background data! -> '" + data + "'");
        }
        /*DEBUG*/ logMessage("ServiceDelegate:onReceiveVehicleData: responseCode = " + responseCode);
        //DEBUG*/ logMessage("ServiceDelegate:onReceiveVehicleData: responseData = " + responseData);

        var battery_level;
        var charging_state;
        var battery_range;
        var inside_temp;
        var sentry;
        var preconditioning;

        var status = Application.getApp().getProperty("status");
        if (status != null) {
            var array = to_array(status, "|");

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
            suffix = " ";
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

            pos = responseData.find("inside_temp");
            str = responseData.substring(pos + 13, pos + 23);
            posEnd = str.find(",");
            inside_temp = str.substring(0, posEnd);

            pos = responseData.find("sentry_mode");
            str = responseData.substring(pos + 13, pos + 19);
            posEnd = str.find(",");
            sentry = str.substring(0, posEnd);

            pos = responseData.find("preconditioning_enabled");
            str = responseData.substring(pos + 25, pos + 31);
            posEnd = str.find(",");
            preconditioning = str.substring(0, posEnd);

            suffix = suffix + "| ";
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
        data.put("status", status);
        data.put("responseCode", responseCode);

        Background.exit(data);
    }
}
