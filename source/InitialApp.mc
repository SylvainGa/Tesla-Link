using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;

(:background)
class TeslaLink extends App.AppBase {
    var _data;

    function initialize() {
		/*DEBUG*/ logMessage("App: Initialising app");
        _data = new TeslaData();
        
        AppBase.initialize();
    }

	function onStart(state) {
		/*DEBUG*/ logMessage("App: starting app");
	}

	function onStop(state) {
		/*DEBUG*/ logMessage("App: stopping app");
	}

    (:can_glance)
    function getServiceDelegate(){
		/*DEBUG*/ logMessage("App: getServiceDelegate");
        return [ new MyServiceDelegate() ];
    }

    (:glance, :can_glance, :bkgnd32kb)
    function getGlanceView() {
		/*DEBUG*/ logMessage("Glance: Starting glance view");
        Application.getApp().setProperty("bkgnd32kb", true);        
        Background.registerForTemporalEvent(new Time.Duration(60*5));
        return [ new GlanceView(_data) ];
    }

    (:glance, :can_glance, :bkgnd64kb)
    function getGlanceView() {
		/*DEBUG*/ logMessage("Glance: Starting glance view");
        Application.getApp().setProperty("bkgnd32kb", false);        
        Background.registerForTemporalEvent(new Time.Duration(60*5));
        return [ new GlanceView(_data) ];
    }

    function getInitialView() {
		/*DEBUG*/ logMessage("Glance: Starting main view");

        // No phone? This widget ain't gonna work! Show the offline view
        if (!System.getDeviceSettings().phoneConnected) {
            return [ new OfflineView() ];
        }

		//Application.getApp().setProperty("canGlance", (System.getDeviceSettings() has :isGlanceModeEnabled && System.getDeviceSettings().isGlanceModeEnabled) == true);

        var view = new MainView(_data);
		return [ view, new MainDelegate(view, _data, view.method(:onReceive)) ];
    }

    // This fires when the background service returns
    (:can_glance)
    function onBackgroundData(data) {
		/*DEBUG*/ logMessage("App: onBackgroundData");
        if (data != null) {
            /*DEBUG*/ logMessage("App: onBackgroundData: " + data["status"]);

            var status = data["status"];
            if (status != null) {
                Application.getApp().setProperty("status", status);
            }

            var responseCode = data["responseCode"];
            /*DEBUG*/ logMessage("App: onBackgroundData responseCode is " + responseCode);
            if (responseCode != null) {
                if (responseCode == 401) {
                    refreshAccessToken();
                }
                else if (responseCode == 408) {
                    testAwake(status);
                } else if (responseCode == 200) {
                    _data._vehicle_awake = true;
                }
            }
        }

        Background.registerForTemporalEvent(new Time.Duration(300));

        Ui.requestUpdate();
    }  

    (:can_glance, :bkgnd32kb)
    function testAwake(status) {
        logMessage("ServiceDelegate:testAwake 32kb backgroundprocess");
        _data._vehicle_awake = false;
        if (status != null) {
            Application.getApp().setProperty("status", status + Application.loadResource(Rez.Strings.label_asleep));
        }
        return;
    }

    (:bkgnd64kb)
    function testAwake(status) {
        logMessage("ServiceDelegate:testAwake");
        var token = Application.getApp().getProperty("token");
        Communications.makeWebRequest(
            "https://" + Application.getApp().getProperty("serverAPILocation") + "/api/1/vehicles", null,
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

    (:bkgnd64kb)
	function onReceiveVehicles(responseCode, data) {
		/*DEBUG*/ logMessage("onReceiveVehicles: " + responseCode);
		//logMessage("onReceiveVehicles: data is " + data);

        var status = Application.getApp().getProperty("status");

		if (responseCode == 200) {
			var vehicles = data.get("response");
			var size = vehicles.size();
			if (size > 0) {
				// Need to retrieve the right vehicle, not just the first one!
				var vehicle_index = 0;
				var vehicle_name = Application.getApp().getProperty("vehicle_name");
				if (vehicle_name != null) {
					while (vehicle_index < size) {
					if (vehicle_name.equals(vehicles[vehicle_index].get("display_name"))) {
							break;
						}
						vehicle_index++;
					}

					if (vehicle_index == size) {
						vehicle_index = 0;
					}
				}

				var vehicle_state = vehicles[vehicle_index].get("state");
				if (vehicle_state.equals("online")) {
                    _data._vehicle_awake = true;
                    if (status != null) {
                        Application.getApp().setProperty("status", status + " ");
                        Ui.requestUpdate();
                        return;
                    }
				}
			}
		}

        _data._vehicle_awake = false;
        if (status != null) {
            Application.getApp().setProperty("status", status + Application.loadResource(Rez.Strings.label_asleep));
            Ui.requestUpdate();
        }
    }

    (:can_glance, :bkgnd32kb)
    function refreshAccessToken() {
        logMessage("App:refreshAccessToken 32kb backgroundprocess");
    }

    // Do NOT call from a background process since we're setting registry data in onReceiveToken
    (:bkgnd64kb)
    function refreshAccessToken() {
        logMessage("App:refreshAccessToken");
        var refreshToken = Application.getApp().getProperty("refreshToken");
        if (refreshToken != null && refreshToken.length() != 0) {
            var url = "https://" + Application.getApp().getProperty("serverAUTHLocation") + "/oauth2/v3/token";
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
        }
    }

    // Do NOT call from a background process since we're setting registry data here
    (:bkgnd64kb)
    function onReceiveToken(responseCode, data) {
        /*DEBUG*/ logMessage("onReceiveToken: " + responseCode);

        if (responseCode == 200) {
            var accessToken = data["access_token"];
            var refreshToken = data["refresh_token"];
            var expires_in = data["expires_in"];
            //var state = data["state"];
            var created_at = Time.now().value();

            //logMessage("onReceiveToken: state field is '" + state + "'");

            Application.getApp().setProperty("token", accessToken);
            Application.getApp().setProperty("refreshToken", refreshToken);
            Application.getApp().setProperty("TokenExpiresIn", expires_in);
            Application.getApp().setProperty("TokenCreatedAt", created_at);

            Communications.makeWebRequest(
                "https://" + Application.getApp().getProperty("serverAPILocation") + "/api/1/vehicles/" + Application.getApp().getProperty("vehicle").toString() + "/vehicle_data", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + accessToken,
                        "User-Agent" => "Tesla-Link for Garmin"
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
                },
                method(:onReceiveVehicleData)
            );
        }
    }

    (:bkgnd64kb)
     function onReceiveVehicleData(responseCode, responseData) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled

        /*DEBUG*/ logMessage("App:onReceiveVehicleData: responseCode = " + responseCode);
        //DEBUG*/ logMessage("App:onReceiveVehicleData: responseData = " + responseData);

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
            if (sentry != null && sentry.equals("true")) {
                sentry = true;
            }
            else {
                sentry = false;
            }

            pos = responseData.find("preconditioning_enabled");
            str = responseData.substring(pos + 25, pos + 31);
            posEnd = str.find(",");
            preconditioning = str.substring(0, posEnd);
            if (preconditioning != null && sentry.equals("true")) {
                preconditioning = true;
            }
            else {
                preconditioning = false;
            }

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
        testAwake(status);

        Ui.requestUpdate();
    }
}
