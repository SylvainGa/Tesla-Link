using Toybox.Background;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Time;

class ChargeView extends Ui.View {
    hidden var _display;
    var _data;
		
    // Initial load - show the 'requesting data' string, make sure we don't process touches
    function initialize(data) {
        View.initialize();
        _data = data;
        _data._ready = false;
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
            
            var Title = View.findDrawableById("Title");
            var Line1Text = View.findDrawableById("Line1Text");
            var Line2Text = View.findDrawableById("Line2Text");
            var Line3Text = View.findDrawableById("Line3Text");
            var Line4Text = View.findDrawableById("Line4Text");
            var Line5Text = View.findDrawableById("Line5Text");
            var Line6Text = View.findDrawableById("Line6Text");
            var Line7Text = View.findDrawableById("Line7Text");
            var Line8Text = View.findDrawableById("Line8Text");
            var Line1Value = View.findDrawableById("Line1Value");
            var Line2Value = View.findDrawableById("Line2Value");
            var Line3Value = View.findDrawableById("Line3Value");
            var Line4Value = View.findDrawableById("Line4Value");
            var Line5Value = View.findDrawableById("Line5Value");
            var Line6Value = View.findDrawableById("Line6Value");
            var Line7Value = View.findDrawableById("Line7Value");
            var Line8Value = View.findDrawableById("Line8Value");

            var chargeLimit = _data._vehicle_data.get("charge_state").get("charge_limit_soc").toNumber();
            Line1Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Charge limit");
            Line1Value.setText(chargeLimit.toString() + "%");

            var batteryLevel = _data._vehicle_data.get("charge_state").get("battery_level").toNumber();
            Line2Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Battery Level");
            Line2Value.setText(batteryLevel.toString() + "%");

            var milesAdded = _data._vehicle_data.get("charge_state").get("charge_miles_added_rated").toFloat();
            milesAdded *=  (Application.getApp().getProperty("imperial") ? 1.0 : 1.6);
            Line3Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Range added");
            Line3Value.setText(milesAdded.toNumber().toString() + (Application.getApp().getProperty("imperial") ? "miles" : "km"));

            var estimatedBatteryRange = _data._vehicle_data.get("charge_state").get("est_battery_range").toFloat();
            estimatedBatteryRange *=  (Application.getApp().getProperty("imperial") ? 1.0 : 1.6);
            Line4Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Estimated Range");
            Line4Value.setText(estimatedBatteryRange.toNumber().toString() + (Application.getApp().getProperty("imperial") ? "miles" : "km"));

            var minutesToFullCharge = _data._vehicle_data.get("charge_state").get("minutes_to_full_charge").toNumber();
            var hours = minutesToFullCharge / 60;
            var minutes = minutesToFullCharge - hours * 60;
            var timeStr;
			if (System.getDeviceSettings().is24Hour) {
				timeStr = Lang.format("$1$h$2$ ", [hours.format("%d"), minutes.format("%02d")]);
			}
			else {
				timeStr = Lang.format("$1$:$2$ ", [hours.format("%d"), minutes.format("%02d")]);
			}
            Line5Text.setText(/*Ui.loadResource(Rez.Strings.departure)*/"Time left");
            Line5Value.setText(timeStr);

            var chargerVoltage = _data._vehicle_data.get("charge_state").get("charger_voltage").toNumber();
            Line6Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Charger voltage");
            Line6Value.setText(chargerVoltage.toString() + "V");

            var chargerActualCurrent = _data._vehicle_data.get("charge_state").get("charger_actual_current").toNumber();
            Line7Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Charger current");
            Line7Value.setText(chargerActualCurrent.toString() + "A");

            var batteryHeaterOn = _data._vehicle_data.get("climate_state").get("battery_heater");
            Line8Text.setText(/*Ui.loadResource(Rez.Strings.label_cabin)*/"Battery Heater");
            Line8Value.setText((batteryHeaterOn ? "On" : "Off"));

            Line1Text.draw(dc);
            Line1Value.draw(dc);
            Line2Text.draw(dc);
            Line2Value.draw(dc);
            Line3Text.draw(dc);
            Line3Value.draw(dc);
            Line4Text.draw(dc);
            Line4Value.draw(dc);
            Line5Text.draw(dc);
            Line5Value.draw(dc);
            Line6Text.draw(dc);
            Line6Value.draw(dc);
            Line7Text.draw(dc);
            Line7Value.draw(dc);
            Line8Text.draw(dc);
            Line8Value.draw(dc);
        }
	}
}
