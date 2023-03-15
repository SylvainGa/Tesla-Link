using Toybox.WatchUi as Ui;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Communications as Communications;
using Toybox.Cryptography;
using Toybox.Graphics;
using Toybox.Time.Gregorian;

const OAUTH_CODE = "myOAuthCode";
const OAUTH_ERROR = "myOAuthError";

class MainDelegate extends Ui.BehaviorDelegate {
	var _view as MainView;
	var _settings;
	var _handler;
	var _tesla;
	var _data;
	var _token;
	var _code_verifier;
	var _sleep_timer;
	var _handler_timer; // So it doesn't interfere with the timer used in onReceiveVehicleData
	var _waiting_data_timer;
	var _vehicle_id;
	var _vehicle_state;
	var _need_auth;
	var _auth_done;
	var _check_wake;
	var _need_wake;
	var _wake_done;
	var _wakeTime;
	var _firstTime;
	var _refreshTimeInterval;
	var _408_count;
	var _skipGetVehicleData;
	var _waitingForVehicleData;
	var _lastTimeStamp;
	var _lastDataRun;
	var _debugTimer;
	var _showingRequestingData;

	var _set_climate_on;
	var _set_climate_off;
	var _set_climate_set;
	var _set_climate_defrost;
	var _set_charging_amps_set;
	var _set_charging_limit_set;
	var _toggle_charging_set;
	var _honk_horn;
	var _open_port;
	var _close_port;
	var _open_frunk;
	var _open_trunk;
	var _unlock;
	var _lock;
	var _vent;
	var _set_seat_heat;
	var _set_steering_wheel_heat;
	var _adjust_departure;
	var _sentry_mode;
	var _homelink;
	var _remote_boombox;
	var _climate_mode;
	var _set_refresh_time;
	var _view_datascreen;
	var _bypass_confirmation;

	function initialize(view as MainView, data, handler) {
		BehaviorDelegate.initialize();
		_view = view;

		_settings = System.getDeviceSettings();
		_data = data;
		_token = Settings.getToken();
		_vehicle_id = Application.getApp().getProperty("vehicle");
		_vehicle_state = "online"; // Assume we're online
		_sleep_timer = new Timer.Timer();
		_handler_timer = new Timer.Timer();
		_waiting_data_timer = new Timer.Timer();
		_handler = handler;
		_tesla = null;

		if (Application.getApp().getProperty("enhancedTouch")) {
			Application.getApp().setProperty("spinner", "+");
		}
		else {
			Application.getApp().setProperty("spinner", "/");
		}
		
// _debugTimer = System.getTimer(); Application.getApp().setProperty("overrideCode", 0);

		var createdAt = Application.getApp().getProperty("TokenCreatedAt");
		if (createdAt == null) {
			createdAt = 0;
		}
		else {
			createdAt = createdAt.toNumber();
		}
		var expireIn = Application.getApp().getProperty("TokenExpiresIn");
		if (expireIn == null) {
			expireIn = 0;
		}
		else {
			expireIn = expireIn.toNumber();
		}
		
		// Check if we need to refresh our access token
		var timeNow = Time.now().value();
		var interval = 5 * 60;
		var answer = (timeNow + interval < createdAt + expireIn);
		
		if (_token != null && _token.length() != 0 && answer == true ) {
			_need_auth = false;
			_auth_done = true;
/*2023-02-18
var expireAt = new Time.Moment(createdAt + expireIn);
var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
logMessage("initialize:Using token '" + _token.substring(0,10) + "...' which expires at " + dateStr);
*/
		} else {
//2023-02-18 logMessage("initialize:No token or expired, will need to get one through a refresh token or authentication");
			_need_auth = true;
			_auth_done = false;
		}

		_check_wake = false; // If we get a 408 on first try or after 20 consecutive 408, see if we should wake up again 
		_need_wake = false; // Assume we're awake and if we get a 408, then wake up (just like _vehicle_state is set to online)
		_wake_done = true;
		_wakeTime = System.getTimer();
		_firstTime = true; // So the Waking up is displayed right away if it's the first time and the the first 408 generate a wake commmand
		_showingRequestingData = true; // When we launch, that string will be displayed so flag it true here

		_set_climate_on = false;
		_set_climate_off = false;
		_set_climate_defrost = false;
		_set_climate_set = false;
		_set_charging_amps_set = false;
		_set_charging_limit_set = false;
		_toggle_charging_set = false;
		_honk_horn = false;
		_open_port = false;
		_close_port = false;
		_open_frunk = false;
		_open_trunk = false;
		_unlock = false;
		_lock = false;
		_vent = false;
		_set_seat_heat = false;
		_set_steering_wheel_heat = false;
		_adjust_departure = false;
		_sentry_mode = false;
		_homelink = false;
		_remote_boombox = false;
		_climate_mode = false;
		_set_refresh_time = false;
		_view_datascreen = false;
		_bypass_confirmation = false;

		_408_count = 0;
		_refreshTimeInterval = Application.getApp().getProperty("refreshTimeInterval");
		if (_refreshTimeInterval == null) {
			_refreshTimeInterval = 4000;
		}

		_skipGetVehicleData = false;
		_waitingForVehicleData = false;
		_lastTimeStamp = 0;

//logMessage("StateMachine: Initialize");
		stateMachine();
	}

	function onReceive(args) {
		if (args == 0) { // The sub page ended and sent us a _handler.invoke(0) call, that's our cue to restart our timer and display our main view
//logMessage("StateMachine: onReceive");
			stateMachine();

		}
		else if (args == 1) { // Swiped left on subview 1, show subview 2
			var view = new ChargeView(_view._data);
			var delegate = new ChargeDelegate(view, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else if (args == 2) { // Swiped left on subview 2, show subview 3
			var view = new ClimateView(_view._data);
			var delegate = new ClimateDelegate(view, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else if (args == 3) { // Swiped left on subview 3, show subview 4 (but none so go back to main screen)
			var view = new DriveView(_view._data);
			var delegate = new DriveDelegate(view, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT); // <<<<<<<<<<<==================== TODO Check if change from _view to Ui affects the display of the data fields. 
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
		var code = message.data[$.OAUTH_CODE];
		var error = message.data[$.OAUTH_ERROR];
		if (message.data != null) {
//2023-02-18 logMessage("onOAuthMessage code: '" + code + "' error: '" + error + "'");
			_handler.invoke([3, Ui.loadResource(Rez.Strings.label_requesting_data)]);
			_showingRequestingData = true;
			var codeForBearerUrl = "https://" + Application.getApp().getProperty("serverAUTHLocation") + "/oauth2/v3/token";
			var codeForBearerParams = {
				"grant_type" => "authorization_code",
				"client_id" => "ownerapi",
				"code" => code,
				"code_verifier" => _code_verifier,
				"redirect_uri" => "https://" + Application.getApp().getProperty("serverAUTHLocation") + "/void/callback"
			};

			var codeForBearerOptions = {
				:method => Communications.HTTP_REQUEST_METHOD_POST,
				:headers => {
				   "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
				   "User-Agent" => "Tesla-Link for Garmin"
				},
				:responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
			};

//2023-02-18 logMessage("onOAuthMessage makeWebRequest codeForBearerUrl: '" + codeForBearerUrl + "' codeForBearerParams: '" + codeForBearerParams + "' codeForBearerOptions: '" + codeForBearerOptions + "'");
logMessage("stateMachine: Asking for access token through an OAUTH2");
			Communications.makeWebRequest(codeForBearerUrl, codeForBearerParams, codeForBearerOptions, method(:onReceiveToken));
		} else {
			_need_auth = true;
			_auth_done = false;
			if (error == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
				_vehicle_id = -2;
	        }
//2023-02-18 logMessage("onOAuthMessage " + error + " reseting token");
			_resetToken();
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_oauth_error)]);
			_sleep_timer.start(method(:stateMachine), 100, false);
		}
	}

	function onReceiveToken(responseCode, data) {
logMessage("onReceiveToken " + responseCode);
		if (responseCode == 200) {
			_auth_done = true;

		   _handler.invoke([3, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n" + Ui.loadResource(Rez.Strings.label_got_token)]);
			_showingRequestingData = true;

			var accessToken = data["access_token"];
			var refreshToken = data["refresh_token"];
			var expires_in = data["expires_in"];
			var created_at = Time.now().value();

var expireAt = new Time.Moment(created_at + expires_in);
var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
logMessage("onReceiveToken acces token expires at " + dateStr);

			_saveToken(accessToken);
			if (refreshToken != null && refreshToken.equals("") == false) { // Only if we received a refresh tokem
/*2023-02-18 if (accessToken != null) {
	logMessage("onReceiveToken refresh token: " + refreshToken.substring(0,20) + "... + access token: " + accessToken.substring(0,20) + "... which expires at " + dateStr);
} else {
	logMessage("onReceiveToken refresh token: " + refreshToken.substring(0,20) + "... + NO ACCESS TOKEN");
}*/
				Settings.setRefreshToken(refreshToken, expires_in, created_at);
			}
/*2023-02-18 else {
	logMessage("onReceiveToken NO REFRESH TOKEN + access token: " + accessToken.substring(0,20) + "... which expires at " + dateStr);
}*/
//			_handler.invoke([0, null]);
		} else {
//2023-02-18 logMessage("onReceiveToken couldn't get tokens, clearing refresh token");
			// Couldn't refresh our access token through the refresh token, invalide it and try again (through username and password instead since our refresh token is now empty
			_need_auth = true;
			_auth_done = false;
			Settings.setRefreshToken(null, 0, 0);

			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
	    }

		_sleep_timer.start(method(:stateMachine), 100, false);
	}

	function GetAccessToken(token, notify) {
		var url = "https://" + Application.getApp().getProperty("serverAUTHLocation") + "/oauth2/v3/token";
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

	function stateMachine() {
logMessage("stateMachine " + (_vehicle_id != null && _vehicle_id > 0 ? "" : "vehicle_id " + _vehicle_id) + " vehicle_state " + _vehicle_state + (_need_auth ? " _need_auth true" : "") + (!_auth_done ? " _auth_done false" : "") + (_check_wake ? " _check_wake true" : "") + (_need_wake ? " _need_wake true" : "") + (!_wake_done ? " _wake_done false" : ""));
		var _spinner = Application.getApp().getProperty("spinner");
		if (_spinner.equals("+")) {
			Application.getApp().setProperty("spinner", "-");
		}
		else if (_spinner.equals("-")) {
			Application.getApp().setProperty("spinner", "+");
		}
		else if (_spinner.equals("/")) {
			Application.getApp().setProperty("spinner", "\\");
		} else {
			Application.getApp().setProperty("spinner", "/");
		}

		if (_skipGetVehicleData) {
logMessage("StateMachine: Skipping stateMachine");
			return;
		}

		var resetNeeded = Application.getApp().getProperty("ResetNeeded");
		if (resetNeeded != null && resetNeeded == true) {
			Application.getApp().setProperty("ResetNeeded", false);
			_vehicle_id = -1;
			_need_auth = true;
		}

		if (_need_auth) {
			_need_auth = false;

			// Do we have a refresh token? If so, try to use it instead of login in
			var _refreshToken = Settings.getRefreshToken();
			if (_refreshToken != null && _refreshToken.length() != 0) {
logMessage("stateMachine: Asking for access token through saved refresh token " + _refreshToken.substring(0,20) + "...");
	    		_handler.invoke([3, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n" + Ui.loadResource(Rez.Strings.label_authenticating_with_token)]);
				_showingRequestingData = true;
				GetAccessToken(_refreshToken, method(:onReceiveToken));
			}
			else {
logMessage("stateMachine: Building an OAUTH2 request");
	        	_handler.invoke([3, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n" + Ui.loadResource(Rez.Strings.label_authenticating_with_login)]);
				_showingRequestingData = true;

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
	                "redirect_uri" => "https://" + Application.getApp().getProperty("serverAUTHLocation") + "/void/callback",
	                "response_type" => "code",
	                "scope" => "openid email offline_access",
	                "state" => "123"
	            };
//2023-02-18 logMessage("params=" + params);
	            
	            _handler.invoke([3, Ui.loadResource(Rez.Strings.label_login_on_phone)]);
	
logMessage("stateMachine: Registring an OAUTH2 request");
	            Communications.registerForOAuthMessages(method(:onOAuthMessage));
	            Communications.makeOAuthRequest(
	                "https://" + Application.getApp().getProperty("serverAUTHLocation") + "/oauth2/v3/authorize",
	                params,
	                "https://" + Application.getApp().getProperty("serverAUTHLocation") + "/void/callback",
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
logMessage("StateMachine: auth NOT done");
			return;
		}

		if (_tesla == null) {
			_tesla = new Tesla(_token);
		}

		if (_vehicle_id == -2) {
			_tesla.getVehicleId(method(:selectVehicle));
			_vehicle_id = -1;
			return;
		}
		if (_vehicle_id == null || _vehicle_id == -1 || _check_wake) { // -1 means the vehicle ID needs to be refreshed.
logMessage("StateMachine: Need to get vehicles list with _vehicle_id " +  (_vehicle_id != null && _vehicle_id > 0 ? "set" : _vehicle_id) + " and _check_wake=" + _check_wake);
			if (_vehicle_id == null) {
	            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
			} else {
//2023-02-18 logMessage("StateMachine: Asking to test if we're awake");
			}
			_tesla.getVehicleId(method(:onReceiveVehicles));
			return;
		}

// 2022-05-21 logMessage("stateMachine: vehicle_state = '" + _vehicle_state + "' _408_count = " + _408_count + " _need_wake = " + _need_wake);
		if (_vehicle_state.equals("online") == false) { // Only matters if we're not online, otherwise be silent
			var timeAsking = System.getTimer() - _wakeTime;
			if (_firstTime) {
	            _handler.invoke([3, Ui.loadResource(Rez.Strings.label_waking_vehicle) + "\n(" + timeAsking / 1000 + "s)"]);
				_showingRequestingData = false;

	        } else {
	            _handler.invoke([3, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n(" + timeAsking / 1000 + "s)"]);
				_showingRequestingData = true;
	        }
		}

		if (_need_wake) { // Asked to wake up
logMessage("stateMachine:Need to wake vehicle");
			if (_firstTime) { // As if we should wake the vehicle
	            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_should_we_wake) + Application.getApp().getProperty("vehicle_name") + "?");
	            var delegate = new SimpleConfirmDelegate(method(:wakeConfirmed), method(:wakeCanceled));
	            Ui.pushView(view, delegate, Ui.SLIDE_UP);
			} else {
				_need_wake = false; // Do it only once
				_wake_done = false;
				_tesla.wakeVehicle(_vehicle_id, method(:onReceiveAwake));
			}
			return;
		}

		if (!_wake_done) { // If wake_done is true, we got our 200 in the onReceiveAwake, now it's time to ask for data, otherwise get out and check again
			return;
		}

		var _handlerType;
		if (Application.getApp().getProperty("quickReturn")) {
			_handlerType = 1;
		}
		else {
			_handlerType = 2;
		}

		if (_set_climate_on) {
logMessage("StateMachine: Climate On - waiting for climateStateHandler");
			_set_climate_on = false;
			_skipGetVehicleData = true;
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_hvac_on)]);
			_tesla.climateOn(_vehicle_id, method(:climateStateHandler));
		}

		if (_set_climate_off) {
logMessage("StateMachine: Climate Off - waiting for climateStateHandler");
			_set_climate_off = false;
			_skipGetVehicleData = true;
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_hvac_off)]);
			_tesla.climateOff(_vehicle_id, method(:climateStateHandler));
		}

		if (_set_climate_defrost) {
logMessage("StateMachine: Climate Defrost - waiting for climateStateHandler");
			_set_climate_defrost = false;
			_skipGetVehicleData = true;
			_handler.invoke([_handlerType, Ui.loadResource(_data._vehicle_data.get("climate_state").get("defrost_mode") == 2 ? Rez.Strings.label_defrost_off : Rez.Strings.label_defrost_on)]);
			_tesla.climateDefrost(_vehicle_id, method(:climateStateHandler), _data._vehicle_data.get("climate_state").get("defrost_mode"));
		}

		if (_set_climate_set) {
logMessage("StateMachine: Climate set temperature - waiting for genericHandler");
			_set_climate_set = false;
			var temperature = Application.getApp().getProperty("driver_temp");
			if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
				temperature = temperature * 9 / 5 + 32;
				_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_climate_set) + temperature.format("%d") + "°F"]);
			} else {
				_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_climate_set) + temperature.format("%.1f") + "°C"]);
			}
			_tesla.climateSet(_vehicle_id, method(:genericHandler), temperature);
		}

		if (_toggle_charging_set) {
logMessage("StateMachine: Toggling charging - waiting for genericHandler");
			_toggle_charging_set = false;
			_handler.invoke([_handlerType, Ui.loadResource(_data._vehicle_data.get("charge_state").get("charging_state").equals("Charging") ? Rez.Strings.label_stop_charging : Rez.Strings.label_start_charging)]);
			_tesla.toggleCharging(_vehicle_id, method(:genericHandler), _data._vehicle_data.get("charge_state").get("charging_state").equals("Charging"));
		}

		if (_set_charging_limit_set) {
logMessage("StateMachine: Setting charge limit - waiting for genericHandler");
			_set_charging_limit_set = false;
			var charging_limit = Application.getApp().getProperty("charging_limit");
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_charging_limit) + charging_limit + "%"]);
			_tesla.setChargingLimit(_vehicle_id, method(:genericHandler), charging_limit);
		}

		if (_set_charging_amps_set) {
logMessage("StateMachine: Setting max current - waiting for genericHandler");
			_set_charging_amps_set = false;
			var charging_amps = Application.getApp().getProperty("charging_amps");
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_charging_amps) + charging_amps + "A"]);
			_tesla.setChargingAmps(_vehicle_id, method(:genericHandler), charging_amps);
		}

		if (_honk_horn) {
			_honk_horn = false;
			if (_bypass_confirmation) {
				_bypass_confirmation = false;
				honkHornConfirmed();
			} else {
				var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_honk_horn));
				var delegate = new SimpleConfirmDelegate(method(:honkHornConfirmed), null);
				Ui.pushView(view, delegate, Ui.SLIDE_UP);
			}
		}

		if (_open_port) {
logMessage("StateMachine: Opening on charge port - waiting for chargeStateHandler");
			_open_port = false;
			_skipGetVehicleData = true;
	    	_handler.invoke([_handlerType, Ui.loadResource(_data._vehicle_data.get("charge_state").get("charge_port_door_open") ? Rez.Strings.label_unlock_port : Rez.Strings.label_open_port)]);
			_tesla.openPort(_vehicle_id, method(:chargeStateHandler));
		}

		if (_close_port) {
logMessage("StateMachine: Closing on charge port - waiting for chargeStateHandler");
			_close_port = false;
			_skipGetVehicleData = true;
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_close_port)]);
			_tesla.closePort(_vehicle_id, method(:chargeStateHandler));
		}

		if (_unlock) {
logMessage("StateMachine: Unlock - waiting for vehicleStateHandler");
			_unlock = false;
			_skipGetVehicleData = true;
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_unlock_doors)]);
			_tesla.doorUnlock(_vehicle_id, method(:vehicleStateHandler));
		}

		if (_lock) {
logMessage("StateMachine: Lock - waiting for vehicleStateHandler");
			_lock = false;
			_skipGetVehicleData = true;
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_lock_doors)]);
			_tesla.doorLock(_vehicle_id, method(:vehicleStateHandler));
		}

		if (_open_frunk) {
			_open_frunk = false;
			if (_bypass_confirmation) {
				_bypass_confirmation = false;
				frunkConfirmed();
			}
			else {
	            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_open_frunk));
	            var delegate = new SimpleConfirmDelegate(method(:frunkConfirmed), null);
	            Ui.pushView(view, delegate, Ui.SLIDE_UP);
	        }
		}

		if (_open_trunk) {
			_open_trunk = false;
			if (_bypass_confirmation) {
				_bypass_confirmation = false;
				trunkConfirmed();
			}
			else {
	            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_open_trunk));
	            var delegate = new SimpleConfirmDelegate(method(:trunkConfirmed), null);
	            Ui.pushView(view, delegate, Ui.SLIDE_UP);
	        }
		}

		if (_vent) {
			_vent = false;
			var venting = Application.getApp().getProperty("venting");

			if (venting == 0) {
	            if (_bypass_confirmation) {
	            	_bypass_confirmation = false;
	            	openVentConfirmed();
	            } else {
		            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_open_vent));
		            var delegate = new SimpleConfirmDelegate(method(:openVentConfirmed), null);
		            Ui.pushView(view, delegate, Ui.SLIDE_UP);
		        }
			}
			else {
	            if (_bypass_confirmation) {
	            	_bypass_confirmation = false;
	            	closeVentConfirmed();
	            } else {
		            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_close_vent));
		            var delegate = new SimpleConfirmDelegate(method(:closeVentConfirmed), null);
		            Ui.pushView(view, delegate, Ui.SLIDE_UP);
	            }
			}
		}

		if (_set_seat_heat) {
logMessage("StateMachine: Setting seat heat - waiting for genericHandler");
			_set_seat_heat = false;
			var seat_chosen = Application.getApp().getProperty("seat_chosen");
			var seat_heat_chosen = Application.getApp().getProperty("seat_heat_chosen");

			switch (seat_heat_chosen) {
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
					seat_heat_chosen = 0;
					break;
			}

			_handler.invoke([_handlerType, Ui.loadResource(seat_chosen)]);

	        if (seat_chosen == Rez.Strings.label_seat_driver) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 0, seat_heat_chosen);
	        } else if (seat_chosen == Rez.Strings.label_seat_passenger) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 1, seat_heat_chosen);
	        } else if (seat_chosen == Rez.Strings.label_seat_rear_left) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 2, seat_heat_chosen);
	        } else if (seat_chosen == Rez.Strings.label_seat_rear_center) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 4, seat_heat_chosen);
	        } else if (seat_chosen == Rez.Strings.label_seat_rear_right) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 5, seat_heat_chosen);
			}
		}

		if (_set_steering_wheel_heat) {
			_set_steering_wheel_heat = false;
logMessage("StateMachine: Setting steering wheel heat - waiting for climateStateHandler");
	        if (_data._vehicle_data != null && _data._vehicle_data.get("climate_state").get("is_climate_on") == false) {
	            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_steering_wheel_need_climate_on)]);
	            _sleep_timer.start(method(:stateMachine), 100, false);
	        }
	        else {
				_skipGetVehicleData = true;
	            _handler.invoke([_handlerType, Ui.loadResource(_data._vehicle_data.get("climate_state").get("steering_wheel_heater") == true ? Rez.Strings.label_steering_wheel_off : Rez.Strings.label_steering_wheel_on)]);
	            _tesla.climateSteeringWheel(_vehicle_id, method(:climateStateHandler), _data._vehicle_data.get("climate_state").get("steering_wheel_heater"));
	        }
		}
		
		if (_adjust_departure) {
			_adjust_departure = false;
			_skipGetVehicleData = true;
			if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
logMessage("StateMachine: Preconditionning off - waiting for chargeStateHandler");
	            _handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_stop_departure)]);
	            _tesla.setDeparture(_vehicle_id, method(:chargeStateHandler), Application.getApp().getProperty("departure_time"), false);
	        }
	        else {
logMessage("StateMachine: Preconditionning on - waiting for chargeStateHandler");
	            _handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_start_departure)]);
	            _tesla.setDeparture(_vehicle_id, method(:chargeStateHandler), Application.getApp().getProperty("departure_time"), true);
	        }
		}

		if (_sentry_mode) {
			_sentry_mode = false;
			_skipGetVehicleData = true;
			if (_data._vehicle_data.get("vehicle_state").get("sentry_mode")) {
	            _handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_sentry_off)]);
	            _tesla.SentryMode(_vehicle_id, method(:vehicleStateHandler), false);
			} else {
	            _handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_sentry_on)]);
	            _tesla.SentryMode(_vehicle_id, method(:vehicleStateHandler), true);
			}
		}

		if (_homelink) {
logMessage("StateMachine: Homelink - waiting for genericHandler");
			_homelink = false;
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_homelink)]);
	        _tesla.homelink(_vehicle_id, method(:genericHandler), Application.getApp().getProperty("latitude"), Application.getApp().getProperty("longitude"));
		}

		if (_remote_boombox) {
logMessage("StateMachine: Remote Boombox - waiting for genericHandler");
			_remote_boombox = false;
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_remote_boombox)]);
	        _tesla.remoteBoombox(_vehicle_id, method(:genericHandler));
		}

		if (_climate_mode) {
			_climate_mode = false;

			var mode_chosen_str;
			var mode_chosen;

			mode_chosen_str = Application.getApp().getProperty("climate_mode_chosen");
			switch (mode_chosen_str) {
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
logMessage("StateMachine: ClimateMode - setting mode to " + Ui.loadResource(mode_chosen_str) + "- calling genericHandler");
			_handler.invoke([_handlerType, Ui.loadResource(Rez.Strings.label_climate_mode) + Ui.loadResource(mode_chosen_str)]);
	        _tesla.setClimateMode(_vehicle_id, method(:genericHandler), mode_chosen);
		}

		if (_set_refresh_time) {
			_set_refresh_time = false;
			_refreshTimeInterval = Application.getApp().getProperty("refreshTimeInterval");
			if (_refreshTimeInterval == null) {
				_refreshTimeInterval = 1000;
			}
logMessage("StateMachine: refreshTimeInterval at " + _refreshTimeInterval + " - not calling a handler");
		}
		
		if (_view_datascreen) {
			_view_datascreen = false;
			onReceive(1); // Show the first submenu
		}

		if (!_skipGetVehicleData) {
			if (!_waitingForVehicleData) {
				_lastDataRun = System.getTimer();
				_waitingForVehicleData = true; // So we don't overrun our buffers by multiple calls doing the same thing
				if (_showingRequestingData) {
					_waiting_data_timer.start(method(:waitingVehicleData), 5000, false);
				}
				_tesla.getVehicleData(_vehicle_id, method(:onReceiveVehicleData));
			} else {
logMessage("StateMachine: Already waiting for data, skipping");
			}
		} else {
logMessage("StateMachine: Skipping requesting data");
		}
	}

	function waitingVehicleData()
	{
		if (_showingRequestingData && _waitingForVehicleData && _view._data._ready == false) { // Are we still showing the requested data message?
logMessage("waitingVehicleData: We're STILL waiting for data");
			_handler.invoke([3, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n" + Ui.loadResource(Rez.Strings.label_requesting_data_waiting)]);
		}
	}

	function wakeConfirmed() {
		_need_wake = false;
		_wake_done = false;
		_wakeTime = System.getTimer();
logMessage("wakeConfirmed:Asking to wake vehicle");
		_tesla.wakeVehicle(_vehicle_id, method(:onReceiveAwake));
	}

	function wakeCanceled() {
		_vehicle_id = -2; // Tells StateMachine to popup a list of vehicles
		stateMachine();
	}

	function openVentConfirmed() {
		_handler.invoke([Application.getApp().getProperty("quickReturn") ? 1 : 2, Ui.loadResource(Rez.Strings.label_vent_opening)]);
logMessage("StateMachine: Open vent - waiting for vehicleStateHandler");
		_skipGetVehicleData = true;
		_tesla.vent(_vehicle_id, method(:vehicleStateHandler), "vent", Application.getApp().getProperty("latitude"), Application.getApp().getProperty("longitude"));
	}

	function closeVentConfirmed() {
	    _handler.invoke([Application.getApp().getProperty("quickReturn") ? 1 : 2, Ui.loadResource(Rez.Strings.label_vent_closing)]);
logMessage("StateMachine: Close vent - waiting for vehicleStateHandler");
		_skipGetVehicleData = true;
		_tesla.vent(_vehicle_id, method(:vehicleStateHandler), "close", Application.getApp().getProperty("latitude"), Application.getApp().getProperty("longitude"));
	}

	function frunkConfirmed() {
logMessage("StateMachine: Acting on frunk - waiting for vehicleStateHandler");
		var hansshowFrunk = Application.getApp().getProperty("HansshowFrunk");
		if (hansshowFrunk) {
	        _handler.invoke([Application.getApp().getProperty("quickReturn") ? 1 : 2, Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("ft") == 0 ? Rez.Strings.label_frunk_opening : Rez.Strings.label_frunk_closing)]);
			_skipGetVehicleData = true;
			_tesla.openTrunk(_vehicle_id, method(:vehicleStateHandler), "front");
		} else {
			if (_data._vehicle_data.get("vehicle_state").get("ft") == 0) {
				_handler.invoke([Application.getApp().getProperty("quickReturn") ? 1 : 2, Ui.loadResource(Rez.Strings.label_frunk_opening)]);
				_skipGetVehicleData = true;
				_tesla.openTrunk(_vehicle_id, method(:vehicleStateHandler), "front");
			} else {
				_handler.invoke([1, Ui.loadResource(Rez.Strings.label_frunk_opened)]);
	            _sleep_timer.start(method(:stateMachine), 100, false);
			}
		}
	}

	function trunkConfirmed() {
logMessage("StateMachine: Acting on trunk - waiting for vehicleStateHandler");
		_handler.invoke([Application.getApp().getProperty("quickReturn") ? 1 : 2, Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("rt") == 0 ? Rez.Strings.label_trunk_opening : Rez.Strings.label_trunk_closing)]);
		_skipGetVehicleData = true;
		_tesla.openTrunk(_vehicle_id, method(:vehicleStateHandler), "rear");
	}

	function honkHornConfirmed() {
logMessage("StateMachine: Honking - waiting for genericHandler");
		_handler.invoke([Application.getApp().getProperty("quickReturn") ? 1 : 2, Ui.loadResource(Rez.Strings.label_honk)]);
		_tesla.honkHorn(_vehicle_id, method(:genericHandler));
	}

	function onSelect() {
		if (Application.getApp().getProperty("useTouch")) {
			return false;
		}

		doSelect();
		return true;
	}

	function doSelect() {
		if (_data._vehicle_data != null && _data._vehicle_data.get("climate_state").get("is_climate_on") == false) {
			_set_climate_on = true;
		} else {
			_set_climate_off = true;
		}
// 2022-10-10 logMessage("stateMachine: doSelect");
		stateMachine();
	}

	function onNextPage() {
		if (Application.getApp().getProperty("useTouch")) {
			return false;
		}

		doNextPage();
		return true;
	}

	function doNextPage() {
		if (_data._vehicle_data != null && !_data._vehicle_data.get("vehicle_state").get("locked")) {
			_lock = true;
		} else {
			_unlock = true;
		}
// 2022-10-10 logMessage("stateMachine: doNextPage");
		stateMachine();
	}

	function onPreviousPage() {
		if (Application.getApp().getProperty("useTouch")) {
			return false;
		}

		doPreviousPage();
		return true;
	}

	function doPreviousPage() {
		if (Application.getApp().getProperty("swap_frunk_for_port") == 0) {
			_open_frunk = true;
		}
		else if (Application.getApp().getProperty("swap_frunk_for_port") == 1) {
			_open_trunk = true;
		}
		else if (Application.getApp().getProperty("swap_frunk_for_port") == 2) {
	        _open_port = true;
		}
		else {
			var menu = new Ui.Menu();

			if (_data._vehicle_data != null && _data._vehicle_data.get("vehicle_state").get("ft") == 0) {
				menu.addItem(Rez.Strings.menu_label_open_frunk, :open_frunk);
			}
			else if (Application.getApp().getProperty("HansshowFrunk")) {
				menu.addItem(Rez.Strings.menu_label_close_frunk, :open_frunk);
			}

			if (_data._vehicle_data != null && _data._vehicle_data.get("vehicle_state").get("rt") == 0) {
				menu.addItem(Rez.Strings.menu_label_open_trunk, :open_trunk);
			}
			else {
				menu.addItem(Rez.Strings.menu_label_close_trunk, :open_trunk);
			}

			if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charge_port_door_open") == false) {
				menu.addItem(Rez.Strings.menu_label_open_port, :open_port);
			} else if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charging_state").equals("Disconnected")) {
				menu.addItem(Rez.Strings.menu_label_close_port, :close_port);
			} else if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charging_state").equals("Charging")) {
				menu.addItem(Rez.Strings.menu_label_stop_charging, :toggle_charge);
			} else {
				menu.addItem(Rez.Strings.menu_label_unlock_port, :open_port);
			}

			if (Application.getApp().getProperty("venting") == 0) {
				menu.addItem(Rez.Strings.menu_label_open_vent, :vent);
			}
			else {
				menu.addItem(Rez.Strings.menu_label_close_vent, :vent);
			}

			Ui.pushView(menu, new TrunksMenuDelegate(self), Ui.SLIDE_UP );
		}
// 2022-10-10 logMessage("stateMachine: doPreviousPage");
		stateMachine();
	}

	function onBack() {
		return false;
	}

	function onMenu() {
		if (Application.getApp().getProperty("useTouch")) {
			return false;
		}

		doMenu();
		return true;
	}

	function addMenuItem(menu, slot)
	{
		var _slot_str = "option_slot" + slot;
		var _index = Application.getApp().getProperty(_slot_str);
		if (_index == null) {
			return;
		} else if (!(_index instanceof Number)) {
			_index = _index.toNumber();
		}

		if (_index < 0) {
			_index = 0;
		}
		else if (_index > 23) {
			_index = 23;
		}

		switch (_index) {
			case 0:
		        if (_data._vehicle_data != null && _data._vehicle_data.get("climate_state").get("defrost_mode") == 2) {
					menu.addItem(Rez.Strings.menu_label_defrost_off, :defrost);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_defrost_on, :defrost);
				}
				break;
			case 1:
				menu.addItem(Rez.Strings.menu_label_set_seat_heat, :set_seat_heat);
				break;
			case 2:
		        if (_data._vehicle_data != null && _data._vehicle_data.get("climate_state").get("steering_wheel_heater") == true) {
					menu.addItem(Rez.Strings.menu_label_set_steering_wheel_heat_off, :set_steering_wheel_heat);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_set_steering_wheel_heat_on, :set_steering_wheel_heat);
				}
				break;
			case 3:
				menu.addItem(Rez.Strings.menu_label_set_charging_limit, :set_charging_limit);
				break;
			case 4:
				menu.addItem(Rez.Strings.menu_label_set_charging_amps, :set_charging_amps);
				break;
			case 5:
		        if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charging_state").equals("Charging")) {
					menu.addItem(Rez.Strings.menu_label_stop_charging, :toggle_charge);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_start_charging, :toggle_charge);
				}
				break;
			case 6:
				menu.addItem(Rez.Strings.menu_label_set_temp, :set_temperature);
				break;
			case 7:
				if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
					menu.addItem(Rez.Strings.menu_label_stop_departure, :adjust_departure);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_start_departure, :adjust_departure);
				}
				break;
			case 8:
				if (_data._vehicle_data.get("vehicle_state").get("sentry_mode")) {
					menu.addItem(Rez.Strings.menu_label_sentry_off, :toggle_sentry);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_sentry_on, :toggle_sentry);
				}
				break;
			case 9:
				menu.addItem(Rez.Strings.menu_label_honk, :honk);
				break;
			case 10:
		        if (_data._vehicle_data != null && _data._vehicle_data.get("vehicle_state").get("ft") == 0) {
					menu.addItem(Rez.Strings.menu_label_open_frunk, :open_frunk);
				}
				else if (Application.getApp().getProperty("HansshowFrunk")) {
					menu.addItem(Rez.Strings.menu_label_close_frunk, :open_frunk);
				}
				break;
			case 11:
		        if (_data._vehicle_data != null && _data._vehicle_data.get("vehicle_state").get("rt") == 0) {
					menu.addItem(Rez.Strings.menu_label_open_trunk, :open_trunk);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_close_trunk, :open_trunk);
				}
				break;
			case 12:
				if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charge_port_door_open") == false) {
					menu.addItem(Rez.Strings.menu_label_open_port, :open_port);
				} else if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charging_state").equals("Disconnected")) {
					menu.addItem(Rez.Strings.menu_label_close_port, :close_port);
				} else if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charging_state").equals("Charging")) {
					menu.addItem(Rez.Strings.menu_label_stop_charging, :toggle_charge);
				} else {
					menu.addItem(Rez.Strings.menu_label_unlock_port, :open_port);
				}

				break;
			case 13:
				if (Application.getApp().getProperty("venting") == 0) {
					menu.addItem(Rez.Strings.menu_label_open_vent, :vent);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_close_vent, :vent);
				}
				break;
			case 14:
				menu.addItem(Rez.Strings.menu_label_homelink, :homelink);
				break;
			case 15:
				menu.addItem(Rez.Strings.menu_label_toggle_view, :toggle_view);
				break;
			case 16:
				menu.addItem(Rez.Strings.menu_label_swap_frunk_for_port, :swap_frunk_for_port);
				break;
			case 17:
				menu.addItem(Rez.Strings.menu_label_datascreen, :data_screen);
				break;
			case 18:
				menu.addItem(Rez.Strings.menu_label_select_car, :select_car);
				break;
			case 19:
				menu.addItem(Rez.Strings.menu_label_reset, :reset);
				break;
			case 20:
				menu.addItem(Rez.Strings.menu_label_wake, :wake);
				break;
			case 21:
				menu.addItem(Rez.Strings.menu_label_refresh, :refresh);
				break;
			case 22:
				menu.addItem(Rez.Strings.menu_label_remote_boombox, :remote_boombox);
				break;
			case 23:
				menu.addItem(Rez.Strings.menu_label_climate_mode, :climate_mode);
				break;
		}
	}
	
	function doMenu() {
		if (!_auth_done) {
			return;
		}

		var _slot_count = Application.getApp().getProperty("NumberOfSlots");
		if (_slot_count == null) {
			_slot_count = 16;
		} else if (!(_slot_count instanceof Number)) {
			_slot_count = _slot_count.toNumber();
		}

		if (_slot_count < 1) {
			_slot_count = 1;
		}
		else if (_slot_count > 16) { // Maximum of 16 entries in a menu
			_slot_count = 16;
		}
		
		var thisMenu = new Ui.Menu();
		
		thisMenu.setTitle(Rez.Strings.menu_option_title);
		for (var i = 1; i <= _slot_count; i++) {
			addMenuItem(thisMenu, i);
		}
		
		Ui.pushView(thisMenu, new OptionMenuDelegate(self), Ui.SLIDE_UP );
	}

	function onTap(click) {
		if (!_data._ready)
		{
			return true;
		}
		
		var coords = click.getCoordinates();
		var x = coords[0];
		var y = coords[1];
		var enhancedTouch = Application.getApp().getProperty("enhancedTouch");
		if (enhancedTouch == null) {
			enhancedTouch = true;
		}

logMessage("stateMachine: onTap - enhancedTouch=" + enhancedTouch);

		// Tap on vehicle name
		if (enhancedTouch && y < _settings.screenHeight / 6 && _tesla != null) {
			_tesla.getVehicleId(method(:selectVehicle));
		}
		// Tap on the space used by the 'Eye'
		else if (enhancedTouch && y > _settings.screenHeight / 6 && y < _settings.screenHeight / 4 && x > _settings.screenWidth / 2 - _settings.screenWidth / 19 && x < _settings.screenWidth / 2 + _settings.screenWidth / 19) {
			_sentry_mode = true;
			stateMachine();
		}
		// Tap on the middle text line where Departure is written
		else if (enhancedTouch && y > _settings.screenHeight / 2 - _settings.screenHeight / 19 && y < _settings.screenHeight / 2 + _settings.screenHeight / 19) {
			if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
	            _adjust_departure = true;
	            stateMachine();
			}
			else {
				Ui.pushView(new DepartureTimePicker(_data._vehicle_data.get("charge_state").get("scheduled_departure_time_minutes")), new DepartureTimePickerDelegate(self), Ui.SLIDE_IMMEDIATE);
			}
		} 
		// Tap on bottom line on screen
		else if (enhancedTouch && y > _settings.screenHeight - _settings.screenHeight / 6 && _tesla != null) {
			var screenBottom = Application.getApp().getProperty(x < _settings.screenWidth / 2 ? "screenBottomLeft" : "screenBottomRight");
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
		            var driver_temp = Application.getApp().getProperty("driver_temp");
		            var max_temp = _data._vehicle_data.get("climate_state").get("max_avail_temp");
		            var min_temp = _data._vehicle_data.get("climate_state").get("min_avail_temp");
		            
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
		
		var coords = click.getCoordinates();
		var x = coords[0];
		var y = coords[1];

		if (x < _settings.screenWidth/2) {
			if (y < _settings.screenHeight/2) {
logMessage("stateMachine: onHold - Upper Left action");
				switch (Application.getApp().getProperty("holdActionUpperLeft")) {
					case 1:
						_open_frunk = true;
						_bypass_confirmation = true;
						stateMachine();
						break;

					case 2:
						_open_trunk = true;
						_bypass_confirmation = true;
						stateMachine();
						break;

					case 3:
						if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charge_port_door_open") == false) {
							_open_port = true;
						} else if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charging_state").equals("Disconnected")) {
							_close_port = true;
						} else if (_data._vehicle_data != null && _data._vehicle_data.get("charge_state").get("charging_state").equals("Charging")) {
							_toggle_charging_set = true;
						} else {
							_open_port = true;
						}
						stateMachine();
						break;

					case 3:
						_vent = true;
						_bypass_confirmation = true;
						stateMachine();
						break;

					default:
						break;
				}
			} else {
logMessage("stateMachine: onHold - Lower Left action");
				switch (Application.getApp().getProperty("holdActionLowerLeft")) {
					case 1:
						_honk_horn = true;
						_bypass_confirmation = true;
						stateMachine();
						break;

					default:
						break;
				}
			}
		} else {
			if (y < _settings.screenHeight/2) {
logMessage("stateMachine: onHold - Upper Right action");
				switch (Application.getApp().getProperty("holdActionUpperRight")) {
					case 1:
						_set_climate_defrost = true;
						stateMachine();
						break;

					default:
						break;
				}
			} else {
logMessage("stateMachine: onHold - Lower Right action");
				switch (Application.getApp().getProperty("holdActionLowerRight")) {
					case 1:
						_homelink = true;
						stateMachine();
						break;

					case 2:
						_remote_boombox = true;
						stateMachine();
						break;

					default:
						break;
				}
			}
		}

		return true;
	}

	function selectVehicle(responseCode, data) {
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
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
		}
	}

	function onReceiveVehicles(responseCode, data) {
logMessage("onReceiveVehicles: " + responseCode);
//logMessage("onReceiveVehicles:data is " + data);
		if (responseCode == 200) {
			var vehicles = data.get("response");
			var size = vehicles.size();
			if (size > 0) {
				// Need to retrieve the right vehicle, not just the first one!
				var vehicle_index = 0;
				var vehicle_name = Application.getApp().getProperty("vehicle_name");
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
				Application.getApp().setProperty("vehicle", _vehicle_id);
				Application.getApp().setProperty("vehicle_name", vehicles[vehicle_index].get("display_name"));

				stateMachine();
				return;
			} else {
				_handler.invoke([0, Ui.loadResource(Rez.Strings.label_no_vehicles)]);
			}
		} else {
			if (responseCode == 401) {
				// Unauthorized
				_resetToken();
	            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_unauthorized)]);
			} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
	        }

			_sleep_timer.start(method(:stateMachine), 100, false);
		}
	}

	function onReceiveVehicleData(responseCode, data) {
// DEBUG CODE FOR TESTING ERRORS
/*		//Application.getApp().setProperty("overrideCode", 0);
		var x = Application.getApp().getProperty("overrideCode");
		if (x != null and x != 0) {
			responseCode = x.toNumber();
		}

		if (System.getTimer() < _debugTimer + 10000 ) {
			responseCode = 408;
		}
		else if (System.getTimer() > _debugTimer + 20000 && System.getTimer() < _debugTimer + 30000) {
			responseCode = 408;
		}
*/
logMessage("onReceiveVehicleData: " + responseCode);
		_waitingForVehicleData = false;
		_showingRequestingData = false;

		if (_skipGetVehicleData) {
logMessage("onReceiveVehicleData: Asked to skip");
			return;
		}

		if (responseCode == 200) {
			_vehicle_state = "online"; // We got data so we got to be online

			// Check if this data feed is older than the previous one and if so, ignore it (two timers could create this situation)
			var response = data.get("response");
			if (response != null && response.hasKey("charge_state") && response.get("charge_state").hasKey("timestamp") && response.get("charge_state").get("timestamp") > _lastTimeStamp) {
				// Update the glance data
				if (System.getDeviceSettings() has :isGlanceModeEnabled && System.getDeviceSettings().isGlanceModeEnabled) { // If we have a glance view, update its status
					var battery_level = response.get("charge_state").get("battery_level");
					var battery_range = response.get("charge_state").get("battery_range") * (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6);
					var charging_state = response.get("charge_state").get("charging_state");

					var suffix;
					try {
						var clock_time = System.getClockTime();
						suffix = " @ " + clock_time.hour.format("%d")+ ":" + clock_time.min.format("%02d");
					} catch (e) {
						suffix = "";
					}
					Application.getApp().setProperty("status", battery_level + "%" + (charging_state.equals("Charging") ? "+" : "") + " / " + battery_range.toNumber() + suffix);
//2023-03-03 logMessage("onReceiveVehicleData set status to '" + Application.getApp().getProperty("status") + "'");
				}

				_data._vehicle_data = response;
				_lastTimeStamp = response.get("charge_state").get("timestamp");
// logMessage("onReceiveVehicleData received " + _data._vehicle_data);
				if (_data._vehicle_data.get("climate_state").hasKey("inside_temp") && _data._vehicle_data.get("charge_state").hasKey("battery_level")) {
if (_408_count) { logMessage("onReceiveVehicleData clearing _408_count"); }
					_408_count = 0; // Reset the count of timeouts since we got our data
					_firstTime = false;
					_handler.invoke([1, null]); // Refresh the screen only if we're not displaying something already that hasn't timed out
					var timeDelta = System.getTimer() - _lastDataRun; // Substract the time we spent waiting from the time interval we should run
// 2022-05-21 logMessage("onReceiveVehicleData: timeDelta is " + timeDelta);
					timeDelta = _refreshTimeInterval - timeDelta;
					if (timeDelta > 500) { // Make sure we leave at least 0.5 sec between calls
// 2022-05-21 logMessage("onReceiveVehicleData: Running StateMachine in " + timeDelta + " msec");
	                	_sleep_timer.start(method(:stateMachine), timeDelta, false);
						return;
					} else {
// 2022-05-21 logMessage("onReceiveVehicleData: Running StateMachine in no less than 500 msec");
					}
				} else {
// 2022-10-10 logMessage("onReceiveVehicleData: Received incomplete data, ignoring");
				}
			} else {
// 2022-10-10 logMessage("onReceiveVehicleData: Received an out or order data or missing timestamp, ignoring");
			}
			_sleep_timer.start(method(:stateMachine), 500, false);
			return;
		} else {
			if (responseCode == 408) { // We got a timeout, check if we're still awake
				if (System.getDeviceSettings() has :isGlanceModeEnabled && System.getDeviceSettings().isGlanceModeEnabled) { // If we have a glance view, update its status
					var suffix;
					try {
						var clock_time = System.getClockTime();
						suffix = " @ " + clock_time.hour.format("%d")+ ":" + clock_time.min.format("%02d");
					} catch (e) {
						suffix = "";
					}
					Application.getApp().setProperty("status", Application.loadResource(Rez.Strings.label_asleep) + suffix);
				}

				if (_vehicle_state.equals("online") == true && _firstTime && _view._data._ready == false) { // We think we're online, it's our first pass and we have already a message displayed
					var timeAsking = System.getTimer() - _wakeTime;
					_handler.invoke([3, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n(" + timeAsking / 1000 + "s)"]);
					_showingRequestingData = true;
				}

logMessage("onReceiveVehicleData: 408_count=" + _408_count + " firstTime=" + _firstTime);
	        	if ((_408_count % 20 == 0 && _firstTime) || (_408_count % 20 == 1 && !_firstTime)) { // First (if we've starting up), second (to let through a spurious 408) and every consecutive 20th 408 recieved will generate a test for the vehicle state. 
					if (_408_count < 2 && !_firstTime) { // Only when we first started to get the errors do we keep the start time
						_wakeTime = System.getTimer();
					}
// 2022-10-10 logMessage("onReceiveVehicleData: Got 408, Check if we need to wake up the car?");
					_check_wake = true;
	            }
				_408_count++;
			} else {
				if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
					_vehicle_id = -2;
		            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
				} else if (responseCode == 401) {
	                // Unauthorized, retry
	                _need_auth = true;
	                _resetToken();
		            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_unauthorized)]);
				} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
		            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
		        }
			}
	    }
		_sleep_timer.start(method(:stateMachine), 500, false);
	}

	function onReceiveAwake(responseCode, data) {
logMessage("onReceiveAwake: " + responseCode);
		if (responseCode == 200) {
			_wake_done = true;
			stateMachine();
			return;
	   } else {
		   // We were unable to wake, try again
			_need_wake = true;
			_wake_done = false;
			if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
				_vehicle_id = -2;
				_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			} else if (responseCode == 401) { // Unauthorized, retry
				_resetToken();
				_need_auth = true;
				_handler.invoke([0, Ui.loadResource(Rez.Strings.label_unauthorized)]);
			} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
				_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			}
		}
		_sleep_timer.start(method(:stateMachine), 100, false);
	}

   function onReceiveVehicleState(responseCode, data) {
logMessage("onReceiveVehicleState: " + responseCode + " calling StateMachine in  0.1 sec");
		var result = null;
		if (responseCode == 200) {
			var response = data.get("response");
			if (response != null && response.hasKey("timestamp") && response.get("timestamp") > _lastTimeStamp) {
				_lastTimeStamp = response.get("timestamp");
				_data._vehicle_data.get("vehicle_state").put("sentry_mode", response.get("sentry_mode"));
				_data._vehicle_data.get("vehicle_state").put("locked", response.get("locked"));
				_data._vehicle_data.get("vehicle_state").put("fd_window", response.get("fd_window"));
				_data._vehicle_data.get("vehicle_state").put("fp_window", response.get("fp_window"));
				_data._vehicle_data.get("vehicle_state").put("rd_window", response.get("rd_window"));
				_data._vehicle_data.get("vehicle_state").put("rp_window", response.get("rp_window"));
				_data._vehicle_data.get("vehicle_state").put("df", response.get("df"));
				_data._vehicle_data.get("vehicle_state").put("pf", response.get("pf"));
				_data._vehicle_data.get("vehicle_state").put("dr", response.get("dr"));
				_data._vehicle_data.get("vehicle_state").put("pr", response.get("pr"));
				_data._vehicle_data.get("vehicle_state").put("ft", response.get("ft"));
				_data._vehicle_data.get("vehicle_state").put("rt", response.get("rt"));
			} else {
logMessage("onReceiveVehicleState: Out of order data or missing timestamp, ignoring");
			}
		} else {
			result = Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + Ui.loadResource(Rez.Strings.label_error) + responseCode + "\n" + errorsStr[responseCode.toString()];
		}

		_handler.invoke([0, result]);
		_skipGetVehicleData = false;
		_sleep_timer.start(method(:stateMachine), 100, false);
	}

   function onReceiveClimateState(responseCode, data) {
logMessage("onReceiveClimateState " + responseCode + " calling StateMachine in  0.1 sec");
		var result = null;
		if (responseCode == 200) {
			var response = data.get("response");
			if (response != null && response.hasKey("timestamp") && response.get("timestamp") > _lastTimeStamp) {
				_lastTimeStamp = response.get("timestamp");
				_data._vehicle_data.get("climate_state").put("is_climate_on", response.get("is_climate_on"));
				_data._vehicle_data.get("climate_state").put("defrost_mode", response.get("defrost_mode"));
				_data._vehicle_data.get("climate_state").put("battery_heater", response.get("battery_heater"));
			} else {
logMessage("onReceiveClimateState: Out of order data or missing timestamp, ignoring");
			}
		} else {
			result = Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + Ui.loadResource(Rez.Strings.label_error) + responseCode + "\n" + errorsStr[responseCode.toString()];
		}

		_handler.invoke([0, result]);
		_skipGetVehicleData = false;
		_sleep_timer.start(method(:stateMachine), 100, false);
	}

   function onReceiveChargeState(responseCode, data) {
logMessage("onReceiveChargeState " + responseCode + " calling StateMachine in  0.1 sec");
		var result = null;
		if (responseCode == 200) {
			var response = data.get("response");
			if (response != null && response.hasKey("timestamp") && response.get("timestamp") > _lastTimeStamp) {
				_lastTimeStamp = response.get("timestamp");
				_data._vehicle_data.get("charge_state").put("preconditioning_enabled", response.get("preconditioning_enabled"));
				_data._vehicle_data.get("charge_state").put("scheduled_departure_time_minutes", response.get("scheduled_departure_time_minutes"));
				_data._vehicle_data.get("charge_state").put("charge_port_door_open", response.get("charge_port_door_open"));
			} else {
logMessage("onReceiveChargeState: Out of order data or missing timestamp, ignoring");
			}
		} else {
			result = Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + Ui.loadResource(Rez.Strings.label_error) + responseCode + "\n" + errorsStr[responseCode.toString()];
		}

		_handler.invoke([0, result]);
		_skipGetVehicleData = false;
		_sleep_timer.start(method(:stateMachine), 100, false);
	}

	function getVehicleState() {
logMessage("getVehicleState: waiting for onReceiveVehicleState");
		_tesla.getVehicleState(_vehicle_id, method(:onReceiveVehicleState));
	}

	function vehicleStateHandler(responseCode, data) {
		if (responseCode == 200) {
			if (Application.getApp().getProperty("quickReturn")) {
logMessage("vehicleStateHandler: " + responseCode + " skiping getVehicleState, calling stateMachine in  0.1 sec");
				_skipGetVehicleData = false;
				_handler_timer.start(method(:stateMachine), 100, false);
			} else {
logMessage("vehicleStateHandler: " + responseCode + " Calling getVehicleState in 1 sec");
		        _handler_timer.start(method(:getVehicleState), 1000, false); // Give it time to process the change of data otherwise we'll get the value BEFORE the change
			}
		} else {  // Our call failed, say the error and back to the main code
logMessage("vehicleStateHandler: " + responseCode + " Calling stateMachine in  0.1 sec");
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			_skipGetVehicleData = false;
			_handler_timer.start(method(:stateMachine), 100, false);
		}
	}

	function getClimateState() {
logMessage("getClimateState: waiting for onReceiveClimateState");
		_tesla.getClimateState(_vehicle_id, method(:onReceiveClimateState));
	}

	function climateStateHandler(responseCode, data) {
		if (responseCode == 200) {
			if (Application.getApp().getProperty("quickReturn")) {
logMessage("climateStateHandler: " + responseCode + " skiping getClimateState, calling stateMachine in  0.1 sec");
				_skipGetVehicleData = false;
				_handler_timer.start(method(:stateMachine), 100, false);
			} else {
logMessage("climateStateHandler: " + responseCode + " Calling getClimateState in 1 sec");
		        _handler_timer.start(method(:getClimateState), 1000, false); // Give it time to process the change of data otherwise we'll get the value BEFORE the change
			}
		} else { // Our call failed, say the error and back to the main code
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			_skipGetVehicleData = false;
logMessage("climateStateHandler: " + responseCode + " Calling stateMachine in  0.1 sec");
			_handler_timer.start(method(:stateMachine), 100, false);
		}
	}

	function getChargeState() {
logMessage("getChargeState: waiting for onReceiveChargeState");
		_tesla.getChargeState(_vehicle_id, method(:onReceiveChargeState));
	}

	function chargeStateHandler(responseCode, data) {
		if (responseCode == 200) {
			if (Application.getApp().getProperty("quickReturn")) {
logMessage("chargeStateHandler: " + responseCode + " skipping getChargeState, calling stateMachine in  0.1 sec");
				_skipGetVehicleData = false;
				_handler_timer.start(method(:stateMachine), 100, false);
			} else {
logMessage("chargeStateHandler: " + responseCode + " Calling getChargeState in 1 sec");
				_handler_timer.start(method(:getChargeState), 1000, false); // Give it time to process the change of data otherwise we'll get the value BEFORE the change
			}
		} else { // Our call failed, say the error and back to the main code
logMessage("chargeStateHandler: " + responseCode + " Calling stateMachine in  0.1 sec");
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			_skipGetVehicleData = false;
			_handler_timer.start(method(:stateMachine), 100, false);
		}
	}

	function genericHandler(responseCode, data) {
logMessage("genericHandler: " + responseCode + " Calling stateMachine in  0.1 sec");
		if (responseCode == 200) {
			_handler.invoke([0, null]);
		} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
		}

		if (_skipGetVehicleData) {
logMessage("genericHandler: WARNING _skipGetVehicleData IS TRUE!!! Should not be for genericHandler");
			_skipGetVehicleData = false; // Shouldn't be required but just to be safe
		}
		_handler_timer.start(method(:stateMachine), 100, false);
	}

	function _saveToken(token) {
		_token = token;
		_auth_done = true;
		Settings.setToken(token);
	}

	function _resetToken() {
logMessage("_resetToken called");
		_token = null;
		_auth_done = false;
		Settings.setToken(null);
	}
}