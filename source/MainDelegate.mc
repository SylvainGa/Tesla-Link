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
	ACTION_OPTION_SEAT_REAR_PASSENGER = 6,
	ACTION_OPTION_MEDIA_PLAY_TOGGLE = 7,
	ACTION_OPTION_MEDIA_PREV_SONG = 8,
	ACTION_OPTION_MEDIA_NEXT_SONG = 9,
	ACTION_OPTION_MEDIA_VOLUME_DOWN = 10,
	ACTION_OPTION_MEDIA_VOLUME_UP = 11
}

enum /* ACTION_TYPES */ {
	ACTION_TYPE_RESET = 0, // No longer implemented
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
	ACTION_TYPE_REFRESH = 18, // No longer implemented
	ACTION_TYPE_DATA_SCREEN = 19,
	ACTION_TYPE_HOMELINK = 20,
	ACTION_TYPE_REMOTE_BOOMBOX = 21,
	ACTION_TYPE_CLIMATE_MODE = 22,
	ACTION_TYPE_CLIMATE_DEFROST = 23,
	ACTION_TYPE_CLIMATE_SET = 24,
	ACTION_TYPE_MEDIA_CONTROL = 25,
	// Following are through buttons or touch screen input
	ACTION_TYPE_CLIMATE_ON = 26,
	ACTION_TYPE_CLIMATE_OFF = 27,
	ACTION_TYPE_LOCK = 28,
	ACTION_TYPE_UNLOCK = 29
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
	var _token;
	var _data;
	var _code_verifier;
	var _workTimer;
	var _vehicle_vin;
	var _check_wake;
	var _need_wake;
	var _wake_done;
	var _in_menu;
	var _waitingFirstData;
	var _wakeWasConfirmed;
	var _408_count;
	var _lastError;
	var _lastTimeStamp;
	var _lastDataRun;
	var _waitingForCommandReturn;
	var _useTouch;
	var _debug_auth;
	var _debug_view;
	var _waitingForCommandValue;
	var _quickReturn;
	var _enhancedTouch;
	var _hansshowFrunk;
	var _askWakeVehicle;
	var _complicationAction;
	var _swap_frunk_for_port;
	var _batteryRangeType;

	// 2023-03-20 var _debugTimer;

	var _pendingActionRequests;
	var _stateMachineCounter;
	
	function initialize(view as MainView, data, handler) {
		BehaviorDelegate.initialize();
	
		_view = view;

		_settings = System.getDeviceSettings();
		_data = data;
		
		//Storage.deleteValue("vehicle_vin");
		_vehicle_vin = Storage.getValue("vehicle_vin");
		_data._vehicle_state = null; // We'll need to get the state of the vehicle
		_workTimer = new Timer.Timer();
		_handler = handler;
		_tesla = null;
		_waitingForCommandReturn = null;
		// _debugTimer = System.getTimer(); Storage.setValue("overrideCode", 0);

		_check_wake = false; // If we get a 408 on first try or after 20 consecutive 408, see if we should wake up again 
		_need_wake = false; // Assume we're awake and if we get a 408, then wake up (just like _data._vehicle_state is set to awake)
		_wake_done = true;
		_in_menu = false;
		gWaitTime = System.getTimer();
		_waitingFirstData = 1; // So the Waking up is displayed right away if it's the first time
		_wakeWasConfirmed = false; // So we only display the Asking to wake only once

		_408_count = 0;
		_lastError = null;

		_lastTimeStamp = 0;

		_pendingActionRequests = [];
		_stateMachineCounter = 0;
		_lastDataRun = System.getTimer();

		onSettingsChanged();

		// This is where the main code will start running. Don't intialise stuff after this line
		//DEBUG*/ logMessage("initialize: quickAccess=" + _quickReturn + " enhancedTouch=" + _enhancedTouch);
		_workTimer.start(method(:workerTimer), 100, true);

		stateMachine(); // Launch getting the states right away.
	}

	function onSettingsChanged() {
		_token = $.getProperty("tessieToken", null, method(:validateString));
		if (_tesla) {
			_tesla.setToken(_token);
		}

		_quickReturn = $.getProperty("quickReturn", false, method(:validateBoolean));
		_useTouch = $.getProperty("useTouch", true, method(:validateBoolean));
		_enhancedTouch = $.getProperty("enhancedTouch", true, method(:validateBoolean));
		if (_enhancedTouch) {
			Storage.setValue("spinner", "+");
		}
		else {
			Storage.setValue("spinner", "/");
		}
		_hansshowFrunk = $.getProperty("HansshowFrunk", false, method(:validateBoolean));
		_askWakeVehicle = $.getProperty("askWakeVehicle", true, method(:validateBoolean));
		_complicationAction = $.getProperty("complicationAction", 0, method(:validateNumber));
		_swap_frunk_for_port = $.getProperty("swap_frunk_for_port", 0, method(:validateNumber));
		_batteryRangeType = $.getProperty("batteryRangeType", 0, method(:validateNumber));
	}

	function onReceive(args) {
		//DEBUG*/ logMessage("StateMachine: onReceive with args=" + args);
		if (args == 0) { // The sub page ended and sent us a _handler.invoke(0) call, display our main view
			//DEBUG*/ logMessage("StateMachine: onReceive returning to main view");
			_stateMachineCounter = 1;
		}
		else if (args == 1 || args > 3) { // Swiped left from main screen or out of data views, show subview 1
			//DEBUG*/ logMessage("StateMachine: onReceive pushing charge view");
			var view = new ChargeView(_view._data);
			var delegate = new ChargeDelegate(view, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else if (args == 2) { // Swiped left on subview 1, show subview 2
			//DEBUG*/ logMessage("StateMachine: onReceive pushing climate view");
			var view = new ClimateView(_view._data);
			var delegate = new ClimateDelegate(view, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
		else if (args == 3) { // Swiped left on subview 2, show subview 3
			//DEBUG*/ logMessage("StateMachine: onReceive pushing drive view");
			var view = new DriveView(_view._data);
			var delegate = new DriveDelegate(view, method(:onReceive));
			Ui.pushView(view, delegate, Ui.SLIDE_LEFT);
		}
	    Ui.requestUpdate();
	}

	function onSwipe(swipeEvent) {
		if (_view._data._ready) { // Don't handle swipe if where not showing the data screen
	    	if (swipeEvent.getDirection() == WatchUi.SWIPE_LEFT) {
				onReceive(1); // Show the first submenu
		    }
	    	// if (swipeEvent.getDirection() == WatchUi.SWIPE_UP) {
			// 	var view = new MediaControlView();
			// 	var delegate = new MediaControlDelegate(view, self, _stateMachineCounter, view.method(:onReceive));
			// 	Ui.pushView(view, delegate, Ui.SLIDE_UP);
		    // }
		}
		return true;
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
				if (_enhancedTouch) {
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
		//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is " + _pendingActionRequests.size() + (_vehicle_vin != null && _vehicle_vin > 0 ? "" : "vehicle_id " + _vehicle_vin) + " vehicle_state " + _data._vehicle_state + (_check_wake ? " _check_wake true" : "") + (_need_wake ? " _need_wake true" : "") + (!_wake_done ? " _wake_done false" : "") + (_waitingFirstData ? " _waitingFirstData=" + _waitingFirstData : ""));

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
		if (_quickReturn) {
			_handlerType = 1;
		}
		else {
			_handlerType = 2;
		}

		var view;
		var delegate;

		switch (action) {
			case ACTION_TYPE_CLIMATE_ON:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Climate On - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_hvac_on)]);
				_waitingForCommandReturn = ACTION_TYPE_CLIMATE_ON;
				_tesla.climateOn(_vehicle_vin, 40, !_quickReturn, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLIMATE_OFF:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Climate Off - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_hvac_off)]);
				_waitingForCommandReturn = ACTION_TYPE_CLIMATE_OFF;
				_tesla.climateOff(_vehicle_vin, 40, !_quickReturn, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLIMATE_DEFROST:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				var isDefrostOn = _data._vehicle_data.get("climate_state").get("is_front_defroster_on");
				_waitingForCommandValue = !isDefrostOn;

				//DEBUG*/ logMessage("actionMachine: Climate Defrost is currently " + isDefrostOn + " - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(isDefrostOn ? Rez.Strings.label_defrost_off : Rez.Strings.label_defrost_on)]);
				_waitingForCommandReturn = ACTION_TYPE_CLIMATE_DEFROST;
				_tesla.climateDefrost(_vehicle_vin, 40, !_quickReturn, isDefrostOn, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLIMATE_SET:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				var temperature = value;
				if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
					temperature = temperature * 9 / 5 + 32;
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_climate_set) + temperature.format("%d") + "°F"]);
				} else {
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_climate_set) + temperature.format("%.1f") + "°C"]);
				}
				//DEBUG*/ logMessage("actionMachine: Climate set temperature to " + temperature + " - waiting for onCommandReturn");
				_tesla.climateSet(_vehicle_vin, 40, !_quickReturn, temperature, method(:onCommandReturn));
				break;

			case ACTION_TYPE_MEDIA_CONTROL:
				//DEBUG 2023-10-02*/ logMessage("actionMachine: Media control - Shouldn't get there!");
				break;

			case ACTION_TYPE_TOGGLE_CHARGE:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				var chargingState = _data._vehicle_data.get("charge_state").get("charging_state").equals("Charging");
				//DEBUG*/ logMessage("actionMachine: Toggling charging, currently " + chargingState + " - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(chargingState ? Rez.Strings.label_stop_charging : Rez.Strings.label_start_charging)]);
				_tesla.toggleCharging(_vehicle_vin, 40, !_quickReturn, chargingState, method(:onCommandReturn));
				break;

			case ACTION_TYPE_SET_CHARGING_LIMIT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				_waitingForCommandValue = value;
				//DEBUG*/ logMessage("actionMachine: Setting charge limit to " + _waitingForCommandValue + " - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_charging_limit) + _waitingForCommandValue + "%"]);
				_waitingForCommandReturn = ACTION_TYPE_SET_CHARGING_LIMIT;
				_tesla.setChargingLimit(_vehicle_vin, 40, !_quickReturn, _waitingForCommandValue, method(:onCommandReturn));
				break;

			case ACTION_TYPE_SET_CHARGING_AMPS:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				_waitingForCommandValue = value;
				//DEBUG*/ logMessage("actionMachine: Setting max current to " + _waitingForCommandValue + " - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_charging_amps) + _waitingForCommandValue + "A"]);
				_waitingForCommandReturn = ACTION_TYPE_SET_CHARGING_AMPS;
				_tesla.setChargingAmps(_vehicle_vin, 40, !_quickReturn, _waitingForCommandValue, method(:onCommandReturn));
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
				_waitingForCommandReturn = ACTION_TYPE_OPEN_PORT;
				_tesla.openPort(_vehicle_vin, 40, !_quickReturn, method(:onCommandReturn));
				break;

			case ACTION_TYPE_CLOSE_PORT:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Closing on charge port - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_close_port)]);
				_waitingForCommandReturn = ACTION_TYPE_CLOSE_PORT;
				_tesla.closePort(_vehicle_vin, 40, !_quickReturn, method(:onCommandReturn));
				break;

			case ACTION_TYPE_UNLOCK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Unlock - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_unlock_doors)]);
				_waitingForCommandReturn = ACTION_TYPE_UNLOCK;
				_tesla.doorUnlock(_vehicle_vin, 40, !_quickReturn, method(:onCommandReturn));
				break;

			case ACTION_TYPE_LOCK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Lock - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_lock_doors)]);
				_waitingForCommandReturn = ACTION_TYPE_LOCK;
				_tesla.doorLock(_vehicle_vin, 40, !_quickReturn, method(:onCommandReturn));
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
					else if (_hansshowFrunk) {
						view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.menu_label_close_frunk));
					}
					else {
						_stateMachineCounter = 1;
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
				_waitingForCommandValue = venting;

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
				_tesla.climateSeatHeat(_vehicle_vin, 40, !_quickReturn, position, seat_heat_chosen, method(:onCommandReturn));
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
					_tesla.climateSteeringWheel(_vehicle_vin, 40, !_quickReturn, _data._vehicle_data.get("climate_state").get("steering_wheel_heater"), method(:onCommandReturn));
				}
				else {
					_stateMachineCounter = 1;
				}
				break;

			case ACTION_TYPE_ADJUST_DEPARTURE:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				_waitingForCommandReturn = ACTION_TYPE_ADJUST_DEPARTURE;
				_waitingForCommandValue = _data._vehicle_data.get("charge_state").get("preconditioning_enabled");

				if (_waitingForCommandValue) {
					//DEBUG*/ logMessage("actionMachine: Preconditionning off - waiting for onCommandReturn");
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_stop_departure)]);
					_tesla.setDeparture(_vehicle_vin, 40, !_quickReturn, value, false, method(:onCommandReturn));
				}
				else {
					//DEBUG*/ logMessage("actionMachine: Preconditionning on - waiting for onCommandReturn");
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_start_departure)]);
					_tesla.setDeparture(_vehicle_vin, 40, !_quickReturn, value, true, method(:onCommandReturn));
				}
				break;

			case ACTION_TYPE_TOGGLE_SENTRY:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				_waitingForCommandReturn = ACTION_TYPE_TOGGLE_SENTRY;
				_waitingForCommandValue = _data._vehicle_data.get("vehicle_state").get("sentry_mode");

				if (_waitingForCommandValue) {
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_sentry_off)]);
					_tesla.SentryMode(_vehicle_vin, 40, !_quickReturn, false, method(:onCommandReturn));
				} else {
					_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_sentry_on)]);
					_tesla.SentryMode(_vehicle_vin, 40, !_quickReturn, true, method(:onCommandReturn));
				}
				break;

			case ACTION_TYPE_HOMELINK:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Homelink - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_homelink)]);
				_tesla.homelink(_vehicle_vin, 40, !_quickReturn, method(:onCommandReturn));
				break;

			case ACTION_TYPE_REMOTE_BOOMBOX:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: Remote Boombox - waiting for onCommandReturn");
				_handler.invoke([_handlerType, -1, Ui.loadResource(Rez.Strings.label_remote_boombox)]);
				_tesla.remoteBoombox(_vehicle_vin, 40, !_quickReturn, method(:onCommandReturn));
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
				_tesla.setClimateMode(_vehicle_vin, 40, !_quickReturn, mode_chosen, method(:onCommandReturn));
				break;

			case ACTION_TYPE_DATA_SCREEN:
				//DEBUG*/ logMessage("actionMachine: _pendingActionRequest size is now " + _pendingActionRequests.size());

				//DEBUG*/ logMessage("actionMachine: viewing DataScreen - not calling a handler");
				onReceive(1); // Show the first submenu
				break;

			default:
				//DEBUG 2023-10-02*/ logMessage("actionMachine: WARNING Invalid action");
				_stateMachineCounter = 1;
				break;
		}
	}

	function stateMachine() {
		//DEBUG*/ logMessage("stateMachine:" + " vehicle_vin " + _vehicle_vin + " vehicle_state " + _data._vehicle_state + (_check_wake ? " _check_wake true" : "") + (_need_wake ? " _need_wake true" : "") + (!_wake_done ? " _wake_done false" : "") + (_waitingFirstData ? " _waitingFirstData=" + _waitingFirstData : ""));

		if (_token == null || _token.equals("")) {
			_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_need_token)]);
			_stateMachineCounter = 100; // No need to pound here, we don't habe a token, so wait 10 seconds
			return;
		}

		if (_tesla == null) {
			_tesla = new Tesla(_token);
		}

		_stateMachineCounter = 0; // So we don't get in if we're alreay in

		var resetNeeded = Storage.getValue("ResetNeeded");
		if (resetNeeded != null && resetNeeded == true) {
			Storage.setValue("ResetNeeded", false);
			_vehicle_vin = null;
		}

		if (_vehicle_vin == null) {
            _handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
			_stateMachineCounter = -1;
			_tesla.getVehicles(method(:onSelectVehicle));
			_vehicle_vin = "N/A";
			return;
		}

		if (_vehicle_vin.equals("N/A")) {
			//DEBUG*/ logMessage("StateMachine: Getting vehicles, _vehicle_vin is " +  _vehicle_vin + " _check_wake=" + _check_wake);
			if (_vehicle_vin == null) {
	            _handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_getting_vehicles)]);
			}
			_tesla.getVehicles(method(:onReceiveVehicles));
			_stateMachineCounter = 50; // Wait five second before running again so we don't start flooding the communication
			return;
		}

		if (_data._vehicle_state == null || _check_wake == true) {
			if (_data._vehicle_state == null) {
	            _handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_vehicleStatus)]);
				_data._vehicle_state = "Acquiring";
			}
			_check_wake = false; // Do it only once
			_tesla.getVehicleStatus(_vehicle_vin, method(:onReceiveVehicleStatus));
			return;
		}

		if (_data._vehicle_state.equals("Acquiring")) {
			return;
		}

		if (_need_wake) { // Asked to wake up
			if (_waitingFirstData > 0 && !_wakeWasConfirmed && _askWakeVehicle) { // Ask if we should wake the vehicle
				//DEBUG*/ logMessage("stateMachine: Asking if OK to wake");
	            var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_should_we_wake) + Storage.getValue("vehicle_name") + "?");
				_stateMachineCounter = -1;
	            var delegate = new SimpleConfirmDelegate(method(:wakeConfirmed), method(:wakeCanceled));
				_in_menu = true;
	            Ui.pushView(view, delegate, Ui.SLIDE_UP);
			} else {
				//DEBUG*/ logMessage("stateMachine: Waking vehicle");
				_need_wake = false; // Do it only once
				_wake_done = false;
				_tesla.wakeVehicle(_vehicle_vin, method(:onReceiveAwake));
			}
			return;
		}

		if (!_wake_done && _quickReturn == false) { // If wake_done is true, we got our 200 in the onReceiveAwake, now it's time to ask for data, otherwise get out and check again
			return;
		}

		// If we've come from a watch face, simulate a upper left quandrant touch hold once we started to get data.
		if (_view._data._ready == true && Storage.getValue("launchedFromComplication") == true) {
			Storage.setValue("launchedFromComplication", false);

			var action = _complicationAction;
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

		// We're not waiting for a command to return, we're waiting for an action to be performed
		if (_waitingForCommandReturn == null && _pendingActionRequests.size() > 0) {
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
				var timeDelta = System.getTimer() - _lastDataRun;
				if (timeDelta > 45000) {
					//DEBUG*/ logMessage("workerTimer: We've been waiting for data for " + timeDelta + "ms. Assume we lost this packet and try again");
					_lastDataRun = System.getTimer();
					_stateMachineCounter = 1;
				}				
				//logMessage("workerTimer: " + _stateMachineCounter);
			}
		}

		// If we are still waiting for our first set of data and not at a login prompt or wasking to wake, once we reach 150 iterations of the 0.1sec workTimer (ie, 15 seconds has elapsed since we started)
		if (_waitingFirstData > 0 && _need_wake == false) {
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

	function wakeConfirmed() { // Wake confirmed, wait for vehicle to wake before showing the data
		_need_wake = false;
		_wake_done = false;
		_wakeWasConfirmed = true;
		gWaitTime = System.getTimer();
		//DEBUG*/ logMessage("wakeConfirmed: Waking the vehicle");

		_handler.invoke([3, _408_count, Ui.loadResource(Rez.Strings.label_waking_vehicle)]);
		_in_menu = false;
		_tesla.wakeVehicle(_vehicle_vin, method(:onReceiveAwake));
	}

	function wakeCanceled() { // Wake canceled, show what we got
		_need_wake = false;
		gWaitTime = System.getTimer();
		Storage.setValue("launchedFromComplication", false); // If we came from a watchface complication and we canceled the wake, ignore the complication event
		//DEBUG*/ logMessage("wakeCancelled:");
		_stateMachineCounter = 1;
		_in_menu = false;
	}

	function openVentConfirmed() {
		_handler.invoke([_quickReturn ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_vent_opening)]);
		//DEBUG*/ logMessage("actionMachine: Open vent with venting= " + _waitingForCommandValue + " - waiting for onCommandReturn");
		_tesla.vent(_vehicle_vin, 40, !_quickReturn, true, method(:onCommandReturn));
	}

	function closeVentConfirmed() {
	    _handler.invoke([_quickReturn ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_vent_closing)]);
		//DEBUG*/ logMessage("actionMachine: Close vent with venting= " + _waitingForCommandValue + " - waiting for onCommandReturn");
		_tesla.vent(_vehicle_vin, 40, !_quickReturn, false, method(:onCommandReturn));
	}

	function frunkConfirmed() {
		//DEBUG*/ logMessage("actionMachine: Acting on frunk - waiting for onCommandReturn");

		_waitingForCommandValue = _data._vehicle_data.get("vehicle_state").get("ft");

		if (_hansshowFrunk) {
	        _handler.invoke([_quickReturn ? 1 : 2, -1, Ui.loadResource(_waitingForCommandValue == 0 ? Rez.Strings.label_frunk_opening : Rez.Strings.label_frunk_closing)]);
			_waitingForCommandReturn = ACTION_TYPE_OPEN_FRUNK;
			_tesla.openTrunk(_vehicle_vin, 40, !_quickReturn, false, method(:onCommandReturn));
		} else {
			if (_waitingForCommandValue == 0) {
				_handler.invoke([_quickReturn ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_frunk_opening)]);
				_waitingForCommandReturn = ACTION_TYPE_OPEN_FRUNK;
				_tesla.openTrunk(_vehicle_vin, 40, !_quickReturn, false, method(:onCommandReturn));
			} else {
				_handler.invoke([1, -1, Ui.loadResource(Rez.Strings.label_frunk_opened)]);
	            _stateMachineCounter = 1;
			}
		}
	}

	function trunkConfirmed() {
		//DEBUG*/ logMessage("actionMachine: Acting on trunk - waiting for onCommandReturn");
		_waitingForCommandValue = _data._vehicle_data.get("vehicle_state").get("rt");
		_handler.invoke([_quickReturn ? 1 : 2, -1, Ui.loadResource(_waitingForCommandValue == 0 ? Rez.Strings.label_trunk_opening : Rez.Strings.label_trunk_closing)]);
		_waitingForCommandReturn = ACTION_TYPE_OPEN_TRUNK;
		_tesla.openTrunk(_vehicle_vin, 40, !_quickReturn, true, method(:onCommandReturn));
	}

	function honkHornConfirmed() {
		//DEBUG*/ logMessage("actionMachine: Honking - waiting for onCommandReturn");
		_handler.invoke([_quickReturn ? 1 : 2, -1, Ui.loadResource(Rez.Strings.label_honk)]);
		_tesla.honkHorn(_vehicle_vin, 40, !_quickReturn, method(:onCommandReturn));
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

		if (!_data._vehicle_data.get("vehicle_state").get("locked")) {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_LOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		} else {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_UNLOCK, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
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

		switch (_swap_frunk_for_port) {
			case 0:
				if (!_hansshowFrunk && _data._vehicle_data.get("vehicle_state").get("ft") == 1) {
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
				else if (_hansshowFrunk) {
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
				//DEBUG 2023-10-02*/ logMessage("doPreviousPage: WARNING swap_frunk_for_port is " + _swap_frunk_for_port);
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
				else if (_hansshowFrunk) {
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
				menu.addItem(new MenuItem(Rez.Strings.menu_label_wake, null, :wake, {}));
				break;
			case 21:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_remote_boombox, null, :remote_boombox, {}));
				break;
			case 22:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_climate_mode, null, :climate_mode, {}));
				break;
			case 23:
				menu.addItem(new MenuItem(Rez.Strings.menu_label_media_control, null, :media_control, {}));
				break;
			default:
				//DEBUG*/ logMessage("addMenuItem: Index " + index + " out of range");
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
		var menuItems = $.to_array($.getProperty("optionMenuOrder", "1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22", method(:validateString)),",");
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

		//DEBUG*/ logMessage("onTap: enhancedTouch=" + _enhancedTouch + " x=" + x + " y=" + y);
		if (System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_RECTANGLE && _settings.screenWidth < _settings.screenHeight) {
			y = y - ((_settings.screenHeight - _settings.screenWidth) / 2.7).toNumber();
		}

		// Tap on vehicle name
		if (_enhancedTouch && y < _settings.screenHeight / 7 && _tesla != null) {
			_stateMachineCounter = -1;
			_tesla.getVehicles(method(:onSelectVehicle));
		}
		// Tap on the space used by the 'Eye'
		else if (_enhancedTouch && y > _settings.screenHeight / 7 && y < (_settings.screenHeight / 3.5).toNumber() && x > _settings.screenWidth / 2 - (_settings.screenWidth / 11).toNumber() && x < _settings.screenWidth / 2 + (_settings.screenWidth / 11).toNumber()) {
			_pendingActionRequests.add({"Action" => ACTION_TYPE_TOGGLE_SENTRY, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
		}
		// Tap on the middle text line where Departure is written
		else if (_enhancedTouch && y > (_settings.screenHeight / 2.3).toNumber() && y < (_settings.screenHeight / 1.8).toNumber()) {
			var time = _data._vehicle_data.get("charge_state").get("scheduled_departure_time_minutes");
			if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
				_pendingActionRequests.add({"Action" => ACTION_TYPE_ADJUST_DEPARTURE, "Option" => ACTION_OPTION_NONE, "Value" => time, "Tick" => System.getTimer()});
			}
			else {
				Ui.pushView(new DepartureTimePicker(time), new DepartureTimePickerDelegate(self), Ui.SLIDE_IMMEDIATE);
			}
		} 
		// Tap on bottom line on screen
		else if (_enhancedTouch && y > (_settings.screenHeight  / 1.25).toNumber() && _tesla != null) {
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
			action = _complicationAction;
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
			var vehicles = data.get("results");
			var size = vehicles.size();
			if (size == 0) {
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_no_vehicles)]);
				_vehicle_vin = null;
				_stateMachineCounter = 100;
				return;
			}

			var vehiclesName = new [size];
			var vehiclesVin = new [size];
			for (var i = 0; i < size; i++) {
				vehiclesName[i] = vehicles[i].get("last_state").get("display_name");
				vehiclesVin[i] = vehicles[i].get("vin");
			}

			if (size == 1) {
				Storage.setValue("vehicle_vin", vehiclesVin[0]);
				Storage.setValue("vehicle_name", vehiclesName[0]);

				// Start fresh as if we just loaded
				_waitingFirstData = 1;
				_408_count = 0;
				_check_wake = false;
				_need_wake = false;
				_wake_done = true;
				_wakeWasConfirmed = false;
				_data._vehicle_state = null;
				_vehicle_vin = vehiclesVin[0];
				_stateMachineCounter = 1;
			}
			else {
				_in_menu = true;
				Ui.pushView(new CarPicker(vehiclesName), new CarPickerDelegate(vehiclesName, vehiclesVin, self), Ui.SLIDE_UP);
			}
		}
		else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
			_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down!
		}
		else {
			_handler.invoke([0, -1, buildErrorString(responseCode)]);
			_stateMachineCounter = 100;
		}
	}

	function onReceiveVehicles(responseCode, data) {
		//DEBUG*/ logMessage("onReceiveVehicles: " + responseCode);
		//logMessage("onReceiveVehicles: data is " + data);

		if (responseCode == 200) {
			var vehicles = data.get("results");
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

				//DEBUG*/ logMessage("onReceiveVehicles: Vehicle '" + vehicles[vehicle_index].get("display_name") + "' (" + _vehicle_vin + ")");

				_vehicle_vin = vehicles[vehicle_index].get("vin");
				Storage.setValue("vehicle", _vehicle_vin);
				Storage.setValue("vehicle_name", vehicles[vehicle_index].get("display_name"));

				_check_wake = true;
				_stateMachineCounter = 1;
				return;
			}
			else {
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_no_vehicles)]);
				_stateMachineCounter = 50;
			}
		}
		else {
			if (responseCode == 401) {
				// Unauthorized
	            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
			}
			else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
	            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
				_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down!
				return;
			}
			else if (responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke([0, -1, buildErrorString(responseCode)]);
	        }
			_stateMachineCounter = 50;
		}
	}

	function onReceiveVehicleStatus(responseCode, data) {
		//logMessage("onReceiveVehicleStatus: data is " + data);

		if (responseCode == 200) {
			_data._vehicle_state = data.get("status");
			//DEBUG*/ logMessage("onReceiveVehicleStatus: " + responseCode + " status is " + _data._vehicle_state);

			if (_data._vehicle_state == null) { // Fail safe in case we read nothing
				_data._vehicle_state = "asleep";
			}
			if (_data._vehicle_state.equals("asleep")) {
				if (_waitingFirstData > 0 && !_wakeWasConfirmed && _askWakeVehicle) {
					_need_wake = true;
					_stateMachineCounter = 1; // We're asleep, but we're going to ask if ok to wake up so no wait
				}
				else {
					_stateMachineCounter = 100; // We're asleep, no point asking to read data right away, it's stale anyway
				}
			}
			else {
				_stateMachineCounter = 1; // We seem to be awake, try to get the most recent data
			}

			_check_wake = false;
		}
		else {
			//DEBUG*/ logMessage("onReceiveVehicleStatus: " + responseCode);
			if (responseCode == 401) {
				// Unauthorized
	            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
			}
			else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
	            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
				_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down!
				return;
			}
			else if (responseCode != -5  && responseCode != -101) { // These are silent errors
	            _handler.invoke([0, -1, buildErrorString(responseCode)]);
	        }

			_stateMachineCounter = 50;
		}
	}

	function onReceiveVehicleData(responseCode, data) {
		//DEBUG 2023-10-02*/ logMessage("onReceiveVehicleData: " + responseCode);

		if (_stateMachineCounter < 0) {
			//DEBUG 2023-10-02*/ if (_stateMachineCounter == -3) { logMessage("onReceiveVehicleData: skipping, actionMachine running"); }
			//DEBUG 2023-10-02*/ if (_stateMachineCounter == -2) { logMessage("onReceiveVehicleData: WARNING skipping again because of the menu?"); }
			if (_stateMachineCounter == -1) { 
				//DEBUG*/ logMessage("onReceiveVehicleData: skipping, we're in a menu");
				 _stateMachineCounter = -2; // Let the menu blocking us know that we missed data
			}
			return;
		}

		if (responseCode == 200) {
			_lastError = null;
			// Check if this data feed is older than the previous one and if so, ignore it (two timers could create this situation)
			if (data != null && data instanceof Lang.Dictionary && data.get("climate_state") != null && data.get("charge_state") != null && data.get("vehicle_state") != null && data.get("drive_state") != null) {
				var currentTimeStamp = $.validateLong(data.get("charge_state").get("timestamp"), 0);
				if (currentTimeStamp > _lastTimeStamp) { // We got new data since the last poll, interpret it
					SpinSpinner(responseCode);

					_data._vehicle_data = data;
					if (_waitingForCommandReturn == null) { // We're not waiting for a command to return
						_handler.invoke([0, -1, null]); // We received the status of our command, show the main screen right away
						_stateMachineCounter = 1;
					}
					else if (_quickReturn) { // We're not waiting for the command completion to show the main screen
						_handler.invoke([1, -1, null]); // Refresh the screen only if we're not displaying something already that hasn't timed out
					}
					else { // For the command to show completed before showing the main screen
						var showNow = false;
						switch (_waitingForCommandReturn) {
							case ACTION_TYPE_CLIMATE_ON:
								if (data.get("climate_state").get("is_climate_on") == true) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_CLIMATE_OFF:
								if (data.get("climate_state").get("is_climate_on") == false) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_CLIMATE_DEFROST:
								if (data.get("climate_state").get("is_front_defroster_on") == _waitingForCommandValue) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_SET_CHARGING_LIMIT:
								if (data.get("charge_state").get("charge_limit_soc") == _waitingForCommandValue) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_SET_CHARGING_AMPS:
								if (data.get("charge_state").get("charge_current_request") == _waitingForCommandValue) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_LOCK:
								if (data.get("vehicle_state").get("locked") == true) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_UNLOCK:
								if (data.get("vehicle_state").get("locked") == false) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_OPEN_PORT:
								if (data.get("charge_state").get("charge_port_door_open") == true) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_CLOSE_PORT:
								if (data.get("charge_state").get("charge_port_door_open") == false) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_OPEN_FRUNK:
								if (data.get("vehicle_state").get("ft") != _waitingForCommandValue) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_OPEN_TRUNK:
								if (data.get("vehicle_state").get("rt") != _waitingForCommandValue) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_VENT:
								var venting = data.get("vehicle_state").get("fd_window").toNumber() + data.get("vehicle_state").get("rd_window").toNumber() + data.get("vehicle_state").get("fp_window").toNumber() + data.get("vehicle_state").get("rp_window").toNumber();

								if (venting != _waitingForCommandValue) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_ADJUST_DEPARTURE:
								var departureEnabled = data.get("charge_state").get("preconditioning_enabled");

								if (departureEnabled != _waitingForCommandValue) {
									showNow = true;
								}
								break;
							case ACTION_TYPE_TOGGLE_SENTRY:
								var sentryEnabled = data.get("vehicle_state").get("sentry_mode");

								if (sentryEnabled != _waitingForCommandValue) {
									showNow = true;
								}
								break;
						}
						if (showNow) {
							_waitingForCommandReturn = null;
							_handler.invoke([0, -1, null]); // We received the status of our command, show the main screen right away
							//DEBUG*/ logMessage("onReceiveVehicleData: action has completed");
						}
						else {
							//DEBUG*/ logMessage("onReceiveVehicleData: waiting for action to complete");
						}
					}

					// get the media state for the MediaControl View
					if (data.get("vehicle_state").get("media_info") != null) {
						var media_info = data.get("vehicle_state").get("media_info");
						Storage.setValue("media_playback_status", media_info.get("media_playback_status"));
						Storage.setValue("now_playing_title", media_info.get("now_playing_title"));
						Storage.setValue("media_volume", ($.validateFloat(media_info.get("audio_volume"), 0.0) * 10).toNumber());
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

						var which_battery_type = _batteryRangeType;
						var bat_range_str = [ "battery_range", "est_battery_range", "ideal_battery_range"];

						status.put("battery_level", $.validateNumber(data.get("charge_state").get("battery_level"), 0));
						status.put("battery_range", $.validateNumber(data.get("charge_state").get(bat_range_str[which_battery_type]), 0));
						status.put("charging_state", $.validateString(data.get("charge_state").get("charging_state"), ""));
						status.put("inside_temp", $.validateNumber(data.get("climate_state").get("inside_temp"), 0));
						status.put("shift_state", $.validateString(data.get("drive_state").get("shift_state"), ""));
						status.put("sentry", $.validateBoolean(data.get("vehicle_state").get("sentry_mode"), false));
						status.put("preconditioning", $.validateBoolean(data.get("charge_state").get("preconditioning_enabled"), false));
						status.put("vehicleAwake", _data._vehicle_state);

						Storage.setValue("status", status);
						$.sendComplication(status);
						
						//2023-03-03 logMessage("onReceiveVehicleData: set status to '" + Storage.getValue("status") + "'");
					}

					if (_408_count) {
						//DEBUG*/ logMessage("onReceiveVehicleData: clearing _408_count");
						_408_count = 0; // Reset the count of timeouts since we got our data
					}

					if (_waitingFirstData > 0) { // We got our first responseCode 200 since launching
						_waitingFirstData = 0;
						// if (!_wakeWasConfirmed) { // And we haven't asked to wake the vehicle, so it was already awoken when we got in, so send a gratious wake command so we stay awake for the app running time
						// 	/*DEBUG*/ logMessage("onReceiveVehicleData: sending gratious wake");
						// 	_need_wake = false;
						// 	_wake_done = false;
						// 	_waitingForCommandReturn = null;
						// 	_stateMachineCounter = 1; // Make sure we check on the next workerTimer
						// 	_tesla.wakeVehicle(_vehicle_vin, method(:onReceiveAwake)); // 
						// 	return;
						// }
					}

					if (_waitingForCommandReturn != null) { // We're still waiting for our commands to confirm it has been executed, so check soon
						_stateMachineCounter = 1;
					}
					else {
						var diff = currentTimeStamp - _lastTimeStamp;
						if (diff > 15000) { // Timestamp seems to be stalled (more than 5 seconds since the 10 secs update intervals), check if we're still awake
							_check_wake = true;
							_stateMachineCounter = 10; // Wait one second before checking if we're asleep (so we play nice and not pound)
						}
						else {
							_stateMachineCounter = (10000L - diff) / 100;
							if (_stateMachineCounter < 50) {
								_stateMachineCounter = 50; // We're close to the last update, check soon
							}
						}
					}
				}
				else if (currentTimeStamp == _lastTimeStamp) { // Not newer or equal to previous, ignore it
					SpinSpinner(responseCode);

					var systemTimeStamp = Time.now().value().toLong() * 1000L;
					var diff = systemTimeStamp - _lastTimeStamp;
					if (diff > 15000) { // Timestamp seems to be stalled (more than 5 seconds since the 10 secs update intervals), check if we're still awake
						_check_wake = true;
						_stateMachineCounter = 10; // Wait one second before checking if we're asleep (so we play nice and not pound)
					}
					else {
						_stateMachineCounter = (10000L - diff) / 100;
						if (_stateMachineCounter < 50) {
							_stateMachineCounter = 50; // We're close to the last update, check soon
						}
					}
				}
				else { // Not newer or equal to previous, ignore it and try again in 500 msec
					_stateMachineCounter = 5;
				}
				//DEBUG*/ logMessage("onReceiveVehicleData: timestamp previous " + _lastTimeStamp + " current " + currentTimeStamp + " diff of " + (currentTimeStamp - _lastTimeStamp).toString() + " _stateMachineCounter is " + _stateMachineCounter);

				_lastTimeStamp = currentTimeStamp;
			}
			else {
				//DEBUG*/ logMessage("onReceiveVehicleData: WARNING Received incomplete data, ignoring");
				_stateMachineCounter = 1;
			}
			return;
		}
		else {
			SpinSpinner(responseCode);

			_lastError = responseCode;

			if (_waitingFirstData > 0) { // Reset that counter if what we got was an error packet. We're interested in gap between packets received.
				_waitingFirstData = 1;
			}

			if (responseCode == 408) { // We got a timeout, check if we're still awake
				var i = _408_count + 1;
				//DEBUG*/ logMessage("onReceiveVehicleData: 408_count=" + i + " _waitingFirstData=" + _waitingFirstData);
				if (_waitingFirstData > 0 && _view._data._ready == false) { // We haven't received any data yet and we have already a message displayed
					_handler.invoke([3, i, Ui.loadResource(_data._vehicle_state.equals("asleep") == false ? Rez.Strings.label_requesting_data : Rez.Strings.label_waking_vehicle)]);
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
					_vehicle_vin = null;
		            _handler.invoke([0, -1, buildErrorString(responseCode)]);
				}
				else if (responseCode == 401) {
	                // Unauthorized, retry
		            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
				}
				else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
					_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
					_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down!
					return;
				}
				else if (responseCode != -5  && responseCode != -101) { // These are silent errors
		            _handler.invoke([0, -1, buildErrorString(responseCode)]);
		        }
			}
	    }
		_stateMachineCounter = 5;
	}

	function onReceiveAwake(responseCode, data) {
		//DEBUG*/ logMessage("onReceiveAwake: " + responseCode);

		if (responseCode == 200 || (responseCode == 403 && _data._vehicle_state != null && _data._vehicle_state.equals("asleep") == false)) { // If we get 403, check to see if we saw it awake since some country do not accept waking remotely
			var result = data.get("result");
			if (result == true) {
				_wake_done = true;
				_data._vehicle_state = "awake"; // Since we succeeded, say we're awake
				_stateMachineCounter = 1;
			}
			else { // If it's false, it timed out or not allowed. Ask user to wake him up himself
				_wake_done = true;
				_data._vehicle_state = "asleep"; // Since we succeeded, say we're awake
				_stateMachineCounter = 500; // Wait five seconds so we don't flood the communication
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_ask_manual_wake)]);
			}
		}
		else {
		   // We were unable to wake, try again
			_need_wake = true;
			_wake_done = false;
			if (responseCode == 404) { // Car not found? invalidate the vehicle and the next refresh will try to query what's our car
				_vehicle_vin = null;
				_handler.invoke([0, -1, buildErrorString(responseCode)]);
			}
			else if (responseCode == 403) { // Forbiden, ask to manually wake the vehicle and test its state through the vehicle states returned by onReceiveVehicles
				_stateMachineCounter = 10; // Wait a second so we don't flood the communication
				_vehicle_vin = "N/A";
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_ask_manual_wake)]);
				return;
			}
			else if (responseCode == 401) { // Unauthorized, retry
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_unauthorized)]);
			}
			else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
	            _handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
				_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down!
				return;
			}
			else if (responseCode != -5  && responseCode != -101) { // These are silent errors
				_handler.invoke([0, -1, buildErrorString(responseCode)]);
			}
			_stateMachineCounter = 50;
		}
	}

	function onCommandReturn(responseCode, data) {
		SpinSpinner(responseCode);

		if (_quickReturn) { // If we're not waiting for the command to return, null out it here so we're ready for the next one
			_waitingForCommandReturn = null;
		}

		//DEBUG*/ logMessage("onCommandReturn: " + responseCode);
		if (responseCode == 200) {
			var result = data.get("result");
			
			//DEBUG*/ var woke = data.get("woke"); logMessage("onCommandReturn: result is " + result + " woke is " + woke);
			if (result == true) {
				_data._vehicle_state = "awake"; // Since we succeeded, say we're awake
			}
			else {
				_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_might_have_failed)]); // The command failed, says so
			}
			_stateMachineCounter = 1;
		}
		else if (responseCode == 429 || responseCode == -400) { // -400 because that's what I received instead of 429 for some reason, although the http traffic log showed 429
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_too_many_request)]);
			_stateMachineCounter = 100; // We're pounding the Tesla's server, slow down!
		}
		else { // Our call failed, say the error and back to the main code
			_handler.invoke([0, -1, Ui.loadResource(Rez.Strings.label_might_have_failed) + "\n" + buildErrorString(responseCode)]);
			_stateMachineCounter = 1;
		}
	}

	function buildErrorString(responseCode) {
		if (responseCode == null || errorsStr[responseCode.toString()] == null) {
			return(Ui.loadResource(Rez.Strings.label_error) + responseCode);
		}
		else {
			return(Ui.loadResource(Rez.Strings.label_error) + responseCode + "\n" + errorsStr[responseCode.toString()]);
		}
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