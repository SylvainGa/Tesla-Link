using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;

(:background)
class TeslaLink extends App.AppBase {

    function initialize() {
		// 2023-03-20 logMessage("App: Initialising app");
        AppBase.initialize();
    }

	function onStart(state) {
		// 2023-03-20 logMessage("App: starting app with state set to " + state);
	}

	function onStop(state) {
		// 2023-03-20 logMessage("App: stopping app with state set to " + state);
	}

    (:can_glance)
    function getServiceDelegate(){
        return [ new MyServiceDelegate() ];
    }

    // This fires when the background service returns
    (:can_glance)
    function onBackgroundData(data) {
        Application.getApp().setProperty("status", data["status"]);
		//var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
		//var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
		//System.println(dateStr + " : " + "onBackgroundData: " + data["status"]);

        Background.registerForTemporalEvent(new Time.Duration(60*5));

        Ui.requestUpdate();
    }  

    (:glance, :can_glance)
    function getGlanceView() {
        Application.getApp().setProperty("canGlance", true);
		//System.println("Glance: Starting glance view");
        Background.registerForTemporalEvent(new Time.Duration(60*5));
        return [ new GlanceView() ];
    }

    function getInitialView() {
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

(:debug, :background)
function logMessage(message) {
	var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
	var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
	System.println(dateStr + " : " + message);
}

(:release, :background)
function logMessage(message) {
}
