using Toybox.Background;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Time;

class MainView extends Ui.View {
    hidden var _display;
    hidden var _displayType = 1;
	hidden var _previousDisplayType = 1;
    var _data;
	var _errorTimer;
	var _bufferedText;
					
    // Initial load - show the 'requesting data' string, make sure we don't process touches
    function initialize(data) {
        View.initialize();
        _data = data;
        _data._ready = false;
		_errorTimer = System.getTimer() + 2000;
		_bufferedText = null;
			
        _display = Ui.loadResource(Rez.Strings.label_requesting_data);
        _bufferedText = _display;
//logMessage("MainView:initialize with _display at " + _display);

		Application.getApp().setProperty("spinner", "-");
        if (Application.getApp().getProperty("refreshTimeInterval") == null) {
        	Application.getApp().setProperty("refreshTimeInterval", 4);
        }
    }

    function onShow() {
	    Application.getApp().setProperty("refreshTimer", true);
	}
	
    function onHide() {
	    Application.getApp().setProperty("refreshTimer", false);
	}

    function onLayout(dc) {
        setLayout(Rez.Layouts.ImageLayout(dc));
    }

    function onReceive(args) {
        _displayType = args[0];
        _display = args[1];
        Ui.requestUpdate();
    }

    function onUpdate(dc) {
        // Set up all our variables for drawing things in the right place!
        var width = dc.getWidth();
        var height = dc.getHeight();
        var extra = (width/7+width/28) * ((width.toFloat()/height.toFloat())-1);
        var image_x_left = (width/7+width/28+extra).toNumber();
        var image_y_top = (height/7+height/21).toNumber();
        var image_x_right = (width/7*4-width/28+extra).toNumber();
        var image_y_bottom = (height/7*4-height/21).toNumber();
        var center_x = dc.getWidth()/2;
        var center_y = dc.getHeight()/2;
        var sentry_y = image_y_top - height/21;
        
        // Load our custom font if it's there, generally only for high res, high mem devices
        var font_montserrat;
        if (Rez.Fonts has :montserrat) {
            font_montserrat=Ui.loadResource(Rez.Fonts.montserrat);
        } else {
            font_montserrat=Graphics.FONT_TINY;
        }

        // Next background update in 5 mins!
        Background.registerForTemporalEvent(new Time.Duration(60*5));

        // Redraw the layout and wipe the canvas
        if (_display != null || (_errorTimer > 0 && _previousDisplayType != 1)) {
            // We're showing a message, so set 'ready' false to prevent touches
            _data._ready = false;

			if (_displayType == 0 && _display != null) { // We're displaying an error, time it so it stays up (at least) 2 seconds
//logMessage("Priority Message " + _display);
				_errorTimer = System.getTimer() + 2000;
				_bufferedText = _display;
				_previousDisplayType = _displayType;
			} else if (_errorTimer == 0) {
//logMessage("Show this Message " + _display);
				if (_displayType == 1) {
					_errorTimer = System.getTimer() + 1000;
				} else {
					_errorTimer = 0; // Confirmation message disappears as soon as the next message show up
				}

				_bufferedText = _display;
				_previousDisplayType = _displayType;
			}
			_displayType = -1;

			if (System.getTimer() > _errorTimer) { // Time's up
				_errorTimer = 0;
			}
			_display = _bufferedText;
// 2022-10-10 logMessage("Showing Message " + _display);
			
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            dc.drawText(center_x, center_y, font_montserrat, _display, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (_data._vehicle_data != null) {
            // Showing the main layouts, so we can process touches now
            _data._ready = true;
            _errorTimer = 0;

            // We're going to use the image layout by default if it's a touchscreen, also check the option setting to allow toggling
            var is_touchscreen = System.getDeviceSettings().isTouchScreen;
            var use_image_layout = Application.getApp().getProperty("image_view") == null ? System.getDeviceSettings().isTouchScreen : Application.getApp().getProperty("image_view");
            Application.getApp().setProperty("image_view", use_image_layout);

			// Read temperature unit from the watch settings
			//Application.getApp().setProperty("imperial", System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE);

            // Swap frunk for port?
            // New value : Frunk = 0, Trunk = 1. Port = 2
            var swap_frunk_for_port = Application.getApp().getProperty("swap_frunk_for_port");
            
            if (use_image_layout)
            {
                // We're loading the image layout
                setLayout(Rez.Layouts.ImageLayout(dc));
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.clear();
                View.onUpdate(dc);
            
                // Draw the initial icons (in white) in case we don't have vehicle data
                //dc.drawBitmap(image_x_left,image_y_top,swap_frunk_for_port == 0 ?  Ui.loadResource(Rez.Drawables.frunk_icon_white) : swap_frunk_for_port == 1 ?  Ui.loadResource(Rez.Drawables.trunk_icon_white) : swap_frunk_for_port == 2 ?  Ui.loadResource(Rez.Drawables.charge_icon) : Ui.loadResource(Rez.Drawables.frunktrunkport_icon_white));
                if (swap_frunk_for_port != 3) {
	                dc.drawBitmap(image_x_left,image_y_top,swap_frunk_for_port == 0 || swap_frunk_for_port == null ?  Ui.loadResource(Rez.Drawables.frunk_icon_white) : swap_frunk_for_port == 1 ?  Ui.loadResource(Rez.Drawables.trunk_icon_white) : Ui.loadResource(Rez.Drawables.charge_icon));
	            }
	            else {
                    var venting = _data._vehicle_data.get("vehicle_state").get("fd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("fp_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rp_window").toNumber();
					var which_bitmap = 0;
					var iconList = [
						Rez.Drawables.frunk0trunk0port0vent0_icon_white,
						Rez.Drawables.frunk1trunk0port0vent0_icon_white,
						Rez.Drawables.frunk0trunk1port0vent0_icon_white,
						Rez.Drawables.frunk1trunk1port0vent0_icon_white,
						Rez.Drawables.frunk0trunk0port1vent0_icon_white,
						Rez.Drawables.frunk1trunk0port1vent0_icon_white,
						Rez.Drawables.frunk0trunk1port1vent0_icon_white,
						Rez.Drawables.frunk1trunk1port1vent0_icon_white,
						Rez.Drawables.frunk0trunk0port0vent1_icon_white,
						Rez.Drawables.frunk1trunk0port0vent1_icon_white,
						Rez.Drawables.frunk0trunk1port0vent1_icon_white,
						Rez.Drawables.frunk1trunk1port0vent1_icon_white,
						Rez.Drawables.frunk0trunk0port1vent1_icon_white,
						Rez.Drawables.frunk1trunk0port1vent1_icon_white,
						Rez.Drawables.frunk0trunk1port1vent1_icon_white,
						Rez.Drawables.frunk1trunk1port1vent1_icon_white
					];

					if (_data._vehicle_data.get("vehicle_state").get("ft") != 0) {
						which_bitmap = 1;
					}
					if (_data._vehicle_data.get("vehicle_state").get("rt") != 0) {
						which_bitmap += 2;
					}
					if (_data._vehicle_data.get("charge_state").get("charge_port_door_open") == true) {
						which_bitmap += 4;
					}
					if (venting) {
						which_bitmap += 8;
					}

					dc.drawBitmap(image_x_left, image_y_top, Ui.loadResource(iconList[which_bitmap]));
	            }
	            
                dc.drawBitmap(image_x_right, image_y_top, Ui.loadResource(Rez.Drawables.climate_on_icon_white));
                dc.drawBitmap(image_x_left, image_y_bottom, Ui.loadResource(Rez.Drawables.locked_icon_white));
                dc.drawBitmap(image_x_right, image_y_bottom, Ui.loadResource(is_touchscreen? Rez.Drawables.settings_icon : Rez.Drawables.back_icon));
            }
            else
            {
                // We're loading the text based layout
                setLayout(Rez.Layouts.TextLayout(dc));
                var frunk_drawable = View.findDrawableById("frunk");
                
                frunk_drawable.setText(swap_frunk_for_port == 0 ?  Rez.Strings.label_frunk : swap_frunk_for_port == 1 ?  Rez.Strings.label_trunk : swap_frunk_for_port == 2 ?  Rez.Strings.label_port : Rez.Strings.label_frunktrunkport);
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
                dc.clear();
                View.onUpdate(dc);
            }

            // Draw the grey arc in an appropriate size for the display
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
            var radius;
            if (center_x < center_y) {
                radius = center_x-3;
            } else {
                radius = center_y-3;
            }

            // Dynamic pen width based on screen size
            dc.setPenWidth(((dc.getWidth()/33)).toNumber());
            dc.drawArc(center_x, center_y, radius, Graphics.ARC_CLOCKWISE, 225, 315);

            // If we have the vehicle data back from the API, this is where the good stuff happens
            if (_data._vehicle_data != null) {
                // Retrieve and display the vehicle name
                var name_drawable = View.findDrawableById("name");
                var vehicle_name = _data._vehicle_data.get("display_name");
                if (Application.getApp().getProperty("vehicle_name") == null) {
                    Application.getApp().setProperty("vehicle_name", vehicle_name);
                }
                name_drawable.setText(vehicle_name);
                name_drawable.draw(dc);

                // Grab the data we're going to use around charge and climate
                var battery_level = _data._vehicle_data.get("charge_state").get("battery_level");
                var charge_limit = _data._vehicle_data.get("charge_state").get("charge_limit_soc");
                var charging_state = _data._vehicle_data.get("charge_state").get("charging_state");
                var inside_temp = _data._vehicle_data.get("climate_state").get("inside_temp");
                var inside_temp_local = "???";
                if (inside_temp != null) {
                    inside_temp_local = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? ((inside_temp.toNumber()*9/5) + 32) + "°F" : inside_temp.toNumber() + "°C";
                }
                var driver_temp = _data._vehicle_data.get("climate_state").get("driver_temp_setting");
				var latitude = _data._vehicle_data.get("drive_state").get("latitude");
				var longitude = _data._vehicle_data.get("drive_state").get("longitude");
                var venting = _data._vehicle_data.get("vehicle_state").get("fd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rd_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("fp_window").toNumber() + _data._vehicle_data.get("vehicle_state").get("rp_window").toNumber();
			    var door_open = _data._vehicle_data.get("vehicle_state").get("df").toNumber() + _data._vehicle_data.get("vehicle_state").get("dr").toNumber() + _data._vehicle_data.get("vehicle_state").get("pf").toNumber() + _data._vehicle_data.get("vehicle_state").get("pr").toNumber();

                var departure_time = _data._vehicle_data.get("charge_state").get("scheduled_departure_time_minutes");

	            Application.getApp().setProperty("driver_temp", driver_temp);
	            Application.getApp().setProperty("venting", venting);
	            Application.getApp().setProperty("door_open", door_open);
	            Application.getApp().setProperty("latitude", latitude);
	            Application.getApp().setProperty("longitude", longitude);
                
                // Draw the charge status
                dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_BLACK);
                var charge_angle = 225 - (battery_level * 270 / 100);
                charge_angle = charge_angle < 0 ? 360 + charge_angle : charge_angle;
                dc.drawArc(center_x, center_y, radius, Graphics.ARC_CLOCKWISE, 225, charge_angle);

                // Draw the charge limit indicator
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
                var limit_angle = 225 - (charge_limit * 270 / 100);
                var limit_start_angle = limit_angle + 2;
                limit_start_angle = limit_start_angle < 0 ? 360 + limit_start_angle : limit_start_angle;
                var limit_end_angle = limit_angle - 2;
                limit_end_angle = limit_end_angle < 0 ? 360 + limit_end_angle : limit_end_angle;
                dc.drawArc(center_x, center_y, radius, Graphics.ARC_CLOCKWISE, limit_start_angle, limit_end_angle);

                if (use_image_layout)
                {
                    // We're using image layout, so update the lock state indicator
                    dc.drawBitmap(image_x_left.toNumber(),image_y_bottom,(_data._vehicle_data.get("vehicle_state").get("locked") ? Ui.loadResource(Rez.Drawables.locked_icon) : door_open ? Ui.loadResource(Rez.Drawables.door_open_icon) : Ui.loadResource(Rez.Drawables.unlocked_icon)));

                    // Update the text at the bottom of the screen with charge and temperature
                    var status_drawable = View.findDrawableById("status");
                    var charging_current = _data._vehicle_data.get("charge_state").get("charge_current_request");
                    if (charging_current == null) {
                    	charging_current = 0;
                    }
                    
                    status_drawable.setText(battery_level + (charging_state.equals("Charging") ? "%+ " : "% ") + charging_current + "A " + inside_temp_local);
                    status_drawable.draw(dc);

                    // Update the text in the middle of the screen with departure time (if set)
                    if (_data._vehicle_data.get("charge_state").get("preconditioning_enabled")) {
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

	        		var _spinner = Application.getApp().getProperty("spinner");
					if (_spinner.equals("+") || _spinner.equals("-") || _spinner.equals("?")) {
	                    var spinner_drawable = View.findDrawableById("spinner");
	                    spinner_drawable.setText(_spinner.toString());
	                    spinner_drawable.draw(dc);
					}

                    // Update the climate state indicator, note we have blue or red icons depending on heating or cooling
                    var climate_state = _data._vehicle_data.get("climate_state").get("is_climate_on");
                    var climate_defrost = _data._vehicle_data.get("climate_state").get("defrost_mode");
                    var climate_batterie_preheat = _data._vehicle_data.get("climate_state").get("battery_heater");
                    var left_temp_direction = _data._vehicle_data.get("climate_state").get("left_temp_direction");
//                    var right_temp_direction = _data._vehicle_data.get("climate_state").get("right_temp_direction");

//logMessage("Climate_state: " + climate_state + " left_temp_direction: " + left_temp_direction);
//logMessage("venting: " + venting + " locked: " + _data._vehicle_data.get("vehicle_state").get("locked") + " climate: " + climate_state);

                    if (climate_state == false)
                    {
                    	if (climate_batterie_preheat) {
	                        dc.drawBitmap(image_x_right,image_y_top.toNumber(), Ui.loadResource(Rez.Drawables.climate_off_icon_preheat));
	                    } else {
	                        dc.drawBitmap(image_x_right,image_y_top.toNumber(), Ui.loadResource(Rez.Drawables.climate_off_icon));
	                    }
                    }
                    else if (climate_state == true && left_temp_direction < 0 && !climate_defrost)
                    {
//logMessage("Cooling drv:" + driver_temp + " inside:" + inside_temp);
                       dc.drawBitmap(image_x_right,image_y_top, Ui.loadResource(Rez.Drawables.climate_on_icon_blue));
                    }
                    else
                    {
//logMessage("Heating drv:" + driver_temp + " inside:" + inside_temp);
                    	if (climate_defrost == 2) {
	                        dc.drawBitmap(image_x_right,image_y_top, Ui.loadResource(Rez.Drawables.climate_on_icon_red_defrost));
	                    } else if (climate_batterie_preheat) {
	                        dc.drawBitmap(image_x_right,image_y_top.toNumber(), Ui.loadResource(Rez.Drawables.climate_on_icon_preheat));
	                    } else {
	                        dc.drawBitmap(image_x_right,image_y_top.toNumber(), Ui.loadResource(Rez.Drawables.climate_on_icon_red));
	                    }
                    }
                    
                    if (_data._vehicle_data.get("vehicle_state").get("sentry_mode")) {
                    	var bitmap = Ui.loadResource(Rez.Drawables.sentry_icon) as BitmapResource;
                    	var bitmap_width = bitmap.getWidth();
                    	var bitmap_height = bitmap.getHeight();
                        dc.drawBitmap(center_x - bitmap_width / 2 - 3, sentry_y + bitmap_height / 2, bitmap);
                    }
                }
                else
                {           
                    // Text layout, so update the lock status text   
                    var status_drawable = View.findDrawableById("status");
                    if (_data._vehicle_data.get("vehicle_state").get("locked")) {
                        status_drawable.setColor(Graphics.COLOR_DK_GREEN);
                        status_drawable.setText(Rez.Strings.label_locked);
                    } else {
                        status_drawable.setColor(Graphics.COLOR_RED);
                        status_drawable.setText(Rez.Strings.label_unlocked);
                    }              
                    status_drawable.draw(dc);
                    
                    // Update the temperature text
                    var inside_temp_drawable = View.findDrawableById("inside_temp");
                    inside_temp_drawable.setText(Ui.loadResource(Rez.Strings.label_cabin) + inside_temp_local.toString());

                    // Update the climate state text
                    var climate_state_drawable = View.findDrawableById("climate_state");
                    var climate_state = Ui.loadResource(Rez.Strings.label_climate) + (_data._vehicle_data.get("climate_state").get("defrost_mode") == 2 ? Ui.loadResource(Rez.Strings.label_defrost) : _data._vehicle_data.get("climate_state").get("is_climate_on") ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off));
                    climate_state_drawable.setText(climate_state);

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
        }
    }
}
