using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

var gSettingsChanged;

(:background)
class TeslaLink extends App.AppBase {
    function initialize() {
        AppBase.initialize();

		//DEBUG*/ logMessage("App: Initialising");
        gSettingsChanged = false;
    }

	function onStart(state) {
   		//DEBUG*/ logMessage("App: starting");
	}

	function onStop(state) {
		//DEBUG*/ logMessage("App: stopping");
	}

	function onSettingsChanged() {
		//DEBUG*/ logMessage("App: Settings changed");
        gSettingsChanged = true; // Only relevant in Glance as it will recalculate some class variables
        Ui.requestUpdate();
    }

    (:can_glance)
    function getServiceDelegate(){
		//DEBUG*/ logMessage("App: getServiceDelegate");
        return [ new MyServiceDelegate() ];
    }

    (:glance, :can_glance)
    function getGlanceView() {
		//DEBUG*/ logMessage("Glance: Starting");
        Storage.setValue("inGlance", true);
        Background.registerForTemporalEvent(new Time.Duration(60 * 5));
        return [ new GlanceView() ];
    }

    function getInitialView() {
		//DEBUG*/ logMessage("MainView: Starting");

        // No phone? This widget ain't gonna work! Show the offline view
        if (!System.getDeviceSettings().phoneConnected) {
            return [ new OfflineView() ];
        }

        Storage.setValue("inGlance", false);

		//Storage.setValue("canGlance", (System.getDeviceSettings() has :isGlanceModeEnabled && System.getDeviceSettings().isGlanceModeEnabled) == true);
        var data = new TeslaData();
        var view = new MainView(data);
		return [ view, new MainDelegate(view, data, view.method(:onReceive)) ];
    }

    // This fires when the background service returns
    (:can_glance, :bkgnd32kb)
    function onBackgroundData(data) {

        if (Storage.getValue("inGlance") == false) { // We're in our Main View. it will refresh 'status' there by itself
            /*DEBUG*/ logMessage("onBackgroundData: In main view, skipping background sent data");
            return;
        }

        gSettingsChanged = true;
        if (data != null) {
            //DEBUG*/ logMessage("onBackgroundData: " + data);

            var status = data["status"];
            if (status != null) {
                Storage.setValue("status", status);
            }
        }
        else {
    		//DEBUG*/ logMessage("onBackgroundData WITHOUT data");
        }

        // No need, it keeps going until the app stops or it's deleted
        //Background.registerForTemporalEvent(new Time.Duration(300));

        Ui.requestUpdate();
    }  

    (:can_glance, :bkgnd64kb)
    function onBackgroundData(data) {
        if (Storage.getValue("inGlance") == false) { // We're in our Main View. it will refresh 'status' there by itself
            return;
        }
        
        gSettingsChanged = true;
        if (data != null) {
            //DEBUG*/ logMessageAndData("onBackgroundData with data=", data);

            // Refresh our tokens
            var token = data["token"];
            if (token != null) {
                Storage.setValue("token", token);
            }

            token = data["refreshToken"];
            if (token != null && token.equals("") == false) {
                Properties.setValue("refreshToken", token);
            }
            else {
                /*DEBUG*/ logMessage("Tried to reset the refresh token!");
            }

            token = data["TokenExpiresIn"];
            if (token != null) {
                Storage.setValue("TokenExpiresIn", token);
            }

            token = data["TokenCreatedAt"];
            if (token != null) {
                Storage.setValue("TokenCreatedAt", token);
            }

            // Fetch was passed to us to process/display
            var responseCode = data["responseCode"];
            if (responseCode == null) {
                responseCode = 401;
            }

            var timestamp = data["timestamp"];

            var text;

            // If we have a status field, we got good data at least once since last time we ran so use that to display, otherwise grab the old status and break it down so we can rebuild it
            var numFields = 8;
            var status = data["status"];
            if (status == null) {
                // No status field in our buffer, built one from our last time we got data. Unless we were down while the vehicle was being used, this data should still be somewhat accurate
                status = Storage.getValue("status");
                numFields = 9;
                //DEBUG*/ logMessage("onBackgroundData reusing previous status: " + status);
            }
            // Disect our status line into its elements
            if (status != null && status.equals("") == false) {
                var array = $.to_array(status, "|");
                if (array.size() == numFields) {
                    //responseCode = array[0].toNumber();
                    var battery_level = array[1];
                    var charging_state = array[2];
                    var battery_range = array[3];
                    var inside_temp = array[4];
                    var sentry = array[5];
                    var preconditioning = array[6];
                    // These two are not kept so we ignore them
                    // var timestamp = array[7];
                    // var label = array[8];

                    status = responseCode + "|" + battery_level + "|" + charging_state + "|" + battery_range.toNumber() + "|" + inside_temp + "|" + sentry + "|" + preconditioning + "|";
                }
                else { // Wrong format, start fresh
                    status = responseCode + "|N/A|N/A|0|0|N/A|N/A|";
                }
            }

            if (responseCode == 200) { // Our last vehicle data query was successful, display our status 'as is'
                text = "";
            }
            else if (responseCode == 401) { // We tried but couldn't get or vehicle data because of our token, tell the Glance view to ask the user to launch the widget
                text = Application.loadResource(Rez.Strings.label_launch_widget);
            }
            else if (responseCode == 408) { // We got a vehicle not available, see what the vehicle list returned
                var vehicleAwake = data["vehicleAwake"];
                if (vehicleAwake != null && vehicleAwake.equals("asleep") == true) { // We're asleep, say so plus timestap (if any)
                    text = Application.loadResource(Rez.Strings.label_asleep);
                }
                else { // We got a 408 error while not asleep, show the error and timestap (if any)
                    text = Application.loadResource(Rez.Strings.label_error) + responseCode;
                }
            }
            else {
                text = Application.loadResource(Rez.Strings.label_error) + responseCode;
            }

            status = status + (timestamp != null ? timestamp : "") + "|" + text;
            Storage.setValue("status", status);
        }
        else {
    		//DEBUG*/ logMessage("onBackgroundData WITHOUT data");
        }

        // No need, it keeps going until the app stops or it's deleted
        //Background.registerForTemporalEvent(new Time.Duration(300));

        Ui.requestUpdate();
    }
}
