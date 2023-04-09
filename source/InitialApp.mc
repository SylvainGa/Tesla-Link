using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;

(:background)
class TeslaLink extends App.AppBase {
    var _serviceDelegate;

    function initialize() {
		//DEBUG*/ logMessage("App: Initialising app");
        AppBase.initialize();
    }

	function onStart(state) {
		//DEBUG*/ logMessage("App: starting app");
	}

	function onStop(state) {
		//DEBUG*/ logMessage("App: stopping app");
	}

    (:can_glance)
    function getServiceDelegate(){
		//DEBUG*/ logMessage("App: getServiceDelegate");
        _serviceDelegate = new MyServiceDelegate();
        return [ _serviceDelegate ];
    }

    // This fires when the background service returns
    (:can_glance)
    function onBackgroundData(data) {
		//DEBUG*/ logMessage("App: onBackgroundData");
        if (data != null) {
            //DEBUG*/ logMessage("App: onBackgroundData: " + data["status"]);

            var status = data["status"];
            if (status != null) {
                Application.getApp().setProperty("status", status);
            }

            var responseCode = data["responseCode"];
            //DEBUG*/ logMessage("App: onBackgroundData responseCode is " + responseCode);
            if (responseCode != null && responseCode == 401) {
                //DEBUG*/ logMessage("App: onBackgroundData needs to refresh our access token");
                if (_serviceDelegate == null) {
                    //DEBUG*/ logMessage("App: onBackgroundData needs a service delegate");
                    _serviceDelegate = new MyServiceDelegate();
                }
                _serviceDelegate.GetAccessToken();
            }
        }

        Background.registerForTemporalEvent(new Time.Duration(300));

        Ui.requestUpdate();
    }  

    (:glance, :can_glance)
    function getGlanceView() {
		//DEBUG*/ logMessage("Glance: Starting glance view");

        Application.getApp().setProperty("canGlance", true);
        Background.registerForTemporalEvent(new Time.Duration(60*5));
        return [ new GlanceView() ];
    }

    function getInitialView() {
		//DEBUG*/ logMessage("Glance: Starting main view");

        // No phone? This widget ain't gonna work! Show the offline view
        if (!System.getDeviceSettings().phoneConnected) {
            return [ new OfflineView() ];
        }

		Application.getApp().setProperty("canGlance", (System.getDeviceSettings() has :isGlanceModeEnabled && System.getDeviceSettings().isGlanceModeEnabled) == true);

        var data = new TeslaData();
		var useTouch = Application.getApp().getProperty("useTouch");
		var hasTouch = System.getDeviceSettings().isTouchScreen;
		var neededButtons = System.BUTTON_INPUT_SELECT + System.BUTTON_INPUT_UP + System.BUTTON_INPUT_DOWN + System.BUTTON_INPUT_MENU;
		var hasButtons = (System.getDeviceSettings().inputButtons & neededButtons) == neededButtons;

		// Make sure the combination of having buttons and touchscreen matches what we're asking through useTouch
		if (useTouch == null || useTouch == true && hasTouch == false || hasButtons == false && hasTouch == true && useTouch == false) {
			useTouch = hasTouch;
			Application.getApp().setProperty("useTouch", useTouch);
		}
        
		var view = new MainView(data);
		return [ view, new MainDelegate(view, data, view.method(:onReceive)) ];
    }
}
