using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Graphics;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

(:superapp)
class DogModeView extends Ui.View {
    var _data;
    var _text;
    var _fontHeightTiny;
    var _fontHeightSmall;
    var _bg;
    var _lastVehicleData;

    function initialize(data) {
        View.initialize();

        _data = data;
        _lastVehicleData = Sys.getTimer();

        _bg = Ui.loadResource(Rez.Drawables.dogmode_black_bg);
    }

    function onLayout(dc) {
        _fontHeightTiny = Graphics.getFontHeight(Graphics.FONT_TINY);
        _fontHeightSmall = Graphics.getFontHeight(Graphics.FONT_SMALL);
    }

	function onReceive(args) {
        //DEBUG 2023-10-02*/ logMessage("DogModeView:onReceive with args=" + args);
        _text = args;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        //DEBUG 2023-10-02*/ logMessage("DogModeView:onUpdate");
		var width = dc.getWidth();
		var height = dc.getHeight();

        dc.clear();
        View.onUpdate(dc);

        dc.drawBitmap(width / 4, height / 2, _bg);

		var clockTime = Sys.getClockTime();
		var formattedTime = getFormattedTime(clockTime.hour, clockTime.min, clockTime.sec);

		var hours = formattedTime[:hour];
		var minutes = formattedTime[:min];
        var seconds = formattedTime[:sec];
		var amPmText = formattedTime[:amPm];

		dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			width / 2,
			height / 16,
			Graphics.FONT_MEDIUM,
			hours + ":" + minutes + ":" + seconds + amPmText,
			Graphics.TEXT_JUSTIFY_CENTER
		);

        var charge = $.validateNumber(_data._vehicle_data.get("charge_state").get("battery_level"), 0);
		dc.setColor(charge < 25 ? Graphics.COLOR_RED : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			width / 4,
			height / 4 + _fontHeightSmall / 2,
			Graphics.FONT_SMALL,
			charge + "%",
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);

        var inside_temp = $.validateNumber(_data._vehicle_data.get("climate_state").get("inside_temp"), 0);
        var inside_temp_str = Sys.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? (((inside_temp * 9) / 5) + 32) + "°F" : inside_temp + "°C";
		dc.setColor(inside_temp > 25 ? Graphics.COLOR_RED : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			width / 2,
			height / 4 + _fontHeightSmall / 2,
			Graphics.FONT_SMALL,
			inside_temp_str,
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);

        var dataTimeStamp = $.validateLong(_data._vehicle_data.get("climate_state").get("timestamp"), 0) / 1000;
        var curTimeStamp = Time.now().value();
        var variation = curTimeStamp - dataTimeStamp;
        if (variation < 0) {
            variation = 0;
        }
        var variation_str;
        if (variation > 59) {
            var variation_min = (variation / 60).toNumber();
            variation_str = variation_min + "m" + (((variation / 60.0) - variation_min) * 60.0).toNumber() + "s";
        }
        else {
            variation_str = variation + "s";
        }
		dc.setColor(variation > 120 ? Graphics.COLOR_RED : Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			(width * 3) / 4,
			height / 4 + _fontHeightSmall / 2,
			Graphics.FONT_SMALL,
			variation_str,
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);

        var dogModeActive = $.validateString(_data._vehicle_data.get("climate_state").get("climate_keeper_mode"), "off").equals("dog");

        if (curTimeStamp - dataTimeStamp > 120 || inside_temp > 25 || !dogModeActive) {
            if (Attention has :vibrate) {
                var vibeData = [ new Attention.VibeProfile(50, 200) ]; // On for half a second
                Attention.vibrate(vibeData);
            }
            // Play a predefined tone
            if (Attention has :playTone) {
                Attention.playTone(Attention.TONE_LOUD_BEEP);
            }

    		dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                width / 2,
                height / 4 + (_fontHeightSmall * 2.5).toNumber(),
                Graphics.FONT_MEDIUM,
                Ui.loadResource(!dogModeActive ? Rez.Strings.label_dogmode_off : inside_temp > 25.0 ? Rez.Strings.label_dogmode_toohigh : Rez.Strings.label_dogmode_nodata),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        if (_text != null) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
			dc.drawText(width / 2, height - _fontHeightTiny * 2, Graphics.FONT_TINY, _text, Graphics.TEXT_JUSTIFY_CENTER);
            _text = null;
        }
    }

    // Return a formatted time dictionary that respects is24Hour and HideHoursLeadingZero settings.
    // - hour: 0-23.
    // - min:  0-59.
    // - sec: 0-59
    function getFormattedTime(hour, min, sec) {
        var amPm = "";

        if (!Sys.getDeviceSettings().is24Hour) {

            // #6 Ensure noon is shown as PM.
            var isPm = (hour >= 12);
            if (isPm) {
                
                // But ensure noon is shown as 12, not 00.
                if (hour > 12) {
                    hour = hour - 12;
                }
                amPm = "pm";
            } else {
                
                // #27 Ensure midnight is shown as 12, not 00.
                if (hour == 0) {
                    hour = 12;
                }
                amPm = "am";
            }
        }

        return {
            :hour => hour,
            :min => min.format("%02d"),
            :sec => sec.format("%02d"),
            :amPm => amPm
        };
    }
}

(:nosuperapp)
class DogModeView extends Ui.View {
    function initialize(data) {
        View.initialize();
    }

	function onReceive(args) {
        //DEBUG 2023-10-02*/ logMessage("DogModeView:onReceive with args=" + args);
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.clear();
        View.onUpdate(dc);

		dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			dc.getWidth() / 2,
			dc.getHeight() / 2,
			Graphics.FONT_MEDIUM,
            Ui.loadResource(Rez.Strings.label_mode_notavail),
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
		);
    }
}
