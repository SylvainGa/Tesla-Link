using Toybox.WatchUi as Ui;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Communications as Communications;
using Toybox.Cryptography;
using  Toybox.Graphics;

const OAUTH_CODE = "myOAuthCode";
const OAUTH_ERROR = "myOAuthError";

class MainDelegate extends Ui.BehaviorDelegate {
	var _view as MainView;
    var _handler;
    var _token;
    var _tesla;
    var _sleep_timer;
    var _vehicle_id;
    var _need_auth;
    var _auth_done;
    var _need_wake;
    var _wake_done;

    var _set_climate_on;
    var _set_climate_off;
    var _set_climate_set;
    var _set_climate_defrost;
    var _set_charging_amps_set;
    var _set_charging_limit_set;
    var _toggle_charging_set;
    var _get_vehicle_data;
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
    var _disableRefreshTimer; // When this is true, the refreshTimer will not call stateMachine since we are already inside stateMachine from a direct call elsewhere
    var _data;
	var refreshTimer;
    var _code_verifier;
    var _adjust_departure;
    var _sentry_mode;
	var _408_count;
	var _set_refresh_time;
	
    function initialize(view as MainView, data, handler) {
        BehaviorDelegate.initialize();
    	_view = view;
//logMessage("MainDelegate:initialize");
        _settings = System.getDeviceSettings();
        _data = data;
        _token = Settings.getToken();
//logMessage("MainDelegate:initialize token is " + _token);
        _vehicle_id = Application.getApp().getProperty("vehicle");
        _sleep_timer = new Timer.Timer();
        _handler = handler;
        _tesla = null;
		
        if (_token != null && _token.length() != 0) {
            _need_auth = false;
            _auth_done = true;
        } else {
            _need_auth = true;
            _auth_done = false;
        }

        _need_wake = true;
        _wake_done = true;

        _set_climate_on = false;
        _set_climate_off = false;
        _set_climate_defrost = false;
        _set_climate_set = false;
		_toggle_charging_set = false;
		
        _get_vehicle_data = 1;
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
			
		_disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;

	    refreshTimer = new Timer.Timer();
//logMessage("MainDelegate:Starting initial refresh timer" + " _get_vehicle_data " + _get_vehicle_data);
	    refreshTimer.start(method(:timerRefresh), 4000, true);
    }

    function onSwipe(swipeEvent) {
logMessage("Swipe " + swipeEvent.getDirection().toString());
    	if (swipeEvent.getDirection() == 3) {
    		_view.IncLayout();
	    }
    	else if (swipeEvent.getDirection() == 1) {
    		_view.DecLayout();
	    }
	    
	    _view.requestUpdate();
        return true;
	}
	
    function onShow() {
//logMessage("MainDelegate:Starting refresh timer" + " _get_vehicle_data " + _get_vehicle_data);
	    refreshTimer.start(method(:timerRefresh), 4000, true);
	}
	
    function onHide() {
//logMessage("MainDelegate:Stopping refresh timer" + " _get_vehicle_data " + _get_vehicle_data);
	    refreshTimer.stop();
	}
	
    function bearerForAccessOnReceive(responseCode, data) {
//logMessage("MainDelegate:bearerForAccessOnReceive " + responseCode.toString() + " _get_vehicle_data " + _get_vehicle_data);
        if (responseCode == 200) {
            _saveToken(data["access_token"]);
            _disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;
        }
        else {
            _resetToken();
            _handler.invoke(Ui.loadResource(Rez.Strings.label_oauth_error));
        }
    }

    function codeForBearerOnReceive(responseCode, data) {
//logMessage("MainDelegate:codeForBearerOnReceive " + responseCode.toString() + " _get_vehicle_data " + _get_vehicle_data);
        if (responseCode == 200) {
            var bearerForAccessUrl = "https://owner-api.teslamotors.com/oauth/token";
            var bearerForAccessParams = {
                "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "client_id" => "81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384",
                "client_secret" => "c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3"
            };

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
            _resetToken();
            _handler.invoke(Ui.loadResource(Rez.Strings.label_oauth_error));
        }
    }

    function onOAuthMessage(message) {
//logMessage("MainDelegate:onOAuthMessage" + " _get_vehicle_data " + _get_vehicle_data);
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

            Communications.makeWebRequest(codeForBearerUrl, codeForBearerParams, codeForBearerOptions, method(:codeForBearerOnReceive));
        } else {
            _resetToken();
            _handler.invoke(Ui.loadResource(Rez.Strings.label_oauth_error));
        }
    }

    function stateMachine() {
//logMessage("MainDelegate:stateMachine with _get_vehicle_data at " + _get_vehicle_data);
        if (_need_auth) {
//logMessage("MainDelegate:_need_auth");

            _need_auth = false;

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
            
            _handler.invoke(Ui.loadResource(Rez.Strings.label_login_on_phone));

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
//logMessage("MainDelegate:Made makeOAuthRequest");
            return;
        }

        if (!_auth_done) {
            return;
        }
//logMessage("MainDelegate:_auth_done true");

        if (_tesla == null) {
//logMessage("MainDelegate:Need _tesla");
            _tesla = new Tesla(_token);
        }

        if (_vehicle_id == null) {
//logMessage("MainDelegate:Need vehicle_id");
            _handler.invoke(Ui.loadResource(Rez.Strings.label_getting_vehicles));
            _tesla.getVehicleId(method(:onReceiveVehicles));
            return;
        }

        if (_need_wake || _408_count > 5) { // Asked to wake up or got five 408 errors (timeout) without a single 200
//logMessage("MainDelegate:Need wake");
            _need_wake = false;
            _wake_done = false;
            _handler.invoke(Ui.loadResource(Rez.Strings.label_waking_vehicle));
            _tesla.wakeVehicle(_vehicle_id, method(:onReceiveAwake));
            return;
        }

        if (!_wake_done) {
            return;
        }

		var _gotBackgroundData = Application.getApp().getProperty("gotBackgroundData");
		if (_gotBackgroundData == true) {
			Application.getApp().setProperty("gotBackgroundData", false);
	        if (_get_vehicle_data == 2) { // If we were waiting for data that was read by the background process, request it again
	            _get_vehicle_data = 1;
			}        
		}

        if (_get_vehicle_data == 1) {
//logMessage("MainDelegate:*** Requesting vehicle data ***");
            _get_vehicle_data = 2;
            _tesla.getVehicleData(_vehicle_id, method(:onReceiveVehicleData));
		}
		else {
			Ui.requestUpdate(); // We're not getting any data but still refresh the view
		}

        if (_set_climate_on) {
            _set_climate_on = false;
            _handler.invoke(Ui.loadResource(Rez.Strings.label_hvac_on));
            _tesla.climateOn(_vehicle_id, method(:genericHandler));
        }

        if (_set_climate_off) {
            _set_climate_off = false;
            _handler.invoke(Ui.loadResource(Rez.Strings.label_hvac_off));
            _tesla.climateOff(_vehicle_id, method(:genericHandler));
        }

        if (_set_climate_defrost) {
            _set_climate_defrost = false;
            _handler.invoke(Ui.loadResource(_data._vehicle_data.get("climate_state").get("defrost_mode") == 2 ? Rez.Strings.label_defrost_off : Rez.Strings.label_defrost_on));
            _tesla.climateDefrost(_vehicle_id, method(:genericHandler), _data._vehicle_data.get("climate_state").get("defrost_mode"));
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
            var delegate = new SimpleConfirmDelegate(method(:honkHornConfirmed));
            Ui.pushView(view, delegate, Ui.SLIDE_UP);
        }

        if (_open_port) {
            _open_port = false;
            _handler.invoke(Ui.loadResource(Rez.Strings.label_open_port));
            _tesla.openPort(_vehicle_id, method(:genericHandler));
        }

        if (_unlock) {
            _unlock = false;
            _handler.invoke(Ui.loadResource(Rez.Strings.label_unlock_doors));
            _tesla.doorUnlock(_vehicle_id, method(:genericHandler));
        }

        if (_lock) {
            _lock = false;
            _handler.invoke(Ui.loadResource(Rez.Strings.label_lock_doors));
            _tesla.doorLock(_vehicle_id, method(:genericHandler));
        }

        if (_open_frunk) {
            _open_frunk = false;
            if (_bypass_confirmation) {
            	_bypass_confirmation = false;
				frunkConfirmed();
			}
			else {
	            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_open_frunk));
	            var delegate = new SimpleConfirmDelegate(method(:frunkConfirmed));
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
	            var delegate = new SimpleConfirmDelegate(method(:trunkConfirmed));
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
		            var delegate = new SimpleConfirmDelegate(method(:openVentConfirmed));
		            Ui.pushView(view, delegate, Ui.SLIDE_UP);
		        }
            }
            else {
	            if (_bypass_confirmation) {
	            	_bypass_confirmation = false;
	            	closeVentConfirmed();
	            } else {
		            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_close_vent));
		            var delegate = new SimpleConfirmDelegate(method(:closeVentConfirmed));
		            Ui.pushView(view, delegate, Ui.SLIDE_UP);
	            }
            }
        }

		if (_set_seat_heat) {
			_set_seat_heat = false;
			var seat_chosen = Application.getApp().getProperty("seat_chosen");
			var seat_heat_chosen = Application.getApp().getProperty("seat_heat_chosen");

            _handler.invoke(Ui.loadResource(seat_chosen));

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
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_steering_wheel_need_climate_on));
	        }
	        else {
	            _handler.invoke(Ui.loadResource(_data._vehicle_data.get("climate_state").get("steering_wheel_heater") == true ? Rez.Strings.label_steering_wheel_off : Rez.Strings.label_steering_wheel_on));
	            _tesla.climateSteeringWheel(_vehicle_id, method(:onClimateDone), _data._vehicle_data.get("climate_state").get("steering_wheel_heater"));
	        }
        }
        
        if (_adjust_departure) {
            _adjust_departure = false;
			if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_stop_departure));
	            _tesla.stopDeparture(_vehicle_id, method(:genericHandler));
	        }
	        else {
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_start_departure));
	            _tesla.startDeparture(_vehicle_id, method(:genericHandler), Application.getApp().getProperty("departure_time"));
	        }
        }

        if (_sentry_mode) {
            _sentry_mode = false;
            if (_data._vehicle_data.get("vehicle_state").get("sentry_mode")) {
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_sentry_off));
	            _tesla.SentryMode(_vehicle_id, method(:genericHandler), false);
            } else {
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_sentry_on));
	            _tesla.SentryMode(_vehicle_id, method(:genericHandler), true);
            }
        }

		if (_set_refresh_time) {
            _set_refresh_time = false;
            var refreshTime = Application.getApp().getProperty("refreshTime");
            if (refreshTime != null) {
			    refreshTimer.stop();
			    refreshTimer.start(method(:timerRefresh), refreshTime.toNumber() * 1000, true);
            }
		}
    }

    function openVentConfirmed() {
		_handler.invoke(Ui.loadResource(Rez.Strings.label_vent_opening));
        Application.getApp().setProperty("venting", 4);
        _tesla.vent(_vehicle_id, method(:genericHandler), "vent", Application.getApp().getProperty("latitude"), Application.getApp().getProperty("longitude"));
    }

    function closeVentConfirmed() {
	    _handler.invoke(Ui.loadResource(Rez.Strings.label_vent_closing));
        Application.getApp().setProperty("venting", 0);
        _tesla.vent(_vehicle_id, method(:genericHandler), "close", Application.getApp().getProperty("latitude"), Application.getApp().getProperty("longitude"));
    }

    function frunkConfirmed() {
        _handler.invoke(Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("ft") == 0 ? Rez.Strings.label_frunk_opening : Rez.Strings.label_frunk_opened));
        _tesla.openTrunk(_vehicle_id, method(:genericHandler), "front");
    }

    function trunkConfirmed() {
        _handler.invoke(Ui.loadResource(_data._vehicle_data.get("vehicle_state").get("rt") == 0 ? Rez.Strings.label_trunk_opening : Rez.Strings.label_trunk_closing));
        _tesla.openTrunk(_vehicle_id, method(:genericHandler), "rear");
    }

    function honkHornConfirmed() {
        _handler.invoke(Ui.loadResource(Rez.Strings.label_honk));
        _tesla.honkHorn(_vehicle_id, method(:genericHandler));
    }

    function timerRefresh() {
		if (Application.getApp().getProperty("refreshTimer")) {
	    	if (!_disableRefreshTimer) {
        		var _spinner = Application.getApp().getProperty("spinner");
				if (_spinner.equals("+")) {
					Application.getApp().setProperty("spinner", "-");
				} else {
					Application.getApp().setProperty("spinner", "+");
				}

				if (_data._vehicle_data != null) {
					if (_get_vehicle_data == 0) {
//logMessage("MainDelegate:timerRefresh calling stateMachine asking for vehicle data");
				        _get_vehicle_data = 1;
					}
					else {
						Application.getApp().setProperty("spinner", "?");
//logMessage("MainDelegate:timerRefresh calling stateMachine with _get_vehicle_data at " + _get_vehicle_data);
					}
				}
				else {
//logMessage("MainDelegate:timerRefresh calling stateMachine with _data._vehicle_data as null");
				}
					
		        stateMachine();
			}
		    else {
//logMessage("MainDelegate:timerRefresh with _disableRefreshTimer true");
		    }
		}
	    else {
//logMessage("MainDelegate:timerRefresh App property is false");
	    }
    }

    function delayedRetry() {
//logMessage("MainDelegate:delayedRetry called" + " _get_vehicle_data " + _get_vehicle_data);
//        _need_wake = true;
        var _oldDisable = _disableRefreshTimer; 
		_get_vehicle_data = 1;
		_disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = _oldDisable;
    }

    function onSelect() {
        if (_settings.isTouchScreen) {
            return false;
        }

		if (_view._layoutNumber == 0) {
	        doSelectLayout0();
	    }
        return true;
    }

    function doSelectLayout0() {
        if (_data._vehicle_data != null && _data._vehicle_data.get("climate_state").get("is_climate_on") == false) {
            _set_climate_on = true;
        } else {
            _set_climate_off = true;
        }
        _disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;
    }

    function onNextPage() {
        if (_settings.isTouchScreen) {
            return false;
        }

		if (_view._layoutNumber == 0) {
	        doNextPageLayout0();
	    }
        return true;
    }

    function doNextPageLayout0() {
		if (_view._layoutNumber == 0) {
	        if (_data._vehicle_data != null && !_data._vehicle_data.get("vehicle_state").get("locked")) {
	            _lock = true;
	        } else {
	            _unlock = true;
	        }
	        _disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;
	    }
    }

    function onPreviousPage() {
        if (_settings.isTouchScreen) {
            return false;
        }

		if (_view._layoutNumber == 0) {
	        doPreviousPageLayout0();
	    }
        return true;
    }

    function doPreviousPageLayout0() {
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
        _disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;
    }

    function onBack() {
        return false;
    }

    function onMenu() {
        if (_settings.isTouchScreen) {
            return false;
        }

		if (_view._layoutNumber == 0) {
	        doMenuLayout0();
	    }
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
		else if (_index > 19) {
			_index = 19;
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
				menu.addItem(Rez.Strings.menu_label_select_car, :select_car);
				break;
			case 17:
				menu.addItem(Rez.Strings.menu_label_reset, :reset);
				break;
			case 18:
				menu.addItem(Rez.Strings.menu_label_wake, :wake);
				break;
			case 19:
				menu.addItem(Rez.Strings.menu_label_refresh, :refresh);
				break;
		}
	}
	
    function doMenuLayout0() {
        if (!_auth_done) {
            return;
        }

    	_disableRefreshTimer = true;

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
		
		WatchUi.pushView(thisMenu, new OptionMenuDelegate(self), Ui.SLIDE_UP );
//        Ui.pushView(new Rez.Menus.OptionMenu(), new OptionMenuDelegate(self), Ui.SLIDE_UP);
        _disableRefreshTimer = false; 
    }

    function onTap(click) {
        if (!_data._ready)
        {
            return true;
        }
        
		if (_view._layoutNumber == 0) {
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
	            stateMachine();
			}
			// Tap on the middle text line where Departure is written
			else if (enhancedTouch && y > _settings.screenHeight / 2 - _settings.screenHeight / 19 && y < _settings.screenHeight / 2 + _settings.screenHeight / 19) {
				if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
		            _adjust_departure = true;
		            stateMachine();
	            }
	            else {
					Ui.pushView(new DepartureTimePicker(_data._vehicle_data.get("charge_state").get("scheduled_departure_time_minutes")), new DepartureTimePickerDelegate(self), WatchUi.SLIDE_IMMEDIATE);
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
	                doPreviousPageLayout0();
	            } else {
	                doNextPageLayout0();
	            }
	        } else {
	            if (y < _settings.screenHeight/2) {
	                doSelectLayout0();
	            } else {
	                doMenuLayout0();
	            }
	        }
		}
        return true;
    }

    function selectVehicle(responseCode, data) {
//logMessage("MainDelegate:selectVehicle " + responseCode.toString() + " _get_vehicle_data " + _get_vehicle_data);
        if (responseCode == 200) {
            var vehicles = data.get("response");
            var vins = new [vehicles.size()];
            for (var i = 0; i < vehicles.size(); i++) {
                vins[i] = vehicles[i].get("display_name");
            }
            Ui.pushView(new CarPicker(vins), new CarPickerDelegate(self), Ui.SLIDE_UP);
        } else {
            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
        }
    }

    function onReceiveAuth(responseCode, data) {
//logMessage("MainDelegate:onReceiveAuth " + responseCode.toString() + " _get_vehicle_data " + _get_vehicle_data);
        if (responseCode == 200) {
            _auth_done = true;
            _disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;
        } else {
            _resetToken();
            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
        }
    }

    function onReceiveVehicles(responseCode, data) {
//logMessage("MainDelegate:onReceiveVehicles " + responseCode.toString() + " _get_vehicle_data " + _get_vehicle_data);
        if (responseCode == 200) {
            var vehicles = data.get("response");
            if (vehicles.size() > 0) {
                _vehicle_id = vehicles[0].get("id");
                Application.getApp().setProperty("vehicle", _vehicle_id);
                _disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;
            } else {
                _handler.invoke(Ui.loadResource(Rez.Strings.label_no_vehicles));
            }
        } else {
			if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
	            Application.getApp().setProperty("vehicle", null);
                _resetToken();
                _need_auth = true;
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
//logMessage("MainDelegate:onReceiveVehicles clearing vehicle id");
			} else if (responseCode == 401) {
                // Unauthorized
                _resetToken();
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_unauthorized));
                return;
			} else if (responseCode != 408 && responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
	        } else if (responseCode == 408) {
				_408_count += 1;
	        }
            _sleep_timer.start(method(:delayedRetry), 500, false);
        }
    }

    function onReceiveVehicleData(responseCode, data) {
//logMessage("MainDelegate:onReceiveVehicleData " + responseCode.toString() + " _get_vehicle_data " + _get_vehicle_data);
        if (responseCode == 200) {
            _data._vehicle_data = data.get("response");
            if (_data._vehicle_data.get("climate_state").hasKey("inside_temp") && _data._vehicle_data.get("charge_state").hasKey("battery_level")) {
		        _get_vehicle_data = 0; // All is well, we got our data
				_408_count = 0; // Reset the count of timeouts since we got our data
logMessage(_data._vehicle_data.get("charge_state"));
                _handler.invoke(null);
            } else {
//logMessage("MainDelegate:onReceiveVehicleData missing some data");
                _sleep_timer.start(method(:delayedRetry), 500, false);
            }
        } else {
			if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
	            Application.getApp().setProperty("vehicle", null);
                _resetToken();
                _need_auth = true;
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
//logMessage("MainDelegate:onReceiveVehicleData clesaring vehicle id");
			} else if (responseCode == 401) {
			    // Unauthorized
			    _resetToken();
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_unauthorized));
                return;
			} else if (responseCode != 408 && responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
	        } else if (responseCode == 408) {
				_408_count += 1;
	        }
            _sleep_timer.start(method(:delayedRetry), 500, false);
	    }
    }

    function onReceiveAwake(responseCode, data) {
//logMessage("MainDelegate:onReceiveAwake " + responseCode.toString() + " _get_vehicle_data " + _get_vehicle_data);
        if (responseCode == 200) {
            _wake_done = true;
			_handler.invoke(Ui.loadResource(Rez.Strings.label_requesting_data));
            _get_vehicle_data = 1;
            _disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;
			_408_count = 0;
        } else {
            _need_wake = true;
            _wake_done = false;
            
			if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
	            Application.getApp().setProperty("vehicle", null);
                _resetToken();
                _need_auth = true;
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
//logMessage("MainDelegate:onReceiveAwake clearing vehicle id");
			} else if (responseCode == 401) {
                // Unauthorized
                _resetToken();
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_unauthorized));
                return;
			} else if (responseCode != 408 && responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
	        } else if (responseCode == 408) {
				_408_count += 1;
	        }
            _sleep_timer.start(method(:delayedRetry), 500, false);
        }
    }

    function genericHandler(responseCode, data) {
//logMessage("MainDelegate:genericHandler " + responseCode.toString() + " _get_vehicle_data " + _get_vehicle_data);
        if (responseCode == 200) {
            if (_get_vehicle_data == 0) {
	            _get_vehicle_data = 1;
			}
            _handler.invoke(null);
            _disableRefreshTimer = true; stateMachine(); _disableRefreshTimer = false;
        } else {
			if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
	            Application.getApp().setProperty("vehicle", null);
                _resetToken();
                _need_auth = true;
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
//logMessage("MainDelegate:genericHandler clearing vehicle id");
			} else if (responseCode == 401) {
                // Unauthorized
                _resetToken();
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_unauthorized));
                return;
			} else if (responseCode != 408 && responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke(Ui.loadResource(Rez.Strings.label_error) + responseCode.toString() + "\n" + errorsStr[responseCode.toString()]);
	        } else if (responseCode == 408) {
				_408_count += 1;
	        }
            _sleep_timer.start(method(:delayedRetry), 500, false);
        }
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