using Toybox.Background;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Time;

class ClimateView extends Ui.View {
    hidden var _display;
    var _data;
    var _viewOffset;
		
    // Initial load - show the 'requesting data' string, make sure we don't process touches
    function initialize(data) {
        View.initialize();
        _data = data;
        _data._ready = false;
        _viewOffset = 0;
    }

    function onLayout(dc) {
        setLayout(Rez.Layouts.DataScreenLayout(dc));
    }

    function onReceive(args) {
        _display = args;
        Ui.requestUpdate();
    }

    function onUpdate(dc) {
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
        if (_display != null) 
        {
            // We're showing a message, so set 'ready' false to prevent touches
            _data._ready = false;

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            dc.drawText(center_x, center_y, font_montserrat, _display, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {           
            // Showing the main layouts, so we can process touches now
            _data._ready = true;

            // We're going to use the image layout by default if it's a touchscreen, also check the option setting to allow toggling
            var is_touchscreen = System.getDeviceSettings().isTouchScreen;

			// Read temperature unit from the watch settings
			Application.getApp().setProperty("imperial", System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE);

            // We're loading the image layout
            setLayout(Rez.Layouts.DataScreenLayout(dc));
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            View.onUpdate(dc);
            
            var title = View.findDrawableById("Title");
            var line1Text = View.findDrawableById("Line1Text");
            var line2Text = View.findDrawableById("Line2Text");
            var line3Text = View.findDrawableById("Line3Text");
            var line4Text = View.findDrawableById("Line4Text");
            var line5Text = View.findDrawableById("Line5Text");
            var line6Text = View.findDrawableById("Line6Text");
            var line7Text = View.findDrawableById("Line7Text");
            var line8Text = View.findDrawableById("Line8Text");
            var line1Value = View.findDrawableById("Line1Value");
            var line2Value = View.findDrawableById("Line2Value");
            var line3Value = View.findDrawableById("Line3Value");
            var line4Value = View.findDrawableById("Line4Value");
            var line5Value = View.findDrawableById("Line5Value");
            var line6Value = View.findDrawableById("Line6Value");
            var line7Value = View.findDrawableById("Line7Value");
            var line8Value = View.findDrawableById("Line8Value");

logMessage("_viewOffset is " + _viewOffset);
			if (_viewOffset == 0) {
	            line1Text.setText(Ui.loadResource(Rez.Strings.subview_label_climate_data_1_4));

	            var line3Data = _data._vehicle_data.get("climate_state").get("driver_temp_setting").toNumber();
	            var line3Unit = "°C";
		        if (Application.getApp().getProperty("imperial")) {
					line3Data = (line3Data * 9.0 / 5.0 + 32.0).toNumber().format("%d");	
					line3Unit = "°F";
		        }
	            line3Text.setText(Ui.loadResource(Rez.Strings.subview_label_driver_temp_setting));
	            line3Value.setText(line3Data.toString() + line3Unit);

	            var line4Data = _data._vehicle_data.get("climate_state").get("passenger_temp_setting").toNumber();
	            var line4Unit = "°C";
		        if (Application.getApp().getProperty("imperial")) {
					line4Data = (line4Data * 9.0 / 5.0 + 32.0).toNumber().format("%d");	
					line4Unit = "°F";
		        }
	            line4Text.setText(Ui.loadResource(Rez.Strings.subview_label_passenger_temp_setting));
	            line4Value.setText(line4Data.toString() + line4Unit);
	
	            var line5Data = _data._vehicle_data.get("climate_state").get("inside_temp").toNumber();
	            var line5Unit = "°C";
		        if (Application.getApp().getProperty("imperial")) {
					line5Data = (line5Data * 9.0 / 5.0 + 32.0).toNumber().format("%d");	
					line5Unit = "°F";
		        }
	            line5Text.setText(Ui.loadResource(Rez.Strings.subview_label_inside_temp));
	            line5Value.setText(line5Data.toString() + line5Unit);
	
	            var line6Data = _data._vehicle_data.get("climate_state").get("outside_temp").toNumber();
	            var line6Unit = "°C";
		        if (Application.getApp().getProperty("imperial")) {
					line6Data = (line6Data * 9.0 / 5.0 + 32.0).toNumber().format("%d");	
					line6Unit = "°F";
		        }
	            line6Text.setText(Ui.loadResource(Rez.Strings.subview_label_outside_temp));
	            line6Value.setText(line6Data.toString() + line6Unit);
			}
			else if (_viewOffset == 4) {
	            line1Text.setText(Ui.loadResource(Rez.Strings.subview_label_climate_data_2_4));

	            var line3Data = _data._vehicle_data.get("climate_state").get("is_climate_on");
	            line3Text.setText(Ui.loadResource(Rez.Strings.subview_label_is_climate_on));
	            line3Value.setText((line3Data ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));

	            var line4Data = _data._vehicle_data.get("climate_state").get("is_front_defroster_on");
	            line4Text.setText(Ui.loadResource(Rez.Strings.subview_label_is_front_defroster_on));
	            line4Value.setText((line4Data ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            var line5Data = _data._vehicle_data.get("climate_state").get("is_rear_defroster_on");
	            line5Text.setText(Ui.loadResource(Rez.Strings.subview_label_is_rear_defroster_on));
	            line5Value.setText((line5Data ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            var line6Data = _data._vehicle_data.get("climate_state").get("side_mirror_heaters");
	            line6Text.setText(Ui.loadResource(Rez.Strings.subview_label_side_mirror_heaters));
	            line6Value.setText((line6Data ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
			}
			else if (_viewOffset == 8) {
	            line1Text.setText(Ui.loadResource(Rez.Strings.subview_label_climate_data_3_4));

	            var line3Data = _data._vehicle_data.get("climate_state").get("seat_heater_left").toNumber();
				var driverAutoSeat = (_data._vehicle_data.get("climate_state").get("auto_seat_climate_left") ? " (A)" : "");
	            line3Text.setText(Ui.loadResource(Rez.Strings.subview_label_seat_heater_left));
	            line3Value.setText(line3Data.toString() + driverAutoSeat);

	            var line4Data = _data._vehicle_data.get("climate_state").get("seat_heater_right").toNumber();
				var passengerAutoSeat = (_data._vehicle_data.get("climate_state").get("auto_seat_climate_right") ? " (A)" : "");
	            line4Text.setText(Ui.loadResource(Rez.Strings.subview_label_seat_heater_right));
	            line4Value.setText(line4Data.toString() + passengerAutoSeat);
	
	            var line5Data = _data._vehicle_data.get("climate_state").get("steering_wheel_heater");
	            line5Text.setText(Ui.loadResource(Rez.Strings.subview_label_steering_wheel_heater));
	            line5Value.setText((line5Data ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            var line6Data = _data._vehicle_data.get("climate_state").get("wiper_blade_heater");
	            line6Text.setText(Ui.loadResource(Rez.Strings.subview_label_wiper_blade_heater));
	            line6Value.setText((line6Data ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
			}
			else if (_viewOffset == 12) {
	            line1Text.setText(Ui.loadResource(Rez.Strings.subview_label_climate_data_4_4));

	            var line3Data = _data._vehicle_data.get("climate_state").get("climate_keeper_mode");
	            line3Text.setText(Ui.loadResource(Rez.Strings.subview_label_climate_keeper_mode));
	            line3Value.setText(line3Data.toString());

	            var line4Data = _data._vehicle_data.get("climate_state").get("allow_cabin_overheat_protection");
	            line4Text.setText(Ui.loadResource(Rez.Strings.subview_label_allow_cabin_overheat_protection));
	            line4Value.setText((line4Data ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            var line5Data = _data._vehicle_data.get("climate_state").get("supports_fan_only_cabin_overheat_protection");
	            line5Text.setText(Ui.loadResource(Rez.Strings.subview_label_supports_fan_only_cabin_overheat_protection));
	            line5Value.setText((line5Data ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            var line6Data = _data._vehicle_data.get("climate_state").get("cabin_overheat_protection_actively_cooling");
	            line6Text.setText(Ui.loadResource(Rez.Strings.subview_label_cabin_overheat_protection_actively_cooling));
	            line6Value.setText((line6Data ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
			}

            line1Text.draw(dc);
            line1Value.draw(dc);
            line2Text.draw(dc);
            line2Value.draw(dc);
            line3Text.draw(dc);
            line3Value.draw(dc);
            line4Text.draw(dc);
            line4Value.draw(dc);
            line5Text.draw(dc);
            line5Value.draw(dc);
            line6Text.draw(dc);
            line6Value.draw(dc);
            line7Text.draw(dc);
            line7Value.draw(dc);
            line8Text.draw(dc);
            line8Value.draw(dc);
        }
	}
}
