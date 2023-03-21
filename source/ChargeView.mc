using Toybox.Background;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Time;

class ChargeView extends Ui.View {
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

// 2022-10-10 logMessage("ChargeView:onUpdate: _viewOffset is " + _viewOffset);
            var lineData; 
			if (_viewOffset == 0) {
	            lineText[0].setText(Ui.loadResource(Rez.Strings.subview_label_charge_data_1_2));

	            lineData = _data._vehicle_data.get("charge_state").get("charge_limit_soc").toNumber();
	            lineText[2].setText(Ui.loadResource(Rez.Strings.subview_label_charge_limit_soc));
	            lineValue[2].setText(lineData.toString() + "%");
	
	            lineData = _data._vehicle_data.get("charge_state").get("battery_level").toNumber();
	            lineText[3].setText(Ui.loadResource(Rez.Strings.subview_label_battery_level));
	            lineValue[3].setText(lineData.toString() + "%");
	
	            lineData = _data._vehicle_data.get("charge_state").get("charge_miles_added_rated").toFloat();
	            lineData *=  (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6);
	            lineText[4].setText(Ui.loadResource(Rez.Strings.subview_label_charge_miles_added_rated));
	            lineValue[4].setText(lineData.toNumber().toString() + (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? "miles" : "km"));
	
	            lineData = _data._vehicle_data.get("charge_state").get("battery_range").toFloat();
	            lineData *=  (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6);
	            lineText[5].setText(Ui.loadResource(Rez.Strings.subview_label_est_battery_range));
	            lineValue[5].setText(lineData.toNumber().toString() + (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? "miles" : "km"));
	
			}
			else if (_viewOffset == 4) {
	            lineText[0].setText(Ui.loadResource(Rez.Strings.subview_label_charge_data_2_2));

	            lineData = _data._vehicle_data.get("charge_state").get("minutes_to_full_charge").toNumber();
	            var hours = lineData / 60;
	            var minutes = lineData - hours * 60;
	            var timeStr;
				if (System.getDeviceSettings().is24Hour) {
					timeStr = Lang.format("$1$h$2$ ", [hours.format("%d"), minutes.format("%02d")]);
				}
				else {
					timeStr = Lang.format("$1$:$2$ ", [hours.format("%d"), minutes.format("%02d")]);
				}
	            lineText[2].setText(Ui.loadResource(Rez.Strings.subview_label_minutes_to_full_charge));
	            lineValue[2].setText(timeStr);

	            lineData = _data._vehicle_data.get("charge_state").get("charger_voltage").toNumber();
	            lineText[3].setText(Ui.loadResource(Rez.Strings.subview_label_charger_voltage));
	            lineValue[3].setText(lineData.toString() + "V");
	
	            lineData = _data._vehicle_data.get("charge_state").get("charger_actual_current").toNumber();
	            lineText[4].setText(Ui.loadResource(Rez.Strings.subview_label_charger_actual_current));
	            lineValue[4].setText(lineData.toString() + "A");
	
	            lineData = _data._vehicle_data.get("climate_state").get("battery_heater");
	            lineText[5].setText(Ui.loadResource(Rez.Strings.subview_label_battery_heater));
	            lineValue[5].setText((lineData ? Ui.loadResource(Rez.Strings.label_on) : Ui.loadResource(Rez.Strings.label_off)));
			}
			
            for (var i = 0; i < 8; i++) {
                lineText[i].draw(dc);
                lineValue[i].draw(dc);
            }
        }
	}
}
