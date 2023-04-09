using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;

(:background, :can_glance)
class MyServiceDelegate extends System.ServiceDelegate {

    var _token;
    var _tesla;
    var _vehicle_id;

    function initialize() {
        System.ServiceDelegate.initialize();
        
        _token = Settings.getToken();
        //System.println("ServiceDelegate: token = " + _token);
        _tesla = new Tesla(_token);
        _vehicle_id = Application.getApp().getProperty("vehicle");
    }

    // This fires on our temporal event - we're going to go off and get the vehicle data, only if we have a token and vehicle ID
    function onTemporalEvent() {

        //DEBUG*/ logMessage("ServiceDelegate: onTemporalEvent");
        if (_token != null && _vehicle_id != null) {
            //DEBUG*/ logMessage("ServiceDelegate : onTemporalEvent getting data");
            _tesla.getVehicleData(_vehicle_id, method(:onReceiveVehicleData));
        }
    }

    function onReceiveVehicleData(responseCode, responseData) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled

        var data = Background.getBackgroundData();
        if (data == null) {
            data = {};
		}
        else {
            //DEBUG*/ logMessage("ServiceDelegate:onTemporalEvent already has background data! -> '" + data + "'");
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
            //suffix = array[4];
            //text = array[5];
        }
        else {
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
            var vehicle_data = responseData.get("response");
            if (vehicle_data != null) {
                var charge_state =  vehicle_data.get("charge_state");
                if (charge_state != null) {
                    battery_level = charge_state.get("battery_level");
                    battery_range = charge_state.get("battery_range") * (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6);
                    charging_state = charge_state.get("charging_state");
                    var inside_temp = vehicle_data.get("climate_state").get("inside_temp");
                    inside_temp = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? ((inside_temp.toNumber()*9/5) + 32) + "°F" : inside_temp.toNumber() + "°C";
                    var sentry = (vehicle_data.get("vehicle_state").get("sentry_mode") ? " S On" : " S Off");
                    var preconditioning = (vehicle_data.get("charge_state").get("preconditioning_enabled") ? " P On" : " P Off");
                    suffix = suffix + "|\n" + inside_temp + sentry + preconditioning;
                }
                else {
                    suffix = suffix + "|\n" + Application.loadResource(Rez.Strings.label_launch_widget);
                }
            }
            else {
                suffix = suffix + "|\n" + Application.loadResource(Rez.Strings.label_launch_widget);
            }
        }
        else if (responseCode == 401) {
            var _refreshToken = Settings.getRefreshToken();
            if (_refreshToken != null && _refreshToken.length() != 0) {
                suffix = suffix + "|\n" + Application.loadResource(Rez.Strings.label_waiting_data);
            }
            else {
                suffix = suffix + "|\n" + Application.loadResource(Rez.Strings.label_launch_widget);
            }
        }
        else if (responseCode == 408) {
            suffix = suffix + "|\n" + Application.loadResource(Rez.Strings.label_asleep);
        }
        else {
            suffix = suffix + "|\n" + Application.loadResource(Rez.Strings.label_error) + responseCode.toString();
        }

        data.put("status", responseCode + "|" + battery_level + "|" + charging_state + "|" + battery_range.toNumber() + "|" + suffix);
        data.put("responseCode", responseCode);

        Background.exit(data);
    }

    // Do NOT call from a background process since we're setting registry data in onReceiveToken
    function GetAccessToken() {
        logMessage("ServiceDelegate:GetAccessToken");
        var _refreshToken = Settings.getRefreshToken();
        var _debug_auth = false;

        if (_debug_auth == false && _refreshToken != null && _refreshToken.length() != 0) {
            var url = "https://" + Application.getApp().getProperty("serverAUTHLocation") + "/oauth2/v3/token";
            Communications.makeWebRequest(
                url,
                {
                    "grant_type" => "refresh_token",
                    "client_id" => "ownerapi",
                    "refresh_token" => _refreshToken,
                    "scope" => "openid email offline_access"
                },
                {
                    :method => Communications.HTTP_REQUEST_METHOD_POST,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:onReceiveToken)
            );
        }
   }

    // Do NOT call from a background process since we're setting registry data here
	function onReceiveToken(responseCode, data) {
		/*DEBUG*/ logMessage("onReceiveToken: " + responseCode);

		if (responseCode == 200) {
			var accessToken = data["access_token"];
			var refreshToken = data["refresh_token"];
			var expires_in = data["expires_in"];
			//var state = data["state"];
			var created_at = Time.now().value();

			//logMessage("onReceiveToken: state field is '" + state + "'");

    		Settings.setToken(accessToken);

			//DEBUG*/ var expireAt = new Time.Moment(created_at + expires_in);
			//DEBUG*/ var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
			//DEBUG*/ var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");

			if (refreshToken != null && refreshToken.equals("") == false) { // Only if we received a refresh tokem
				if (accessToken != null) {
					//DEBUG*/ logMessage("onReceiveToken: refresh token=" + refreshToken.substring(0,10) + "... lenght=" + refreshToken.length() + " access token=" + accessToken.substring(0,10) + "... lenght=" + accessToken.length() + " which expires at " + dateStr);
				} else {
					//DEBUG*/ logMessage("onReceiveToken: refresh token=" + refreshToken.substring(0,10) + "... lenght=" + refreshToken.length() + "+ NO ACCESS TOKEN");
				}
				Settings.setRefreshToken(refreshToken, expires_in, created_at);
			}
			else {
				//DEBUG*/ logMessage("onReceiveToken: WARNING - NO REFRESH TOKEN but got an access token: " + accessToken.substring(0,20) + "... lenght=" + accessToken.length() + " which expires at " + dateStr);
			}
		}
	}
}