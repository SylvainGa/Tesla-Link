using Toybox.Application as App;
using Toybox.Background;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as Ui;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

(:background, :can_glance, :bkgnd32kb)
class MyServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        System.ServiceDelegate.initialize();
    }

    // This fires on our temporal event - we're going to go off and get the vehicle data, only if we have a token and vehicle ID
    function onTemporalEvent() {
        if (Storage.getValue("runBG") == false) { // We're in our Main View. it will refresh 'status' there by itself
            Background.exit(null);
        }

        var token = Storage.getValue("token");
        var vehicle = Storage.getValue("vehicle");
        if (token != null && vehicle != null) {
            //DEBUG*/ logMessage("onTemporalEvent getting data");
            Communications.makeWebRequest(
                "https://" + Properties.getValue("serverAPILocation") + "/api/1/vehicles/" + vehicle.toString() + "/vehicle_data", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token,
                        "User-Agent" => "Tesla-Link for Garmin"
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN
                },
                method(:onReceiveVehicleData)
            );
        }
        else {
            /*DEBUG*/ logMessage("onTemporalEvent with token at " + (token == null ? token : token.substring(0, 10)) + " vehicle at " + vehicle);
            Background.exit({"responseCode" => 401});
        }
    }

    function onReceiveVehicleData(responseCode, responseData) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled
        /*DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);
        //DEBUG*/ logMessage("onReceiveVehicleData: responseData=" + responseData);

        var data = Background.getBackgroundData();
        if (data == null) {
            data = {};
		}
        else {
            //DEBUG*/ logMessage("onReceiveVehicleData already has background data! -> '" + data + "'");
        }

        data.put("responseCode", responseCode);

        var timestamp;
        var suffix = "";
        try {
            var clock_time = System.getClockTime();
            var hours = clock_time.hour;
            var minutes = clock_time.min.format("%02d");
            if (System.getDeviceSettings().is24Hour == false) {
                suffix = "am";
                if (hours == 0) {
                    hours = 12;
                }
                else if (hours > 12) {
                    suffix = "pm";
                    hours -= 12;
                }
            }

            timestamp = " @ " + hours + ":" + minutes + suffix;
        }
        catch (e) {
            timestamp = "";
        }

        data.put("timestamp", timestamp);

        // Deal with appropriately - we care about awake (200), non authenticated (401) or asleep (408)
        //DEBUG*/ responseCode = 200;
        //DEBUG*/ responseData = "{\"response\":{\"id\":1234567890123456,\"user_id\":123456789012,\"vehicle_id\":123456789012,\"vin\":\"5YJ3E1EA3MF000001\",\"display_name\":\"Tesla\",\"option_codes\":null,\"color\":null,\"access_type\":\"DRIVER\",\"tokens\":[\"1234567890123456\",\"1234567890123456\"],\"state\":\"online\",\"in_service\":false,\"id_s\":\"1234567890123456\",\"calendar_enabled\":true,\"api_version\":52,\"backseat_token\":null,\"backseat_token_updated_at\":null,\"ble_autopair_enrolled\":false,\"charge_state\":{\"battery_heater_on\":false,\"battery_level\":58,\"battery_range\":143.9,\"charge_amps\":32,\"charge_current_request\":32,\"charge_current_request_max\":32,\"charge_enable_request\":true,\"charge_energy_added\":15.85,\"charge_limit_soc\":65,\"charge_limit_soc_max\":100,\"charge_limit_soc_min\":50,\"charge_limit_soc_std\":90,\"charge_miles_added_ideal\":77.5,\"charge_miles_added_rated\":77.5,\"charge_port_cold_weather_mode\":false,\"charge_port_color\":\"<invalid>\",\"charge_port_door_open\":false,\"charge_port_latch\":\"Engaged\",\"charge_rate\":0.0,\"charger_actual_current\":0,\"charger_phases\":null,\"charger_pilot_current\":32,\"charger_power\":0,\"charger_voltage\":2,\"charging_state\":\"Disconnected\",\"conn_charge_cable\":\"<invalid>\",\"est_battery_range\":115.18,\"fast_charger_brand\":\"<invalid>\",\"fast_charger_present\":false,\"fast_charger_type\":\"<invalid>\",\"ideal_battery_range\":143.9,\"managed_charging_active\":false,\"managed_charging_start_time\":null,\"managed_charging_user_canceled\":false,\"max_range_charge_counter\":0,\"minutes_to_full_charge\":0,\"not_enough_power_to_heat\":null,\"off_peak_charging_enabled\":false,\"off_peak_charging_times\":\"all_week\",\"off_peak_hours_end_time\":360,\"preconditioning_enabled\":false,\"preconditioning_times\":\"all_week\",\"scheduled_charging_mode\":\"Off\",\"scheduled_charging_pending\":false,\"scheduled_charging_start_time\":null,\"scheduled_charging_start_time_app\":390,\"scheduled_departure_time\":1681904700,\"scheduled_departure_time_minutes\":465,\"supercharger_session_trip_planner\":false,\"time_to_full_charge\":0.0,\"timestamp\":1682469473457,\"trip_charging\":false,\"usable_battery_level\":57,\"user_charge_enable_request\":false},\"climate_state\":{\"allow_cabin_overheat_protection\":true,\"auto_seat_climate_left\":true,\"auto_seat_climate_right\":true,\"battery_heater\":false,\"battery_heater_no_power\":null,\"cabin_overheat_protection\":\"Off\",\"cabin_overheat_protection_actively_cooling\":false,\"climate_keeper_mode\":\"off\",\"cop_activation_temperature\":\"High\",\"defrost_mode\":0,\"driver_temp_setting\":21.0,\"fan_status\":0,\"hvac_auto_request\":\"On\",\"inside_temp\":11.4,\"is_auto_conditioning_on\":false,\"is_climate_on\":false,\"is_front_defroster_on\":false,\"is_preconditioning\":false,\"is_rear_defroster_on\":false,\"left_temp_direction\":0,\"max_avail_temp\":28.0,\"min_avail_temp\":15.0,\"outside_temp\":7.5,\"passenger_temp_setting\":21.0,\"remote_heater_control_enabled\":false,\"right_temp_direction\":0,\"seat_heater_left\":0,\"seat_heater_rear_center\":0,\"seat_heater_rear_left\":0,\"seat_heater_rear_right\":0,\"seat_heater_right\":0,\"side_mirror_heaters\":false,\"steering_wheel_heater\":false,\"supports_fan_only_cabin_overheat_protection\":true,\"timestamp\":1682469473457,\"wiper_blade_heater\":false},\"drive_state\":{\"active_route_latitude\":0.00000,\"active_route_longitude\":0.00000,\"active_route_traffic_minutes_delay\":0.0,\"gps_as_of\":1682469471,\"heading\":173,\"latitude\":0.000000,\"longitude\":0.000000,\"native_latitude\":0.000000,\"native_location_supported\":1,\"native_longitude\":0.000000,\"native_type\":\"wgs\",\"power\":0,\"shift_state\":\"D\",\"speed\":null,\"timestamp\":1682469473457},\"gui_settings\":{\"gui_24_hour_time\":true,\"gui_charge_rate_units\":\"kW\",\"gui_distance_units\":\"km/hr\",\"gui_range_display\":\"Rated\",\"gui_temperature_units\":\"C\",\"gui_tirepressure_units\":\"Psi\",\"show_range_units\":false,\"timestamp\":1682469473457},\"vehicle_config\":{\"aux_park_lamps\":\"NaBase\",\"badge_version\":0,\"can_accept_navigation_requests\":true,\"can_actuate_trunks\":true,\"car_special_type\":\"base\",\"car_type\":\"model3\",\"charge_port_type\":\"US\",\"cop_user_set_temp_supported\":true,\"dashcam_clip_save_supported\":true,\"default_charge_to_max\":false,\"driver_assist\":\"TeslaAP3\",\"ece_restrictions\":false,\"efficiency_package\":\"M32021\",\"eu_vehicle\":false,\"exterior_color\":\"RedMulticoat\",\"exterior_trim\":\"Black\",\"exterior_trim_override\":\"\",\"has_air_suspension\":false,\"has_ludicrous_mode\":false,\"has_seat_cooling\":false,\"headlamp_type\":\"Global\",\"interior_trim_type\":\"Black2\",\"key_version\":2,\"motorized_charge_port\":true,\"paint_color_override\":\"10,1,1,0.1,0.04\",\"performance_package\":\"BasePlus\",\"plg\":true,\"pws\":true,\"rear_drive_unit\":\"PM216MOSFET\",\"rear_seat_heaters\":1,\"rear_seat_type\":0,\"rhd\":false,\"roof_color\":\"RoofColorGlass\",\"seat_type\":null,\"spoiler_type\":\"None\",\"sun_roof_installed\":null,\"supports_qr_pairing\":false,\"third_row_seats\":\"None\",\"timestamp\":1682469473457,\"trim_badging\":\"50\",\"use_range_badging\":true,\"utc_offset\":-14400,\"webcam_selfie_supported\":true,\"webcam_supported\":true,\"wheel_type\":\"Pinwheel18CapKit\"},\"vehicle_state\":{\"api_version\":52,\"autopark_state_v2\":\"unavailable\",\"calendar_supported\":true,\"car_version\":\"2023.2.12 a734fb860b32\",\"center_display_state\":0,\"dashcam_clip_save_available\":false,\"dashcam_state\":\"Unavailable\",\"df\":0,\"dr\":0,\"fd_window\":0,\"feature_bitmask\":\"dffbff,0\",\"fp_window\":0,\"ft\":0,\"is_user_present\":false,\"locked\":true,\"media_info\":{\"audio_volume\":2.6667,\"audio_volume_increment\":0.333333,\"audio_volume_max\":10.333333,\"media_playback_status\":\"Stopped\",\"now_playing_album\":\"\",\"now_playing_artist\":\"\",\"now_playing_duration\":0,\"now_playing_elapsed\":0,\"now_playing_source\":\"12\",\"now_playing_station\":\"\",\"now_playing_title\":\"\"},\"media_state\":{\"remote_control_enabled\":true},\"notifications_supported\":true,\"odometer\":0.0,\"parsed_calendar_supported\":true,\"pf\":0,\"pr\":0,\"rd_window\":0,\"remote_start\":false,\"remote_start_enabled\":true,\"remote_start_supported\":true,\"rp_window\":0,\"rt\":0,\"santa_mode\":0,\"sentry_mode\":false,\"sentry_mode_available\":true,\"service_mode\":false,\"service_mode_plus\":false,\"software_update\":{\"download_perc\":0,\"expected_duration_sec\":2700,\"install_perc\":1,\"status\":\"\",\"version\":\" \"},\"speed_limit_mode\":{\"active\":false,\"current_limit_mph\":85.0,\"max_limit_mph\":120,\"min_limit_mph\":50.0,\"pin_code_set\":false},\"timestamp\":1682469473457,\"tpms_hard_warning_fl\":false,\"tpms_hard_warning_fr\":false,\"tpms_hard_warning_rl\":false,\"tpms_hard_warning_rr\":false,\"tpms_last_seen_pressure_time_fl\":1682455078,\"tpms_last_seen_pressure_time_fr\":1682455079,\"tpms_last_seen_pressure_time_rl\":1682455078,\"tpms_last_seen_pressure_time_rr\":1682455078,\"tpms_pressure_fl\":2.925,\"tpms_pressure_fr\":2.9,\"tpms_pressure_rl\":2.925,\"tpms_pressure_rr\":2.95,\"tpms_rcp_front_value\":2.9,\"tpms_rcp_rear_value\":2.9,\"tpms_soft_warning_fl\":false,\"tpms_soft_warning_fr\":false,\"tpms_soft_warning_rl\":false,\"tpms_soft_warning_rr\":false,\"valet_mode\":false,\"valet_pin_needed\":true,\"vehicle_name\":\"Tesla\",\"vehicle_self_test_progress\":0,\"vehicle_self_test_requested\":false,\"webcam_available\":true}}}";
        if (responseCode == 200 && responseData != null) {
            var pos = responseData.find("battery_level");
            var str = responseData.substring(pos + 15, pos + 20);
            var posEnd = str.find(",");
            data.put("battery_level",$.validateNumber(str.substring(0, posEnd)));

            pos = responseData.find("battery_range");
            str = responseData.substring(pos + 15, pos + 22);
            posEnd = str.find(",");
            data.put("battery_range", $.validateNumber(str.substring(0, posEnd)));

            pos = responseData.find("charging_state");
            str = responseData.substring(pos + 17, pos + 37);
            posEnd = str.find("\"");
            data.put("charging_state", $.validateString(str.substring(0, posEnd)));

            pos = responseData.find("inside_temp");
            str = responseData.substring(pos + 13, pos + 20);
            posEnd = str.find(",");
            data.put("inside_temp", $.validateNumber(str.substring(0, posEnd)));

            pos = responseData.find("shift_state");
            str = responseData.substring(pos + 13, pos + 20);
            posEnd = str.find(",");
            var value = $.validateString(str.substring(0, posEnd));
            data.put("shift_state", (value.equals("null") ? "P" : value));

            pos = responseData.find("sentry_mode");
            str = responseData.substring(pos + 13, pos + 20);
            posEnd = str.find(",");
            data.put("sentry", $.validateString(str.substring(0, posEnd)).equals("true"));

            pos = responseData.find("preconditioning_enabled");
            str = responseData.substring(pos + 25, pos + 32);
            posEnd = str.find(",");
            data.put("preconditioning", $.validateString(str.substring(0, posEnd)).equals("true"));
        }
        else if (responseCode == 408) {
            data.put("vehicleAwake", "asleep");
        }

        //DEBUG*/ logMessage("onReceiveVehicleData exiting with data=" + data);
        Background.exit(data);
    }
}

(:background, :can_glance, :bkgnd64kb)
class MyServiceDelegate extends System.ServiceDelegate {
    var _data;
    var _fromTokenRefresh;

    function initialize() {
        System.ServiceDelegate.initialize();

        _fromTokenRefresh = false;
        _data = Background.getBackgroundData();
        if (_data == null) {
            /*DEBUG*/ logMessage("ServiceDelegate: tokens from prop");
            _data = {};
            _data.put("token", Storage.getValue("token"));
            _data.put("refreshToken", Properties.getValue("refreshToken"));
            _data.put("TokenExpiresIn", Storage.getValue("TokenExpiresIn"));
            _data.put("TokenCreatedAt", Storage.getValue("TokenCreatedAt"));
        }
        else {
            /*DEBUG*/ logMessage("ServiceDelegate: have tokens");
        }
    }

    // This fires on our temporal event - we're going to go off and get the vehicle data, only if we have a token and vehicle ID
    function onTemporalEvent() {
        if (Storage.getValue("runBG") == false) { // We're in our Main View. it will refresh 'status' there by itself
            /*DEBUG*/ logMessage("onTemporalEvent: In main view, skipping reading data");
            Background.exit(null);
        }

        var token = Storage.getValue("token");
        var vehicle = Storage.getValue("vehicle");
        if (token != null && vehicle != null) {
            //DEBUG*/ logMessage("onTemporalEvent getting data");
            _fromTokenRefresh = false;
            Communications.makeWebRequest(
                "https://" + Properties.getValue("serverAPILocation") + "/api/1/vehicles/" + vehicle.toString() + "/vehicle_data", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token,
                        "User-Agent" => "Tesla-Link for Garmin"
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                },
                method(:onReceiveVehicleData)
            );
        }
        else {
            /*DEBUG*/ logMessage("onTemporalEvent with token at " + (token == null ? token : token.substring(0, 10)) + " vehicle at " + vehicle);
            _data.put("responseCode", 401);
            Background.exit(_data);
        }
    }

    function onReceiveVehicleData(responseCode, responseData) {
        // The API request has returned check for any other background data waiting. There shouldn't be any. Log it if logging is enabled
        /*DEBUG*/ logMessage("onReceiveVehicleData: responseCode = " + responseCode);
        //DEBUG*/ logMessage("onReceiveVehicleData: responseData = " + responseData);

        _data.put("responseCode", responseCode);

        var timestamp;
        try {
            var clock_time = System.getClockTime();
            var hours = clock_time.hour;
            var minutes = clock_time.min.format("%02d");
            var suffix = "";
            if (System.getDeviceSettings().is24Hour == false) {
                suffix = "am";
                if (hours == 0) {
                    hours = 12;
                }
                else if (hours > 12) {
                    suffix = "pm";
                    hours -= 12;
                }
            }

            timestamp = " @ " + hours + ":" + minutes + suffix;
        }
        catch (e) {
            timestamp = "";
        }
        _data.put("timestamp", timestamp);

        // Deal with appropriately - we care about awake (200), non authenticated (401) or asleep (408)
        if (responseCode == 200 && responseData != null) {
			var response = responseData.get("response");
            if (response.get("charge_state") != null && response.get("climate_state") != null && response.get("drive_state") != null) {
                _data.put("battery_level", $.validateNumber(response.get("charge_state").get("battery_level")));
                _data.put("battery_range", $.validateNumber(response.get("charge_state").get("battery_range")));
                _data.put("charging_state", $.validateString(response.get("charge_state").get("charging_state")));
                _data.put("inside_temp", $.validateNumber(response.get("climate_state").get("inside_temp")));
                _data.put("shift_state", (response.get("drive_state").get("shift_state") == null ? "P" : $.validateString(response.get("drive_state").get("shift_state"))));
                _data.put("sentry", $.validateBoolean(response.get("vehicle_state").get("sentry_mode")));
                _data.put("preconditioning", $.validateBoolean(response.get("charge_state").get("preconditioning_enabled")));
            }
        }
        else if (responseCode == 401) {
            if (_fromTokenRefresh == false) {
                refreshAccessToken();
                return;
            }
            else {
                /*DEBUG*/ logMessage("onReceiveVehicleData: refreshAccessToken!");
            }
        }
        else if (responseCode == 408) {
            testAwake();
            return;
        }

        //DEBUG*/ logMessageAndData("onReceiveVehicleData exiting with data=", _data);
        Background.exit(_data);
    }

    function testAwake() {
        //DEBUG*/ logMessage("testAwake called");
        var token = _data.get("token");

        Communications.makeWebRequest(
            "https://" + Properties.getValue("serverAPILocation") + "/api/1/vehicles", null,
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

	function onReceiveVehicles(responseCode, data) {
		//DEBUG*/ logMessage("onReceiveVehicles: " + responseCode);
		//logMessage("onReceiveVehicles: data is " + data);

		if (responseCode == 200) {
			var vehicles = data.get("response");
			var size = vehicles.size();
			if (size > 0) {
				// Need to retrieve the right vehicle, not just the first one!
				var vehicle_index = 0;
				var vehicle_name = Storage.getValue("vehicle_name");
				if (vehicle_name != null) {
					while (vehicle_index < size) {
                        if (vehicle_name.equals(vehicles[vehicle_index].get("display_name"))) {
                            break;
                        }
                        vehicle_index++;
                    }
                }

                if (vehicle_index == size) {
                    //DEBUG*/ logMessage("onReceiveVehicles: Not found");
                    _data.put("vehicleAwake", "Not found");
                }
                else {
                    var vehicle_state = vehicles[vehicle_index].get("state");
                    //DEBUG*/ logMessage("onReceiveVehicles: vehicle state: " + vehicle_state);
                    _data.put("vehicleAwake", vehicle_state);
				}
			}
            else {
                _data.put("vehicleAwake", "No vehicle");
            }
        }
        else {
            _data.put("vehicleAwake", "error");
        }

        //DEBUG*/ logMessageAndData("onReceiveVehicles exiting with data=", _data);
        Background.exit(_data);
    }

    function refreshAccessToken() {
        //DEBUG*/ logMessage("refreshAccessToken called");
        var refreshToken = _data.get("refreshToken");
        if (refreshToken == null || refreshToken.equals("") == true) {
            /*DEBUG*/ logMessage("refreshAccessToken: WARNIGN refreshToken in data stream empty!");
            refreshToken = Properties.getValue("refreshToken");
        }
        if (refreshToken != null && refreshToken.equals("") == false) {
            var url = "https://" + Properties.getValue("serverAUTHLocation") + "/oauth2/v3/token";
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
            return;
        }

        _data.put("responseCode", 401);
        //DEBUG*/ logMessageAndData("refreshAccessToken exiting with data=", _data);
        Background.exit(_data);
    }

    // Do NOT call from a background process since we're setting registry data here
    function onReceiveToken(responseCode, data) {
        //DEBUG*/ logMessage("onReceiveToken: " + responseCode);

        if (responseCode == 200) {
            var token = data["access_token"];
            var refreshToken = data["refresh_token"];
            var expires_in = data["expires_in"];
            //var state = data["state"];
            var created_at = Time.now().value();

			//DEBUG*/ var expireAt = new Time.Moment(created_at + expires_in);
			//DEBUG*/ var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
			//DEBUG*/ var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
			//DEBUG*/ logMessage("onReceiveToken: Expires at " + dateStr);

            //logMessage("onReceiveToken: state field is '" + state + "'");

            _data.put("token", token);
            _data.put("TokenExpiresIn", expires_in);
            _data.put("TokenCreatedAt", created_at);
            if (refreshToken != null && refreshToken.equals("") == false) {
                _data.put("refreshToken", refreshToken);
            }
            else {
                /*DEBUG*/ logMessage("onReceiveToken: WARNIGN refreshToken received was empty!");
            }

            //DEBUG*/ logMessage("onReceiveToken getting data");
            var vehicle = Storage.getValue("vehicle");

            _fromTokenRefresh = true;
            Communications.makeWebRequest(
                "https://" + Properties.getValue("serverAPILocation") + "/api/1/vehicles/" + vehicle.toString() + "/vehicle_data", null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :headers => {
                        "Authorization" => "Bearer " + token,
                        "User-Agent" => "Tesla-Link for Garmin"
                    },
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                },
                method(:onReceiveVehicleData)
            );
        }
        else {
            //DEBUG*/ logMessageAndData("onReceiveToken exiting with data=", _data);
            Background.exit(_data);
        }
    }
}
