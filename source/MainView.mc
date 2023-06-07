using Toybox.Background;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Time;
using Toybox.Timer;
using Toybox.Graphics;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

import Toybox.WatchUi;

/* For displayType
	Message received with type 0 : Will last 2 seconds
	Message received with type 1 : Will last 1 seconds
	Message received with type 2 : Will last 15 seconds or cleared if message null with type 0 received
	Message received with type 3 : Will disappear as soon as the screen can be displayed
	Messages with the same type as the previous overrides the previous message
	No message with type 0: Timer reset, sceen will be displayed
	No message with any other types, ignored
*/

var gWaitTime; // Sorry, easiest way of dealing with variables used in subviews (carPicker in this situation)

class MainView extends Ui.View {
	hidden var _display;
	hidden var _displayTimer;
	hidden var _displayType;
	hidden var _errorTimer;
	hidden var _408_count;
	hidden var _curPosX;
	hidden var _startPosX;
	hidden var _xDir;
	hidden var _scrollEndTimer;
	hidden var _scrollStartTimer;
	var _data;
	var _refreshTimer;
	var _viewUpdated;
	// DEBUG variables
	//DEBUG*/ var _showLogMessage, old_climate_state; var old_left_temp_direction; var old_right_temp_direction; var old_climate_defrost; var old_climate_batterie_preheat; var old_rear_defrost; var old_defrost_mode;

	// Initial load - show the 'requesting data' string, make sure we don't process touches
	function initialize(data) {
		View.initialize();

		_data = data;
		_data._ready = false;
		_errorTimer = 0;
		_displayType = -1;
		gWaitTime = System.getTimer();
		// DEBUG variables
		//DEBUG*/ _showLogMessage = true; old_climate_state = false; old_left_temp_direction = 0; old_right_temp_direction = 0; old_climate_defrost = false; old_climate_batterie_preheat = false; old_rear_defrost = false; old_defrost_mode = 0;

		_display = Ui.loadResource(Rez.Strings.label_requesting_data);
		_displayTimer = "";
		_408_count = 0;
		_curPosX = null;
		_startPosX = null;
		_xDir = -1;
		_scrollEndTimer = 0;
		_scrollStartTimer = 0;

		//DEBUG*/ logMessage("MainView:initialize: _refreshTimer is " + _refreshTimer);
		_refreshTimer = new Timer.Timer();

		Storage.setValue("spinner", "-");
		if (Storage.getValue("refreshTimeInterval") == null) {
			Storage.setValue("refreshTimeInterval", 4);
		}

		Ui.requestUpdate();
		_viewUpdated = false;
	}

	function onLayout(dc) {
		setLayout(Rez.Layouts.ImageLayout(dc));
	}

	function onShow() {
		//DEBUG*/ logMessage("MainView:onShow");
		if (Properties.getValue("titleScrolling")) {
			_refreshTimer.start(method(:refreshView), 50, true);
		}
		else {
			_refreshTimer.start(method(:refreshView), 500, true);
		}
	}
	
	function onHide() {
		//DEBUG*/ logMessage("MainView:onHide");
        Storage.setValue("runBG", true); // Make sure that the background jobs can run when we leave the main view
		_refreshTimer.stop();
		//_refreshTimer = null;
	}

	function refreshView() {
		//logMessage("MainView:refreshView: requesting update");
		//DEBUG*/ _showLogMessage = false;
		if (_displayTimer != null) {
			var timeWaiting = System.getTimer() - gWaitTime;
			var tmpStr = null;
			if (_408_count > 0) {
				tmpStr = "(408x" + _408_count;
			}
			if (timeWaiting > 1000) {
				if (tmpStr) {
					tmpStr = tmpStr + " - ";
				}
				else {
					tmpStr = "(";
				}
				_displayTimer = "\n" + tmpStr + timeWaiting / 1000 + "s)";
			}
			else if (tmpStr != null) {
				_displayTimer = "\n" + tmpStr + ")";
			}
			else {
				_displayTimer = "";
			}
		}
		if (_viewUpdated) {
			Ui.requestUpdate();
			_viewUpdated = false;
		}
		else {
			//logMessage("MainView:refreshView: skipping, already waiting for a viewUpdate");
		}
	}

	function onReceive(args) {
		//DEBUG*/ _showLogMessage = false;

		if (System.getTimer() > _errorTimer) { // Have we timed out our previous text display
			_errorTimer = 0;
		}

		if (args[2] != null) {
			if (args[0] == 0) {
				//DEBUG*/ logMessage("MainView:onReceive: priority msg: '" + args[2] + "'");
				_errorTimer = System.getTimer() + 2000; // priority message stays two seconds
				//DEBUG*/ if (_display == null || !_display.equals(args[2])) { _showLogMessage = true; }
				_display = args[2];
				_displayType = args[0];
			} else if (_errorTimer == 0 || _displayType == args[0]) {
				//DEBUG*/ logMessage("MainView:onReceive: type " + args[0] + " msg: '" + args[2] + "'");
				if (args[0] == 1) { // Informational message stays a second
					_errorTimer = System.getTimer() + 1000;
				} else if (args[0] > 1) { // Actionable message (type 2) will disappear when type 0 with null is received or 60 seconds has passed and type 3 with a null when type 1 is received
					_errorTimer = System.getTimer() + 60000;
				}
				//DEBUG*/ if (_display == null || _display.equals(args[2]) == false) { _showLogMessage = true; }
				_display = args[2];
				_displayType = args[0];
			}

			if (args[1] != -1 && _displayType != 0) { //Add the timer to the string being displayed, unless we're showing an error (no counter there)
				_408_count = args[1];
				var timeWaiting = System.getTimer() - gWaitTime;
				var tmpStr = null;
				if (_408_count > 0) {
					tmpStr = "(408x" + _408_count;
				}
				if (timeWaiting > 1000) {
					if (tmpStr) {
						tmpStr = tmpStr + " - ";
					}
					else {
						tmpStr = "(";
					}
					_displayTimer = "\n" + tmpStr + timeWaiting / 1000 + "s)";
				}
				else if (tmpStr != null) {
					_displayTimer = "\n" + tmpStr + ")";
				}
				else {
					_displayTimer = "";
				}
			} else {
				_displayTimer = null;
			}
		} else if (_errorTimer == 0 || args[0] == 0 || (args[0] == 1 && _displayType == 3)) {
			//DEBUG*/ if (args[0] != 1 || _errorTimer != 0) { logMessage("MainView:onReceive: null msg, args[0]=" + args[0] + ", _errorTimer=" + _errorTimer); }
			_display = null;
			_displayTimer = null;
			_displayType = -1;
			_errorTimer = 0;
		}

		Ui.requestUpdate();
		_viewUpdated = false;
	}

	function onUpdate(dc) {
		// Set up all our variables for drawing things in the right place!
		var width = dc.getWidth();
		var height = dc.getHeight();
		var center_x = width / 2 - 1;
		var center_y = height / 2 - 1;

		_viewUpdated = true; // Tell refreshScreen that we updated our view

		// Load our custom font if it's there, generally only for high res, high mem devices
		var font_montserrat;
		if (Rez.Fonts has :montserrat) {
			font_montserrat=Ui.loadResource(Rez.Fonts.montserrat);
		} else {
			font_montserrat=Graphics.FONT_TINY;
		}

		// Redraw the layout and wipe the canvas
		if (_display != null) { // We have a message to dislay instead of our canvas
			// We're showing a message, so set 'ready' false to prevent touches
			_data._ready = false;

			//DEBUG*/ if (_showLogMessage) { logMessage("MainView:onUpdate: Msg '" + _display + (_displayTimer != null ? _displayTimer : "") + "'"); }
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
			dc.clear();
			dc.drawText(center_x, center_y, font_montserrat, _display + (_displayTimer != null ? _displayTimer : ""), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

			if (System.getTimer() > _errorTimer && _errorTimer != 0 && _data._vehicle_data != null) { // Have we timed out our text display and we have something to display
				//DEBUG*/ logMessage("MainView:onUpdate: Clearing timer/display");
				_errorTimer = 0;
				_display = null;
				_displayTimer = "";
			}
		}
		else if (_data._vehicle_data != null) {
			//DEBUG*/ if (_showLogMessage) { logMessage("MainView:onUpdate: drawing"); }

			// Showing the main layouts, so we can process touches now
			_data._ready = true;
			_errorTimer = 0;

			// We're going to use the image layout by default if it's a touchscreen, also check the option setting to allow toggling
			var is_touchscreen = System.getDeviceSettings().isTouchScreen;
			var use_image_layout = Storage.getValue("image_view");
			if (use_image_layout == null) {					   /* Defaults to image_layout for all watches */
				use_image_layout = true;
				Storage.setValue("image_view", /* System.getDeviceSettings().isTouchScreen */ true);
				//DEBUG*/ logMessage("MainView:onUpdate: defaulting to image layout");
			}

			// Set up our layout based on the mode chosen
			if (use_image_layout) {
				// We're loading the image layout
				setLayout(Rez.Layouts.ImageLayout(dc));
			}
			else {
				// We're loading the text based layout
				setLayout(Rez.Layouts.TextLayout(dc));
			}

			// Set up the screen and draw common items
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
			dc.clear();
			View.onUpdate(dc);

			// Dynamic pen width based on screen size
			var penWidth = Math.round(width/33+0.5).toNumber();
			dc.setPenWidth(penWidth);

			var radius;
			if (center_x < center_y) {
				radius = center_x - penWidth / 2;
				center_y = center_y + (height - width) / 2;
			}
			else {
				radius = center_y - penWidth / 2;
			}

			// If we have the vehicle data back from the API, this is where the good stuff happens
			// Retrieve and display the vehicle name
			var name_drawable = View.findDrawableById("name");
			var vehicle_name = $.validateString(_data._vehicle_data.get("vehicle_state").get("vehicle_name"), "");
			var app_vehicle_name = Storage.getValue("vehicle_name");
			if (app_vehicle_name == null) {
				Storage.setValue("vehicle_name", vehicle_name);
			}
			else if (vehicle_name.equals(app_vehicle_name) == false) { // We switched vehicle, have it recalculate our position on screen
				_curPosX = null;
				_xDir = -1;
				_scrollEndTimer = 0;
				_scrollStartTimer = 0;
			}
			//DEBUG*/ vehicle_name = "Tesla";
			var fontHeight = Graphics.getFontHeight(Graphics.FONT_SMALL);
			var textWidth = dc.getTextWidthInPixels(vehicle_name, Graphics.FONT_SMALL);
			var screenShape = System.getDeviceSettings().screenShape;
			var textPos;
			var textMaxWidth;
			if (screenShape == System.SCREEN_SHAPE_RECTANGLE && width < height) {
				textPos = 0;
				textMaxWidth = width;
			}
			else if (Properties.getValue("titleScrolling")) {
				textPos = center_x / 14;
				var textFromCenter = center_x - textPos - fontHeight / 2;
				var rad = Math.acos(textFromCenter.toFloat() / radius.toFloat());
				var halfMaxText = Math.sin(rad) * radius.toFloat();
				textMaxWidth = 2 * halfMaxText - penWidth;
			}
			else {
				textMaxWidth = width;
				textPos = center_x / 14;
			}

			//var textMaxWidth = (2 * radius * Math.sin(Math.toRadians(2 * Math.toDegrees(Math.acos(1 - (15.0 / radius)))) / 2)).toNumber();
			if (_curPosX == null) {
				if (textWidth > textMaxWidth + penWidth) {
					_curPosX = center_x - textMaxWidth / 2;
					_startPosX = _curPosX;
				}
				else {
					_curPosX = center_x - textWidth / 2;
					_startPosX = _curPosX;
				}
			}
			else if (textWidth > textMaxWidth + penWidth) {
				if (_scrollStartTimer > 20) {
					_curPosX = _curPosX + _xDir;

					if (_curPosX + textWidth < _startPosX + textMaxWidth) {
						_xDir = 0;
						_scrollEndTimer = _scrollEndTimer + 1;
						if (_scrollEndTimer == 20) {
							_curPosX = center_x - textMaxWidth / 2;
							_startPosX = _curPosX;
							_xDir = -1;
							_scrollEndTimer = 0;
							_scrollStartTimer = 0;
						}
					}
				}
				else {
					_scrollStartTimer = _scrollStartTimer + 1;
				}
			}

			//name_drawable.setText(vehicle_name);
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
			if (screenShape == System.SCREEN_SHAPE_RECTANGLE && width == height) {
				dc.setClip(center_x - textMaxWidth / 2, 0, textMaxWidth, height);
			}
			dc.drawText(_curPosX, textPos, Graphics.FONT_SMALL, vehicle_name, Graphics.TEXT_JUSTIFY_LEFT);
			name_drawable.draw(dc);
			dc.clearClip();

			// Draw the grey arc in an appropriate size for the display
			dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
			dc.drawArc(center_x, center_y , radius, Graphics.ARC_CLOCKWISE, 225, 315);

			// Grab the data we're going to use around charge and climate
			var swap_frunk_for_port = Properties.getValue("swap_frunk_for_port");
			var battery_level = $.validateNumber(_data._vehicle_data.get("charge_state").get("battery_level"), 0);
			var charge_limit = $.validateNumber(_data._vehicle_data.get("charge_state").get("charge_limit_soc"), 0);
			var charging_state = $.validateString(_data._vehicle_data.get("charge_state").get("charging_state"), "");
			var inside_temp = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? ((($.validateNumber(_data._vehicle_data.get("climate_state").get("inside_temp"), 0) * 9) / 5) + 32) + "°F" : $.validateNumber(_data._vehicle_data.get("climate_state").get("inside_temp"), 0) + "°C";
			var door_open = $.validateNumber(_data._vehicle_data.get("vehicle_state").get("df"), 0) + $.validateNumber(_data._vehicle_data.get("vehicle_state").get("dr"), 0) + $.validateNumber(_data._vehicle_data.get("vehicle_state").get("pf"), 0) + $.validateNumber(_data._vehicle_data.get("vehicle_state").get("pr"), 0);

			// Draw the charge status
			dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_BLACK);
			var charge_angle = 225 - (battery_level * 270 / 100);
			charge_angle = charge_angle < 0 ? 360 + charge_angle : charge_angle;
			dc.drawArc(center_x, center_y , radius, Graphics.ARC_CLOCKWISE, 225, charge_angle);

			// Draw the charge limit indicator
			dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
			var limit_angle = 225 - (charge_limit * 270 / 100);
			var limit_start_angle = limit_angle + 2;
			limit_start_angle = limit_start_angle < 0 ? 360 + limit_start_angle : limit_start_angle;
			var limit_end_angle = limit_angle - 2;
			limit_end_angle = limit_end_angle < 0 ? 360 + limit_end_angle : limit_end_angle;
			dc.drawArc(center_x, center_y , radius, Graphics.ARC_CLOCKWISE, limit_start_angle, limit_end_angle);

			// Common climate data
			var climate_state = $.validateBoolean(_data._vehicle_data.get("climate_state").get("is_climate_on"), false);
			var climate_defrost = $.validateBoolean(_data._vehicle_data.get("climate_state").get("is_front_defroster_on"), false);
			var defrost_mode = $.validateNumber(_data._vehicle_data.get("climate_state").get("defrost_mode"), false);

			// Image layout is where most of the stuff is drawn
			if (use_image_layout) {
				var spacing = 0;
				if (screenShape == System.SCREEN_SHAPE_RECTANGLE && width < height) {
					center_y = center_y - fontHeight / 3;
					spacing = fontHeight / 3;
				}
				
				var bm = Ui.loadResource(Rez.Drawables.settings_icon);
				var bm_width = bm.getWidth();
				var bm_height = bm.getHeight();

				var image_x_left = center_x - center_x / 3 - bm_width / 2;
				var image_y_top = center_y - center_x / 3 - bm_height / 2;
				var image_x_right = center_x + center_x / 3 - bm_width / 2;
				var image_y_bottom = center_y + center_x / 3 - bm_height / 2 + spacing;

				dc.drawBitmap(image_x_right, image_y_bottom, Ui.loadResource(is_touchscreen? Rez.Drawables.settings_icon : Rez.Drawables.back_icon));

				// Draw the dynamic icon for the frunk/trunk/port/vent
				dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.vehicle));

				// If we're driving, only show a moving car. No interaction possible!
				var shift_state = $.validateString(_data._vehicle_data.get("drive_state").get("shift_state"), "");
				if (shift_state.equals("") == false && shift_state.equals("P") == false) {
					dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.driving));
				}
				else {
					if (swap_frunk_for_port == null) {
						swap_frunk_for_port = 0;
					}

					var venting = $.validateNumber(_data._vehicle_data.get("vehicle_state").get("fd_window"), 0) + $.validateNumber(_data._vehicle_data.get("vehicle_state").get("rd_window"), 0) + $.validateNumber(_data._vehicle_data.get("vehicle_state").get("fp_window"), 0) + $.validateNumber(_data._vehicle_data.get("vehicle_state").get("rp_window"), 0);

					// Show what we chould interact with
					switch (swap_frunk_for_port) {
						case 0:
							dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.frunkAction));
							break;
						case 1:
							dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.trunkAction));
							break;
						case 2:
							dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.portAction));
							break;
						case 3:
							if (venting == 0) {
								dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.popMenu));
							}
							break;
					}

					if ($.validateNumber(_data._vehicle_data.get("vehicle_state").get("ft"), 0) != 0) {
						dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.frunkOpened));
					}
					if ($.validateNumber(_data._vehicle_data.get("vehicle_state").get("rt"), 0) != 0) {
						dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.trunkOpened));
					}
					if ($.validateBoolean(_data._vehicle_data.get("charge_state").get("charge_port_door_open"), false) == true) {
						dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.portOpened));
					}
					if (venting) {
						dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(Rez.Drawables.windowsOpened));
					}
				}

				// Update the lock state indicator
				dc.drawBitmap(image_x_left, image_y_bottom,($.validateBoolean(_data._vehicle_data.get("vehicle_state").get("locked"), false) ? Ui.loadResource(Rez.Drawables.locked_icon) : door_open ? Ui.loadResource(Rez.Drawables.door_open_icon) : Ui.loadResource(Rez.Drawables.unlocked_icon)));

				bm = Ui.loadResource(Rez.Drawables.locked_icon);
				bm_width = bm.getWidth();
				bm_height = bm.getHeight();

				// Update the climate state indicator, note we have blue or red icons depending on heating or cooling
				var climate_batterie_preheat = $.validateBoolean(_data._vehicle_data.get("climate_state").get("battery_heater"), false);
				var rear_defrost = $.validateBoolean(_data._vehicle_data.get("climate_state").get("is_rear_defroster_on"), false);
				var left_temp_direction = $.validateNumber(_data._vehicle_data.get("climate_state").get("left_temp_direction"), 0);
				var bm_waves;
				var bm_blades;

				/*DEBUG climate_state = false;
				climate_batterie_preheat = true;
				defrost_mode = 1;
				climate_defrost = false;
				rear_defrost = true;
				left_temp_direction = -1;*/ 

				/*DEBUG var driver_temp = _data._vehicle_data.get("climate_state").get("driver_temp_setting");
				var right_temp_direction = _data._vehicle_data.get("climate_state").get("right_temp_direction");
				var venting = _data._vehicle_data.get("vehicle_state").get("fd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("fp_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rp_window").toNumber();
				 if (climate_state != old_climate_state || left_temp_direction != old_left_temp_direction || right_temp_direction != old_right_temp_direction || climate_defrost != old_climate_defrost || climate_batterie_preheat != old_climate_batterie_preheat || rear_defrost != old_rear_defrost || defrost_mode != old_defrost_mode) {
					logMessage("MainView:onUpdate: Climate_state: " + climate_state + " left_temp_direction: " + left_temp_direction + " right_temp_direction: " + right_temp_direction + " climate_defrost: " + climate_defrost + " climate_batterie_preheat: " + climate_batterie_preheat + " rear_defrost: " + rear_defrost + " defrost_mode: " + defrost_mode);
					// 2023-03-20 _showLogMessage = true;
					old_climate_state = climate_state; old_left_temp_direction = left_temp_direction; old_right_temp_direction = right_temp_direction; old_climate_defrost = climate_defrost; old_climate_batterie_preheat = climate_batterie_preheat; old_rear_defrost = rear_defrost; old_defrost_mode = defrost_mode;
					//logMessage("MainView:onUpdate: venting: " + venting + " locked: " + _data._vehicle_data.get("vehicle_state").get("locked") + " climate: " + climate_state);
				}*/

				try {
					if (climate_state == false) {
						bm = Ui.loadResource(Rez.Drawables.climate_off_icon) as BitmapResource;
						bm_waves = Ui.loadResource(Rez.Drawables.climate_waves_off) as BitmapResource;
						bm_blades = Ui.loadResource(Rez.Drawables.climate_blades_off) as BitmapResource;
					}
					else if (left_temp_direction < 0 && !climate_defrost) {
						// 2023-03-20 if (_showLogMessage) { logMessage("MainView:onUpdate: Cooling drv:" + driver_temp + " inside:" + inside_temp); }
						bm = Ui.loadResource(Rez.Drawables.climate_on_icon_blue) as BitmapResource;
						bm_waves = Ui.loadResource(Rez.Drawables.climate_waves_blue) as BitmapResource;
						bm_blades = Ui.loadResource(Rez.Drawables.climate_blades_blue) as BitmapResource;
					}
					else {
						// 2023-03-20 if (_showLogMessage) { logMessage("MainView:onUpdate: Heating drv:" + driver_temp + " inside:" + inside_temp); }
						bm = Ui.loadResource(Rez.Drawables.climate_on_icon_red) as BitmapResource;
						bm_waves = Ui.loadResource(Rez.Drawables.climate_waves_red) as BitmapResource;
						bm_blades = Ui.loadResource(Rez.Drawables.climate_blades_red) as BitmapResource;
					}
				}
				catch (e) {
					//DEBUG*/ logMessage("View:onUpdate: Caught exception " + e);
					bm = Ui.loadResource(Rez.Drawables.climate_off_icon) as BitmapResource;
					bm_waves = Ui.loadResource(Rez.Drawables.climate_waves_off) as BitmapResource;
					bm_blades = Ui.loadResource(Rez.Drawables.climate_blades_off) as BitmapResource;
				}

				// Draw the climate icon
				bm_width = bm.getWidth();
				bm_height = bm.getHeight();
				dc.drawBitmap(image_x_right, image_y_top, bm);
				image_x_right = image_x_right;
				image_y_top = image_y_top;
				if (climate_batterie_preheat) {
					dc.drawBitmap(image_x_right + bm_width / 2 + bm_width / 8, image_y_top + bm_height / 4, bm_waves);
				}
				if (climate_defrost) {
					dc.drawBitmap(image_x_right + bm_width / 4, image_y_top + bm_height / 4, bm_waves);
				}

				if (rear_defrost) {
					dc.drawBitmap(image_x_right + bm_width / 4, image_y_top + bm_height / 2 + bm_height / 8, bm_waves);
				}

				if (defrost_mode == 1) {
					dc.drawBitmap(image_x_right + bm_width / 2 + bm_width / 8, image_y_top + bm_height / 2 + bm_height / 8, bm_blades);
				}
				else if (defrost_mode == 2) {
					dc.drawBitmap(image_x_right + bm_width / 2 + bm_width / 8, image_y_top + bm_height / 2 + bm_height / 8, bm_waves);
				}
				
				// Update the text at the bottom of the screen with charge and temperature
				var status_drawable = View.findDrawableById("status");
				var charging_current = $.validateNumber(_data._vehicle_data.get("charge_state").get("charge_current_request"), 0);
				if (charging_current == null) {
					charging_current = 0;
				}
				
				status_drawable.setText(battery_level + (charging_state.equals("Charging") ? "%+ " : "% ") + charging_current + "A " + inside_temp);
				status_drawable.draw(dc);

				// Draw the text in the middle of the screen with departure time (if set)
				if ($.validateBoolean(_data._vehicle_data.get("charge_state").get("preconditioning_enabled"), false)) {
					var departure_time = $.validateNumber(_data._vehicle_data.get("charge_state").get("scheduled_departure_time_minutes"), 0);
					var departure_drawable = View.findDrawableById("departure");
					var hours = (departure_time / 60).toLong();
					var minutes = (((departure_time / 60.0) - hours) * 60).toLong();
					var timeStr;
					if (System.getDeviceSettings().is24Hour) {
						timeStr = Lang.format(Ui.loadResource(Rez.Strings.label_departure) + "$1$h$2$", [hours.format("%2d"), minutes.format("%02d")]);
					}
					else {
						var ampm = "am";
						var hours12 = hours;

						if (hours == 0) {
							hours12 = 12;
						}
						else if (hours > 12) {
							ampm = "pm";
							hours12 -= 12;
						}
						
						timeStr = Lang.format(Ui.loadResource(Rez.Strings.label_departure) + "$1$:$2$$3$", [hours12.format("%2d"), minutes.format("%02d"), ampm]);
					}
					departure_drawable.setText(timeStr.toString());
					departure_drawable.draw(dc);
				}

				// Draw our spinner
				var _spinner = Storage.getValue("spinner");
				if (_spinner != null) {
					var spinner_drawable = View.findDrawableById("spinner");
					spinner_drawable.setText(_spinner.toString());
					spinner_drawable.draw(dc);
				}

				// Draw the Sentry 'eye' icon if activated
				var sentry_y = image_y_top - height/13;
				var bitmap = Ui.loadResource($.validateBoolean(_data._vehicle_data.get("vehicle_state").get("sentry_mode"), false) ? Rez.Drawables.sentry_on_icon : Rez.Drawables.sentry_off_icon) as BitmapResource;
				var bitmap_width = bitmap.getWidth();
				var bitmap_height = bitmap.getHeight();
				dc.drawBitmap(center_x - bitmap_width / 2, sentry_y + bitmap_height / 2, bitmap);

				/*DEBUG /* Draw rectangles to show where the enhanced touch points are
				var x, y;
				dc.setPenWidth(1);
				dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_BLACK);

				// Tap on the vehicle name
				dc.drawRectangle(0, 0, System.getDeviceSettings().screenWidth, System.getDeviceSettings().screenHeight / 7);
				// Tap on the space used by the 'Eye'
				x = System.getDeviceSettings().screenWidth / 2 - (System.getDeviceSettings().screenWidth / 11).toNumber();
				y = System.getDeviceSettings().screenHeight / 7;
				dc.drawRectangle(x, y, System.getDeviceSettings().screenWidth / 2 + (System.getDeviceSettings().screenWidth / 11).toNumber() - x, (System.getDeviceSettings().screenHeight / 3.5).toNumber() - y);
				// Tap on the middle text line where Departure is written
				x = 0;
				y = (System.getDeviceSettings().screenHeight / 2.3).toNumber();
				dc.drawRectangle(x, y, System.getDeviceSettings().screenWidth, (System.getDeviceSettings().screenHeight / 1.8).toNumber() - y);
				// Tap on bottom line on screen
				y = (System.getDeviceSettings().screenHeight  / 1.25).toNumber();
				dc.drawRectangle(0, y, System.getDeviceSettings().screenWidth / 2, System.getDeviceSettings().screenHeight);
				dc.drawRectangle(System.getDeviceSettings().screenWidth / 2, y, System.getDeviceSettings().screenWidth, System.getDeviceSettings().screenHeight);

				// Quadrants
				dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_BLACK);
				dc.drawLine(System.getDeviceSettings().screenWidth/2, 0, System.getDeviceSettings().screenWidth/2, System.getDeviceSettings().screenHeight);
				dc.drawLine(0, System.getDeviceSettings().screenHeight/2, System.getDeviceSettings().screenWidth, System.getDeviceSettings().screenHeight/2);
				/*DEBUG*/
			}
			else {
				// Text layout, so update the lock status text   
				var status_drawable = View.findDrawableById("status");
				if ($.validateBoolean(_data._vehicle_data.get("vehicle_state").get("locked"), false)) {
					status_drawable.setColor(Graphics.COLOR_DK_GREEN);
					status_drawable.setText(Rez.Strings.label_locked);
				} else {
					status_drawable.setColor(Graphics.COLOR_RED);
					status_drawable.setText(Rez.Strings.label_unlocked);
				}              
				status_drawable.draw(dc);

				// Update frunk/trunk/port text
				var frunk_drawable = View.findDrawableById("frunk");
				frunk_drawable.setText(swap_frunk_for_port == 0 ?  Rez.Strings.label_frunk : swap_frunk_for_port == 1 ?  Rez.Strings.label_trunk : swap_frunk_for_port == 2 ?  Rez.Strings.label_port : Rez.Strings.label_frunktrunkport);

				// Update the temperature text
				var inside_temp_drawable = View.findDrawableById("inside_temp");
				inside_temp_drawable.setText(Ui.loadResource(Rez.Strings.label_cabin) + inside_temp);

				// Update the climate state text
				var climate_state_drawable = View.findDrawableById("climate_state");
				var climate_state_str = Ui.loadResource(Rez.Strings.label_climate) + ((defrost_mode == 2 || climate_defrost) ? Ui.loadResource(Rez.Strings.label_defrost) : climate_state ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off));
				climate_state_drawable.setText(climate_state_str);

				// Update the battery level text
				var battery_level_drawable = View.findDrawableById("battery_level");  
				battery_level_drawable.setColor((charging_state.equals("Charging")) ? Graphics.COLOR_RED : Graphics.COLOR_WHITE);
				battery_level_drawable.setText(Ui.loadResource(Rez.Strings.label_charge) + battery_level.toString() + "%");
				
				// Do the draws
				inside_temp_drawable.draw(dc);
				climate_state_drawable.draw(dc);
				battery_level_drawable.draw(dc);
			}
		}
		else {
			// 2023-03-20 logMessage("MainView:onUpdate: How did we get here?");
		}
	}
}
