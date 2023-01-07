using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi as Ui;

(:background)
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

//System.println("onTemporalEvent");
        if (_token != null && _vehicle_id != null)
        {
//System.println("onTemporalEvent getting data");
            _tesla.getChargeState(_vehicle_id, method(:onReceiveVehicleData));
        }
    }

    function onReceiveVehicleData(responseCode, responseData) {
        // The API request has returned check for any other background data waiting (we don't want to lose it)
        var data = Background.getBackgroundData();
        if (data == null) {
            data = {};
		}
//System.println("onReceiveVehicleData: responseCode = " + responseCode);
//System.println("onReceiveVehicleData: responseData = " + responseData);

        // Deal with appropriately - we care about awake (200), non authenticated (401) or asleep (408)
        if (responseCode == 200) {
            var vehicle_data = responseData.get("response");    
            var battery_level = vehicle_data.get("battery_level");
            var battery_range = vehicle_data.get("battery_range") * (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6);
            var charging_state = vehicle_data.get("charging_state");

            var suffix;
            try {
                var clock_time = System.getClockTime();
                suffix = " @ " + clock_time.hour.format("%d")+ ":" + clock_time.min.format("%02d");
            } catch (e) {
                suffix = "";
            }
            data.put("status", battery_level + "%" + (charging_state.equals("Charging") ? "+" : "") + " / " + battery_range.toNumber() + suffix);
            Background.exit(data);
        } else if (responseCode == 401) {
            data.put("status", Application.loadResource(Rez.Strings.label_launch_widget));
            Background.exit(data);
        } else if (responseCode == 408) {
            var suffix;
            try {
                var clock_time = System.getClockTime();
                suffix = " @ " + clock_time.hour.format("%d")+ ":" + clock_time.min.format("%02d");
            } catch (e) {
                suffix = "";
            }
            data.put("status", Application.loadResource(Rez.Strings.label_asleep) + suffix);
            Background.exit(data);
        } else {
            Background.exit(data);
        }
    }
}