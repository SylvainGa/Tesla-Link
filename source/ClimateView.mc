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
        var center_x = dc.getWidth()/2;
        var center_y = dc.getHeight()/2;
        
        // Load our custom font if it's there, generally only for high res, high mem devices
        var font_montserrat;
        if (Rez.Fonts has :montserrat) {
            font_montserrat=Ui.loadResource(Rez.Fonts.montserrat);
        } else {
            font_montserrat=Graphics.FONT_TINY;
        }

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

            // We're loading the image layout
            setLayout(Rez.Layouts.DataScreenLayout(dc));
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            View.onUpdate(dc);
            
		    var lineText = new [8];
		    var lineValue = new [8];
            
            for (var i = 1; i <= 8; i++) {
                lineText[i - 1]  = View.findDrawableById("Line" + i + "Text");
                lineValue[i - 1] = View.findDrawableById("Line" + i + "Value");
            }

			// 2022-10-10 logMessage("ClimateView:onUpdate: _viewOffset is " + _viewOffset);
            var lineData; 
            var lineUnit; 
			if (_viewOffset == 0) {
	            lineText[0].setText(Ui.loadResource(Rez.Strings.subview_label_climate_data_1_4));

	            lineData = $.validateNumber(_data._vehicle_data.get("climate_state").get("driver_temp_setting"));
	            lineUnit = "°C";
		        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
					lineData = (lineData * 9.0 / 5.0 + 32.0).toNumber().format("%d");	
					lineUnit = "°F";
		        }
	            lineText[2].setText(Ui.loadResource(Rez.Strings.subview_label_driver_temp_setting));
	            lineValue[2].setText(lineData + lineUnit);

	            lineData = $.validateNumber(_data._vehicle_data.get("climate_state").get("passenger_temp_setting"));
	            lineUnit = "°C";
		        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
					lineData = (lineData * 9.0 / 5.0 + 32.0).toNumber().format("%d");	
					lineUnit = "°F";
		        }
	            lineText[3].setText(Ui.loadResource(Rez.Strings.subview_label_passenger_temp_setting));
	            lineValue[3].setText(lineData + lineUnit);
	
	            lineData = $.validateFloat(_data._vehicle_data.get("climate_state").get("inside_temp")).format("%.1f");
	            lineUnit = "°C";
		        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
					lineData = (lineData.toFloat() * 9.0 / 5.0 + 32.0).toNumber();	
					lineUnit = "°F";
		        }
	            lineText[4].setText(Ui.loadResource(Rez.Strings.subview_label_inside_temp));
	            lineValue[4].setText(lineData + lineUnit);
	
	            lineData = $.validateFloat(_data._vehicle_data.get("climate_state").get("outside_temp")).format("%.1f");
	            lineUnit = "°C";
		        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
					lineData = (lineData.toFloat() * 9.0 / 5.0 + 32.0).toNumber();
					lineUnit = "°F";
		        }
	            lineText[5].setText(Ui.loadResource(Rez.Strings.subview_label_outside_temp));
	            lineValue[5].setText(lineData + lineUnit);
			}
			else if (_viewOffset == 4) {
	            lineText[0].setText(Ui.loadResource(Rez.Strings.subview_label_climate_data_2_4));

	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("is_climate_on"));
	            lineText[2].setText(Ui.loadResource(Rez.Strings.subview_label_is_climate_on));
	            lineValue[2].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));

	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("is_front_defroster_on"));
	            lineText[3].setText(Ui.loadResource(Rez.Strings.subview_label_is_front_defroster_on));
	            lineValue[3].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("is_rear_defroster_on"));
	            lineText[4].setText(Ui.loadResource(Rez.Strings.subview_label_is_rear_defroster_on));
	            lineValue[4].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("side_mirror_heaters"));
	            lineText[5].setText(Ui.loadResource(Rez.Strings.subview_label_side_mirror_heaters));
	            lineValue[5].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
			}
			else if (_viewOffset == 8) {
	            lineText[0].setText(Ui.loadResource(Rez.Strings.subview_label_climate_data_3_4));

	            lineData = $.validateNumber(_data._vehicle_data.get("climate_state").get("seat_heater_left"));
				var driverAutoSeat = (_data._vehicle_data.get("climate_state").get("auto_seat_climate_left") ? " (A)" : "");
	            lineText[2].setText(Ui.loadResource(Rez.Strings.subview_label_seat_heater_left));
	            lineValue[2].setText(lineData + driverAutoSeat);

	            lineData = $.validateNumber(_data._vehicle_data.get("climate_state").get("seat_heater_right"));
				var passengerAutoSeat = (_data._vehicle_data.get("climate_state").get("auto_seat_climate_right") ? " (A)" : "");
	            lineText[3].setText(Ui.loadResource(Rez.Strings.subview_label_seat_heater_right));
	            lineValue[3].setText(lineData + passengerAutoSeat);
	
	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("steering_wheel_heater"));
	            lineText[4].setText(Ui.loadResource(Rez.Strings.subview_label_steering_wheel_heater));
	            lineValue[4].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("wiper_blade_heater"));
	            lineText[5].setText(Ui.loadResource(Rez.Strings.subview_label_wiper_blade_heater));
	            lineValue[5].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
			}
			else if (_viewOffset == 12) {
	            lineText[0].setText(Ui.loadResource(Rez.Strings.subview_label_climate_data_4_4));

	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("climate_keeper_mode")).toString();
	            lineText[2].setText(Ui.loadResource(Rez.Strings.subview_label_climate_keeper_mode));
	            lineValue[2].setText(lineData);

	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("allow_cabin_overheat_protection"));
	            lineText[3].setText(Ui.loadResource(Rez.Strings.subview_label_allow_cabin_overheat_protection));
	            lineValue[3].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("supports_fan_only_cabin_overheat_protection"));
	            lineText[4].setText(Ui.loadResource(Rez.Strings.subview_label_supports_fan_only_cabin_overheat_protection));
	            lineValue[4].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
	
	            lineData = $.validateBoolean(_data._vehicle_data.get("climate_state").get("cabin_overheat_protection_actively_cooling"));
	            lineText[5].setText(Ui.loadResource(Rez.Strings.subview_label_cabin_overheat_protection_actively_cooling));
	            lineValue[5].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
			}

            for (var i = 0; i < 8; i++) {
                lineText[i].draw(dc);
                lineValue[i].draw(dc);
            }
        }
	}
}
