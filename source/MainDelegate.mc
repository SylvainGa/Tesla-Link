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
	ACTION_OPTION_NONE =                0,
	ACTION_OPTION_BYPASS_CONFIRMATION = 1,
	ACTION_OPTION_SEAT_DRIVER =         2,
	ACTION_OPTION_SEAT_PASSENGER =      3,
	ACTION_OPTION_SEAT_REAR_DRIVER =    4,
	ACTION_OPTION_SEAT_REAR_CENTER =    5,
	ACTION_OPTION_SEAT_REAR_PASSENGER = 6,
	ACTION_OPTION_MEDIA_PLAY_TOGGLE =   7,
	ACTION_OPTION_MEDIA_PREV_SONG =     8,
	ACTION_OPTION_MEDIA_NEXT_SONG =     9,
	ACTION_OPTION_MEDIA_VOLUME_DOWN =  10,
	ACTION_OPTION_MEDIA_VOLUME_UP =    11
}

enum /* ACTION_TYPES */ {
	ACTION_TYPE_RESET =                    0,
	ACTION_TYPE_HONK =                     1,
	ACTION_TYPE_SELECT_CAR =               2, // Done in OptionMenu, not ActionMachine
	ACTION_TYPE_OPEN_PORT =                3,
	ACTION_TYPE_CLOSE_PORT =               4,
	ACTION_TYPE_OPEN_FRUNK =               5,
	ACTION_TYPE_OPEN_TRUNK =               6,
	ACTION_TYPE_TOGGLE_VIEW =              7, // Done in OptionMenu, not ActionMachine
	ACTION_TYPE_SWAP_FRUNK_FOR_PORT =      8, // Done in OptionMenu, not ActionMachine
	ACTION_TYPE_SET_CHARGING_AMPS =        9,
	ACTION_TYPE_SET_CHARGING_LIMIT =      10,
	ACTION_TYPE_SET_SEAT_HEAT =           11,
	ACTION_TYPE_SET_STEERING_WHEEL_HEAT = 12,
	ACTION_TYPE_VENT =                    13,
	ACTION_TYPE_TOGGLE_CHARGE =           14,
	ACTION_TYPE_ADJUST_DEPARTURE =        15,
	ACTION_TYPE_TOGGLE_SENTRY =           16,
	ACTION_TYPE_WAKE =                    17, // Done in OptionMenu, not ActionMachine
	ACTION_TYPE_REFRESH =                 18,
	ACTION_TYPE_DATA_SCREEN =             19,
	ACTION_TYPE_HOMELINK =                20,
	ACTION_TYPE_REMOTE_BOOMBOX =          21,
	ACTION_TYPE_CLIMATE_MODE =            22,
	ACTION_TYPE_CLIMATE_DEFROST =         23,
	ACTION_TYPE_CLIMATE_SET =             24,
	ACTION_TYPE_MEDIA_CONTROL =           25,
	ACTION_TYPE_DOGMODE_WATCH =           26,
	// Following are through buttons or touch screen input
	ACTION_TYPE_CLIMATE_ON =              27,
	ACTION_TYPE_CLIMATE_OFF =             28,
	ACTION_TYPE_LOCK =                    29, // (from Complication call also)
	ACTION_TYPE_UNLOCK =                  30  // (from Complication call also)
}

enum { /* Wake state */
	WAKE_NEEDED =   0,
	WAKE_TEST =     1,
	WAKE_SENT =     2,
	WAKE_RECEIVED = 3,
	WAKE_WAITING =  4,
	WAKE_RETEST =   5,
	WAKE_UNKNOWN =  6,
	WAKE_OFFLINE =  7,
	WAKE_ONLINE =   8
}

enum { /* Which API */
	API_NO_TOKEN =    -2,
	API_NEED_CONFIG = -1,
	API_TESLA =        0,
	API_TESSIE =       1,
	API_TESLEMETRY =   2
}

enum { /* v_ehicle_id type */
	VEHICLE_ID_NEED_LIST =  -2,
	VEHICLE_ID_NEED_ID =    -1,
	VEHICLE_ID_VALID_ID =    0
}

enum { /* _check_wake option */
	CHECK_WAKE_NO_CHECK = 0,
	CHECK_WAKE_CHECK_SILENT = 1,
	CHECK_WAKE_CHECK_AND_WAKE = 2,
}
/* _stateMachineCounter DEFINITION
-3 In onReceiveVehicleData, means actionMachine is running so ignore the data received
-2 In onReceiveVehicleData, means as we're in a menu (flagged by -1), we got a SECOND vehicleData, should NOT happen
-1 In onReceiveVehicleData, means we're in a menu and to ignore the data we just received
0 In stateMachine, means not to run
1 In stateMachine, it's time call getVehicleData
2 and above, we wait until we get to 1. Decremented every 100 msecond
*/

class MainDelegate extends Ui.BehaviorDelegate {
	var _view as MainView;
	var _subView;
	var _settings;
	var _handler;
	var _tesla;
	var _data;
	var _token;
	var _useTeslaAPI;
	var _code_verifier;
	var _workTimer;
	var _vehicle_id;
	var _vehicle_vin;
	var _vehicle_state;
	var _need_auth;
	var _auth_done;
	var _check_wake;
	var _wake_state;
	var _in_menu;
	var _waitingFirstData;
	var _wakeWasConfirmed;
	var _refreshTimeInterval;
	var _408_count;
	var _lastError;
	var _lastTimeStamp;
	var _lastDataRun;
	var _waitingForCommandReturn;
	var _useTouch;
	var _subViewCounter;
	var _subViewExitCounter;
	var _debug_auth;
	var _debug_view;
	// 2023-03-20 var _debugTimer;

	var _pendingActionRequests;
	var _stateMachineCounter;
	var _serverAUTHLocation;

	function initialize(view as MainView, data, handler) {
		BehaviorDelegate.initialize();
	
		//DEBUG*/ logMessage("initialize:Starting up");

		_view = view;
		_handler = handler;
		_data = data;

		settingsChanged(true);

		_vehicle_state = "online"; // Assume we're online so we try to display our data asap
		_data._vehicle_state = _vehicle_state;
		_workTimer = new Timer.Timer();
		_waitingForCommandReturn = false;

		// _debugTimer = System.getTimer(); Storage.setValue("overrideCode", 0);

		_check_wake = CHECK_WAKE_NO_CHECK; // If we get a 408 on first try or after 20 consecutive 408, see if we should wake up again 
		_wake_state = WAKE_UNKNOWN; // We don't know the state of our waken status yet. Once we show our data screen, go get it
		_in_menu = false;
		gWaitTime = System.getTimer();
		_waitingFirstData = 1; // So the Waking up is displayed right away if it's the first time
		_wakeWasConfirmed = false; // So we only display the Asking to wake only once

		_408_count = 0;
		_lastError = null;
		_lastTimeStamp = 0;
		_subViewCounter = 0;
		_subViewExitCounter = 0;

		_pendingActionRequests = [];
		_stateMachineCounter = 0;
		_lastDataRun = System.getTimer();

		// This is where the main code will start running. Don't intialise stuff after this line
		//DEBUG*/ logMessage("initialize: quickAccess=" + $.getProperty("quickReturn", false, method(:validateBoolean)) + " enhancedTouch=" + $.getProperty("enhancedTouch", true, method(:validateBoolean)));
		_workTimer.start(method(:workerTimer), 100, true);

		stateMachine(); // Launch getting the states right away.
	}

	function settingsChanged(fromInit) {
		_serverAUTHLocation = $.getProperty("serverAUTHLocation", "auth.tesla.com", method(:validateString));
		_settings = System.getDeviceSettings();
		if ($.getProperty("whichAPI", 0, method(:validateNumber)) != API_TESLA) {
			_useTeslaAPI = false;
			_vehicle_id = Storage.getValue("vehicle");
			_vehicle_vin = Storage.getValue("vehicleVIN");
			_token = Settings.getRefreshToken();
			if (_token == null || _token.length() == 0) {
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_no_token)]);
			}
			Settings.setToken(_token, 0, 0);
			
			_need_auth = false;
			_auth_done = true;

			//DEBUG*/ if (fromInit) { logMessage("initialize:Using teslemetry or Tessie"); } else { logMessage("settingsChanged:Using teslemetry or Tessie"); }
		}
		else {
			//DEBUG*/ if (fromInit) { logMessage("initialize:Using Tesla API"); } else { logMessage("settingsChanged:Using Tesla API"); }
			_useTeslaAPI = true;
			_vehicle_id = Storage.getValue("vehicle");
			_vehicle_vin = _vehicle_id; // Teslemetry needs a VIN to talk to cars, but Tesla's API need the vehicle_id. 
			_token = Settings.getToken();

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
			var not_expired = (timeNow + interval < createdAt + expireIn);

			_debug_auth = false;
			if (_debug_auth == false && _token != null && _token.length() > 0 && not_expired == true ) {
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
		}

		_useTouch = $.getProperty("useTouch", true, method(:validateBoolean));

		if ($.getProperty("enhancedTouch", true, method(:validateBoolean))) {
			Storage.setValue("spinner", "+");
		}
		else {
			Storage.setValue("spinner", "/");
		}
		
		_refreshTimeInterval = Storage.getValue("refreshTimeInterval");
		if (_refreshTimeInterval == null || _refreshTimeInterval.toNumber() < 500) {
			_refreshTimeInterval = 4000;
		}

		if (_token == null) {
			_tesla = null;
		}
		else {
			_tesla = new Tesla(_token);
		}
	}

	function onReceive(args) {
		if (args == 0) { // The sub page ended and sent us a _handler.invoke(0) call, display our main view
			//logMessage("StateMachine: onReceive");
			_stateMachineCounter = 1; // 0.1 second
		}
		else if (args == 1) { // Swiped left from main screen, show subview 1
			var view = new ChargeView(_view._data);
			_subView = view;
			var delegate = new ChargeDelegate(view, self, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else if (args == 2) { // Swiped left on subview 1, show subview 2
			var view = new ClimateView(_view._data);
			_subView = view;
			var delegate = new ClimateDelegate(view, self, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else if (args == 3) { // Swiped left on subview 2, show subview 3
			var view = new DriveView(_view._data);
			_subView = view;
			var delegate = new DriveDelegate(view, self, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else { // Swiped left on subview 3, we're back at the main display
			_stateMachineCounter = 1; // 0.1 second
			_subView = null;
		}
	    Ui.requestUpdate();
	}

	function onSwipe(swipeEvent) {
		if (_view._data._ready) { // Don't handle swipe if where not showing the data screen
	    	if (swipeEvent.getDirection() == WatchUi.SWIPE_LEFT) {
				onReceive(1); // Show the first submenu
		    }
	    	if (swipeEvent.getDirection() == WatchUi.SWIPE_UP) {
				var view = new MediaControlView();
				var delegate = new MediaControlDelegate(view, self, _stateMachineCounter, view.method(:onReceive));
				Ui.pushView(view, delegate, Ui.SLIDE_UP);
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
			var codeForBearerUrl = "https://" + _serverAUTHLocation + "/oauth2/v3/token";
			var codeForBearerParams = {
				"grant_type" => "authorization_code",
				"client_id" => "ownerapi",
				"code" => code,
				"code_verifier" => _code_verifier,
				"redirect_uri" => "https://" + _serverAUTHLocation + "/void/callback"
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
			_stateMachineCounter = 1; // 0.1 second
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

			//DEBUG 2023-10-02*/ var expireAt = new Time.Moment(created_at + expires_in);
			//DEBUG 2023-10-02*/ var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
			//DEBUG 2023-10-02*/ var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");

			if (refreshToken != null && refreshToken.equals("") == false) { // Only if we received a refresh tokem
				if (accessToken != null) {
					//DEBUG*/ logMessage("onReceiveToken: refresh token=" + refreshToken.substring(0,10) + "... lenght=" + refreshToken.length() + " access token=" + accessToken.substring(0,10) + "... lenght=" + accessToken.length() + " which expires at " + dateStr);
				} else {
					//DEBUG 2023-10-02*/ logMessage("onReceiveToken: refresh token=" + refreshToken.substring(0,10) + "... lenght=" + refreshToken.length() + "+ NO ACCESS TOKEN");
				}
				Settings.setRefreshToken(refreshToken);
			}
			else {
				//DEBUG 2023-10-02*/ logMessage("onReceiveToken: WARNING - NO REFRESH TOKEN but got an access token: " + accessToken.substring(0,20) + "... lenght=" + accessToken.length() + " which expires at " + dateStr);
			}
		}
		else {
			//DEBUG 2023-10-02*/ logMessage("onReceiveToken: couldn't get tokens, clearing refresh token");
			// Couldn't refresh our access token through the refresh token, invalide it and try again (through username and password instead since our refresh token is now empty
			_need_auth = true;
			_auth_done = false;

			Settings.setRefreshToken(null);

			if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
	            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
				_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down! 10 seconds delay
				return;
			}

			_handler.invoke([0, -1, buildErrorString(responseCode)]);
	    }

		_stateMachineCounter = 1; // 0.1 second
	}

	function GetAccessToken(token, notify) {
		var url = "https://" + _serverAUTHLocation + "/oauth2/v3/token";
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
				if ($.getProperty("enhancedTouch", true, method(:validateBoolean))) {
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
		//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is " + _pendingActionRequests.size() + " _vehicle_vin=" + (_vehicle_vin != null && _vehicle_vin.length() > 0 ? "valid" : _vehicle_vin) + " _vehicle_id=" +  (_vehicle_id != null && _vehicle_id > 0 ? "valid" : _vehicle_id) + " _check_wake=" + _check_wake + " _wake_state=" + _wake_state + (_waitingFirstData ? " _waitingFirstData=" + _waitingFirstData : ""));

		// Sanity check
		if (_pendingActionRequests.size() <= 0) {
			//DEBUG 2023-10-02*/ logMessage("actionMachine: WARNING _pendingActionSize can't be less than 1 if we're here");
			return;
		}

		var request = _pendingActionRequests[0];

		//DEBUG*/ logMessage("actionMachine: _pendingActionRequests[0] is " + request);

		// Sanity check
		if (request == null) {
			//DEBUG 2023-10-02*/ logMessage("actionMachine: WARNING the request shouldn't be null");
			return;
		}

		var action = request.get("Action");
		var option = request.get("Option");
		var value = request.get("Value");
		//var tick = request.get("Tick");

		_pendingActionRequests.remove(request);

		_stateMachineCounter = -3; // Don't bother us with getting states when we do our things

		var _handlerType;
		if ($.getProperty("quickReturn", false, method(:validateBoolean))) {
			_handlerType = 1;
		}
		else {
			_handlerType = 2;
		}

		var view;
		var delegate;

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
				_tesla.climateOn(_vehicle_vin, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLIMATE_OFF:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Climate Off - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_hvac_off)]);
				_tesla.climateOff(_vehicle_vin, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLIMATE_DEFROST:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Climate Defrost - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(_data._vehicle_data.get("climate_state").get("defrost_mode") == 2 ? Rez.Strings.label_defrost_off : Rez.Strings.label_defrost_on)]);
				_tesla.climateDefrost(_vehicle_vin, method(:onCommandReturn), _data._vehicle_data.get("climate_state").get("defrost_mode"));
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
				_tesla.climateSet(_vehicle_vin, method(:onCommandReturn), temperature);
				break;

			case ACTION_TYPE_MEDIA_CONTROL:
				//DEBUG 2023-10-02*/ logMessage("actionMachine: Media control - Shouldn't get there!");
				break;

			case ACTION_TYPE_TOGGLE_CHARGE:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Toggling charging - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(_data._vehicle_data.get("charge_state").get("charging_state").equals("Charging") ? Rez.Strings.label_stop_charging : Rez.Strings.label_start_charging)]);
				_tesla.toggleCharging(_vehicle_vin, method(:onCommandReturn), _data._vehicle_data.get("charge_state").get("charging_state").equals("Charging"));
				break;

			case ACTION_TYPE_SET_CHARGING_LIMIT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Setting charge limit - waiting for onCommandReturn");
				var charging_limit = value;
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_charging_limit) + charging_limit + "%"]);
				_tesla.setChargingLimit(_vehicle_vin, method(:onCommandReturn), charging_limit);
				break;

			case ACTION_TYPE_SET_CHARGING_AMPS:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Setting max current - waiting for onCommandReturn");
				var charging_amps = value;
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_charging_amps) + charging_amps + "A"]);
				_tesla.setChargingAmps(_vehicle_vin, method(:onCommandReturn), charging_amps);
				break;

			case ACTION_TYPE_HONK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (option == ACTION_OPTION_BYPASS_CONFIRMATION) {
					honkHornConfirmed();
				} else {
					view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_honk_horn));
					delegate = new SimpleConfirmDelegate(method(:honkHornConfirmed), method(:operationCanceled));
					Ui.pushView(view, delegate, Ui.SLIDE_UP);
				}
				break;

			case ACTION_TYPE_OPEN_PORT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Opening on charge port - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(_data._vehicle_data.get("charge_state").get("charge_port_door_open") ? Rez.Strings.label_unlock_port : Rez.Strings.label_open_port)]);
				_tesla.openPort(_vehicle_vin, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLOSE_PORT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Closing on charge port - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_close_port)]);
				_tesla.closePort(_vehicle_vin, method(:onCommandReturn));
				break;

			case ACTION_TYPE_UNLOCK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Unlock - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_unlock_doors)]);
				_tesla.doorUnlock(_vehicle_vin, method(:onCommandReturn));
				break;

			case ACTION_TYPE_LOCK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Lock - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_lock_doors)]);
				_tesla.doorLock(_vehicle_vin, method(:onCommandReturn));
				break;

			case ACTION_TYPE_OPEN_FRUNK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (option == ACTION_OPTION_BYPASS_CONFIRMATION) {
					frunkConfirmed();
				}
				else {
					if (_data._vehicle_data.get("vehicle_state").get("ft") == 0) {
						view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.menu_label_open_frunk));
					}
					else if ($.getProperty("HansshowFrunk", false, method(:validateBoolean))) {
						view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.menu_label_close_frunk));
					}
					else {
						_stateMachineCounter = 1; // 0.1 second
						_handler.invoke([1, -1, Ui.loadResource(Rez.Strings.label_frunk_opened)]);
						break;

					}
					delegate = new SimpleConfirmDelegate(method(:frunkConfirmed), method(:operationCanceled));
					Ui.pushView(view, delegate, Ui.SLIDE_UP);
				}
				break;

			case ACTION_TYPE_OPEN_TRUNK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (option == ACTION_OPTION_BYPASS_CONFIRMATION) {
					trunkConfirmed();
				}
				else {
					view = new Ui.Confirmation(Ui.loadResource((_data._vehicle_data.get("vehicle_state").get("rt") == 0 ? Rez.Strings.menu_label_open_trunk : Rez.Strings.menu_label_close_trunk)));
					delegate = new SimpleConfirmDelegate(method(:trunkConfirmed), method(:operationCanceled));
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
						view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_open_vent));
						delegate = new SimpleConfirmDelegate(method(:openVentConfirmed), method(:operationCanceled));
						Ui.pushView(view, delegate, Ui.SLIDE_UP);
					}
				}
				else {
					if (option == ACTION_OPTION_BYPASS_CONFIRMATION) {
						closeVentConfirmed();
					} else {
						view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_close_vent));
						delegate = new SimpleConfirmDelegate(method(:closeVentConfirmed), method(:operationCanceled));
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
						_stateMachineCounter = 1; // 0.1 second
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
				_tesla.climateSeatHeat(_vehicle_vin, method(:onCommandReturn), position, seat_heat_chosen);
				break;

			case ACTION_TYPE_SET_STEERING_WHEEL_HEAT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Setting steering wheel heat - waiting for onCommandReturn");
				if (_data._vehicle_data.get("climate_state").get("is_climate_on") == false) {
					_handler.invoke([1, -1, Ui.loadResource(Rez.Strings.label_steering_wheel_need_climate_on)]);
					_stateMachineCounter = 1; // 0.1 second
				}
				else if (_data._vehicle_data.get("climate_state").get("steering_wheel_heater") != null) {
					_handler.invoke([_handlerType, -1, Ui.loadResource(_data._vehicle_data.get("climate_state").get("steering_wheel_heater") == true ? Rez.Strings.label_steering_wheel_off : Rez.Strings.label_steering_wheel_on)]);
					_tesla.climateSteeringWheel(_vehicle_vin, method(:onCommandReturn), _data._vehicle_data.get("climate_state").get("steering_wheel_heater"));
				}
				else {
					_stateMachineCounter = 1; // 0.1 second
				}
				break;

			case ACTION_TYPE_ADJUST_DEPARTURE:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
					//DEBUG*/ logMessage("actionMachine: Preconditionning off - waiting for onCommandReturn");
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_stop_departure)]);
					_tesla.setDeparture(_vehicle_vin, method(:onCommandReturn), value, false);
				}
				else {
					//DEBUG*/ logMessage("actionMachine: Preconditionning on - waiting for onCommandReturn");
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_start_departure)]);
					_tesla.setDeparture(_vehicle_vin, method(:onCommandReturn), value, true);
				}
				break;

			case ACTION_TYPE_TOGGLE_SENTRY:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				if (_data._vehicle_data.get("vehicle_state").get("sentry_mode")) {
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_sentry_off)]);
					_tesla.SentryMode(_vehicle_vin, method(:onCommandReturn), false);
				} else {
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_sentry_on)]);
					_tesla.SentryMode(_vehicle_vin, method(:onCommandReturn), true);
				}
				break;

			case ACTION_TYPE_HOMELINK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Homelink - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_homelink)]);
				_tesla.homelink(_vehicle_vin, method(:onCommandReturn), _data._vehicle_data.get("drive_state").get("latitude"), _data._vehicle_data.get("drive_state").get("longitude"));
				break;

			case ACTION_TYPE_REMOTE_BOOMBOX:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Remote Boombox - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_remote_boombox)]);
				_tesla.remoteBoombox(_vehicle_vin, method(:onCommandReturn));
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
				_tesla.setClimateMode(_vehicle_vin, method(:onCommandReturn), mode_chosen);
				break;

			case ACTION_TYPE_REFRESH:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				_refreshTimeInterval = Storage.getValue("refreshTimeInterval");
				if (_refreshTimeInterval == null) {
					_refreshTimeInterval = 1000;
				}
				//DEBUG*/ logMessage("actionMachine: refreshTimeInterval at " + _refreshTimeInterval + " - not calling a handler");
				_stateMachineCounter = 1; // 0.1 second
				break;

			case ACTION_TYPE_DATA_SCREEN:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: viewing DataScreen - not calling a handler");
				onReceive(1); // Show the first submenu
				break;

			default:
				//DEBUG 2023-10-02*/ logMessage("actionMachine: WARNING Invalid action");
				_stateMachineCounter = 1; // 0.1 second
				break;
		}
	}

	function stateMachine() {
		//DEBUG*/ logMessage("stateMachine:" + (_vehicle_id != null && _vehicle_id > 0 ? "" : " vehicle_id " + _vehicle_id) + " vehicle_state " + _vehicle_state + (_need_auth ? " _need_auth true" : "") + (!_auth_done ? " _auth_done false" : "") + (_check_wake > CHECK_WAKE_NO_CHECK ? " _check_wake " + _check_wake : "") + " _wake_state: " + _wake_state) + (_waitingFirstData ? " _waitingFirstData=" + _waitingFirstData : ""));

/* DEBUG
		if (_debug_view) {
			_need_auth = false;
			_auth_done = true;
			_wake_state = WAKE_UNKNOWN;
			_408_count = 0;
			_waitingFirstData = 0;
			_stateMachineCounter = 1;
			_handler.invoke([1, -1, null]); // Refresh the screen only if we're not displaying something already that hasn't timed out
			return;
		}//*/

		_stateMachineCounter = 0; // So we don't get in if we're alreay in

		var resetNeeded = Storage.getValue("ResetNeeded");
		if (resetNeeded != null && resetNeeded == true) {
			Storage.setValue("ResetNeeded", false);
			_vehicle_id = VEHICLE_ID_NEED_ID;
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
	                "redirect_uri" => "https://" + _serverAUTHLocation + "/void/callback",
	                "response_type" => "code",
	                "scope" => "openid email offline_access",
	                "state" => "123"
	            };
				//logMessage("stateMachine: params=" + params);
	            
	            _handler.invoke([3, -1, Ui.loadResource(Rez.Strings.label_login_on_phone)]);

				//DEBUG*/ logMessage("stateMachine: serverAUTHLocation: " + _serverAUTHLocation);	
	            Communications.registerForOAuthMessages(method(:onOAuthMessage));
				var url_oauth = "https://" + _serverAUTHLocation + "/oauth2/v3/authorize";
				var url_callback = "https://" + _serverAUTHLocation + "/void/callback";
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
			//DEBUG 2023-10-02*/ logMessage("StateMachine: WARNING auth NOT done");
			return;
		}

		if (_tesla == null) {
			_tesla = new Tesla(_token);
		}

		if (_vehicle_id == VEHICLE_ID_NEED_LIST) {
            _handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
			_stateMachineCounter = -1;
			_tesla.getVehicleId(method(:onSelectVehicle));
			_vehicle_id = VEHICLE_ID_NEED_ID;
			return;
		}

		if (_wake_state == WAKE_TEST) {
			// Waiting for our wake test to finish
			return;
		}

		// Get vehicle ID and wake state if we have no VIN, no ID or asked to get our ID, asked to wake or received confirmation or wake packet was received by the server
		if (_vehicle_vin == null || _vehicle_id == null || _vehicle_id == VEHICLE_ID_NEED_ID || _check_wake > CHECK_WAKE_NO_CHECK || _wake_state == WAKE_RECEIVED || _wake_state == WAKE_RETEST) { 
			//DEBUG*/ logMessage("StateMachine: Getting vehicles, _vehicle_vin=" + (_vehicle_vin != null && _vehicle_vin.length() > 0 ? "valid" : _vehicle_vin ) + " _vehicle_id=" +  (_vehicle_id != null && _vehicle_id > 0 ? "valid" : _vehicle_id) + " _check_wake=" + _check_wake + " _wake_state=" + _wake_state + (_waitingFirstData ? " _waitingFirstData=" + _waitingFirstData : ""));
			if (_vehicle_id == null) {
	            _handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
			}

			if (_check_wake >= CHECK_WAKE_CHECK_SILENT && _wake_state >= WAKE_UNKNOWN) {
				// We're asked to check our wake state (and potentialy wake it, make sure we don't come back here until we received something from onReceiveVehicles)
				_wake_state = WAKE_TEST;
			}

			// If we're waiting for receiving our wake status, flag it so we don't come back here and request again
			if (_wake_state == WAKE_RECEIVED || _wake_state == WAKE_RETEST) {
				_wake_state = WAKE_WAITING;
			}

			// This, beside getting our vehicle ID, will get the wake state of the vehicle. It will also request a wake if _check_wake is CHECK_WAKE_CHECK_AND_WAKE
			//DEBUG*/ logMessage("StateMachine: Calling getVehicleId with _wake_state=" + _wake_state);
			_tesla.getVehicleId(method(:onReceiveVehicles));
			_stateMachineCounter = 20; // Wait 2 second before running again so we don't start flooding the communication
			return;
		}

		if (_wake_state == WAKE_NEEDED) { // Asked to wake up
			if (_waitingFirstData > 0 && !_wakeWasConfirmed && $.getProperty("askWakeVehicle", true, method(:validateBoolean))) { // Ask if we should wake the vehicle
				//DEBUG*/ logMessage("stateMachine: Asking if OK to wake");
	            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_should_we_wake) + Storage.getValue("vehicle_name") + "?");
				_stateMachineCounter = -1;
	            var delegate = new SimpleConfirmDelegate(method(:wakeConfirmed), method(:wakeCanceled));
				_in_menu = true;
	            Ui.pushView(view, delegate, Ui.SLIDE_UP);
			} else {
				//DEBUG*/ logMessage("stateMachine: Waking vehicle without asking");
				_wake_state = WAKE_SENT;
				_tesla.wakeVehicle(_vehicle_vin, method(:onReceiveAwake));
			}
			return;
		}

		if (_wake_state < WAKE_UNKNOWN) { // Until _wake_state is less than WAKE_UNKNOWN, we stop here
			return;
		}

		// We've got data but don't know our wake state yet (tessie in cache mode), get that state
		if (_waitingFirstData == 0 && _wake_state == WAKE_UNKNOWN) {
			_check_wake = CHECK_WAKE_CHECK_SILENT;
			_stateMachineCounter = 1;
			return;
		}

		// If we've come from a watch face, simulate a upper left quandrant touch hold once we started to get data.
		if (_view._data._ready == true && Storage.getValue("launchedFromComplication") == true) {
			Storage.setValue("launchedFromComplication", false);

			var action = $.getProperty("complicationAction", 0, method(:validateNumber));
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
		//DEBUG*/ logMessage("StateMachine: getVehicleData");
		_tesla.getVehicleData(_vehicle_vin, method(:onReceiveVehicleData));
	}

	function workerTimer() {
		if (_in_menu) { // If we're waiting for input in a menu, skip this iteration
			return;
		}

		// Check if we are in a subview with a "should we exit" countdown
		if (_subViewExitCounter > 1) {
			_subViewExitCounter--;
		}
		else if (_subViewExitCounter == 1) {
        	_subViewExitCounter = 0;
	        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
		}

		// If we have changed our settings, update
		if (gSettingsChanged != null && gSettingsChanged) {
			gSettingsChanged = false;
			settingsChanged(false);
		}

		// We're not waiting for a command to return, we're waiting for an action to be performed
		if (_waitingForCommandReturn == false && _pendingActionRequests.size() > 0) {
			if (_wake_state < WAKE_ONLINE) {
				// We're not online (probably in Tessie cache mode), if we haven't already sent a wake command, send one
				if (_wake_state < WAKE_SENT || _wake_state > WAKE_RETEST) {
					//DEBUG*/ logMessage("workerTimer: Need to wake before sending command");
					_wake_state = WAKE_NEEDED;
					_stateMachineCounter = 1;
					_handler.invoke([3, 0, Ui.loadResource(Rez.Strings.label_waking_vehicle)]); // Say we're still waiting for data
				}

				// Now we need to run our stateMachine function that will have the job of waking the car
				if (_stateMachineCounter <= 1) {
					stateMachine();
					_stateMachineCounter = 10; // Try again in 1 second
				} else {
					_stateMachineCounter--;
				}
			}
			else if (_view._data._ready == true && _lastError == null) {
				// We're not displaying a message on screen and the last webRequest returned responseCode 200, do you thing actionMenu!
				//DEBUG*/ logMessage("workerTimer: Do action");
				actionMachine();
			}
			// Call stateMachine as soon as it's out of it (_stateMachineCounter will get modified in onReceiveVehicleData). That's in case we have no data yet.
			else if (_stateMachineCounter != 0) {
				//_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_waiting_online)]);
				//DEBUG*/ logMessage("actionMachine: Differing, _pendingActionRequests size at " + _pendingActionRequests.size() + " DataViewReady is " + _view._data._ready + " lastError is " + _lastError + " _stateMachineCounter is " + _stateMachineCounter);
				stateMachine();
			}
		}
		// We have no actions waiting
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
				var timeDelta = System.getTimer() - _lastDataRun;
				if (timeDelta > 15000) {
					//DEBUG 2023-10-02*/ logMessage("workerTimer: We've been waiting for data for " + timeDelta + "ms. Assume we lost this packet and try again");
					_lastDataRun = System.getTimer();
					_stateMachineCounter = 1; // 0.1 second
				}				
				//logMessage("workerTimer: " + _stateMachineCounter);
			}
		}

		// If we are still waiting for our first set of data, not at a login prompt and not waiting to wake, once we reach 150 iterations of the 0.1sec workTimer (ie, 15 seconds has elapsed since we started)
		if (_waitingFirstData > 0 && _auth_done && _wake_state >= WAKE_UNKNOWN) {
			_waitingFirstData++;
			if (_waitingFirstData % 150 == 0) {
				_handler.invoke([3, 0, Ui.loadResource(Rez.Strings.label_still_waiting_data)]); // Say we're still waiting for data
			}
		}

		// If we're showing a subView, request a one second view refresh
		if (_subView != null) {
			if (_subViewCounter >= 10) {
				_subViewCounter = 0;
				Ui.requestUpdate();
			}
			else {
				_subViewCounter++;
			}
		}
	}

	function operationCanceled() {
		//DEBUG*/ logMessage("operationCanceled:");
		_stateMachineCounter = 1; // 0.1 second
	}

	function complicationConfirmed() {
		//DEBUG*/ logMessage("complicationConfirmed:");
		onHold(true); // Simulate a hold on the top left quadrant
	}

	function wakeConfirmed() {
		_wakeWasConfirmed = true;
		gWaitTime = System.getTimer();
		//DEBUG*/ logMessage("wakeConfirmed: Waking the vehicle");

		_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_waking_vehicle)]);
		_in_menu = false;
		_wake_state = WAKE_SENT;
		_tesla.wakeVehicle(_vehicle_vin, method(:onReceiveAwake));
	}

	function wakeCanceled() {
		gWaitTime = System.getTimer();
		Storage.setValue("launchedFromComplication", false); // If we came from a watchface complication and we canceled the wake, ignore the complication event
		//DEBUG*/ logMessage("wakeCancelled:");

		if (_tesla.getTessieCacheMode()) {
			_wake_state = (_vehicle_state.equals("online") ? WAKE_ONLINE : WAKE_OFFLINE);
		}
		else {
			_vehicle_id = VEHICLE_ID_NEED_LIST; // Tells StateMachine to popup a list of vehicles
			_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
		}
		_stateMachineCounter = 1; // 0.1 second
		_in_menu = false;
	}

	function openVentConfirmed() {
		_handler.invoke([$.getProperty("quickReturn", false, method(:validateBoolean)) ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_vent_opening)]);
		//DEBUG*/ logMessage("actionMachine: Open vent - waiting for onCommandReturn");
		_tesla.vent(_vehicle_vin, method(:onCommandReturn), "vent", _data._vehicle_data.get("drive_state").get("latitude"), _data._vehicle_data.get("drive_state").get("longitude"));
	}

	function closeVentConfirmed() {
	    _handler.invoke([$.getProperty("quickReturn", false, method(:validateBoolean)) ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_vent_closing)]);
		//DEBUG*/ logMessage("actionMachine: Close vent - waiting for onCommandReturn");
		_tesla.vent(_vehicle_vin, method(:onCommandReturn), "close", _data._vehicle_data.get("drive_state").get("latitude"), _data._vehicle_data.get("drive_state").get("longitude"));
	}

	function frunkConfirmed() {
		//DEBUG*/ logMessage("actionMachine: Acting on frunk - waiting for onCommandReturn");
		var hansshowFrunk = $.getProperty("HansshowFrunk", false, method(:validateBoolean));
		if (hansshowFrunk) {
	        _handler.invoke([$.getProperty("quickReturn", false, method(:validateBoolean)) ? 1 : 2, -1, Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("ft") == 0 ? Rez.Strings.label_frunk_opening : Rez.Strings.label_frunk_closing)]);
			_tesla.openTrunk(_vehicle_vin, method(:onCommandReturn), "front");
		} else {
			if (_data._vehicle_data.get("vehicle_state").get("ft") == 0) {
				_handler.invoke([$.getProperty("quickReturn", false, method(:validateBoolean)) ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_frunk_opening)]);
				_tesla.openTrunk(_vehicle_vin, method(:onCommandReturn), "front");
			} else {
				_handler.invoke([1, -1, Ui.loadResource(Rez.Strings.label_frunk_opened)]);
	            _stateMachineCounter = 1; // 0.1 second
			}
		}
	}

	function trunkConfirmed() {
		//DEBUG*/ logMessage("actionMachine: Acting on trunk - waiting for onCommandReturn");
		_handler.invoke([$.getProperty("quickReturn", false, method(:validateBoolean)) ? 1 : 2, -1, Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("rt") == 0 ? Rez.Strings.label_trunk_opening : Rez.Strings.label_trunk_closing)]);
		_tesla.openTrunk(_vehicle_vin, method(:onCommandReturn), "rear");
	}

	function honkHornConfirmed() {
		//DEBUG*/ logMessage("actionMachine: Honking - waiting for onCommandReturn");
		_handler.invoke([$.getProperty("quickReturn", false, method(:validateBoolean)) ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_honk)]);
		_tesla.honkHorn(_vehicle_vin, method(:onCommandReturn));
	}

	function onSelect() {
		if (_useTouch) {
			return false;
		}

		doSelect();
		return true;
	}

	function doSelect() {
		//DEBUG*/ logMessage("doSelect: climate on/off");
		if (!_data._ready) {
			//DEBUG 2023-10-02*/ logMessage("doSelect: WARNING Not ready to do action");
			return;
		}

		if (_data._vehicle_data.get("climate_state").get("is_climate_on") == false) {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_CLIMATE_ON, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		} else {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_CLIMATE_OFF, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		}
	}

	function onNextPage() {
		if (_useTouch) {
			return false;
		}

		doNextPage();
		return true;
	}

	function doNextPage() {
		//DEBUG*/ logMessage("doNextPage: lock/unlock");
		if (!_data._ready) {
			//DEBUG 2023-10-02*/ logMessage("doNextPage: WARNING Not ready to do action");
			return;
		}

		if (_data._vehicle_data.get("vehicle_state").get("locked")) {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_UNLOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		} else {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_LOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		}
	}

	function onPreviousPage() {
		if (_useTouch) {
			return false;
		}

		doPreviousPage();
		return true;
	}

	function doPreviousPage() {
		//DEBUG*/ logMessage("doPreviousPage: trunk/frunk/port");
		if (!_data._ready) {
			//DEBUG 2023-10-02*/ logMessage("doPreviousPage: WARNING Not ready to do action");
			return;
		}

		var drive_state = _data._vehicle_data.get("drive_state");
		if (drive_state != null && drive_state.get("shift_state") != null && drive_state.get("shift_state").equals("P") == false) {
			//DEBUG*/ logMessage("doPreviousPage: Moving, ignoring command");
			return;
		}

		switch ($.getProperty("swap_frunk_for_port", 0, method(:validateNumber))) {
			case 0:
				var hansshowFrunk = $.getProperty("HansshowFrunk", false, method(:validateBoolean));
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
				else if ($.getProperty("HansshowFrunk", false, method(:validateBoolean))) {
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
				//DEBUG 2023-10-02*/ logMessage("doPreviousPage: WARNING swap_frunk_for_port is " + $.getProperty("swap_frunk_for_port", 0, method(:validateNumber)));
		}
	}

	function onMenu() {
		if (_useTouch) {
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
				else if ($.getProperty("HansshowFrunk", false, method(:validateBoolean))) {
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
			case 25:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_media_control, null, :media_control, {}));
				break;
			case 26:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_dogmodewatch, null, :dogmode_watch, {}));
				break;
			default:
				//DEBUG 2023-10-02*/ logMessage("addMenuItem: Index " + index + " out of range");
				break;
		}
	}
	
	function doMenu() {
		//DEBUG*/ logMessage("doMenu: Menu");
		if (!_data._ready) {
			//DEBUG 2023-10-02*/ logMessage("doMenu: WARNING Not ready to do action");
			return;
		}

		var thisMenu = new Ui.Menu2({:title=>Rez.Strings.menu_option_title});
		var menuItems = $.to_array($.getProperty("optionMenuOrder", "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,24,25", method(:validateString)),",");
		for (var i = 0; i < menuItems.size(); i++) {
			addMenuItem(thisMenu, menuItems[i]);
		}
		
		Ui.pushView(thisMenu, new OptionMenuDelegate(self), Ui.SLIDE_UP );
	}

	function onBack() {
		// if (_useTouch) {
		// 	return false;
		// }

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

		var enhancedTouch = $.getProperty("enhancedTouch", true, method(:validateBoolean));

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
			var screenBottom = $.getProperty(x < _settings.screenWidth / 2 ? "screenBottomLeft" : "screenBottomRight", 0, method(:validateNumber));
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
		var action;

		if (click instanceof Lang.Boolean) {
			x = 0;
			y = 0;
			action = $.getProperty("complicationAction", 0, method(:validateNumber));
		}
		else {
			var coords = click.getCoordinates();
			x = coords[0];
			y = coords[1];
			action = $.getProperty("holdActionUpperLeft", 0, method(:validateNumber));
		}

		var vibrate = true;

		if (x < _settings.screenWidth/2) {
			if (y < _settings.screenHeight/2) {
				//DEBUG*/ logMessage("onHold: Upper Left");
				switch (action) {
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

					case 5:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_CLIMATE_ON, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						break;

					case 6:
						if (_data._vehicle_data.get("vehicle_state").get("locked")) {
							_pendingActionRequests.add({"Action" => ACTION_TYPE_UNLOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						} else {
							_pendingActionRequests.add({"Action" => ACTION_TYPE_LOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						}
						break;

					case 7:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_LOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						break;

					case 8:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_UNLOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						break;

					default:
						//DEBUG 2023-10-02*/ logMessage("onHold: Upper Left WARNING Invalid");
						break;
				}
			} else {
				//DEBUG*/ logMessage("onHold: Lower Left");
				switch ($.getProperty("holdActionLowerLeft", 0, method(:validateNumber))) {
					case 0:
						vibrate = false;
						break;

					case 1:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_HONK, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
						break;

					default:
						//DEBUG 2023-10-02*/ logMessage("onHold: Lower Left WARNING Invalid");
						break;
				}
			}
		} else {
			if (y < _settings.screenHeight/2) {
				//DEBUG*/ logMessage("onHold: Upper Right");
				switch ($.getProperty("holdActionUpperRight", 0, method(:validateNumber))) {
					case 0:
						vibrate = false;
						break;

					case 1:
						_pendingActionRequests.add({"Action" => ACTION_TYPE_CLIMATE_DEFROST, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
						break;

					default:
						//DEBUG 2023-10-02*/ logMessage("onHold: Upper Right WARNING Invalid");
						break;
				}
			} else {
				//DEBUG*/ logMessage("onHold: Lower Right");
				switch ($.getProperty("holdActionLowerRight", 0, method(:validateNumber))) {
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
						//DEBUG 2023-10-02*/ logMessage("onHold: Lower Right WARNING Invalid");
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
			var vinsVIN = new [size];

			for (var i = 0; i < size; i++) {
				vinsName[i] = vehicles[i].get("display_name");
				vinsId[i] = vehicles[i].get("id");
				vinsVIN[i] = vehicles[i].get("vin");
			}
			_in_menu = true;
			Ui.pushView(new CarPicker(vinsName), new CarPickerDelegate(vinsName, vinsId, vinsVIN, self), Ui.SLIDE_UP);
		}
		else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
			_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down! Wait 10 seconds
		}
		else {
			_handler.invoke([0, -1, buildErrorString(responseCode)]);
			_stateMachineCounter = 1; // 0.1 second
		}
	}

	// Get the vehicle ID and the wake state of the vehicle. It will also request a wake if not awoken and _check_wake is CHECK_WAKE_CHECK_AND_WAKE
	// If there are no vehicles, it will pop up a message saying so
	// If there is no current vehicle and the list has more than one, it will request a menu to show asking to choose a vehicle by setting _vehicle_id to VEHICLE_ID_NEED_LIST
	function onReceiveVehicles(responseCode, data) {
		//DEBUG*/ logMessage("onReceiveVehicles: " + responseCode);
		//logMessage("onReceiveVehicles: data is " + data);

		if (responseCode == 200) {
			var vehicles = data.get("response");
			var size = vehicles.size();
			if (size > 0) {
				_stateMachineCounter = 1; // 0.1 second by default

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
						//DEBUG*/logMessage("onReceiveVehicles: couldn't find " + vehicle_name);
						if (size > 1) {
							// We had a vehicle but it's no longer in our list, our list has more than one vehicle so pop a menu asking which one
							_vehicle_id = VEHICLE_ID_NEED_LIST;
							if (_wake_state == WAKE_TEST) {
								_wake_state = WAKE_UNKNOWN;
							}
						//DEBUG*/logMessage("onReceiveVehicles: Vehicle not in list, display list");
							return;		
						}
						vehicle_index = 0; // Use first one
					}
				}
				else {
					// No vehicle currently stored. If we have just one in our list, use that one, otherwise pop a menu asking which one
					if (size > 1) {
						_vehicle_id = VEHICLE_ID_NEED_LIST;
						if (_wake_state == WAKE_TEST) {
							_wake_state = WAKE_UNKNOWN;
						}
						//DEBUG*/logMessage("onReceiveVehicles: No vehicle saved, display list");
						return;		
					}
				}

				_vehicle_id = vehicles[vehicle_index].get("id");
				if (_useTeslaAPI) {
					_vehicle_vin = _vehicle_id;
				}
				else {
					_vehicle_vin = vehicles[vehicle_index].get("vin");
				}

				_vehicle_state = vehicles[vehicle_index].get("state");
				_data._vehicle_state = _vehicle_state;

				var status = Storage.getValue("status");
				if (status != null) {
					status.put("vehicleAwake", _vehicle_state);
					Storage.setValue("status", status);
					$.sendComplication(status);
				}
				
				if (_vehicle_state.equals("online")) {
					_wake_state = WAKE_ONLINE; // We're online! It's time to get the data!
				}
				else if (_wake_state == WAKE_WAITING) { // We've already sent our Wake command and waiting for the result, don't ask it to wake it again here
					_stateMachineCounter = 20; // Try again in  seconds (leaving _wake_state at WAKE_RECEIVED will trigger a new wake check)
					_wake_state = WAKE_RETEST;
				}
				else if (_wake_state == WAKE_UNKNOWN && _tesla.getTessieCacheMode() && _waitingFirstData > 0) { // We don't know our wake state, we're in Tessie Cache mode and we're waiting for our first set of data, don't "Ask to wake" 
					_wake_state = WAKE_OFFLINE;
				}
				else if (_check_wake != CHECK_WAKE_CHECK_SILENT) { // If we're WAKE_UNKMOWN state, we simply silently want our wake state, don't wake up
					_wake_state = WAKE_NEEDED; // Next iteration of StateMachine will call the wake function
				}
				else {
					_wake_state = WAKE_OFFLINE;
				}
				//DEBUG*/ logMessage("onReceiveVehicles: Vehicle state is '" + _vehicle_state + "', wake state is " + _wake_state);

				_check_wake = CHECK_WAKE_NO_CHECK;

				Storage.setValue("vehicle", _vehicle_id);
				Storage.setValue("vehicleVIN", _vehicle_vin);
				Storage.setValue("vehicle_name", vehicles[vehicle_index].get("display_name"));

				return;
			}
			else {
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_no_vehicles)]);
				_stateMachineCounter = 100; // 10 seconds
			}
		}
		else {
			_stateMachineCounter = 50; // 5 seconds
			if (_wake_state == WAKE_TEST) {
				_wake_state = WAKE_UNKNOWN;
			}
			if (_check_wake == CHECK_WAKE_NO_CHECK) {
				_check_wake = CHECK_WAKE_CHECK_AND_WAKE;
			}
			
			if (responseCode == 401) {
				if (_useTeslaAPI) {
					// Unauthorized
					_stateMachineCounter = 1; // 0.1 second
					_resetToken();
					_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
				}
				else {
					_handler.invoke([3, -1, Ui.loadResource(Rez.Strings.label_invalid_token)]);
				}
			}
			else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
	            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
				_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down! Wait 10 seconds
				return;
			}
			else if (responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke([0, -1, buildErrorString(responseCode)]);
	        }
		}
	}

	function onReceiveVehicleData(responseCode, data) {
		//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);

		SpinSpinner(responseCode);

		if (_stateMachineCounter < 0) {
			//DEBUG*/ if (_stateMachineCounter == -3) { logMessage("onReceiveVehicleData: " + responseCode + " skipping, actionMachine running"); }
			//DEBUG*/ if (_stateMachineCounter == -2) { logMessage("onReceiveVehicleData: " + responseCode + " WARNING skipping again because of the menu?"); }
			if (_stateMachineCounter == -1) { 
				//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode + " skipping, we're in a menu");
				 _stateMachineCounter = -2; // Let the menu blocking us know that we missed data
			}
			return;
		}

		if (responseCode == 200) {
			_lastError = null;
			if (_tesla.getTessieCacheMode() == false) {
				// We got data so we got to be online (not for Tessie cache mode)
				_vehicle_state = "online";
				_data._vehicle_state = _vehicle_state;
				_wake_state = WAKE_ONLINE;
			}

			// Check if this data feed is older than the previous one and if so, ignore it (two timers could create this situation)
			if (data != null && data instanceof Lang.Dictionary && _tesla != null) {
				var response;
				response = data.get("response");
				if (response == null) {
					response = data;
				}

				//DEBUG*/ logMessage("onReceiveVehicleData: received " + response);
				if (response != null && response instanceof Lang.Dictionary && response.get("climate_state") != null && response.get("charge_state") != null && response.get("vehicle_state") != null && response.get("drive_state") != null) {
					var dataTimeStamp = $.validateLong(response.get("charge_state").get("timestamp"), 0);
					if (dataTimeStamp > _lastTimeStamp) {
						//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode + " Received fresh data!");
						_lastTimeStamp = dataTimeStamp;
						_data._vehicle_data = response;
						if (_waitingForCommandReturn) {
							_handler.invoke([0, -1, null]); // We received the status of our command, show the main screen right away
							_stateMachineCounter = 1; // 0.1 second
						}
						else {
							_handler.invoke([1, -1, null]); // Refresh the screen only if we're not displaying something already that hasn't timed out
						}

						// get the media state for the MediaControl View
						if (response.get("vehicle_state").get("media_info") != null) {
							var media_info = response.get("vehicle_state").get("media_info");
							Storage.setValue("media_playback_status", media_info.get("media_playback_status"));
							Storage.setValue("now_playing_title", media_info.get("now_playing_title"));
							Storage.setValue("media_volume", ($.validateFloat(media_info.get("audio_volume"), 0.0)).toFloat());
							Storage.setValue("media_volume_inc", ($.validateFloat(media_info.get("audio_volume_increment"), (1.0/3.0))).toFloat());
							Storage.setValue("media_volume_max", ($.validateFloat(media_info.get("audio_volume_max"), 11.0)).toFloat());
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

							var which_battery_type = $.getProperty("batteryRangeType", 0, method(:validateNumber));
							var bat_range_str = [ "battery_range", "est_battery_range", "ideal_battery_range"];

							status.put("battery_level", $.validateNumber(response.get("charge_state").get("battery_level"), 0));
							status.put("battery_range", $.validateNumber(response.get("charge_state").get(bat_range_str[which_battery_type]), 0));
							status.put("charging_state", $.validateString(response.get("charge_state").get("charging_state"), ""));
							status.put("inside_temp", $.validateNumber(response.get("climate_state").get("inside_temp"), 0));
							status.put("shift_state", $.validateString(response.get("drive_state").get("shift_state"), ""));
							status.put("sentry", $.validateBoolean(response.get("vehicle_state").get("sentry_mode"), false));
							status.put("preconditioning", $.validateBoolean(response.get("charge_state").get("preconditioning_enabled"), false));
							status.put("vehicleAwake", "online");

							Storage.setValue("status", status);
							//DEBUG*/logMessage("onReceiveVehicleData: calling sendComplication");
							$.sendComplication(status);
							
							//DEBUG*/ logMessage("onReceiveVehicleData: set status to '" + Storage.getValue("status") + "'");
						}

						if (_408_count) {
							//DEBUG*/ logMessage("onReceiveVehicleData: clearing _408_count");
							_408_count = 0; // Reset the count of timeouts since we got our data
						}

						if (_waitingFirstData > 0) { // We got our first responseCode 200 since launching
							_waitingFirstData = 0;
							_waitingForCommandReturn = false; // TODO Why? Can't have commands waiting if we're just starting
							_stateMachineCounter = 1; // Make sure we check on the next workerTimer

							if (!_wakeWasConfirmed && _tesla.getTessieCacheMode() == false) { // And we haven't asked to wake the vehicle, so it was already awoken when we got in, so send a gratious wake command ao we stay awake for the app running time
								//DEBUG*/ logMessage("onReceiveVehicleData: sending gratious wake");
								_wake_state = WAKE_SENT;
								_tesla.wakeVehicle(_vehicle_vin, method(:onReceiveAwake)); // 
							}
							return;
						}

						if (_waitingForCommandReturn) {
							_stateMachineCounter = 1; // 0.1 second
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
					//DEBUG*/ } else if ($.validateLong(response.get("charge_state").get("timestamp"), 0) ==  _lastTimeStamp) { logMessage("onReceiveVehicleData: " + responseCode + " Identical timestamps, ignoring");
					} else {
						//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode + " WARNING Received an out or order data or missing timestamp, ignoring");
					}
				} else {
					//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode + " WARNING Received incomplete data, ignoring");
				}
			} else {
				//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode + " WARNING Received NO data or data is NOT a dictionary, ignoring");
			}
			_stateMachineCounter = 5; // 0.5 second
		}
		else {
			_stateMachineCounter = 5; // 0.5 second
			_lastError = responseCode;

			if (_waitingFirstData > 0) { // Reset that counter if what we got was an error packet. We're interested in gap between packets received, not if it's an error.
				_waitingFirstData = 1;
			}

			if (responseCode == 408) { // We got a timeout, check if we're still awake
				var i = _408_count + 1;
				//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode + " 408_count=" + i + " _waitingFirstData=" + _waitingFirstData);
				if (_waitingFirstData > 0 && _view._data._ready == false) { // We haven't received any data yet and we have already a message displayed
					_handler.invoke([3, i, Ui.loadResource(_wake_state >= WAKE_UNKNOWN ? Rez.Strings.label_requesting_data : Rez.Strings.label_waking_vehicle)]);
				}

	        	if ((_408_count % 10 == 0 && _waitingFirstData > 0) || (_408_count % 10 == 1 && _waitingFirstData == 0)) { // First (if we've starting up), and every consecutive 10th 408 recieved (skipping a spurious 408 when we aren't started up) will generate a test for the vehicle state. 
					if (_408_count < 2 && _waitingFirstData == 0) { // Only when we first started to get the errors do we keep the start time, unless we've started because our start time has been recorded already
						gWaitTime = System.getTimer();
					}
					//DEBUG*/ logMessage("onReceiveVehicleData: Got 408, wake the vehicle if it's asleep (offline) and NOT in cache mode");
					if (_tesla.getTessieCacheMode() == false) {
						// We're not in cache mode, we need to wake to get fresh data 
						_check_wake = CHECK_WAKE_CHECK_AND_WAKE;
					}
	            }
				_408_count++;
			} else {
				if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
					//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);
					_vehicle_id = VEHICLE_ID_NEED_LIST;
		            _handler.invoke([0, -1, buildErrorString(responseCode)]);
				}
				else if (responseCode == 401) {
					//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);
					if (_useTeslaAPI) {
						// Unauthorized, retry
						_need_auth = true;
						_resetToken();
						_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
					}
					else {
						_stateMachineCounter = 50;  // 5 seconds
						_handler.invoke([3, -1, Ui.loadResource(Rez.Strings.label_invalid_token)]);
					}
				}
				else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
					//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);
					_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
					_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down! Wait 10 seconds
				}
				else if (responseCode != -5  && responseCode != -101) { // These are silent errors
					//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);
		            _handler.invoke([0, -1, buildErrorString(responseCode)]);
		        }
				else {
					//DEBUG*/ logMessage("onReceiveVehicleData: " + responseCode);
				}
			}
	    }
	}

	function onReceiveAwake(responseCode, data) {
		//DEBUG*/ logMessage("onReceiveAwake: " + responseCode);

		_stateMachineCounter = 1; // Default to 0.1 second

		if (responseCode == 200 || (responseCode == 403 && _vehicle_state != null && _vehicle_state.equals("online") == true)) { // If we get 403, check to see if we saw it online since some country do not accept waking remotely
			_wake_state = WAKE_RECEIVED;
		}
		else {
		   // We were unable to wake, try again
			_wake_state = WAKE_NEEDED;
			if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
				_vehicle_id = VEHICLE_ID_NEED_LIST;
				_handler.invoke([0, -1, buildErrorString(responseCode)]);
			}
			else if (responseCode == 403) { // Forbiden, ask to manually wake the vehicle and test its state through the vehicle states returned by onReceiveVehicles
				_stateMachineCounter = 50; // Wait a second so we don't flood the communication. Wait 5 seconds
				_vehicle_id = VEHICLE_ID_NEED_ID;
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_ask_manual_wake)]);
				return;
			}
			else if (responseCode == 401) { // Unauthorized, retry
				if (_useTeslaAPI) {
					_resetToken();
					_need_auth = true;
					_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
				}
				else {
					_stateMachineCounter = 50; // Wait a second so we don't flood the communication. Wait 5 seconds
					_handler.invoke([3, -1, Ui.loadResource(Rez.Strings.label_invalid_token)]);
				}
			}
			else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
	            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
				_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down! Wait 10 seconds
				return;
			}
			else if (responseCode != -5  && responseCode != -101) { // These are silent errors
				_handler.invoke([0, -1, buildErrorString(responseCode)]);
			}
		}
	}

	function onCommandReturn(responseCode, data) {
		SpinSpinner(responseCode);

		if (responseCode == 200) {
			if ($.getProperty("quickReturn", false, method(:validateBoolean))) {
				//DEBUG*/ logMessage("onCommandReturn: " + responseCode + " running StateMachine in 100msec");
				_stateMachineCounter = 1; // 0.1 second
			} else {
				// Wait a second to let time for the command change to be recorded on Tesla's server
				//DEBUG*/ logMessage("onCommandReturn: " + responseCode + " running StateMachine in 1 sec");
				_stateMachineCounter = 10; // 1 second
				_waitingForCommandReturn = true;
			}
			_tesla.setNoCacheNextVehicleData(); // Tell the next vehicle data query to get the real data, not the cached one
		}
		else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
			//DEBUG*/ logMessage("onCommandReturn: " + responseCode + " running StateMachine in 100msec");
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
			_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down! Wait 10 seconds
		}
		else { // Our call failed, say the error and back to the main code
			//DEBUG*/ logMessage("onCommandReturn: " + responseCode + " running StateMachine in 100msec");
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + buildErrorString(responseCode)]);
			_stateMachineCounter = 1; // 0.1 second
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
		}
		else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
			_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down! Wait 10 seconds
			return;
		}
		else if (responseCode != -5  && responseCode != -101) { // These are silent errors
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + buildErrorString(responseCode)]);
		}

		_stateMachineCounter = 1; // 0.1 second
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
		//DEBUG 2023-10-02*/ logMessage("_resetToken: Reseting tokens");
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