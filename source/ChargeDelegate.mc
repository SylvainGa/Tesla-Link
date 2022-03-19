using Toybox.WatchUi as Ui;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Communications as Communications;
using Toybox.Cryptography;
using Toybox.Graphics;

class ChargeDelegate extends Ui.BehaviorDelegate {
	var _view as ChargeView;
    var _handler;
    var _token;
    var _tesla;
    var _vehicle_id;
    var _settings;
	var _get_vehicle_data;
    var _disableRefreshTimer; // When this is true, the refreshTimer will not call stateMachine since we are already inside stateMachine from a direct call elsewhere
    var _data;
	var refreshTimer;
	var _408_count;
	var _set_refresh_time;
	
    function initialize(view as ChargeView, data, tesla, handler) {
        BehaviorDelegate.initialize();
    	_view = view;

        _settings = System.getDeviceSettings();
        _data = data;
        _token = Settings.getToken();

        _vehicle_id = Application.getApp().getProperty("vehicle");
        _handler = handler;
        _tesla = tesla;
        _get_vehicle_data = 1;
		_408_count = 0;
		_set_refresh_time = false;

	    Application.getApp().setProperty("refreshTimer", false);
		_disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;

	    refreshTimer = new Timer.Timer();
        var refreshTimeInterval = Application.getApp().getProperty("refreshTimeInterval");
	    refreshTimer.start(method(:timerRefresh), refreshTimeInterval.toNumber() * 1000, true);
    }

    function stateMachine() {
		var _gotBackgroundData = Application.getApp().getProperty("gotBackgroundData");
		if (_gotBackgroundData == true) {
			Application.getApp().setProperty("gotBackgroundData", false);
	        if (_get_vehicle_data == 2) { // If we were waiting for data that was read by the background process, request it again
	            _get_vehicle_data = 1;
			}        
		}

        if (_get_vehicle_data == 1) {
            _get_vehicle_data = 2;
            _tesla.getVehicleData(_vehicle_id, method(:onReceiveVehicleData));
		}
    }

    function timerRefresh() {
logMessage("ChargeDelegate:timerRefresh _data._vehicle_data is null " + (_data._vehicle_data == null).toString() + "_get_vehicle_data is " + _get_vehicle_data);
    	if (!_disableRefreshTimer) {
			if (_data._vehicle_data != null) {
				if (_get_vehicle_data == 0) {
			        _get_vehicle_data = 1;
				}
			}
				
	        stateMachine();
		}
    }

    function onBack() {
logMessage("ChargeDelegate:onBack called");
	    refreshTimer.stop();
		_handler.invoke(true);
		Ui.popView(Ui.SLIDE_IMMEDIATE);
        return true;
    }

    function onTap(click) {
logMessage("ChargeDelegate:onTap called");
	    refreshTimer.stop();
		_handler.invoke(true);
		Ui.popView(Ui.SLIDE_IMMEDIATE);
        return true;
    }

    function onReceiveVehicleData(responseCode, data) {
        if (responseCode == 200) {
            _data._vehicle_data = data.get("response");
            if (_data._vehicle_data.get("climate_state").hasKey("inside_temp") && _data._vehicle_data.get("charge_state").hasKey("battery_level")) {
logMessage("Charge state: " + _data._vehicle_data.get("charge_state"));
//logMessage("Vehicle state: " + _data._vehicle_data.get("vehicle_state"));
//logMessage("Climate state: " + _data._vehicle_data.get("climate_state"));
//logMessage("Drive state: " + _data._vehicle_data.get("drive_state"));
		        _get_vehicle_data = 0; // All is well, we got our data
				_408_count = 0; // Reset the count of timeouts since we got our data
                _handler.invoke(null);
            }
	    }
    }
}
