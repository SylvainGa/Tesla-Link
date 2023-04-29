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

    (:can_glance, :bkgnd64kb)
	function onStart(state) {
   		//DEBUG*/ logMessage("App: starting");
	}

    (:can_glance, :bkgnd64kb)
	function onStop(state) {
        // if (Storage.getValue("runBG")) {
    	// 	//DEBUG*/ logMessage("App: stopping with runBG True");
        // }
        // else {
    	// 	//DEBUG*/ logMessage("App: stopping with runBG False");
        // }
	}

    (:can_glance)
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
        Storage.setValue("runBG", true);
        Background.registerForTemporalEvent(new Time.Duration(60 * 5));
        return [ new GlanceView() ];
    }

    function getInitialView() {
		//DEBUG*/ logMessage("MainView: Starting");

        // No phone? This widget ain't gonna work! Show the offline view
        if (!System.getDeviceSettings().phoneConnected) {
            return [ new OfflineView() ];
        }

        Storage.setValue("runBG", false);

		//Storage.setValue("canGlance", (System.getDeviceSettings() has :isGlanceModeEnabled && System.getDeviceSettings().isGlanceModeEnabled) == true);
        var data = new TeslaData();
        var view = new MainView(data);
		return [ view, new MainDelegate(view, data, view.method(:onReceive)) ];
    }

    (:can_glance)
    function onBackgroundData(data) {
        if (Storage.getValue("runBG") == false) { // We're in our Main View. it will refresh 'status' there by itself
            //DEBUG*/ logMessage("onBackgroundData: Main view running, skipping");
            return;
        }
        
        gSettingsChanged = true;
        if (data != null) {
            //DEBUG*/ logMessageAndData("onBackgroundData with data=", data);

            // Refresh our tokens
            var token = data["token"];
            if (token != null && token.equals("") == false) {
                Storage.setValue("token", token);
            }

            token = data["refreshToken"];
            if (token != null && token.equals("") == false) {
                Properties.setValue("refreshToken", token);
            }
            else {
                //DEBUG*/ logMessage("onBackgroundData: Tried to reset the refresh token!");
            }

            token = data["TokenExpiresIn"];
            if (token != null) {
                Storage.setValue("TokenExpiresIn", token);
            }

            token = data["TokenCreatedAt"];
            if (token != null) {
                Storage.setValue("TokenCreatedAt", token);
            }

            // Read what we had before
            var status = Storage.getValue("status");
            if (status != null && !(status instanceof Lang.Dictionary)) {
                Storage.deleteValue("status");
                status = null;
            }

            if (status == null) {
                status = {};
            }

            // Fetch was passed to us and replace the old value if we have new one
            var value = data["responseCode"];
            if (value != null) {
                status.put("responseCode", value);
            }
            value = data["timestamp"];
            if (value != null) {
                status.put("timestamp", value);
            }
            value = data["battery_level"];
            if (value != null) {
                status.put("battery_level", value);
            }
            value = data["charging_state"];
            if (value != null) {
                status.put("charging_state", value);
            }
            value = data["battery_range"];
            if (value != null) {
                status.put("battery_range", value);
            }
            value = data["inside_temp"];
            if (value != null) {
                status.put("inside_temp", value);
            }
            value = data["sentry"];
            if (value != null) {
                status.put("sentry", value);
            }
            value = data["preconditioning"];
            if (value != null) {
                status.put("preconditioning", value);
            }
            value = data["shift_state"];
            if (value != null) {
                status.put("shift_state", value);
            }
            value = data["vehicleAwake"];
            if (value != null) {
                status.put("vehicleAwake", value);
            }

    		//DEBUG*/ logMessage("onBackgroundData status is " + status);
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
