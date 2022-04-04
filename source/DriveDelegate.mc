using Toybox.WatchUi as Ui;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Communications as Communications;
using Toybox.Cryptography;
using Toybox.Graphics;

class DriveDelegate extends Ui.BehaviorDelegate {
	var _view as DriveView;
    var _handler;
    var _token;
    var _tesla;
    var _vehicle_id;
    var _settings;
	var _get_vehicle_data;
    var _disableRefreshTimer; // When this is true, the refreshTimer will not call stateMachine since we are already inside stateMachine from a direct call elsewhere
    var _data;
	var refreshTimer;
	
    function initialize(view as DriveView, data, tesla, handler) {
        BehaviorDelegate.initialize();
    	_view = view;

        _settings = System.getDeviceSettings();
        _data = data;
        _token = Settings.getToken();

        _vehicle_id = Application.getApp().getProperty("vehicle");
        _handler = handler;
        _tesla = tesla;
        _get_vehicle_data = 1;

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
//logMessage("DriveDelegate:timerRefresh");
    	if (!_disableRefreshTimer) {
			if (_data._vehicle_data != null) {
				if (_get_vehicle_data == 0) {
			        _get_vehicle_data = 1;
				}
			}
				
	        stateMachine();
		}
    }

    function onPreviousPage() {
    	_view._viewOffset -= 4;
    	if (_view._viewOffset < 0) {
			_view._viewOffset = 0;
    	}
	    _view.requestUpdate();
        return true;
    }

    function onNextPage() {
    	_view._viewOffset += 4;
    	if (_view._viewOffset > 0) { // One page but coded to accept more if required
			_view._viewOffset = 0;
    	}
	    _view.requestUpdate();
        return true;
    }

	function onMenu() {
	    refreshTimer.stop(); // Stop our timers so we don't grab received events from our other pages
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_handler.invoke(4); // Tell MainDelegate to show next subview

	    _view.requestUpdate();
        return true;
	}
	
    function onSwipe(swipeEvent) {
    	if (swipeEvent.getDirection() == 3) {
	    	onMenu();
    	}
        return true;
	}
	
    function onBack() {
	    refreshTimer.stop();
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_handler.invoke(0);
        return true;
    }

    function onTap(click) {
	    refreshTimer.stop();
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_handler.invoke(2);
        return true;
    }

    function onReceiveVehicleData(responseCode, data) {
logMessage("DriveDelegate:onReceiveVehicleData responseCode is " + responseCode);
        if (responseCode == 200) {
            _data._vehicle_data = data.get("response");
            if (_data._vehicle_data.get("climate_state").hasKey("inside_temp") && _data._vehicle_data.get("charge_state").hasKey("battery_level")) {
logMessage("DriveDeletegate:Drive state: " + _data._vehicle_data.get("drive_state"));
		        _get_vehicle_data = 0; // All is well, we got our data
                _handler.invoke(null);
            }
	    }
    }
}
