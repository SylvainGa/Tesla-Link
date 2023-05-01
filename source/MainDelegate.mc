using Toybox.WatchUi as Ui;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Communications as Communications;
using Toybox.Cryptography;
using Toybox.Graphics;
using Toybox.Time.Gregorian;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

const OAUTH_CODE = "myOAuthCode";
const OAUTH_ERROR = "myOAuthError";

enum /* ACTION_OPTIONS */ {
	ACTION_OPTION_NONE = 0,
	ACTION_OPTION_BYPASS_CONFIRMATION = 1,
	ACTION_OPTION_SEAT_DRIVER = 2,
	ACTION_OPTION_SEAT_PASSENGER = 3,
	ACTION_OPTION_SEAT_REAR_DRIVER = 4,
	ACTION_OPTION_SEAT_REAR_CENTER = 5,
	ACTION_OPTION_SEAT_REAR_PASSENGER = 6
}

enum /* ACTION_TYPES */ {
	ACTION_TYPE_RESET = 0,
	ACTION_TYPE_HONK = 1,
	ACTION_TYPE_SELECT_CAR = 2, // Done in OptionMenu, not ActionMachine
	ACTION_TYPE_OPEN_PORT = 3,
	ACTION_TYPE_CLOSE_PORT = 4,
	ACTION_TYPE_OPEN_FRUNK = 5,
	ACTION_TYPE_OPEN_TRUNK = 6,
	ACTION_TYPE_TOGGLE_VIEW = 7, // Done in OptionMenu, not ActionMachine
	ACTION_TYPE_SWAP_FRUNK_FOR_PORT = 8, // Done in OptionMenu, not ActionMachine
	ACTION_TYPE_SET_CHARGING_AMPS = 9,
	ACTION_TYPE_SET_CHARGING_LIMIT = 10,
	ACTION_TYPE_SET_SEAT_HEAT = 11,
	ACTION_TYPE_SET_STEERING_WHEEL_HEAT = 12,
	ACTION_TYPE_VENT = 13,
	ACTION_TYPE_TOGGLE_CHARGE = 14,
	ACTION_TYPE_ADJUST_DEPARTURE = 15,
	ACTION_TYPE_TOGGLE_SENTRY = 16,
	ACTION_TYPE_WAKE = 17, // Done in OptionMenu, not ActionMachine
	ACTION_TYPE_REFRESH = 18,
	ACTION_TYPE_DATA_SCREEN = 19,
	ACTION_TYPE_HOMELINK = 20,
	ACTION_TYPE_REMOTE_BOOMBOX = 21,
	ACTION_TYPE_CLIMATE_MODE = 22,
	ACTION_TYPE_CLIMATE_DEFROST = 23,
	ACTION_TYPE_CLIMATE_SET = 24,
	// Following are through buttons or touch screen input
	ACTION_TYPE_CLIMATE_ON = 25,
	ACTION_TYPE_CLIMATE_OFF = 26,
	ACTION_TYPE_LOCK = 27,
	ACTION_TYPE_UNLOCK = 28
}

/* _stateMachineCounter DEFINITION
-3 In onReceiveVehicleData, means actionMachine is running so ignore the data received
-2 In onReceiveVehicleData, means as we're in a menu (flagged by -1), we got a SECOND vehicleData, should NOT happen
-1 In onReceiveVehicleData, means we're in a menu and to ignore the data we just received
0 In stateMachine, means not to run
1 In stateMachine, it's time call getVehicleData
2 and above, we wait until we get to 1
*/

class MainDelegate extends Ui.BehaviorDelegate {
	var _view as MainView;
	var _settings;
	var _handler;
	var _tesla;
	var _data;
	var _token;
	var _code_verifier;
	var _workTimer;
	var _vehicle_id;
	var _vehicle_state;
	var _need_auth;
	var _auth_done;
	var _check_wake;
	var _need_wake;
	var _wake_done;
	var _waitingFirstData;
	var _wakeWasConfirmed;
	var _refreshTimeInterval;
	var _408_count;
	var _lastError;
	var _lastTimeStamp;
	var _lastDataRun;
	var _waitingForCommandReturn;
	var _debug_auth;
	var _debug_view;
	// 2023-03-20 var _debugTimer;

	var _pendingActionRequests;
	var _stateMachineCounter;
	
	function initialize(view as MainView, data, handler) {
		BehaviorDelegate.initialize();
	
		_view = view;

		_settings = System.getDeviceSettings();
		_data = data;
		_token = Settings.getToken();
		_vehicle_id = Storage.getValue("vehicle");
		_vehicle_state = "online"; // Assume we're online
		_workTimer = new Timer.Timer();
		_handler = handler;
		_tesla = null;
		_waitingForCommandReturn = false;

		if (Properties.getValue("enhancedTouch")) {
			Storage.setValue("spinner", "+");
		}
		else {
			Storage.setValue("spinner", "/");
		}
		
		// _debugTimer = System.getTimer(); Storage.setValue("overrideCode", 0);
		_debug_auth = false;
		_debug_view = false;

		var createdAt = Storage.getValue("TokenCreatedAt");
		if (createdAt == null) {
			createdAt = 0;
		}
		else {
			createdAt = createdAt.toNumber();
		}
		var expireIn = Storage.getValue("TokenExpiresIn");
		if (expireIn == null) {
			expireIn = 0;
		}
		else {
			expireIn = expireIn.toNumber();
		}

		// Check if we need to refresh our access token
		var timeNow = Time.now().value();
		var interval = 5 * 60;
		var expired = (timeNow + interval < createdAt + expireIn);
		
		if (_debug_auth == false && _token != null && _token.length() > 0 && expired == true ) {
			_need_auth = false;
			_auth_done = true;
			//DEBUG*/ var expireAt = new Time.Moment(createdAt + expireIn);
			//DEBUG*/ var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
			//DEBUG*/ var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
			//DEBUG*/ logMessage("initialize:Using access token '" + _token.substring(0,10) + "...' lenght=" + _token.length() + " which expires at " + dateStr);
		} else {
			//DEBUG*/ logMessage("initialize:No token or expired, will need to get one through a refresh token or authentication");
			_need_auth = true;
			_auth_done = false;
		}

		_check_wake = false; // If we get a 408 on first try or after 20 consecutive 408, see if we should wake up again 
		_need_wake = false; // Assume we're awake and if we get a 408, then wake up (just like _vehicle_state is set to online)
		_wake_done = true;
		gWaitTime = System.getTimer();
		_waitingFirstData = 1; // So the Waking up is displayed right away if it's the first time
		_wakeWasConfirmed = false; // So we only display the Asking to wake only once

		_408_count = 0;
		_lastError = null;
		_refreshTimeInterval = Storage.getValue("refreshTimeInterval");
		if (_refreshTimeInterval == null || _refreshTimeInterval.toNumber() < 500) {
			_refreshTimeInterval = 4000;
		}

		_lastTimeStamp = 0;

		_pendingActionRequests = [];
		_stateMachineCounter = 0;

		var useTouch = Properties.getValue("useTouch");
		var hasTouch = System.getDeviceSettings().isTouchScreen;
		var neededButtons = System.BUTTON_INPUT_SELECT + System.BUTTON_INPUT_UP + System.BUTTON_INPUT_DOWN + System.BUTTON_INPUT_MENU;
		var hasButtons = (System.getDeviceSettings().inputButtons & neededButtons) == neededButtons;

		// Make sure the combination of having buttons and touchscreen matches what we're asking through useTouch
		if (useTouch == null || useTouch == true && hasTouch == false || hasButtons == false && hasTouch == true && useTouch == false) {
			useTouch = hasTouch;
			Properties.setValue("useTouch", useTouch);
		}

		// This is where the main code will start running. Don't intialise stuff after this line
		//DEBUG*/ logMessage("initialize: quickAccess=" + Properties.getValue("quickReturn") + " enhancedTouch=" + Properties.getValue("enhancedTouch"));
		_workTimer.start(method(:workerTimer), 100, true);

/*DEBUG	if (_debug_view) {
			if (_tesla == null) {
				_tesla = new Tesla(_token);
			}
			_data._vehicle_data = 
			{
				"id" => "1234567890123456",
				"vehicle_id" => "123456789012",
				"vin" => "5YJ3E1EA3MF000001",
				"display_name" => "Tesla",
				"option_codes" => "AD15,MDL3,PBSB,RENA,BT37,ID3W,RF3G,S3PB,DRLH,DV2W,W39B,APF0,COUS,BC3B,CH07,PC30,FC3P,FG31,GLFR,HL31,HM31,IL31,LTPB,MR31,FM3B,RS3H,SA3P,STCP,SC04,SU3C,T3CA,TW00,TM00,UT3P,WR00,AU3P,APH3,AF00,ZCST,MI00,CDM0",
				"color" => null,
				"access_type" => "OWNER",
				"tokens" => [
					"1111111111111111",
					"2222222222222222"
				],
				"state" => "asleep",
				"in_service" => false,
				"id_s" => "1234567890123456",
				"calendar_enabled" => true,
				"api_version" => 36,
				"backseat_token" => null,
				"backseat_token_updated_at" => null,
				"user_id" => "123456789012",
				"charge_state" => {
					"battery_heater_on" => false,
					"battery_level" => 80,
					"battery_range" => 200.05,
					"charge_amps" => 32,
					"charge_current_request" => 32,
					"charge_current_request_max" => 32,
					"charge_enable_request" => true,
					"charge_energy_added" => 1.99,
					"charge_limit_soc" => 80,
					"charge_limit_soc_max" => 100,
					"charge_limit_soc_min" => 50,
					"charge_limit_soc_std" => 90,
					"charge_miles_added_ideal" => 9.5,
					"charge_miles_added_rated" => 9.5,
					"charge_port_cold_weather_mode" => false,
					"charge_port_color" => "<invalid>",
					"charge_port_door_open" => true,
					"charge_port_latch" => "Engaged",
					"charge_rate" => 0.0,
					"charge_to_max_range" => false,
					"charger_actual_current" => 0,
					"charger_phases" => 1,
					"charger_pilot_current" => 32,
					"charger_power" => 0,
					"charger_voltage" => 2,
					"charging_state" => "Complete",
					"conn_charge_cable" => "SAE",
					"est_battery_range" => 165.67,
					"fast_charger_brand" => "<invalid>",
					"fast_charger_present" => false,
					"fast_charger_type" => "ACSingleWireCAN",
					"ideal_battery_range" => 200.05,
					"managed_charging_active" => false,
					"managed_charging_start_time" => null,
					"managed_charging_user_canceled" => false,
					"max_range_charge_counter" => 0,
					"minutes_to_full_charge" => 0,
					"not_enough_power_to_heat" => null,
					"off_peak_charging_enabled" => false,
					"off_peak_charging_times" => "all_week",
					"off_peak_hours_end_time" => 0,
					"preconditioning_enabled" => false,
					"preconditioning_times" => "all_week",
					"scheduled_charging_mode" => "Off",
					"scheduled_charging_pending" => false,
					"scheduled_charging_start_time" => null,
					"scheduled_charging_start_time_app" => 0,
					"scheduled_departure_time" => "1649079000",
					"scheduled_departure_time_minutes" => 570,
					"supercharger_session_trip_planner" => false,
					"time_to_full_charge" => 0.0,
					"timestamp" => "1649373163710",
					"trip_charging" => false,
					"usable_battery_level" => 79,
					"user_charge_enable_request" => null
				},
				"climate_state" => {
					"allow_cabin_overheat_protection" => true,
					"auto_seat_climate_left" => false,
					"auto_seat_climate_right" => false,
					"battery_heater" => false,
					"battery_heater_no_power" => null,
					"cabin_overheat_protection" => "FanOnly",
					"cabin_overheat_protection_actively_cooling" => false,
					"climate_keeper_mode" => "off",
					"defrost_mode" => 0,
					"driver_temp_setting" => 21.0,
					"fan_status" => 0,
					"hvac_auto_request" => "On",
					"inside_temp" => 7.4,
					"is_auto_conditioning_on" => false,
					"is_climate_on" => false,
					"is_front_defroster_on" => false,
					"is_preconditioning" => false,
					"is_rear_defroster_on" => false,
					"left_temp_direction" => 0,
					"max_avail_temp" => 28.0,
					"min_avail_temp" => 15.0,
					"outside_temp" => 6.0,
					"passenger_temp_setting" => 21.0,
					"remote_heater_control_enabled" => false,
					"right_temp_direction" => 0,
					"seat_heater_left" => 0,
					"seat_heater_rear_center" => 0,
					"seat_heater_rear_left" => 0,
					"seat_heater_rear_right" => 0,
					"seat_heater_right" => 0,
					"side_mirror_heaters" => false,
					"steering_wheel_heater" => false,
					"supports_fan_only_cabin_overheat_protection" => true,
					"timestamp" => "1649373163710",
					"wiper_blade_heater" => false
				},
				"drive_state" => {
					"gps_as_of" => "1649371875",
					"heading" => 170,
					"latitude" => 40.0,
					"longitude" => -70.0,
					"native_latitude" => 4.0,
					"native_location_supported" => 1,
					"native_longitude" => -70.0,
					"native_type" => "wgs",
					"power" => 0,
					"shift_state" => null,
					"speed" => null,
					"timestamp" => "1649373163710"
				},
				"gui_settings" => {
					"gui_24_hour_time" => true,
					"gui_charge_rate_units" => "kW",
					"gui_distance_units" => "km/hr",
					"gui_range_display" => "Rated",
					"gui_temperature_units" => "C",
					"show_range_units" => false,
					"timestamp" => "1649373163710"
				},
				"vehicle_config" => {
					"badge_version" => 0,
					"can_accept_navigation_requests" => true,
					"can_actuate_trunks" => true,
					"car_special_type" => "base",
					"car_type" => "model3",
					"charge_port_type" => "US",
					"dashcam_clip_save_supported" => true,
					"default_charge_to_max" => false,
					"driver_assist" => "TeslaAP3",
					"ece_restrictions" => false,
					"efficiency_package" => "M32021",
					"eu_vehicle" => false,
					"exterior_color" => "RedMulticoat",
					"exterior_trim" => "Black",
					"exterior_trim_override" => "",
					"has_air_suspension" => false,
					"has_ludicrous_mode" => false,
					"has_seat_cooling" => false,
					"headlamp_type" => "Global",
					"interior_trim_type" => "Black2",
					"key_version" => 2,
					"motorized_charge_port" => true,
					"paint_color_override" => "10,1,1,0.1,0.04",
					"performance_package" => "BasePlus",
					"plg" => true,
					"pws" => true,
					"rear_drive_unit" => "PM216MOSFET",
					"rear_seat_heaters" => 1,
					"rear_seat_type" => 0,
					"rhd" => false,
					"roof_color" => "RoofColorGlass",
					"seat_type" => null,
					"spoiler_type" => "None",
					"sun_roof_installed" => null,
					"third_row_seats" => "None",
					"timestamp" => "1649373163710",
					"trim_badging" => "50",
					"use_range_badging" => true,
					"utc_offset" => -14400,
					"webcam_supported" => true,
					"wheel_type" => "PinwheelRefresh18"
				},
				"vehicle_state" => {
					"api_version" => 36,
					"autopark_state_v2" => "unavailable",
					"calendar_supported" => true,
					"car_version" => "2022.8.3 e4797d240c70",
					"center_display_state" => 0,
					"dashcam_clip_save_available" => true,
					"dashcam_state" => "Recording",
					"df" => 0,
					"dr" => 0,
					"fd_window" => 0,
					"feature_bitmask" => "5,0",
					"fp_window" => 0,
					"ft" => 0,
					"is_user_present" => false,
					"locked" => true,
					"media_state" => {
						"remote_control_enabled" => true
					},
					"notifications_supported" => true,
					"odometer" => 8775.268476,
					"parsed_calendar_supported" => true,
					"pf" => 0,
					"pr" => 0,
					"rd_window" => 0,
					"remote_start" => false,
					"remote_start_enabled" => true,
					"remote_start_supported" => true,
					"rp_window" => 0,
					"rt" => 0,
					"santa_mode" => 0,
					"sentry_mode" => false,
					"sentry_mode_available" => true,
					"software_update" => {
						"download_perc" => 0,
						"expected_duration_sec" => 2700,
						"install_perc" => 1,
						"status" => "",
						"version" => " "
					},
					"speed_limit_mode" => {
						"active" => false,
						"current_limit_mph" => 85.0,
						"max_limit_mph" => 90,
						"min_limit_mph" => 50.0,
						"pin_code_set" => false
					},
					"timestamp" => "1649373163710",
					"tpms_pressure_fl" => 0.0,
					"tpms_pressure_fr" => 0.0,
					"tpms_pressure_rl" => 0.0,
					"tpms_pressure_rr" => 0.0,
					"valet_mode" => false,
					"vehicle_name" => "Christine",
					"vehicle_self_test_progress" => 0,
					"vehicle_self_test_requested" => false,
					"webcam_available" => true
				}
			};
		}*/

		stateMachine(); // Launch getting the states right away.
	}

	function onReceive(args) {
		if (args == 0) { // The sub page ended and sent us a _handler.invoke(0) call, display our main view
			//logMessage("StateMachine: onReceive");
			_stateMachineCounter = 1;
		}
		else if (args == 1) { // Swiped left from main screen, show subview 1
			var view = new ChargeView(_view._data);
			var delegate = new ChargeDelegate(view, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else if (args == 2) { // Swiped left on subview 1, show subview 2
			var view = new ClimateView(_view._data);
			var delegate = new ClimateDelegate(view, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else if (args == 3) { // Swiped left on subview 2, show subview 3
			var view = new DriveView(_view._data);
			var delegate = new DriveDelegate(view, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else { // Swiped left on subview 3, we're back at the main display
			_stateMachineCounter = 1;
		}
	    Ui.requestUpdate();
	}

	function onSwipe(swipeEvent) {
		if (_view._data._ready) { // Don't handle swipe if where not showing the data screen
	    	if (swipeEvent.getDirection() == 3) {
				onReceive(1); // Show the first submenu
		    }
		}
		return true;
	}

	function onOAuthMessage(message) {
		//DEBUG*/ var responseCode = null;
		var error = null;
		var code = null;

		if (message != null) {
			//DEBUG*/ responseCode = message.responseCode; // I don't think this is being used, but log it just in case if logging is compiled

			if (message.data != null) {
				error = message.data[$.OAUTH_ERROR];
				code = message.data[$.OAUTH_CODE];
			}
		}

		//DEBUG*/ logMessage("onOAuthMessage: responseCode=" + responseCode + " error=" + error + " code=" + (code == null ? "null" : code.substring(0,10) + "..."));

		if (error == null && code != null) {
			_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_requesting_data)]);
			var codeForBearerUrl = "https://" + Properties.getValue("serverAUTHLocation") + "/oauth2/v3/token";
			var codeForBearerParams = {
				"grant_type" => "authorization_code",
				"client_id" => "ownerapi",
				"code" => code,
				"code_verifier" => _code_verifier,
				"redirect_uri" => "https://" + Properties.getValue("serverAUTHLocation") + "/void/callback"
			};

			var mySettings = System.getDeviceSettings();
			var id = mySettings.uniqueIdentifier;

			var codeForBearerOptions = {
				:method => Communications.HTTP_REQUEST_METHOD_POST,
				:headers => {
				   "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
				   "User-Agent" => "Tesla-Link for Garmin device " + id
				},
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
			};

			//logMessage("onOAuthMessage makeWebRequest codeForBearerUrl: '" + codeForBearerUrl + "' codeForBearerParams: '" + codeForBearerParams + "' codeForBearerOptions: '" + codeForBearerOptions + "'");
			//DEBUG*/ logMessage("onOAuthMessage: Asking through an OAUTH2");
			Communications.makeWebRequest(codeForBearerUrl, codeForBearerParams, codeForBearerOptions, method(:onReceiveToken));
		} else {
			_need_auth = true;
			_auth_done = false;

			_resetToken();

			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_oauth_error)]);
			_stateMachineCounter = 1;
		}
	}

	function onReceiveToken(responseCode, data) {
		//DEBUG*/ logMessage("onReceiveToken: " + responseCode);

		if (responseCode == 200) {
			_auth_done = true;

			_handler.invoke([3, -1, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n" + Ui.loadResource(Rez.Strings.label_got_token)]);

			var accessToken = data["access_token"];
			var refreshToken = data["refresh_token"];
			var expires_in = data["expires_in"];
			//var state = data["state"];
			var created_at = Time.now().value();

			//logMessage("onReceiveToken: state field is '" + state + "'");

			_saveToken(accessToken, expires_in, created_at);

			//DEBUG*/ var expireAt = new Time.Moment(created_at + expires_in);
			//DEBUG*/ var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
			//DEBUG*/ var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");

			if (refreshToken != null && refreshToken.equals("") == false) { // Only if we received a refresh tokem
				if (accessToken != null) {
					//DEBUG*/ logMessage("onReceiveToken: refresh token=" + refreshToken.substring(0,10) + "... lenght=" + refreshToken.length() + " access token=" + accessToken.substring(0,10) + "... lenght=" + accessToken.length() + " which expires at " + dateStr);
				} else {
					//DEBUG*/ logMessage("onReceiveToken: refresh token=" + refreshToken.substring(0,10) + "... lenght=" + refreshToken.length() + "+ NO ACCESS TOKEN");
				}
				Settings.setRefreshToken(refreshToken);
			}
			else {
				//DEBUG*/ logMessage("onReceiveToken: WARNING - NO REFRESH TOKEN but got an access token: " + accessToken.substring(0,20) + "... lenght=" + accessToken.length() + " which expires at " + dateStr);
			}
		} else {
			//DEBUG*/ logMessage("onReceiveToken: couldn't get tokens, clearing refresh token");
			// Couldn't refresh our access token through the refresh token, invalide it and try again (through username and password instead since our refresh token is now empty
			_need_auth = true;
			_auth_done = false;

			Settings.setRefreshToken(null);

			_handler.invoke([0, -1, buildErrorString(responseCode)]);
	    }

		_stateMachineCounter = 1;
	}

	function GetAccessToken(token, notify) {
		var url = "https://" + Properties.getValue("serverAUTHLocation") + "/oauth2/v3/token";
		Communications.makeWebRequest(
			url,
			{
				"grant_type" => "refresh_token",
				"client_id" => "ownerapi",
				"refresh_token" => token,
				"scope" => "openid email offline_access"
			},
			{
				:method => Communications.HTTP_REQUEST_METHOD_POST,
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
			},
			notify
		);
	}

	function SpinSpinner(responseCode) {
		var spinner = Storage.getValue("spinner");

		if (spinner == null) {
			//DEBUG*/ logMessage("SpinSpinner: WARNING should not be null");
			spinner = "";
		}

		spinner = spinner.substring(0,1);

		if (responseCode == 200) {
			if (spinner.equals("+")) {
				spinner = "-";
			}
			else if (spinner.equals("-")) {
				spinner = "+";
			}
			else if (spinner.equals("/")) {
				spinner = "\\";
			}
			else if (spinner.equals("\\")) {
				spinner = "/";
			}
			else {
				if (Properties.getValue("enhancedTouch")) {
					spinner = "+";
				}
				else {
					spinner = "/";
				}
			}
		}
		else {
			if (spinner.equals("?")) {
				spinner = "¿";
			}
			else {
				spinner = "?";
			}
		}

		if (_pendingActionRequests.size() > 0) {
			spinner = spinner + "W";
		}

		// 2023-03-25 logMessage("SpinSpinner: '" + spinner + "'");
		Storage.setValue("spinner", spinner);
	}

	function actionMachine() {
		//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is " + _pendingActionRequests.size() + (_vehicle_id != null && _vehicle_id > 0 ? "" : "vehicle_id " + _vehicle_id) + " vehicle_state " + _vehicle_state + (_need_auth ? " _need_auth true" : "") + (!_auth_done ? " _auth_done false" : "") + (_check_wake ? " _check_wake true" : "") + (_need_wake ? " _need_wake true" : "") + (!_wake_done ? " _wake_done false" : "") + (_waitingFirstData ? " _waitingFirstData=" + _waitingFirstData : ""));

		// Sanity check
		if (_pendingActionRequests.size() <= 0) {
			//DEBUG*/ logMessage("actionMachine: WARNING _pendingActionSize can't be less than 1 if we're here");
			return;
		}

		var request = _pendingActionRequests[0];

		//DEBUG*/ logMessage("actionMachine: _pendingActionRequests[0] is " + request);

		// Sanity check
		if (request == null) {
			//DEBUG*/ logMessage("actionMachine: WARNING the request shouldn't be null");
			return;
		}

		var action = request.get("Action");
		var option = request.get("Option");
		var value = request.get("Value");
		//var tick = request.get("Tick");

		_pendingActionRequests.remove(request);

		_stateMachineCounter = -3; // Don't bother us with getting states when we do our things

		var _handlerType;
		if (Properties.getValue("quickReturn")) {
			_handlerType = 1;
		}
		else {
			_handlerType = 2;
		}

		switch (action) {
			case ACTION_TYPE_RESET:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Reset - waiting for revokeHandler");
				_tesla.revoke(method(:revokeHandler));
				break;

			case ACTION_TYPE_CLIMATE_ON:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Climate On - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_hvac_on)]);
				_tesla.climateOn(_vehicle_id, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLIMATE_OFF:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Climate Off - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_hvac_off)]);
				_tesla.climateOff(_vehicle_id, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLIMATE_DEFROST:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Climate Defrost - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(_data._vehicle_data.get("climate_state").get("defrost_mode") == 2 ? Rez.Strings.label_defrost_off : Rez.Strings.label_defrost_on)]);
				_tesla.climateDefrost(_vehicle_id, method(:onCommandReturn), _data._vehicle_data.get("climate_state").get("defrost_mode"));
				break;

			case ACTION_TYPE_CLIMATE_SET:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Climate set temperature - waiting for onCommandReturn");
				var temperature = value;
				if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
					temperature = temperature * 9 / 5 + 32;
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_climate_set) + temperature.format("%d") + "°F"]);
				} else {
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_climate_set) + temperature.format("%.1f") + "°C"]);
				}
				_tesla.climateSet(_vehicle_id, method(:onCommandReturn), temperature);
				break;

			case ACTION_TYPE_TOGGLE_CHARGE:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Toggling charging - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(_data._vehicle_data.get("charge_state").get("charging_state").equals("Charging") ? Rez.Strings.label_stop_charging : Rez.Strings.label_start_charging)]);
				_tesla.toggleCharging(_vehicle_id, method(:onCommandReturn), _data._vehicle_data.get("charge_state").get("charging_state").equals("Charging"));
				break;

			case ACTION_TYPE_SET_CHARGING_LIMIT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Setting charge limit - waiting for onCommandReturn");
				var charging_limit = value;
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_charging_limit) + charging_limit + "%"]);
				_tesla.setChargingLimit(_vehicle_id, method(:onCommandReturn), charging_limit);
				break;

			case ACTION_TYPE_SET_CHARGING_AMPS:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Setting max current - waiting for onCommandReturn");
				var charging_amps = value;
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_charging_amps) + charging_amps + "A"]);
				_tesla.setChargingAmps(_vehicle_id, method(:onCommandReturn), charging_amps);
				break;

			case ACTION_TYPE_HONK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (option == ACTION_OPTION_BYPASS_CONFIRMATION) {
					honkHornConfirmed();
				} else {
					var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_honk_horn));
					var delegate = new SimpleConfirmDelegate(method(:honkHornConfirmed), method(:operationCanceled));
					Ui.pushView(view, delegate, Ui.SLIDE_UP);
				}
				break;

			case ACTION_TYPE_OPEN_PORT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Opening on charge port - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(_data._vehicle_data.get("charge_state").get("charge_port_door_open") ? Rez.Strings.label_unlock_port : Rez.Strings.label_open_port)]);
				_tesla.openPort(_vehicle_id, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLOSE_PORT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Closing on charge port - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_close_port)]);
				_tesla.closePort(_vehicle_id, method(:onCommandReturn));
				break;

			case ACTION_TYPE_UNLOCK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Unlock - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_unlock_doors)]);
				_tesla.doorUnlock(_vehicle_id, method(:onCommandReturn));
				break;

			case ACTION_TYPE_LOCK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Lock - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_lock_doors)]);
				_tesla.doorLock(_vehicle_id, method(:onCommandReturn));
				break;

			case ACTION_TYPE_OPEN_FRUNK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (option == ACTION_OPTION_BYPASS_CONFIRMATION) {
					frunkConfirmed();
				}
				else {
					var view;
					if (_data._vehicle_data.get("vehicle_state").get("ft") == 0) {
						view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.menu_label_open_frunk));
					}
					else if (Properties.getValue("HansshowFrunk")) {
						view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.menu_label_close_frunk));
					}
					else {
						_stateMachineCounter = 1;
						_handler.invoke([1, -1, Ui.loadResource(Rez.Strings.label_frunk_opened)]);
						break;

					}
					var delegate = new SimpleConfirmDelegate(method(:frunkConfirmed), method(:operationCanceled));
					Ui.pushView(view, delegate, Ui.SLIDE_UP);
				}
				break;

			case ACTION_TYPE_OPEN_TRUNK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (option == ACTION_OPTION_BYPASS_CONFIRMATION) {
					trunkConfirmed();
				}
				else {
					var view = new Ui.Confirmation(Ui.loadResource((_data._vehicle_data.get("vehicle_state").get("rt") == 0 ? Rez.Strings.menu_label_open_trunk : Rez.Strings.menu_label_close_trunk)));
					var delegate = new SimpleConfirmDelegate(method(:trunkConfirmed), method(:operationCanceled));
					Ui.pushView(view, delegate, Ui.SLIDE_UP);
				}
				break;

			case ACTION_TYPE_VENT:
				//DEBUG*/ logMessage("actionMachine: Venting - _pendingActionRequest size is now " + _pendingActionRequests.size());

				var venting = _data._vehicle_data.get("vehicle_state").get("fd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("fp_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rp_window").toNumber();
				if (venting == 0) {
					if (option == ACTION_OPTION_BYPASS_CONFIRMATION) {
						openVentConfirmed();
					} else {
						var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_open_vent));
						var delegate = new SimpleConfirmDelegate(method(:openVentConfirmed), method(:operationCanceled));
						Ui.pushView(view, delegate, Ui.SLIDE_UP);
					}
				}
				else {
					if (option == ACTION_OPTION_BYPASS_CONFIRMATION) {
						closeVentConfirmed();
					} else {
						var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_close_vent));
						var delegate = new SimpleConfirmDelegate(method(:closeVentConfirmed), method(:operationCanceled));
						Ui.pushView(view, delegate, Ui.SLIDE_UP);
					}
				}
				break;

			case ACTION_TYPE_SET_SEAT_HEAT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Setting seat heat - waiting for onCommandReturn");
				var seat_heat_chosen_label = Storage.getValue("seat_heat_chosen");
				var seat_heat_chosen;
				switch (seat_heat_chosen_label) {
					case Rez.Strings.label_seat_auto:
						seat_heat_chosen = -1;
						break;

					case Rez.Strings.label_seat_off:
						seat_heat_chosen = 0;
						break;

					case Rez.Strings.label_seat_low:
						seat_heat_chosen = 1;
						break;

					case Rez.Strings.label_seat_medium:
						seat_heat_chosen = 2;
						break;

					case Rez.Strings.label_seat_high:
						seat_heat_chosen = 3;
						break;
						
					default:
						//DEBUG*/ logMessage("actionMachine: seat_heat_chosen is invalid '" + seat_heat_chosen_label + "'");
						seat_heat_chosen = 0;
						_stateMachineCounter = 1;
			            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
						return;
				}

				var label;
				var position;

				switch (option) {
					case ACTION_OPTION_SEAT_DRIVER:
						label = Rez.Strings.label_seat_driver;
						position = 0;
						break;
					case ACTION_OPTION_SEAT_PASSENGER:
						label = Rez.Strings.label_seat_passenger;
						position = 1;
						break;
					case ACTION_OPTION_SEAT_REAR_DRIVER:
						label = Rez.Strings.label_seat_rear_left;
						position = 2;
						break;
					case ACTION_OPTION_SEAT_REAR_CENTER:
						label = Rez.Strings.label_seat_rear_center;
						position = 4;
						break;
					case ACTION_OPTION_SEAT_REAR_PASSENGER:
						label = Rez.Strings.label_seat_rear_right;
						position = 5;
						break;
					default:
						//DEBUG*/ logMessage("actionMachine: Seat Heat option is invalid '" + option + "'");
						break;
				}

				_handler.invoke([_handlerType, -1, Ui.loadResource(label) + " - " + Ui.loadResource(seat_heat_chosen_label)]);
				_tesla.climateSeatHeat(_vehicle_id, method(:onCommandReturn), position, seat_heat_chosen);
				break;

			case ACTION_TYPE_SET_STEERING_WHEEL_HEAT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Setting steering wheel heat - waiting for onCommandReturn");
				if (_data._vehicle_data.get("climate_state").get("is_climate_on") == false) {
					_handler.invoke([1, -1, Ui.loadResource(Rez.Strings.label_steering_wheel_need_climate_on)]);
					_stateMachineCounter = 1;
				}
				else if (_data._vehicle_data.get("climate_state").get("steering_wheel_heater") != null) {
					_handler.invoke([_handlerType, -1, Ui.loadResource(_data._vehicle_data.get("climate_state").get("steering_wheel_heater") == true ? Rez.Strings.label_steering_wheel_off : Rez.Strings.label_steering_wheel_on)]);
					_tesla.climateSteeringWheel(_vehicle_id, method(:onCommandReturn), _data._vehicle_data.get("climate_state").get("steering_wheel_heater"));
				}
				else {
					_stateMachineCounter = 1;
				}
				break;

			case ACTION_TYPE_ADJUST_DEPARTURE:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
					//DEBUG*/ logMessage("actionMachine: Preconditionning off - waiting for onCommandReturn");
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_stop_departure)]);
					_tesla.setDeparture(_vehicle_id, method(:onCommandReturn), value, false);
				}
				else {
					//DEBUG*/ logMessage("actionMachine: Preconditionning on - waiting for onCommandReturn");
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_start_departure)]);
					_tesla.setDeparture(_vehicle_id, method(:onCommandReturn), value, true);
				}
				break;

			case ACTION_TYPE_TOGGLE_SENTRY:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (_data._vehicle_data.get("vehicle_state").get("sentry_mode")) {
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_sentry_off)]);
					_tesla.SentryMode(_vehicle_id, method(:onCommandReturn), false);
				} else {
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_sentry_on)]);
					_tesla.SentryMode(_vehicle_id, method(:onCommandReturn), true);
				}
				break;

			case ACTION_TYPE_HOMELINK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Homelink - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_homelink)]);
				_tesla.homelink(_vehicle_id, method(:onCommandReturn), _data._vehicle_data.get("drive_state").get("latitude"), _data._vehicle_data.get("drive_state").get("longitude"));
				break;

			case ACTION_TYPE_REMOTE_BOOMBOX:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Remote Boombox - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_remote_boombox)]);
				_tesla.remoteBoombox(_vehicle_id, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLIMATE_MODE:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				var mode_chosen;

				switch (value) {
					case Rez.Strings.label_climate_off:
						mode_chosen = 0;
						break;
					case Rez.Strings.label_climate_on:
						mode_chosen = 1;
						break;
					case Rez.Strings.label_climate_dog:
						mode_chosen = 2;
						break;
					case Rez.Strings.label_climate_camp:
						mode_chosen = 3;
						break;
				}
				//DEBUG*/ logMessage("actionMachine: ClimateMode - setting mode to " + Ui.loadResource(value) + "- calling onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_climate_mode) + Ui.loadResource(value)]);
				_tesla.setClimateMode(_vehicle_id, method(:onCommandReturn), mode_chosen);
				break;

			case ACTION_TYPE_REFRESH:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				_refreshTimeInterval = Storage.getValue("refreshTimeInterval");
				if (_refreshTimeInterval == null) {
					_refreshTimeInterval = 1000;
				}
				//DEBUG*/ logMessage("actionMachine: refreshTimeInterval at " + _refreshTimeInterval + " - not calling a handler");
				_stateMachineCounter = 1;
				break;

			case ACTION_TYPE_DATA_SCREEN:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: viewing DataScreen - not calling a handler");
				onReceive(1); // Show the first submenu
				break;

			default:
				//DEBUG*/ logMessage("actionMachine: WARNING Invalid action");
				_stateMachineCounter = 1;
				break;
		}
	}

	function stateMachine() {
		//DEBUG*/ logMessage("stateMachine:" + (_vehicle_id != null && _vehicle_id > 0 ? "" : " vehicle_id " + _vehicle_id) + " vehicle_state " + _vehicle_state + (_need_auth ? " _need_auth true" : "") + (!_auth_done ? " _auth_done false" : "") + (_check_wake ? " _check_wake true" : "") + (_need_wake ? " _need_wake true" : "") + (!_wake_done ? " _wake_done false" : "") + (_waitingFirstData ? " _waitingFirstData=" + _waitingFirstData : ""));

/*DEBUG
		if (_debug_view) {
			_need_auth = false;
			_auth_done = true;
			_need_wake = false;
			_wake_done = true;
			_408_count = 0;
			_waitingFirstData = 0;
			_stateMachineCounter = 1;
			_handler.invoke([1, -1, null]); // Refresh the screen only if we're not displaying something already that hasn't timed out
			return;
		}*/

		_stateMachineCounter = 0; // So we don't get in if we're alreay in

		var resetNeeded = Storage.getValue("ResetNeeded");
		if (resetNeeded != null && resetNeeded == true) {
			Storage.setValue("ResetNeeded", false);
			_vehicle_id = -1;
			_need_auth = true;
		}

		if (_need_auth) {
			_need_auth = false;

			// Do we have a refresh token? If so, try to use it instead of login in
			var _refreshToken = Settings.getRefreshToken();
			if (_debug_auth == false && _refreshToken != null && _refreshToken.length() != 0) {
				//DEBUG*/ logMessage("stateMachine: auth through refresh token '" + _refreshToken.substring(0,10) + "''... lenght=" + _refreshToken.length());
	    		_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n" + Ui.loadResource(Rez.Strings.label_authenticating_with_token)]);
				GetAccessToken(_refreshToken, method(:onReceiveToken));
			}
			else {
				//DEBUG*/ logMessage("stateMachine: Building an OAUTH2 request");
	        	_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n" + Ui.loadResource(Rez.Strings.label_authenticating_with_login)]);

	            _code_verifier = StringUtil.convertEncodedString(Cryptography.randomBytes(86/2), {
	                :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
	                :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX
	            });
	
	            var code_verifier_bytes = StringUtil.convertEncodedString(_code_verifier, {
	                :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
	                :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY
	            });
	            
	            var hmac = new Cryptography.Hash({ :algorithm => Cryptography.HASH_SHA256 });
				hmac.update(code_verifier_bytes);

	            var code_challenge = StringUtil.convertEncodedString(hmac.digest(), {
	                :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
	                :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64
	            });

				// Need to make code_challenge URL safe. '+' becomes '-', '/' becomes '_' and '=' are skipped
				var cc_array = code_challenge.toCharArray();
				var cc_len = code_challenge.length();
				var code_challenge_fixed = "";

				for (var i = 0; i < cc_len; i++) {
					switch (cc_array[i]) {
						case '+':
							code_challenge_fixed=code_challenge_fixed + '-';
							break;

						case '/':
							code_challenge_fixed=code_challenge_fixed + '_';
							break;

						case '=':
							break;

						default:
							code_challenge_fixed=code_challenge_fixed + cc_array[i].toString();
					}
				}	

	            var params = {
	                "client_id" => "ownerapi",
	                "code_challenge" => code_challenge_fixed,
	                "code_challenge_method" => "S256",
	                "redirect_uri" => "https://" + Properties.getValue("serverAUTHLocation") + "/void/callback",
	                "response_type" => "code",
	                "scope" => "openid email offline_access",
	                "state" => "123"
	            };
				//logMessage("stateMachine: params=" + params);
	            
	            _handler.invoke([3, -1, Ui.loadResource(Rez.Strings.label_login_on_phone)]);

				//DEBUG*/ logMessage("stateMachine: serverAUTHLocation: " + Properties.getValue("serverAUTHLocation"));	
	            Communications.registerForOAuthMessages(method(:onOAuthMessage));
				var url_oauth = "https://" + Properties.getValue("serverAUTHLocation") + "/oauth2/v3/authorize";
				var url_callback = "https://" + Properties.getValue("serverAUTHLocation") + "/void/callback";
	            Communications.makeOAuthRequest(
	                url_oauth,
	                params,
	                url_callback,
	                Communications.OAUTH_RESULT_TYPE_URL,
	                {
	                    "code" => $.OAUTH_CODE,
	                    "responseError" => $.OAUTH_ERROR
	                }
	            );
			}
			return;
		}

		if (!_auth_done) {
			//DEBUG*/ logMessage("StateMachine: WARNING auth NOT done");
			return;
		}

		if (_tesla == null) {
			_tesla = new Tesla(_token);
		}

		if (_vehicle_id == -2) {
            _handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
			_stateMachineCounter = -1;
			_tesla.getVehicleId(method(:onSelectVehicle));
			_vehicle_id = -1;
			return;
		}

		if (_vehicle_id == null || _vehicle_id == -1 || _check_wake) { // -1 means the vehicle ID needs to be refreshed.
			// 2023-03025 logMessage("StateMachine: Getting vehicles, _vehicle_id is " +  (_vehicle_id != null && _vehicle_id > 0 ? "valid" : _vehicle_id) + " _check_wake=" + _check_wake);
			if (_vehicle_id == null) {
	            _handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
			}
			_tesla.getVehicleId(method(:onReceiveVehicles));
			return;
		}

		if (_need_wake) { // Asked to wake up
			if (_waitingFirstData > 0 && !_wakeWasConfirmed) { // Ask if we should wake the vehicle
				//DEBUG*/ logMessage("stateMachine: Asking if OK to wake");
	            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_should_we_wake) + Storage.getValue("vehicle_name") + "?");
				_stateMachineCounter = -1;
	            var delegate = new SimpleConfirmDelegate(method(:wakeConfirmed), method(:wakeCanceled));
	            Ui.pushView(view, delegate, Ui.SLIDE_UP);
			} else {
				//DEBUG*/ logMessage("stateMachine: Waking vehicle");
				_need_wake = false; // Do it only once
				_wake_done = false;
				_tesla.wakeVehicle(_vehicle_id, method(:onReceiveAwake));
			}
			return;
		}

		if (!_wake_done) { // If wake_done is true, we got our 200 in the onReceiveAwake, now it's time to ask for data, otherwise get out and check again
			return;
		}

		// If we've come from a watch face, simulate a upper left quandrant touch hold once we started to get data.
		if (_view._data._ready == true && Storage.getValue("launchedFromComplication") == true) {
			Storage.setValue("launchedFromComplication", false);

			var action = Properties.getValue("holdActionUpperLeft");
			//DEBUG*/ logMessage("stateMachine: Launched from Complication with holdActionUpperLeft at " + action);

			if (action != 0) { // 0 means disable. 
				var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_perform_complication));
				_stateMachineCounter = -1;
				var delegate = new SimpleConfirmDelegate(method(:complicationConfirmed), method(:operationCanceled));
				Ui.pushView(view, delegate, Ui.SLIDE_UP);
				return;
			}
		}

		_lastDataRun = System.getTimer();
		// 2023-03-25 logMessage("StateMachine: getVehicleData");
		_tesla.getVehicleData(_vehicle_id, method(:onReceiveVehicleData));
	}

	function workerTimer() {
		// We're not waiting for a command to return, we're waiting for an action to be performed
		if (_waitingForCommandReturn == false && _pendingActionRequests.size() > 0) {
			// We're not displaying a message on screen and the last webRequest returned responseCode 200, do you thing actionMenu!
			if (_view._data._ready == true && _lastError == null) {
				actionMachine();
			}
			// Call stateMachine as soon as it's out of it (_stateMachineCounter will get modified in onReceiveVehicleData)
			else if (_stateMachineCounter != 0) {
				//_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_waiting_online)]);
				//DEBUG*/ logMessage("actionMachine: Differing, _pendingActionRequests size at " + _pendingActionRequests.size() + " DataViewReady is " + _view._data._ready + " lastError is " + _lastError + " _stateMachineCounter is " + _stateMachineCounter);
				stateMachine();
			}
		}
		// We have no priority tasks to do and no actions waiting
		else {
			// Get the current states of the vehicle if it's time, otherwise we do nothing this time around.
			if (_stateMachineCounter > 0) { 
				if (_stateMachineCounter == 1) {
					stateMachine();
				} else {
					_stateMachineCounter--;
					//logMessage("workerTimer: " + _stateMachineCounter);
				}
			} else {
				//logMessage("workerTimer: " + _stateMachineCounter);
			}
		}

		// If we are still waiting for our first set of data and not at a login prompt or wasking to wake, once we reach 150 iterations of the 0.1sec workTimer (ie, 15 seconds has elapsed since we started)
		if (_waitingFirstData > 0 && _auth_done && _need_wake == false) {
			_waitingFirstData++;
			if (_waitingFirstData % 150 == 0) {
				_handler.invoke([3, 0, Ui.loadResource(Rez.Strings.label_still_waiting_data)]); // Say we're still waiting for data
			}
		}
	}

	function operationCanceled() {
		//DEBUG*/ logMessage("operationCanceled:");
		_stateMachineCounter = 1;
	}

	function complicationConfirmed() {
		//DEBUG*/ logMessage("complicationConfirmed:");
		onHold(true); // Simulate a hold on the top left quadrant
	}

	function wakeConfirmed() {
		_need_wake = false;
		_wake_done = false;
		_wakeWasConfirmed = true;
		gWaitTime = System.getTimer();
		//DEBUG*/ logMessage("wakeConfirmed: Waking the vehicle");

		_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_waking_vehicle)]);

		_tesla.wakeVehicle(_vehicle_id, method(:onReceiveAwake));
	}

	function wakeCanceled() {
		_vehicle_id = -2; // Tells StateMachine to popup a list of vehicles
		gWaitTime = System.getTimer();
		Storage.setValue("launchedFromComplication", false); // If we came from a watchface complication and we canceled the wake, ignore the complication event
		//DEBUG*/ logMessage("wakeCancelled:");
		_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
		_stateMachineCounter = 1;
	}

	function openVentConfirmed() {
		_handler.invoke([Properties.getValue("quickReturn") ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_vent_opening)]);
		//DEBUG*/ logMessage("actionMachine: Open vent - waiting for onCommandReturn");
		_tesla.vent(_vehicle_id, method(:onCommandReturn), "vent", _data._vehicle_data.get("drive_state").get("latitude"), _data._vehicle_data.get("drive_state").get("longitude"));
	}

	function closeVentConfirmed() {
	    _handler.invoke([Properties.getValue("quickReturn") ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_vent_closing)]);
		//DEBUG*/ logMessage("actionMachine: Close vent - waiting for onCommandReturn");
		_tesla.vent(_vehicle_id, method(:onCommandReturn), "close", _data._vehicle_data.get("drive_state").get("latitude"), _data._vehicle_data.get("drive_state").get("longitude"));
	}

	function frunkConfirmed() {
		//DEBUG*/ logMessage("actionMachine: Acting on frunk - waiting for onCommandReturn");
		var hansshowFrunk = Properties.getValue("HansshowFrunk");
		if (hansshowFrunk) {
	        _handler.invoke([Properties.getValue("quickReturn") ? 1 : 2, -1, Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("ft") == 0 ? Rez.Strings.label_frunk_opening : Rez.Strings.label_frunk_closing)]);
			_tesla.openTrunk(_vehicle_id, method(:onCommandReturn), "front");
		} else {
			if (_data._vehicle_data.get("vehicle_state").get("ft") == 0) {
				_handler.invoke([Properties.getValue("quickReturn") ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_frunk_opening)]);
				_tesla.openTrunk(_vehicle_id, method(:onCommandReturn), "front");
			} else {
				_handler.invoke([1, -1, Ui.loadResource(Rez.Strings.label_frunk_opened)]);
	            _stateMachineCounter = 1;
			}
		}
	}

	function trunkConfirmed() {
		//DEBUG*/ logMessage("actionMachine: Acting on trunk - waiting for onCommandReturn");
		_handler.invoke([Properties.getValue("quickReturn") ? 1 : 2, -1, Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("rt") == 0 ? Rez.Strings.label_trunk_opening : Rez.Strings.label_trunk_closing)]);
		_tesla.openTrunk(_vehicle_id, method(:onCommandReturn), "rear");
	}

	function honkHornConfirmed() {
		//DEBUG*/ logMessage("actionMachine: Honking - waiting for onCommandReturn");
		_handler.invoke([Properties.getValue("quickReturn") ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_honk)]);
		_tesla.honkHorn(_vehicle_id, method(:onCommandReturn));
	}

	function onSelect() {
		if (Properties.getValue("useTouch")) {
			return false;
		}

		doSelect();
		return true;
	}

	function doSelect() {
		//DEBUG*/ logMessage("doSelect: climate on/off");
		if (!_data._ready) {
			//DEBUG*/ logMessage("doSelect: WARNING Not ready to do action");
			return;
		}

		if (_data._vehicle_data.get("climate_state").get("is_climate_on") == false) {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_CLIMATE_ON, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		} else {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_CLIMATE_OFF, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		}
	}

	function onNextPage() {
		if (Properties.getValue("useTouch")) {
			return false;
		}

		doNextPage();
		return true;
	}

	function doNextPage() {
		//DEBUG*/ logMessage("doNextPage: lock/unlock");
		if (!_data._ready) {
			//DEBUG*/ logMessage("doNextPage: WARNING Not ready to do action");
			return;
		}

		if (!_data._vehicle_data.get("vehicle_state").get("locked")) {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_LOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		} else {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_UNLOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		}
	}

	function onPreviousPage() {
		if (Properties.getValue("useTouch")) {
			return false;
		}

		doPreviousPage();
		return true;
	}

	function doPreviousPage() {
		//DEBUG*/ logMessage("doPreviousPage: trunk/frunk/port");
		if (!_data._ready) {
			//DEBUG*/ logMessage("doPreviousPage: WARNING Not ready to do action");
			return;
		}

		var drive_state = _data._vehicle_data.get("drive_state");
		if (drive_state != null && drive_state.get("shift_state") != null && drive_state.get("shift_state").equals("P") == false) {
			//DEBUG*/ logMessage("doPreviousPage: Moving, ignoring command");
			return;
		}

		switch (Properties.getValue("swap_frunk_for_port")) {
			case 0:
				var hansshowFrunk = Properties.getValue("HansshowFrunk");
				if (!hansshowFrunk && _data._vehicle_data.get("vehicle_state").get("ft") == 1) {
					_handler.invoke([1, -1, Ui.loadResource(Rez.Strings.label_frunk_opened)]);
			 	}
				else {
					_pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_FRUNK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
				}
				break;

			case 1:
				_pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_TRUNK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
				break;

			case 2:
				_pendingActionRequests.add({"Action" => (_data._vehicle_data.get("charge_state").get("charge_port_door_open") == false ? ACTION_TYPE_OPEN_PORT : ACTION_TYPE_CLOSE_PORT), "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
				break;

			case 3:
				var menu = new Ui.Menu2({:title=>Rez.Strings.menu_label_select});

				if (_data._vehicle_data.get("vehicle_state").get("ft") == 0) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_open_frunk, null, :open_frunk, {}));
				}
				else if (Properties.getValue("HansshowFrunk")) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_close_frunk, null, :open_frunk, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_open_frunk_opened, null, :open_frunk, {}));
				}

				if (_data._vehicle_data.get("vehicle_state").get("rt") == 0) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_open_trunk, null, :open_trunk, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_close_trunk, null, :open_trunk, {}));
				}

				// If the door is closed the only option is to open it.
				if (_data._vehicle_data.get("charge_state").get("charge_port_door_open") == false) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_open_port, null, :open_port, {}));
				}
	
				// Door is opened our options are different if we have a cable inserted or not
				else {
					// Cable not inserted
					if (_data._vehicle_data.get("charge_state").get("charging_state").equals("Disconnected")) { // Close the port
						menu.addItem(new MenuItem(Rez.Strings.menu_label_close_port, null, :close_port, {}));
					}
					// Cable inserted
					else {
						// and charging
						if (_data._vehicle_data.get("charge_state").get("charging_state").equals("Charging")) {
							menu.addItem(new MenuItem(Rez.Strings.menu_label_stop_charging, null, :toggle_charge, {})); // Stop the charge
						}
						// and not charging (we have two options)
						else {
							menu.addItem(new MenuItem(Rez.Strings.menu_label_start_charging, null, :toggle_charge, {})); // Start the charge
							menu.addItem(new MenuItem(Rez.Strings.menu_label_unlock_port, null, :open_port, {})); // Unlock port (open_port unlocks the port if it's not charging)
						}
					}
				}

				var venting = _data._vehicle_data.get("vehicle_state").get("fd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("fp_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rp_window").toNumber();
				menu.addItem(new MenuItem((venting == 0 ? Rez.Strings.menu_label_open_vent : Rez.Strings.menu_label_close_vent), null, :vent, {}));

				Ui.pushView(menu, new TrunksMenuDelegate(self), Ui.SLIDE_UP );
				break;

			default:
				//DEBUG*/ logMessage("doPreviousPage: WARNING swap_frunk_for_port is " + Properties.getValue("swap_frunk_for_port"));
		}
	}

	function onMenu() {
		if (Properties.getValue("useTouch")) {
			return false;
		}

		doMenu();
		return true;
	}

	function addMenuItem(menu, index)
	{
		switch (index.toNumber()) {
			case 1:
		        if (_data._vehicle_data.get("climate_state").get("defrost_mode") == 2) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_defrost_off, null, :defrost, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_defrost_on, null, :defrost, {}));
				}
				break;
			case 2:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_set_seat_heat, null, :set_seat_heat, {}));
				break;
			case 3:
		        if (_data._vehicle_data.get("climate_state").get("steering_wheel_heater") == true) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_set_steering_wheel_heat_off, null, :set_steering_wheel_heat, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_set_steering_wheel_heat_on, null, :set_steering_wheel_heat, {}));
				}
				break;
			case 4:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_set_charging_limit, null, :set_charging_limit, {}));
				break;
			case 5:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_set_charging_amps, null, :set_charging_amps, {}));
				break;
			case 6:
		        if (_data._vehicle_data.get("charge_state").get("charging_state").equals("Charging")) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_stop_charging, null, :toggle_charge, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_start_charging, null, :toggle_charge, {}));
				}
				break;
			case 7:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_set_temp, null, :set_temperature, {}));
				break;
			case 8:
				if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_stop_departure, null, :adjust_departure, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_start_departure, null, :adjust_departure, {}));
				}
				break;
			case 9:
				if (_data._vehicle_data.get("vehicle_state").get("sentry_mode")) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_sentry_off, null, :toggle_sentry, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_sentry_on, null, :toggle_sentry, {}));
				}
				break;
			case 10:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_honk, null, :honk, {}));
				break;
			case 11:
		        if (_data._vehicle_data.get("vehicle_state").get("ft") == 0) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_open_frunk, null, :open_frunk, {}));
				}
				else if (Properties.getValue("HansshowFrunk")) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_close_frunk, null, :open_frunk, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_open_frunk_opened, null, :open_frunk, {}));
				}
				break;
			case 12:
		        if (_data._vehicle_data.get("vehicle_state").get("rt") == 0) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_open_trunk, null, :open_trunk, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_close_trunk, null, :open_trunk, {}));
				}
				break;
			case 13:
				// If the door is closed the only option is to open it.
				if (_data._vehicle_data.get("charge_state").get("charge_port_door_open") == false) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_open_port, null, :open_port, {}));
				}
	
				// Door is opened our options are different if we have a cable inserted or not
				else {
					// Cable not inserted
					if (_data._vehicle_data.get("charge_state").get("charging_state").equals("Disconnected")) { // Close the port
						menu.addItem(new MenuItem(Rez.Strings.menu_label_close_port, null, :close_port, {}));
					}
					// Cable inserted
					else {
						// and charging
						if (_data._vehicle_data.get("charge_state").get("charging_state").equals("Charging")) {
							menu.addItem(new MenuItem(Rez.Strings.menu_label_stop_charging, null, :toggle_charge, {})); // Stop the charge
						}
						// and not charging (we have two options)
						else {
							menu.addItem(new MenuItem(Rez.Strings.menu_label_start_charging, null, :toggle_charge, {})); // Start the charge
							menu.addItem(new MenuItem(Rez.Strings.menu_label_unlock_port, null, :open_port, {})); // Unlock port (open_port unlocks the port if it's not charging)
						}
					}
				}
				break;
			case 14:
				var venting = _data._vehicle_data.get("vehicle_state").get("fd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("fp_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rp_window").toNumber();
				if (venting == 0) {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_open_vent, null, :vent, {}));
				}
				else {
					menu.addItem(new MenuItem(Rez.Strings.menu_label_close_vent, null, :vent, {}));
				}
				break;
			case 15:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_homelink, null, :homelink, {}));
				break;
			case 16:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_toggle_view, null, :toggle_view, {}));
				break;
			case 17:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_swap_frunk_for_port, null, :swap_frunk_for_port, {}));
				break;
			case 18:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_datascreen, null, :data_screen, {}));
				break;
			case 19:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_select_car, null, :select_car, {}));
				break;
			case 20:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_reset, null, :reset, {}));
				break;
			case 21:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_wake, null, :wake, {}));
				break;
			case 22:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_refresh, null, :refresh, {}));
				break;
			case 23:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_remote_boombox, null, :remote_boombox, {}));
				break;
			case 24:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_climate_mode, null, :climate_mode, {}));
				break;
			default:
				//DEBUG*/ logMessage("addMenuItem: Index " + index + " out of range");
				break;
		}
	}
	
	function doMenu() {
		//DEBUG*/ logMessage("doMenu: Menu");
		if (!_data._ready) {
			//DEBUG*/ logMessage("doMenu: WARNING Not ready to do action");
			return;
		}

		var thisMenu = new Ui.Menu2({:title=>Rez.Strings.menu_option_title});
		var menuItems = $.to_array(Properties.getValue("optionMenuOrder"), ",");
		for (var i = 0; i < menuItems.size(); i++) {
			addMenuItem(thisMenu, menuItems[i]);
		}
		
		Ui.pushView(thisMenu, new OptionMenuDelegate(self), Ui.SLIDE_UP );
	}

	function onBack() {
		//DEBUG*/ logMessage("onBack: called");
        Storage.setValue("runBG", true); // Make sure that the background jobs can run when we leave the main view
	}

	function onTap(click) {
		if (!_data._ready)
		{
			return true;
		}

		if (!Storage.getValue("image_view")) { // Touch device on the text screen is limited to show the menu so it can swich back to the image layout
			doMenu();
			return true;
		}

		var coords = click.getCoordinates();
		var x = coords[0];
		var y = coords[1];

		var enhancedTouch = Properties.getValue("enhancedTouch");
		if (enhancedTouch == null) {
			enhancedTouch = true;
		}

		//DEBUG*/ logMessage("onTap: enhancedTouch=" + enhancedTouch + " x=" + x + " y=" + y);
		if (System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_RECTANGLE && _settings.screenWidth < _settings.screenHeight) {
			y = y - ((_settings.screenHeight - _settings.screenWidth) / 2.7).toNumber();
		}

		// Tap on vehicle name
		if (enhancedTouch && y < _settings.screenHeight / 7 && _tesla != null) {
			_stateMachineCounter = -1;
			_tesla.getVehicleId(method(:onSelectVehicle));
		}
		// Tap on the space used by the 'Eye'
		else if (enhancedTouch && y > _settings.screenHeight / 7 && y < (_settings.screenHeight / 3.5).toNumber() && x > _settings.screenWidth / 2 - (_settings.screenWidth / 11).toNumber() && x < _settings.screenWidth / 2 + (_settings.screenWidth / 11).toNumber()) {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_TOGGLE_SENTRY, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		}
		// Tap on the middle text line where Departure is written
		else if (enhancedTouch && y > (_settings.screenHeight / 2.3).toNumber() && y < (_settings.screenHeight / 1.8).toNumber()) {
			var time = _data._vehicle_data.get("charge_state").get("scheduled_departure_time_minutes");
			if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
				_pendingActionRequests.add({"Action" => ACTION_TYPE_ADJUST_DEPARTURE, "Option" => ACTION_OPTION_NONE, "Value" => time, "Tick" => System.getTimer()});
			}
			else {
				Ui.pushView(new DepartureTimePicker(time), new DepartureTimePickerDelegate(self), Ui.SLIDE_IMMEDIATE);
			}
		} 
		// Tap on bottom line on screen
		else if (enhancedTouch && y > (_settings.screenHeight  / 1.25).toNumber() && _tesla != null) {
			var screenBottom = Properties.getValue(x < _settings.screenWidth / 2 ? "screenBottomLeft" : "screenBottomRight");
			switch (screenBottom) {
				case 0:
		        	var charging_limit = _data._vehicle_data.get("charge_state").get("charge_limit_soc");
		            Ui.pushView(new ChargingLimitPicker(charging_limit), new ChargingLimitPickerDelegate(self), Ui.SLIDE_UP);
		            break;
		        case 1:
		        	var max_amps = _data._vehicle_data.get("charge_state").get("charge_current_request_max");
		            var charging_amps = _data._vehicle_data.get("charge_state").get("charge_current_request");
		            if (charging_amps == null) {
		            	if (max_amps == null) {
		            		charging_amps = 32;
		            	}
		            	else {
		            		charging_amps = max_amps;
		            	}
		            }
		            
		            Ui.pushView(new ChargerPicker(charging_amps, max_amps), new ChargerPickerDelegate(self), Ui.SLIDE_UP);
		            break;
		        case 2:
		            var driver_temp = _data._vehicle_data.get("climate_state").get("driver_temp_setting");
		            var max_temp =    _data._vehicle_data.get("climate_state").get("max_avail_temp");
		            var min_temp =    _data._vehicle_data.get("climate_state").get("min_avail_temp");
		            
		            if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
		            	driver_temp = driver_temp * 9.0 / 5.0 + 32.0;
		            	max_temp = max_temp * 9.0 / 5.0 + 32.0;
		            	min_temp = min_temp * 9.0 / 5.0 + 32.0;
		            }

		            Ui.pushView(new TemperaturePicker(driver_temp, max_temp, min_temp), new TemperaturePickerDelegate(self), Ui.SLIDE_UP);
					break;
			}
		}
		else if (x < _settings.screenWidth/2) {
			if (y < _settings.screenHeight/2) {
				doPreviousPage();
			} else {
				doNextPage();
			}
		} else {
			if (y < _settings.screenHeight/2) {
				doSelect();
			} else {
				doMenu();
			}
		}

		return true;
	}

	function onHold(click) {
		if (!_data._ready)
		{
			return true;
		}
		
		var drive_state = _data._vehicle_data.get("drive_state");
		if (drive_state != null && drive_state.get("shift_state") != null && drive_state.get("shift_state").equals("P") == false) {
			//DEBUG*/ logMessage("doPreviousPage: Moving, ignoring command");
			return;
		}

		var x;
		var y;

		if (click instanceof Lang.Boolean) {
			x = 0;
			y = 0;
		}
		else {
			var coords = click.getCoordinates();
			x = coords[0];
			y = coords[1];
		}

		var vibrate = true;

		if (x < _settings.screenWidth/2) {
			if (y < _settings.screenHeight/2) {
				//DEBUG*/ logMessage("onHold: Upper Left");
				switch (Properties.getValue("holdActionUpperLeft")) {
					case 0:
						vibrate = false;
						break;

					case 1:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_FRUNK, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
						break;

					case 2:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_TRUNK, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
						break;

					case 3:
						if (_data._vehicle_data.get("charge_state").get("charge_port_door_open") == false) {
							_pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_PORT, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						} else if (_data._vehicle_data.get("charge_state").get("charging_state").equals("Disconnected")) {
							_pendingActionRequests.add({"Action" => ACTION_TYPE_CLOSE_PORT, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						} else if (_data._vehicle_data.get("charge_state").get("charging_state").equals("Charging")) {
							_pendingActionRequests.add({"Action" => ACTION_TYPE_TOGGLE_CHARGE, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						} else {
							_pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_PORT, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						}
						break;

					case 4:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_VENT, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
						break;

					default:
						//DEBUG*/ logMessage("onHold: Upper Left WARNING Invalid");
						break;
				}
			} else {
				//DEBUG*/ logMessage("onHold: Lower Left");
				switch (Properties.getValue("holdActionLowerLeft")) {
					case 0:
						vibrate = false;
						break;

					case 1:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_HONK, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
						break;

					default:
						//DEBUG*/ logMessage("onHold: Lower Left WARNING Invalid");
						break;
				}
			}
		} else {
			if (y < _settings.screenHeight/2) {
				//DEBUG*/ logMessage("onHold: Upper Right");
				switch (Properties.getValue("holdActionUpperRight")) {
					case 0:
						vibrate = false;
						break;

					case 1:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_CLIMATE_DEFROST, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						break;

					default:
						//DEBUG*/ logMessage("onHold: Upper Right WARNING Invalid");
						break;
				}
			} else {
				//DEBUG*/ logMessage("onHold: Lower Right");
				switch (Properties.getValue("holdActionLowerRight")) {
					case 0:
						vibrate = false;
						break;

					case 1:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_HOMELINK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						break;

					case 2:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_REMOTE_BOOMBOX, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						break;

					default:
						//DEBUG*/ logMessage("onHold: Lower Right WARNING Invalid");
						break;
				}
			}
		}

		if (Attention has :vibrate && vibrate == true) {
			var vibeData = [ new Attention.VibeProfile(50, 200) ]; // On for half a second
			Attention.vibrate(vibeData);				
		}

		return true;
	}

	function onSelectVehicle(responseCode, data) {
		//DEBUG*/ logMessage("onSelectVehicle: " + responseCode);

		if (responseCode == 200) {
			var vehicles = data.get("response");
			var size = vehicles.size();
			var vinsName = new [size];
			var vinsId = new [size];
			for (var i = 0; i < size; i++) {
				vinsName[i] = vehicles[i].get("display_name");
				vinsId[i] = vehicles[i].get("id");
			}
			Ui.pushView(new CarPicker(vinsName), new CarPickerDelegate(vinsName, vinsId, self), Ui.SLIDE_UP);
		} else {
			_handler.invoke([0, -1, buildErrorString(responseCode)]);
			_stateMachineCounter = 1;
		}
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

					if (vehicle_index == size) {
						vehicle_index = 0;
					}
				}

				_vehicle_state = vehicles[vehicle_index].get("state");
				// 2022-10-17 logMessage("onReceiveVehicles: Vehicle '" + vehicles[vehicle_index].get("display_name") + "' (" + _vehicle_id + ") state is '" + _vehicle_state + "'");
				if (_vehicle_state.equals("online") == false && _vehicle_id != null && _vehicle_id > 0) { // We're not awake and we have a vehicle ID, next iteration of StateMachine will call the wake function
					_need_wake = true;
					_wake_done = false;
				}
				_check_wake = false;

				_vehicle_id = vehicles[vehicle_index].get("id");
				Storage.setValue("vehicle", _vehicle_id);
				Storage.setValue("vehicle_name", vehicles[vehicle_index].get("display_name"));

				_stateMachineCounter = 1;
				return;
			} else {
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_no_vehicles)]);
			}
		} else {
			if (responseCode == 401) {
				// Unauthorized
				_resetToken();
	            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
			} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke([0, -1, buildErrorString(responseCode)]);
	        }

		}
		_stateMachineCounter = 1;
	}

	function onReceiveVehicleData(responseCode, data) {
		//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);

		SpinSpinner(responseCode);

		if (_stateMachineCounter < 0) {
			//DEBUG*/ if (_stateMachineCounter == -3) { logMessage("onReceiveVehicleData: skipping, actionMachine running"); }
			//DEBUG*/ if (_stateMachineCounter == -2) { logMessage("onReceiveVehicleData: WARNING skipping again because of the menu?"); }
			if (_stateMachineCounter == -1) { 
				//DEBUG*/ logMessage("onReceiveVehicleData: skipping, we're in a menu");
				 _stateMachineCounter = -2; // Let the menu blocking us know that we missed data
			}
			return;
		}

		if (responseCode == 200) {
			_lastError = null;
			_vehicle_state = "online"; // We got data so we got to be online

			// Check if this data feed is older than the previous one and if so, ignore it (two timers could create this situation)
			var response = data.get("response");
			if (response != null && response.hasKey("charge_state") && response.get("charge_state").hasKey("timestamp") && response.get("charge_state").get("timestamp") > _lastTimeStamp) {
				_data._vehicle_data = response;
				_lastTimeStamp = response.get("charge_state").get("timestamp");
				// logMessage("onReceiveVehicleData: received " + _data._vehicle_data);
				if (_data._vehicle_data.get("climate_state").hasKey("inside_temp") && _data._vehicle_data.get("charge_state").hasKey("battery_level")) {
					if (_waitingForCommandReturn) {
						_handler.invoke([0, -1, null]); // We received the status of our command, show the main screen right away
						_stateMachineCounter = 1;
					}
					else {
						_handler.invoke([1, -1, null]); // Refresh the screen only if we're not displaying something already that hasn't timed out
					}

					// Update the glance data
					if (System.getDeviceSettings() has :isGlanceModeEnabled && System.getDeviceSettings().isGlanceModeEnabled) { // If we have a glance view, update its status
						var status = {};

						status.put("responseCode", responseCode);

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
						} catch (e) {
							timestamp = "";
						}
						status.put("timestamp", timestamp);

						status.put("battery_level", $.validateNumber(response.get("charge_state").get("battery_level")));
						status.put("battery_range", $.validateNumber(response.get("charge_state").get("battery_range")));
						status.put("charging_state", $.validateString(response.get("charge_state").get("charging_state")));
						status.put("inside_temp", $.validateNumber(response.get("climate_state").get("inside_temp")));
						status.put("shift_state", $.validateString(response.get("drive_state").get("shift_state")));
						status.put("sentry", $.validateBoolean(response.get("vehicle_state").get("sentry_mode")));
						status.put("preconditioning", $.validateBoolean(response.get("charge_state").get("preconditioning_enabled")));

						Storage.setValue("status", status);

						//2023-03-03 logMessage("onReceiveVehicleData: set status to '" + Storage.getValue("status") + "'");
					}

					if (_408_count) {
						 //DEBUG*/ logMessage("onReceiveVehicleData: clearing _408_count");
						_408_count = 0; // Reset the count of timeouts since we got our data
					}

					if (_waitingFirstData > 0) { // We got our first responseCode 200 since launching
						_waitingFirstData = 0;
						if (!_wakeWasConfirmed) { // And we haven't asked to wake the vehicle, so it was already awoken when we got in, so send a gratious wake command ao we stay awake for the app running time
							//DEBUG*/ logMessage("onReceiveVehicleData: sending gratious wake");
							_need_wake = false;
							_wake_done = false;
							_waitingForCommandReturn = false;
							_stateMachineCounter = 1; // Make sure we check on the next workerTimer
							_tesla.wakeVehicle(_vehicle_id, method(:onReceiveAwake)); // 
							return;
						}
					}

					if (_waitingForCommandReturn) {
						_stateMachineCounter = 1;
						_waitingForCommandReturn = false;
					}
					else {
						var timeDelta = System.getTimer() - _lastDataRun; // Substract the time we spent waiting from the time interval we should run
						// 2022-05-21 logMessage("onReceiveVehicleData: timeDelta is " + timeDelta);
						timeDelta = _refreshTimeInterval - timeDelta;
						if (timeDelta > 500) { // Make sure we leave at least 0.5 sec between calls
							_stateMachineCounter = (timeDelta / 100).toNumber();
							// 2023-03-25 logMessage("onReceiveVehicleData: Next StateMachine in " + _stateMachineCounter + " 100msec cycles");
							return;
						} else {
							// 2023-03-25 logMessage("onReceiveVehicleData: Next StateMachine min is 500 msec");
						}
					}
				} else {
					//DEBUG*/ logMessage("onReceiveVehicleData: WARNING Received incomplete data, ignoring");
				}
			} else {
				//DEBUG*/ logMessage("onReceiveVehicleData: WARNING Received an out or order data or missing timestamp, ignoring");
			}
			_stateMachineCounter = 5;
			return;
		} else {
			_lastError = responseCode;

			if (_waitingFirstData > 0) { // Reset that counter if what we got was an error packet. We're interested in gap between packets received.
				_waitingFirstData = 1;
			}

			if (responseCode == 408) { // We got a timeout, check if we're still awake
				// Comemnted out. Don't mess with the glance data if we get a 408 here. Chances are we're not asleep but can't talk to the vehicle for some reason
				/*if (System.getDeviceSettings() has :isGlanceModeEnabled && System.getDeviceSettings().isGlanceModeEnabled) { // If we have a glance view, update its status
					var timestamp;
					try {
						var clock_time = System.getClockTime();
						timestamp = " @ " + clock_time.hour.format("%d")+ ":" + clock_time.min.format("%02d");
					} catch (e) {
						timestamp = "";
					}
					Storage.setValue("status", Ui.loadResource(Rez.Strings.label_asleep) + timestamp);
				}*/

				var i = _408_count + 1;
				//DEBUG*/ logMessage("onReceiveVehicleData: 408_count=" + i + " _waitingFirstData=" + _waitingFirstData);
				if (_waitingFirstData > 0 && _view._data._ready == false) { // We haven't received any data yet and we have already a message displayed
					_handler.invoke([3, i, Ui.loadResource(_vehicle_state.equals("online") == true ? Rez.Strings.label_requesting_data : Rez.Strings.label_waking_vehicle)]);
				}

	        	if ((_408_count % 10 == 0 && _waitingFirstData > 0) || (_408_count % 10 == 1 && _waitingFirstData == 0)) { // First (if we've starting up), and every consecutive 10th 408 recieved (skipping a spurious 408 when we aren't started up) will generate a test for the vehicle state. 
					if (_408_count < 2 && _waitingFirstData == 0) { // Only when we first started to get the errors do we keep the start time, unless we've started because our start time has been recorded already
						gWaitTime = System.getTimer();
					}
					// 2022-10-10 logMessage("onReceiveVehicleData: Got 408, Check if we need to wake up the car?");
					_check_wake = true;
	            }
				_408_count++;
			} else {
				if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
					_vehicle_id = -2;
		            _handler.invoke([0, -1, buildErrorString(responseCode)]);
				} else if (responseCode == 401) {
	                // Unauthorized, retry
	                _need_auth = true;
	                _resetToken();
		            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
				} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
		            _handler.invoke([0, -1, buildErrorString(responseCode)]);
		        }
			}
	    }
		_stateMachineCounter = 5;
	}

	function onReceiveAwake(responseCode, data) {
		//DEBUG*/ logMessage("onReceiveAwake: " + responseCode);

		if (responseCode == 200) {
			_wake_done = true;
	   } else {
		   // We were unable to wake, try again
			_need_wake = true;
			_wake_done = false;
			if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
				_vehicle_id = -2;
				_handler.invoke([0, -1, buildErrorString(responseCode)]);
			} else if (responseCode == 401) { // Unauthorized, retry
				_resetToken();
				_need_auth = true;
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
			} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
				_handler.invoke([0, -1, buildErrorString(responseCode)]);
			}
		}
		_stateMachineCounter = 1;
	}

	function onCommandReturn(responseCode, data) {
		SpinSpinner(responseCode);

		if (responseCode == 200) {
			if (Properties.getValue("quickReturn")) {
				//DEBUG*/ logMessage("onCommandReturn: " + responseCode + " running StateMachine in 100msec");
				_stateMachineCounter = 1;
			} else {
				// Wait a second to let time for the command change to be recorded on Tesla's server
				//DEBUG*/ logMessage("onCommandReturn: " + responseCode + " running StateMachine in 1 sec");
				_stateMachineCounter = 10;
				_waitingForCommandReturn = true;
			}
		} else { // Our call failed, say the error and back to the main code
			//DEBUG*/ logMessage("onCommandReturn: " + responseCode + " running StateMachine in 100msec");
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + buildErrorString(responseCode)]);
			_stateMachineCounter = 1;
		}
	}

	function revokeHandler(responseCode, data) {
		SpinSpinner(responseCode);

		//DEBUG*/ logMessage("revokeHandler: " + responseCode + " running StateMachine in 100msec");
		if (responseCode == 200) {
            _resetToken();
            Settings.setRefreshToken(null);
            Storage.setValue("vehicle", null);
			Storage.setValue("ResetNeeded", true);
			_handler.invoke([0, -1, null]);
		} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + buildErrorString(responseCode)]);
		}

		_stateMachineCounter = 1;
	}

	function buildErrorString(responseCode) {
		if (responseCode == null || errorsStr[responseCode.toString()] == null) {
			return(Ui.loadResource(Rez.Strings.label_error) + responseCode);
		}
		else {
			return(Ui.loadResource(Rez.Strings.label_error) + responseCode + "\n" + errorsStr[responseCode.toString()]);
		}
	}

	function _saveToken(token, expires_in, created_at) {
		_token = token;
		_auth_done = true;
		Settings.setToken(token, expires_in, created_at);
	}

	function _resetToken() {
		//DEBUG*/ logMessage("_resetToken: Reseting tokens");
		_token = null;
		_auth_done = false;
		Settings.setToken(null, 0, 0);
	}

	var errorsStr = {
		"0" => "UNKNOWN_ERROR",
		"-1" => "BLE_ERROR",
		"-2" => "BLE_HOST_TIMEOUT",
		"-3" => "BLE_SERVER_TIMEOUT",
		"-4" => "BLE_NO_DATA",
		"-5" => "BLE_REQUEST_CANCELLED",
		"-101" => "BLE_QUEUE_FULL",
		"-102" => "BLE_REQUEST_TOO_LARGE",
		"-103" => "BLE_UNKNOWN_SEND_ERROR",
		"-104" => "BLE_CONNECTION_UNAVAILABLE",
		"-200" => "INVALID_HTTP_HEADER_FIELDS_IN_REQUEST",
		"-201" => "INVALID_HTTP_BODY_IN_REQUEST",
		"-202" => "INVALID_HTTP_METHOD_IN_REQUEST",
		"-300" => "NETWORK_REQUEST_TIMED_OUT",
		"-400" => "INVALID_HTTP_BODY_IN_NETWORK_RESPONSE",
		"-401" => "INVALID_HTTP_HEADER_FIELDS_IN_NETWORK_RESPONSE",
		"-402" => "NETWORK_RESPONSE_TOO_LARGE",
		"-403" => "NETWORK_RESPONSE_OUT_OF_MEMORY",
		"-1000" => "STORAGE_FULL",
		"-1001" => "SECURE_CONNECTION_REQUIRED",
		"-1002" => "UNSUPPORTED_CONTENT_TYPE_IN_RESPONSE",
		"-1003" => "REQUEST_CANCELLED",
		"-1004" => "REQUEST_CONNECTION_DROPPED",
		"-1005" => "UNABLE_TO_PROCESS_MEDIA",
		"-1006" => "UNABLE_TO_PROCESS_IMAGE",
		"-1007" => "UNABLE_TO_PROCESS_HLS",
		"400" => "Bad_Request",
		"401" => "Unauthorized",
		"402" => "Payment_Required",
		"403" => "Forbidden",
		"404" => "Not_Found",
		"405" => "Method_Not_Allowed",
		"406" => "Not_Acceptable",
		"407" => "Proxy_Authentication_Required",
		"408" => "Request_Timeout",
		"409" => "Conflict",
		"410" => "Gone",
		"411" => "Length_Required",
		"412" => "Precondition_Failed",
		"413" => "Request_Too_Large",
		"414" => "Request-URI_Too_Long",
		"415" => "Unsupported_Media_Type",
		"416" => "Range_Not_Satisfiable",
		"417" => "Expectation_Failed",
		"500" => "Internal_Server_Error",
		"501" => "Not_Implemented",
		"502" => "Bad_Gateway",
		"503" => "Service_Unavailable",
		"504" => "Gateway_Timeout",
		"505" => "HTTP_Version_Not_Supported",
		"511" => "Network_Authentication_Required",
		"540" => "Vehicle_Server_Error"
	};
}