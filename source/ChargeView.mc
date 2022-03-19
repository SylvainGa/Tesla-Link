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
        setLayout(Rez.Layouts.ChargingLayout(dc));
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
            setLayout(Rez.Layouts.ChargingLayout(dc));
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
	            line1Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Charge data (1/2)");

	            var line3Data = _data._vehicle_data.get("charge_state").get("charge_limit_soc").toNumber();
	            line3Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Charge limit");
	            line3Value.setText(line3Data.toString() + "%");
	
	            var line4Data = _data._vehicle_data.get("charge_state").get("battery_level").toNumber();
	            line4Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Battery Level");
	            line4Value.setText(line4Data.toString() + "%");
	
	            var line5Data = _data._vehicle_data.get("charge_state").get("charge_miles_added_rated").toFloat();
	            line5Data *=  (Application.getApp().getProperty("imperial") ? 1.0 : 1.6);
	            line5Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Range added");
	            line5Value.setText(line5Data.toNumber().toString() + (Application.getApp().getProperty("imperial") ? "miles" : "km"));
	
	            var line6Data = _data._vehicle_data.get("charge_state").get("est_battery_range").toFloat();
	            line6Data *=  (Application.getApp().getProperty("imperial") ? 1.0 : 1.6);
	            line6Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Estimated Range");
	            line6Value.setText(line6Data.toNumber().toString() + (Application.getApp().getProperty("imperial") ? "miles" : "km"));
	
			}
			else if (_viewOffset == 4) {
	            line1Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Charge data (2/2)");

	            var line3Data = _data._vehicle_data.get("charge_state").get("minutes_to_full_charge").toNumber();
	            var hours = line3Data / 60;
	            var minutes = line3Data - hours * 60;
	            var timeStr;
				if (System.getDeviceSettings().is24Hour) {
					timeStr = Lang.format("$1$h$2$ ", [hours.format("%d"), minutes.format("%02d")]);
				}
				else {
					timeStr = Lang.format("$1$:$2$ ", [hours.format("%d"), minutes.format("%02d")]);
				}
	            line3Text.setText(/*Ui.loadResource(Rez.Strings.departure)*/"Time left");
	            line3Value.setText(timeStr);

	            var line4Data = _data._vehicle_data.get("charge_state").get("charger_voltage").toNumber();
	            line4Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Charger voltage");
	            line4Value.setText(line4Data.toString() + "V");
	
	            var line5Data = _data._vehicle_data.get("charge_state").get("charger_actual_current").toNumber();
	            line5Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Charger current");
	            line5Value.setText(line5Data.toString() + "A");
	
	            var line6Data = _data._vehicle_data.get("climate_state").get("battery_heater");
	            line6Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Battery Heater");
	            line6Value.setText((line6Data ? "On" : "Off"));
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
