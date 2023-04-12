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
		/*DEBUG*/ logMessage("App: Initialising");
        _data = new TeslaData();
        _data._vehicle_awake = false; // Assume it's asleep. If we get a 200 later on, we'll set it awake
        
        AppBase.initialize();
    }

	function onStart(state) {
		/*DEBUG*/ logMessage("App: starting");
	}

	function onStop(state) {
		/*DEBUG*/ logMessage("App: stopping");
	}

    (:can_glance)
    function getServiceDelegate(){
		/*DEBUG*/ logMessage("App: getServiceDelegate");
        return [ new MyServiceDelegate() ];
    }

    (:glance, :can_glance, :bkgnd32kb)
    function getGlanceView() {
		/*DEBUG*/ logMessage("Glance: Starting");
        Application.getApp().setProperty("bkgnd32kb", true); // Used in MainDelegate to send the correct amount of data through status
        Background.registerForTemporalEvent(new Time.Duration(60 * 5));
        return [ new GlanceView(_data) ];
    }

    (:glance, :can_glance, :bkgnd64kb)
    function getGlanceView() {
		/*DEBUG*/ logMessage("Glance: Starting");
        Application.getApp().setProperty("bkgnd32kb", false); // Used in MainDelegate to send the correct amount of data through status
        Background.registerForTemporalEvent(new Time.Duration(60 * 5));
        return [ new GlanceView(_data) ];
    }

    function getInitialView() {
		/*DEBUG*/ logMessage("MainView: Starting");

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
        if (data != null) {
            /*DEBUG*/ logMessage("onBackgroundData: " + data);

            var status = data["status"];
            if (status != null) {
                Application.getApp().setProperty("status", status);
            }

            var responseCode = data["responseCode"];
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
        else {
    		/*DEBUG*/ logMessage("onBackgroundData WITHOUT data");
        }

        Background.registerForTemporalEvent(new Time.Duration(300));

        Ui.requestUpdate();
    }  

    (:can_glance, :bkgnd32kb)
    function testAwake(status) {
        logMessage("testAwake 32kb backgroundprocess called");
        _data._vehicle_awake = false;
        if (status != null) {
            Application.getApp().setProperty("status", status + Application.loadResource(Rez.Strings.label_asleep));
        }
        return;
    }

    (:bkgnd64kb)
    function testAwake(status) {
        logMessage("testAwake called");
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
            	/*DEBUG*/ logMessage("onReceiveVehicles: vehicle state: " + vehicle_state);
				if (vehicle_state.equals("online")) {
                    _data._vehicle_awake = true;
                    if (status != null) {
                        Application.getApp().setProperty("status", status);
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
        logMessage("refreshAccessToken 32kb backgroundprocess");
    }

    // Do NOT call from a background process since we're setting registry data in onReceiveToken
    (:bkgnd64kb)
    function refreshAccessToken() {
        logMessage("refreshAccessToken");
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
        }
    }
}
