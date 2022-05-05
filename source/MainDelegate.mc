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
    var _handler;
    var _token;
    var _tesla;
    var _sleep_timer;
	var _handler_timer; // So it doesn't interfere with the timer used in onReceiveVehicleData
    var _vehicle_id;
	var _vehicle_state;
    var _need_auth;
    var _auth_done;
    var _need_wake;
    var _wake_done;
	var _wakeTime;
	var _firstTime;
    var _set_climate_on;
    var _set_climate_off;
    var _set_climate_set;
    var _set_climate_defrost;
    var _set_charging_amps_set;
    var _set_charging_limit_set;
    var _toggle_charging_set;
    var _honk_horn;
    var _open_port;
    var _open_frunk;
    var _open_trunk;
    var _bypass_confirmation;
    var _unlock;
    var _lock;
    var _settings;
    var _vent;
    var _set_seat_heat;
    var _set_steering_wheel_heat;
    var _data;
    var _code_verifier;
    var _adjust_departure;
    var _sentry_mode;
	var _408_count;
	var _set_refresh_time;
	var _view_datascreen;
	var _refreshTimeInterval;
    var _lastDataRun;
	var _skipGetVehicleData;
	var _waitingForVehicleData;
	var _lastTimeStamp;

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
        _handler = handler;
        _tesla = null;
		
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
		
		var timeNow = Time.now().value();
		var interval = 5 * 60;
		var answer = (timeNow + interval < createdAt + expireIn);
		
        if (_token != null && _token.length() != 0 && answer == true ) {
            _need_auth = false;
            _auth_done = true;
			var expireAt = new Time.Moment(createdAt + expireIn);
			var clockTime = Gregorian.info(expireAt, Time.FORMAT_MEDIUM);
			var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
logMessage("initialize:Using token '" + _token.substring(0,10) + "...' which expires at " + dateStr);

        } else {
logMessage("initialize:No token, will need to get one through a refresh token or authentication");
            _need_auth = true;
            _auth_done = false;
        }

        _need_wake = false; // Assume we're awake and if we get a 408, then wake up (just like _vehicle_state is set to online)
        _wake_done = true;
		_wakeTime = System.getTimer();
		_firstTime = true; // So the Waking up is displayed right away if it's the first time and the the first 408 generate a wake commmand
        _set_climate_on = false;
        _set_climate_off = false;
        _set_climate_defrost = false;
        _set_climate_set = false;
		_toggle_charging_set = false;
		
        _honk_horn = false;
        _open_port = false;
        _open_frunk = false;
        _open_trunk = false;
        _unlock = false;
        _lock = false;
		_bypass_confirmation = false;
		_vent = false;
		_set_seat_heat = false;
        _set_steering_wheel_heat = false;
        _adjust_departure = false;
        _sentry_mode = false;
		_408_count = 0;
		_set_refresh_time = false;
		_view_datascreen = false;
		_refreshTimeInterval = Application.getApp().getProperty("refreshTimeInterval");
		if (_refreshTimeInterval == null) {
			_refreshTimeInterval = 1000;
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
            Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
	    _view.requestUpdate();
	}

    function onSwipe(swipeEvent) {
    	if (_view._data._ready) { // Don't handle swipe if where not showing the data screen
	    	if (swipeEvent.getDirection() == 3) {
				onReceive(1); // Show the first submenu
		    }
		}
        return true;
	}

// STEP 4 no longer required. Bearer access token given by step 3	
    function bearerForAccessOnReceive(responseCode, data) {
//logMessage("bearerForAccessOnReceive " + responseCode);
        if (responseCode == 200) {
            _saveToken(data["access_token"]);
//logMessage("StateMachine: bearerForAccessOnReceive");
            stateMachine();
        }
        else {
        	if (responseCode == 401) {
	            _need_auth = true;
        	}
            _resetToken();
            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_oauth_error)]);
			_sleep_timer.start(method(:stateMachine), 500, false);
        }
    }

    function codeForBearerOnReceive(responseCode, data) {
        if (responseCode == 200) {
            var bearerForAccessUrl = "https://owner-api.teslamotors.com/oauth/token";
            var bearerForAccessParams = {
                "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "client_id" => "81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384",
                "client_secret" => "c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3"
            };
//logMessage("codeForBearerOnReceive data is " + data);

            var bearerForAccessOptions = {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                   "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                   "Authorization" => "Bearer " + data["access_token"]
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };

            Communications.makeWebRequest(bearerForAccessUrl, bearerForAccessParams, bearerForAccessOptions, method(:bearerForAccessOnReceive));
        }
        else {
//logMessage("codeForBearerOnReceive " + responseCode);
			if (responseCode == 404) { // If we can't find that page, we're probably not connected to the internet, say so
	            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_no_phone_internet)]);
	            _need_auth = true;
			}
			else {
	            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_oauth_error)]);
	      }
        _resetToken();
		_sleep_timer.start(method(:stateMachine), 500, false);
      } 
    }

    function onOAuthMessage(message) {
        var code = message.data[$.OAUTH_CODE];
        var error = message.data[$.OAUTH_ERROR];
        if (message.data != null) {
            var codeForBearerUrl = "https://auth.tesla.com/oauth2/v3/token";
            var codeForBearerParams = {
                "grant_type" => "authorization_code",
                "client_id" => "ownerapi",
                "code" => code,
                "code_verifier" => _code_verifier,
                "redirect_uri" => "https://auth.tesla.com/void/callback"
            };

            var codeForBearerOptions = {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                   "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            };

// Since step 4 is no longer required, we'll process the token we just received
//            Communications.makeWebRequest(codeForBearerUrl, codeForBearerParams, codeForBearerOptions, method(:codeForBearerOnReceive));
            Communications.makeWebRequest(codeForBearerUrl, codeForBearerParams, codeForBearerOptions, method(:onReceiveToken));
        } else {
            _need_auth = true;
            _auth_done = false;
        	if (error == 404) {
				_vehicle_id = null;
	        }
//logMessage("onOAuthMessage " + responseCode);
            _resetToken();
            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_oauth_error)]);
			_sleep_timer.start(method(:stateMachine), 500, false);
        }
    }

    function onReceiveToken(responseCode, data) {
logMessage("onReceiveToken responseCode is " + responseCode);
if (data != null) { logMessage("onReceiveToken data is " + data.toString().substring(0,60) + "..."); }
        if (responseCode == 200) {
            _auth_done = true;

			var accessToken = data["access_token"];
			var refreshToken = data["refresh_token"];
			var expires_in = data["expires_in"];
			var created_at = Time.now().value();
			_saveToken(accessToken);
			if (refreshToken != null && refreshToken.equals("") == false) { // Only if we received a refresh tokem
				Settings.setRefreshToken(refreshToken, expires_in, created_at);
			}
        } else {
			// Couldn't refresh our access token through the refresh token, invalide it and try again (through username and password instead since our refresh token is now empty
            _need_auth = true;
            _auth_done = false;
			Settings.setRefreshToken(null, 0, 0);
	    }
		_sleep_timer.start(method(:stateMachine), 500, false);
    }

    function GetAccessToken(token, notify) {
        var url = "https://auth.tesla.com/oauth2/v3/token";
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
//logMessage("Running stateMachine " + _need_auth + " " + _tesla + " " + _auth_done);
		var _spinner = Application.getApp().getProperty("spinner");
		if (_spinner.equals("+")) {
			Application.getApp().setProperty("spinner", "-");
		} else {
			Application.getApp().setProperty("spinner", "+");
		}

		if (_skipGetVehicleData) {
logMessage("StateMachine: Skipping stateMachine");
			return;
		}


        if (_need_auth) {
            _need_auth = false;

			// Do we have a refresh token? If so, try to use it instead of login in
			var _refreshToken = Settings.getRefreshToken();
			if (_refreshToken != null && _refreshToken.length() != 0) {
logMessage("stateMachine: Asking for access token through refresh token " + _refreshToken);
				 GetAccessToken(_refreshToken, method(:onReceiveToken));
			}
			else {
logMessage("stateMachine: Asking for access token through user credentials ");
	            _code_verifier = StringUtil.convertEncodedString(Cryptography.randomBytes(86/2), {
	                :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
	                :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX,
	            });
	
	            var code_verifier_bytes = StringUtil.convertEncodedString(_code_verifier, {
	                :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
	                :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
	            });
	            
	            var hmac = new Cryptography.HashBasedMessageAuthenticationCode({
	                :algorithm => Cryptography.HASH_SHA256,
	                :key => code_verifier_bytes
	            });
	
	            var code_challenge = StringUtil.convertEncodedString(hmac.digest(), {
	                :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
	                :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
	            });
	
	            var params = {
	                "client_id" => "ownerapi",
	                "code_challenge" => code_challenge,
	                "code_challenge_method" => "S256",
	                "redirect_uri" => "https://auth.tesla.com/void/callback",
	                "response_type" => "code",
	                "scope" => "openid email offline_access",
	                "state" => "123"                
	            };
	            
	            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_login_on_phone)]);
	
	            Communications.registerForOAuthMessages(method(:onOAuthMessage));
	            Communications.makeOAuthRequest(
	                "https://auth.tesla.com/oauth2/v3/authorize",
	                params,
	                "https://auth.tesla.com/void/callback",
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
            return;
        }

        if (_tesla == null) {
            _tesla = new Tesla(_token);
        }

        if (_vehicle_id == null || _vehicle_id == -1) { // -1 means we're from a 408 response, use this call to see if we're awake
			if (_vehicle_id == null) {
	            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
			} else {
logMessage("StateMachine: Asking to test if we're awake");
			}
            _tesla.getVehicleId(method(:onReceiveVehicles));
            return;
        }

logMessage("stateMachine: vehicle_state = '" + _vehicle_state + "' _408_count = " + _408_count + " _need_wake = " + _need_wake);
		if (_vehicle_state.equals("online") == false) { // Only matters if we're not online, otherwise be silent
            var timeAsking = System.getTimer() - _wakeTime;
            if (_firstTime) {
	            _handler.invoke([2, Ui.loadResource(Rez.Strings.label_waking_vehicle) + "\n(" + timeAsking / 1000 + "s)"]);
	        } else {
	            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_requesting_data) + "\n(" + timeAsking / 1000 + "s)"]);
	        }
        }

        if (_need_wake) { // Asked to wake up
			if (_firstTime) { // As if we should wake the vehicle
	            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_should_we_wake));
	            var delegate = new SimpleConfirmDelegate(method(:wakeConfirmed), method(:wakeCanceled));
	            Ui.pushView(view, delegate, Ui.SLIDE_UP);
			} else {
				_need_wake = false; // Do it only once
				_wake_done = false;
logMessage("stateMachine:Asking to wake vehicle");
				_tesla.wakeVehicle(_vehicle_id, method(:onReceiveAwake));
			}
            return;
        }

        if (!_wake_done) { // If wake_done is true, we got our 200 in the onReceiveAwake, now it's time to ask for data, otherwise get out and check again
            return;
        }

        if (_set_climate_on) {
//logMessage("StateMachine: Climate On - calling climateStateHandler");
            _set_climate_on = false;
			_skipGetVehicleData = true;
            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_hvac_on)]);
            _tesla.climateOn(_vehicle_id, method(:climateStateHandler));
        }

        if (_set_climate_off) {
//logMessage("StateMachine: Climate Off - calling climateStateHandler");
            _set_climate_off = false;
			_skipGetVehicleData = true;
            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_hvac_off)]);
            _tesla.climateOff(_vehicle_id, method(:climateStateHandler));
        }

        if (_set_climate_defrost) {
            _set_climate_defrost = false;
			_skipGetVehicleData = true;
            _handler.invoke([1, Ui.loadResource(_data._vehicle_data.get("climate_state").get("defrost_mode") == 2 ? Rez.Strings.label_defrost_off : Rez.Strings.label_defrost_on)]);
            _tesla.climateDefrost(_vehicle_id, method(:climateStateHandler), _data._vehicle_data.get("climate_state").get("defrost_mode"));
        }

        if (_set_climate_set) {
            _set_climate_set = false;
            var temperature = Application.getApp().getProperty("driver_temp");
            _tesla.climateSet(_vehicle_id, method(:genericHandler), temperature);
        }

        if (_toggle_charging_set) {
            _toggle_charging_set = false;
            _tesla.toggleCharging(_vehicle_id, method(:genericHandler), _data._vehicle_data.get("charge_state").get("charging_state").equals("Charging"));
        }

        if (_set_charging_limit_set) {
            _set_charging_limit_set = false;
            var charging_limit = Application.getApp().getProperty("charging_limit");
            _tesla.setChargingLimit(_vehicle_id, method(:genericHandler), charging_limit);
        }

        if (_set_charging_amps_set) {
            _set_charging_amps_set = false;
            var charging_amps = Application.getApp().getProperty("charging_amps");
            _tesla.setChargingAmps(_vehicle_id, method(:genericHandler), charging_amps);
        }

        if (_honk_horn) {
            _honk_horn = false;
            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_honk_horn));
            var delegate = new SimpleConfirmDelegate(method(:honkHornConfirmed), null);
            Ui.pushView(view, delegate, Ui.SLIDE_UP);
        }

        if (_open_port) {
            _open_port = false;
			_skipGetVehicleData = true;
            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_open_port)]);
            _tesla.openPort(_vehicle_id, method(:chargeStateHandler));
        }

        if (_unlock) {
//logMessage("StateMachine: Unlock - calling vehicleStateHandler");
            _unlock = false;
			_skipGetVehicleData = true;
            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_unlock_doors)]);
            _tesla.doorUnlock(_vehicle_id, method(:vehicleStateHandler));
        }

        if (_lock) {
//logMessage("StateMachine: Lock - calling vehicleStateHandler");
            _lock = false;
			_skipGetVehicleData = true;
            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_lock_doors)]);
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
			_set_seat_heat = false;
			var seat_chosen = Application.getApp().getProperty("seat_chosen");
			var seat_heat_chosen = Application.getApp().getProperty("seat_heat_chosen");

			switch (seat_heat_chosen) {
				case Rez.Strings.seat_auto:
					seat_heat_chosen = -1;
					break;

				case Rez.Strings.seat_off:
					seat_heat_chosen = 0;
					break;

				case Rez.Strings.seat_low:
					seat_heat_chosen = 1;
					break;

				case Rez.Strings.seat_medium:
					seat_heat_chosen = 2;
					break;

				case Rez.Strings.seat_high:
					seat_heat_chosen = 3;
					break;
					
				default:
					seat_heat_chosen = 0;
					break;
			}
//logMessage("seat_chosen = " + seat_chosen + " seat_heat_chosen = " + seat_heat_chosen);

            _handler.invoke([1, Ui.loadResource(seat_chosen)]);

	        if (seat_chosen == Rez.Strings.seat_driver) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 0, seat_heat_chosen);
	        } else if (seat_chosen == Rez.Strings.seat_passenger) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 1, seat_heat_chosen);
	        } else if (seat_chosen == Rez.Strings.seat_rear_left) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 2, seat_heat_chosen);
	        } else if (seat_chosen == Rez.Strings.seat_rear_center) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 4, seat_heat_chosen);
	        } else if (seat_chosen == Rez.Strings.seat_rear_right) {
	            _tesla.climateSeatHeat(_vehicle_id, method(:genericHandler), 5, seat_heat_chosen);
			}
		}

        if (_set_steering_wheel_heat) {
            _set_steering_wheel_heat = false;
	        if (_data._vehicle_data != null && _data._vehicle_data.get("climate_state").get("is_climate_on") == false) {
	            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_steering_wheel_need_climate_on)]);
	        }
	        else {
	            _handler.invoke([1, Ui.loadResource(_data._vehicle_data.get("climate_state").get("steering_wheel_heater") == true ? Rez.Strings.label_steering_wheel_off : Rez.Strings.label_steering_wheel_on)]);
	            _tesla.climateSteeringWheel(_vehicle_id, method(:onClimateDone), _data._vehicle_data.get("climate_state").get("steering_wheel_heater"));
	        }
        }
        
        if (_adjust_departure) {
            _adjust_departure = false;
			_skipGetVehicleData = true;
			if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
//logMessage("StateMachine: Preconditionning off - calling chargeStateHandler");
	            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_stop_departure)]);
	            _tesla.setDeparture(_vehicle_id, method(:chargeStateHandler), Application.getApp().getProperty("departure_time"), false);
	        }
	        else {
//logMessage("StateMachine: Preconditionning on - calling chargeStateHandler");
	            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_start_departure)]);
	            _tesla.setDeparture(_vehicle_id, method(:chargeStateHandler), Application.getApp().getProperty("departure_time"), true);
	        }
        }

        if (_sentry_mode) {
            _sentry_mode = false;
			_skipGetVehicleData = true;
            if (_data._vehicle_data.get("vehicle_state").get("sentry_mode")) {
	            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_sentry_off)]);
	            _tesla.SentryMode(_vehicle_id, method(:vehicleStateHandler), false);
            } else {
	            _handler.invoke([1, Ui.loadResource(Rez.Strings.label_sentry_on)]);
	            _tesla.SentryMode(_vehicle_id, method(:vehicleStateHandler), true);
            }
        }

		if (_set_refresh_time) {
            _set_refresh_time = false;
            _refreshTimeInterval = Application.getApp().getProperty("refreshTimeInterval");
            if (_refreshTimeInterval == null) {
				_refreshTimeInterval = 1000;
            }
//logMessage("refreshTimer at " + _refreshTimeInterval);
		}
		
		if (_view_datascreen) {
			_view_datascreen = false;
			onReceive(1); // Show the first submenu
		}

		if (!_skipGetVehicleData) {
			if (!_waitingForVehicleData) {
logMessage("StateMachine: Requesting data");
				_lastDataRun = System.getTimer();
				_waitingForVehicleData = true; // So we don't overrun our buffers by multiple calls doing the same thing
				_tesla.getVehicleData(_vehicle_id, method(:onReceiveVehicleData));
			} else {
logMessage("StateMachine: Already waiting for data, skipping");
			}
		} else {
logMessage("StateMachine: Skipping requesting data");
		}
    }

    function wakeConfirmed() {
		_need_wake = false;
		_wake_done = false;
		_wakeTime = System.getTimer();
		_tesla.wakeVehicle(_vehicle_id, method(:onReceiveAwake));
    }

    function wakeCanceled() {
		Ui.popView(SLIDE_IMMEDIATE);
    }

    function openVentConfirmed() {
		_handler.invoke([1, Ui.loadResource(Rez.Strings.label_vent_opening)]);
//        Application.getApp().setProperty("venting", 4); Let onUpdate deal with that
//logMessage("StateMachine: Open vent - calling vehicleStateHandler");
		_skipGetVehicleData = true;
        _tesla.vent(_vehicle_id, method(:vehicleStateHandler), "vent", Application.getApp().getProperty("latitude"), Application.getApp().getProperty("longitude"));
    }

    function closeVentConfirmed() {
	    _handler.invoke([1, Ui.loadResource(Rez.Strings.label_vent_closing)]);
//        Application.getApp().setProperty("venting", 0); Let onUpdate deal with that
//logMessage("StateMachine: Close vent - calling vehicleStateHandler");
		_skipGetVehicleData = true;
        _tesla.vent(_vehicle_id, method(:vehicleStateHandler), "close", Application.getApp().getProperty("latitude"), Application.getApp().getProperty("longitude"));
    }

    function frunkConfirmed() {
		var hansshowFrunk = Application.getApp().getProperty("HansshowFrunk");
		if (hansshowFrunk) {
	        _handler.invoke([1, Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("ft") == 0 ? Rez.Strings.label_frunk_opening : Rez.Strings.label_frunk_closing)]);
			_skipGetVehicleData = true;
			_tesla.openTrunk(_vehicle_id, method(:vehicleStateHandler), "front");
		} else {
			if (_data._vehicle_data.get("vehicle_state").get("ft") == 0) {
				_handler.invoke([1, Ui.loadResource(Rez.Strings.label_frunk_opening)]);
				_skipGetVehicleData = true;
				_tesla.openTrunk(_vehicle_id, method(:vehicleStateHandler), "front");
			} else {
				_handler.invoke([1, Ui.loadResource(Rez.Strings.label_frunk_opened)]);
	            _sleep_timer.start(method(:stateMachine), 500, false);
			}
		}
    }

    function trunkConfirmed() {
        _handler.invoke([1, Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("rt") == 0 ? Rez.Strings.label_trunk_opening : Rez.Strings.label_trunk_closing)]);
		_skipGetVehicleData = true;
        _tesla.openTrunk(_vehicle_id, method(:vehicleStateHandler), "rear");
    }

    function honkHornConfirmed() {
        _handler.invoke([1, Ui.loadResource(Rez.Strings.label_honk)]);
        _tesla.honkHorn(_vehicle_id, method(:genericHandler));
    }

    function onSelect() {
        if (_settings.isTouchScreen) {
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
logMessage("stateMachine: doSelect");
        stateMachine();
    }

    function onNextPage() {
        if (_settings.isTouchScreen) {
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
logMessage("stateMachine: doNextPage");
        stateMachine();
    }

    function onPreviousPage() {
        if (_settings.isTouchScreen) {
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
			Ui.pushView(new Rez.Menus.TrunksMenu(), new TrunksMenuDelegate(self), Ui.SLIDE_UP);
        }
logMessage("stateMachine: doPreviousPage");
        stateMachine();
    }

    function onBack() {
        return false;
    }

    function onMenu() {
        if (_settings.isTouchScreen) {
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
		else if (_index > 20) {
			_index = 20;
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
					menu.addItem(Rez.Strings.menu_label_open_frunk_open, :open_frunk);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_open_frunk_opened, :open_frunk);
				}
				break;
			case 11:
		        if (_data._vehicle_data != null && _data._vehicle_data.get("vehicle_state").get("rt") == 0) {
					menu.addItem(Rez.Strings.menu_label_open_trunk_open, :open_trunk);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_open_trunk_close, :open_trunk);
				}
				break;
			case 12:
				menu.addItem(Rez.Strings.menu_label_open_port, :open_port);
				break;
			case 13:
				if (Application.getApp().getProperty("venting") == 0) {
					menu.addItem(Rez.Strings.menu_label_vent_open, :vent);
				}
				else {
					menu.addItem(Rez.Strings.menu_label_vent_close, :vent);
				}
				break;
			case 14:
				menu.addItem(Rez.Strings.menu_label_toggle_view, :toggle_view);
				break;
			case 15:
				menu.addItem(Rez.Strings.menu_label_swap_frunk_for_port, :swap_frunk_for_port);
				break;
			case 16:
				menu.addItem(Rez.Strings.menu_label_datascreen, :data_screen);
				break;
			case 17:
				menu.addItem(Rez.Strings.menu_label_select_car, :select_car);
				break;
			case 18:
				menu.addItem(Rez.Strings.menu_label_reset, :reset);
				break;
			case 19:
				menu.addItem(Rez.Strings.menu_label_wake, :wake);
				break;
			case 20:
				menu.addItem(Rez.Strings.menu_label_refresh, :refresh);
				break;
		}
	}
	
    function doMenu() {
        if (!_auth_done) {
            return;
        }

		var _slot_count = Application.getApp().getProperty("NumberOfSlots");
		if (_slot_count == null) {
			_slot_count = 17;
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

		// Tap on vehicle name
		if (enhancedTouch && y < _settings.screenHeight / 6 && _tesla != null) {
			_tesla.getVehicleId(method(:selectVehicle));
		}
		// Tap on the space used by the 'Eye'
		else if (enhancedTouch && y > _settings.screenHeight / 6 && y < _settings.screenHeight / 4 && x > _settings.screenWidth / 2 - _settings.screenWidth / 19 && x < _settings.screenWidth / 2 + _settings.screenWidth / 19) {
            _sentry_mode = true;
//logMessage("stateMachine: onTap");
            stateMachine();
		}
		// Tap on the middle text line where Departure is written
		else if (enhancedTouch && y > _settings.screenHeight / 2 - _settings.screenHeight / 19 && y < _settings.screenHeight / 2 + _settings.screenHeight / 19) {
			if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
	            _adjust_departure = true;
logMessage("stateMachine: onTap");
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
		            
		            if (Application.getApp().getProperty("imperial")) {
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

    function selectVehicle(responseCode, data) {
        if (responseCode == 200) {
            var vehicles = data.get("response");
            var vins = new [vehicles.size()];
            for (var i = 0; i < vehicles.size(); i++) {
                vins[i] = vehicles[i].get("display_name");
            }
            Ui.pushView(new CarPicker(vins), new CarPickerDelegate(self), Ui.SLIDE_UP);
        } else {
            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
        }
    }

    function onReceiveVehicles(responseCode, data) {
logMessage("onReceiveVehicles:responseCode is " + responseCode);
//logMessage("onReceiveVehicles:data is " + data);
        if (responseCode == 200) {
            var vehicles = data.get("response");
            if (vehicles.size() > 0) {
				// Need to retrieve the right vehicle, not just the first one!
				var vehicle_index = 0;
				var vehicle_name = Application.getApp().getProperty("vehicle_name");
				if (vehicle_name != null) {
					while (vehicle_index < vehicles.size()) {
						if (vehicle_name.equals(vehicles[vehicle_index].get("display_name"))) {
							break;
						}
					}
					if (vehicle_index == vehicles.size()) {
						vehicle_index = 0;
					}
				}
				_vehicle_state = vehicles[vehicle_index].get("state");
                _vehicle_id = vehicles[vehicle_index].get("id");
                Application.getApp().setProperty("vehicle", _vehicle_id);
                Application.getApp().setProperty("vehicle_name", vehicles[vehicle_index].get("display_name"));
logMessage("onReceiveVehicles: Vehicle '" + vehicles[vehicle_index].get("display_name") + "' (" + _vehicle_id + ") state is '" + _vehicle_state + "'");
				if (_vehicle_state.equals("online") == false) { // We're not awake, next iteration of StateMachine will call the wake function
					_need_wake = true;
					_wake_done = false;
				}

//logMessage("stateMachine: onReceiveVehicles");
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
                return;
			} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
	        }

            _sleep_timer.start(method(:stateMachine), 500, false);
        }
    }

    function onReceiveVehicleData(responseCode, data) {
logMessage("onReceiveVehicleData: responseCode is " + responseCode);
		_waitingForVehicleData = false;
		
		if (_skipGetVehicleData) {
logMessage("onReceiveVehicleData: Asked to skip");
			return;
		}

        if (responseCode == 200) {
			_vehicle_state = "online"; // We got data so we got to be online

			// Check if this data feed is older than the previous one and if so, ignore it (two timers could create this situation)
			var response = data.get("response");
			if (response != null && response.hasKey("charge_state") && response.get("charge_state").hasKey("timestamp") && response.get("charge_state").get("timestamp") > _lastTimeStamp) {
				_data._vehicle_data = response;
				_lastTimeStamp = response.get("charge_state").get("timestamp");
//logMessage("onReceiveVehicleData received " + _data._vehicle_data);
				if (_data._vehicle_data.get("climate_state").hasKey("inside_temp") && _data._vehicle_data.get("charge_state").hasKey("battery_level")) {
					_408_count = 0; // Reset the count of timeouts since we got our data
					_firstTime = false;
					_handler.invoke([0, null]);
					Ui.requestUpdate(); // We got data! Now show it!
					var timeDelta = System.getTimer() - _lastDataRun; // Substract the time we spent waiting from the time interval we should run
logMessage("onReceiveVehicleData: timeDelta is " + timeDelta);
					timeDelta = _refreshTimeInterval - timeDelta;
					if (timeDelta > 500) { // Make sure we leave at least 0.5 sec between calls
logMessage("onReceiveVehicleData: Running StateMachine in " + timeDelta + " msec");
	                	_sleep_timer.start(method(:stateMachine), timeDelta, false);
						return;
					} else {
logMessage("onReceiveVehicleData: Running StateMachine in no less than 500 msec");
					}
				} else {
logMessage("onReceiveVehicleData: Received incomplete data, ignoring");
				}
			} else {
logMessage("onReceiveVehicleData: Received an out or order data or missing timestamp, ignoring");
			}
			_sleep_timer.start(method(:stateMachine), 500, false);
			return;
        } else {
			if (responseCode == 408) { // We got a timeout, check if we're still awake
	        	if ((_408_count == 0 && _firstTime) || (_408_count % 20 == 1 && !_firstTime)) { // First (if we've starting up), second (to let through a spurious 408) and every consecutive 20th 408 recieved will generate a test for the vehicle state. 
					if (_408_count < 2) { // Only when we first started to get the errors do we keep the start time
						_wakeTime = System.getTimer();
					}
logMessage("onReceiveVehicleData: Got 408, Check if we need to wake up the car?");
		            _vehicle_id = -1;
	            }
        		_408_count++;
			} else {
				if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
					_vehicle_id = null;
		            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
				} else if (responseCode == 401) {
	                // Unauthorized, retry
	                _need_auth = true;
	                _resetToken();
		            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_unauthorized)]);
	                return;
				} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
		            _handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
		        }
			}
	    }
        _sleep_timer.start(method(:stateMachine), 500, false);
    }

    function onReceiveAwake(responseCode, data) {
logMessage("onReceiveAwake:responseCode is " + responseCode);
        if (responseCode == 200) {
            _wake_done = true;
//logMessage("stateMachine: onReceiveWake");
            stateMachine();
			return;
       } else {
		   // We were unable to wake, try again
			_need_wake = true;
			_wake_done = false;
			if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
				_vehicle_id = null;
				_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			} else if (responseCode == 401) { // Unauthorized, retry
				_resetToken();
				_need_auth = true;
				_handler.invoke([0, Ui.loadResource(Rez.Strings.label_unauthorized)]);
				return;
			} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
				_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			}
        }
        _sleep_timer.start(method(:stateMachine), 500, false);
    }

   function onReceiveVehicleState(responseCode, data) {
logMessage("onReceiveVehicleState: responseCode is " + responseCode + " calling StateMachine");
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
        } // We silently ignore errors here. We'll get the data using the main stateMachine function anyway, just a bit later

        _handler.invoke([1, null]);
		Ui.requestUpdate();
		_skipGetVehicleData = false;
        stateMachine();
    }

   function onReceiveClimateState(responseCode, data) {
logMessage("onReceiveClimateState responseCode is " + responseCode + " calling StateMachine");
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
        } // We silently ignore errors here. We'll get the data using the main stateMachine function anyway, just a bit later

        _handler.invoke([1, null]);
		Ui.requestUpdate();
		_skipGetVehicleData = false;
        stateMachine();
    }

   function onReceiveChargeState(responseCode, data) {
logMessage("onReceiveChargeState responseCode is " + responseCode + " calling StateMachine");
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
        } // We silently ignore errors here. We'll get the data using the main stateMachine function anyway, just a bit later

        _handler.invoke([1, null]);
		Ui.requestUpdate();
		_skipGetVehicleData = false;
        stateMachine();
    }

    function getVehicleState() {
logMessage("getVehicleState: Calling onReceiveVehicleState");
		_tesla.getVehicleState(_vehicle_id, method(:onReceiveVehicleState));
	}

    function vehicleStateHandler(responseCode, data) {
logMessage("vehicleStateHandler: responseCode is " + responseCode + " Calling getVehicleState");
        if (responseCode == 200) {
	        _handler_timer.start(method(:getVehicleState), 1000, false); // Give it time to process the change of data otherwise we'll get the value BEFORE the change
		} else {  // Our call failed, say the error and back to the main code
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			_skipGetVehicleData = false;
			_handler_timer.start(method(:stateMachine), 500, false);
		}
    }

    function getClimateState() {
logMessage("getClimateState: Calling onReceiveClimateState");
		_tesla.getClimateState(_vehicle_id, method(:onReceiveClimateState));
	}

    function climateStateHandler(responseCode, data) {
logMessage("climateStateHandler: responseCode is " + responseCode + " Calling getClimateState");
        if (responseCode == 200) {
	        _handler_timer.start(method(:getClimateState), 1000, false); // Give it time to process the change of data otherwise we'll get the value BEFORE the change
			return;
		} else { // Our call failed, say the error and back to the main code
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			_skipGetVehicleData = false;
			_handler_timer.start(method(:stateMachine), 500, false);
		}
    }

    function getChargeState() {
logMessage("getChargeState: Calling onReceiveChargeState");
		_tesla.getChargeState(_vehicle_id, method(:onReceiveChargeState));
	}

    function chargeStateHandler(responseCode, data) {
logMessage("chargeStateHandler: responseCode is " + responseCode + " Calling getChargeState");
        if (responseCode == 200) {
	        _handler_timer.start(method(:getChargeState), 1000, false); // Give it time to process the change of data otherwise we'll get the value BEFORE the change
			return;
		} else { // Our call failed, say the error and back to the main code
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
			_skipGetVehicleData = false;
			_handler_timer.start(method(:stateMachine), 500, false);
		}
    }

    function genericHandler(responseCode, data) {
logMessage("genericHandler: responseCode is " + responseCode);
        if (responseCode == 200) {
            _handler.invoke([1, null]);
		} else if (responseCode != -5  && responseCode != -101) { // These are silent errors
			_handler.invoke([0, Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]]);
		}
        _handler_timer.start(method(:stateMachine), 500, false);
    }

    function _saveToken(token) {
        _token = token;
        _auth_done = true;
        Settings.setToken(token);
    }

    function _resetToken() {
        _token = null;
        _auth_done = false;
        Settings.setToken(null);
    }
}