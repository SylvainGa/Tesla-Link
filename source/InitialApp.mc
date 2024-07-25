using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;
using Toybox.Application.Storage;
using Toybox.Application.Properties;
using Toybox.Attention;

var gSettingsChanged;

(:background)
class TeslaLink extends App.AppBase {
    function initialize() {
        AppBase.initialize();

		//DEBUG*/ logMessage("App: Initialising");
        //gSettingsChanged = false; // No, let it stay at null. That way, a background task initilazing will no trigger a setting change
    }

    (:can_glance, :bkgnd64kb)
	function onStart(state) {
   		//DEBUG 2023-10-02*/ logMessage("App: starting");
        if (state != null) {
            //DEBUG 2023-10-02*/ logMessage("full state: " + state.toString());
            //DEBUG 2023-10-02*/ logMessage("resume: " + state.get(:resume ));
            //DEBUG 2023-10-02*/ logMessage("launchedFromGlance: " + state.get(:launchedFromGlance));
            //DEBUG 2023-10-02*/ logMessage("launchedFromComplication: " + state.get(:launchedFromComplication ));

            if (state.get(:launchedFromComplication) != null) {
                Storage.setValue("launchedFromComplication", true);
                if (Attention has :vibrate) {
                    var vibeData = [ new Attention.VibeProfile(50, 200) ]; // On for half a second
                    Attention.vibrate(vibeData);
                }
            }
        }
	}

    // (:can_glance, :bkgnd64kb)
	// function onStop(state) {
    //     if (Storage.getValue("runBG")) {
    // 		//DEBUG*/ logMessage("App: stopping with runBG True");
    //     }
    //     else {
    // 		//DEBUG*/ logMessage("App: stopping with runBG False");
    //     }
	// }

    (:can_glance)
	function onSettingsChanged() {
		/*DEBUG*/ logMessage("App: Settings changed");
        gSettingsChanged = true; 
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
        Storage.setValue("fromGlance", true);
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

        var whichAPI = Properties.getValue("whichAPI");
        if (whichAPI == null || whichAPI < 0) {
            return [ new NeedConfigView() ];
        }

        Storage.setValue("runBG", false);

		//Storage.setValue("canGlance", (System.getDeviceSettings() has :isGlanceModeEnabled && System.getDeviceSettings().isGlanceModeEnabled) == true);
		var useTouch = $.getProperty("useTouch", true, method(:validateBoolean));
		var hasTouch = System.getDeviceSettings().isTouchScreen;
		var neededButtons = System.BUTTON_INPUT_SELECT + System.BUTTON_INPUT_UP + System.BUTTON_INPUT_DOWN + System.BUTTON_INPUT_MENU;
		var hasButtons = (System.getDeviceSettings().inputButtons & neededButtons) == neededButtons;

		// Make sure the combination of having buttons and touchscreen matches what we're asking through useTouch
		if (useTouch == null || useTouch == true && hasTouch == false || hasButtons == false && hasTouch == true && useTouch == false) {
			useTouch = hasTouch;
        }
        Properties.setValue("useTouch", useTouch);

        var data = new TeslaData();
        if ($.validateBoolean(Storage.getValue("fromGlance"), false) || useTouch) { // Up/Down buttons work when launched from glance (or if we don't have/need buttons)
            Storage.setValue("fromGlance", false); // In case we change our watch setting later on that we want to start from the widget and not the glance
            var view = new MainView(data);
            return [ view, new MainDelegate(view, data, view.method(:onReceive)) ];
        }
        else { // Sucks, but we have to have an extra view so the Up/Down button work in our main view
            Storage.setValue("fromGlance", false); // In case we change our watch setting later on that we want to start from the widget and not the glance
            var view = new NoGlanceView();
            return [ view, new NoGlanceDelegate(data) ];
        }
    }

    (:can_glance)
    function onBackgroundData(data) {
        if (Storage.getValue("runBG") == false) { // We're in our Main View. it will refresh 'status' there by itself
            //DEBUG*/ logMessage("onBackgroundData: Main view running, skipping");
            return;
        }
        
		if ($.getProperty("whichAPI", 0, method(:validateNumber)) == API_TESLA) {
            gSettingsChanged = true;
        }
        
        /*DEBUG*/ logMessageAndData("onBackgroundData with data=", data);
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

                // // Deal with -104 (phone not connected)
                // if (responseCode == -104) {
                //     Storage.setValue("PhoneLostDontAsk", true);
                // }
                // else { // We have connection so it will be ok to ask again
                //     Storage.deleteValue("PhoneLost");
                // }
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
