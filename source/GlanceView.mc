using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

(:glance, :can_glance)
class GlanceView extends Ui.GlanceView {
    var _curPos1X;
    var _curPos2X;
    var _curPos3X;
    var _xDir1;
    var _xDir2;
    var _xDir3;
    var _refreshTimer;
    var _scrollStartTimer;
    var _scrollEndTimer;
    var _prevText1Width;
    var _prevText2Width;
    var _prevText3Width;
    var _usingFont;
    var _fontHeight;
    var _dcWidth;
    var _dcHeight;
    var _threeLines;
    var _steps;

    function initialize() {
        GlanceView.initialize();
    }

    function onShow() {
        _refreshTimer = new Timer.Timer();
        _refreshTimer.start(method(:refreshView), 50, true);
        resetSavedPosition();
    }

    function onHide() {
        if (_refreshTimer) {
            _refreshTimer.stop();
            _refreshTimer = null;
        }
    }

    function onLayout(dc) {
        gSettingsChanged = false;
        _usingFont = (Properties.getValue("smallfontsize") ? Graphics.FONT_XTINY : Graphics.FONT_TINY);
        _fontHeight = Graphics.getFontHeight(_usingFont);
        _dcHeight = dc.getHeight();

        if (_dcHeight / _fontHeight >= 3.0) {
            _threeLines = true;
        }
        else {
            _threeLines = false;
        }

        var screenShape = System.getDeviceSettings().screenShape;
        _dcWidth = dc.getWidth();
        if (screenShape == System.SCREEN_SHAPE_ROUND && Properties.getValue("scrollclearsedge") == true) {
            var ratio = 1.0 + (System.getDeviceSettings().screenWidth < 454 ? Math.sqrt((454 - System.getDeviceSettings().screenWidth).toFloat() / 2800.0) : 0.0); // Convoluted way to adjust the width based on the screen width relative to a 454 watch, which shows ok with just the formula below 
            var rad = Math.asin(_dcHeight.toFloat() * (_threeLines ? ratio : 1.0) / _dcWidth.toFloat());
            _dcWidth = (Math.cos(rad) * _dcWidth.toFloat()).toNumber();
        }
        _steps = (System.getDeviceSettings().screenWidth - 200) / 50;
        if (_steps < 1) {
            _steps = 1;
        }

        resetSavedPosition();
    }

    function resetSavedPosition() {
        _curPos1X = null;
        _curPos2X = null;
        _curPos3X = null;
        _prevText1Width = 0;
        _prevText2Width = 0;
        _prevText3Width = 0;

        _scrollStartTimer = 0;
        _scrollEndTimer = 0;
    }

    function refreshView() {
        Ui.requestUpdate();
    }

    function onUpdate(dc) {
        // Retrieve the name of the vehicle if we have it, or the generic string otherwise

        if (gSettingsChanged) {
            onLayout(dc);
        }

        var vehicle_name = Storage.getValue("vehicle_name");
        vehicle_name = (vehicle_name == null) ? Ui.loadResource(Rez.Strings.vehicle) : vehicle_name;

        var responseCode;
        var battery_level;
        var charging_state;
        var battery_range;
        var inside_temp;
        var sentry;
        var preconditioning;
        var timestamp;
        var text;

        //DEBUG*/ logMessage("Glance height=" + dc.getHeight());
        //DEBUG*/ logMessage("Glance width=" + dc.getWidth());
        //DEBUG*/ logMessage("Font height=" +  Graphics.getFontHeight(Graphics.FONT_TINY));

        var status = Storage.getValue("status");
        if (status != null && status.equals("") == false) {
            var array = to_array(status, "|");

            if (array.size() == 9) {
                responseCode = array[0].toNumber();
                battery_level = array[1];
                charging_state = array[2];
                battery_range = (array[3].toNumber() * (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6)).toNumber();
                try {
                  inside_temp = array[4].toNumber();
                  inside_temp = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? ((inside_temp * 9 / 5) + 32) + "°F" : inside_temp + "°C";
                }
                catch (e) {
                  //DEBUG*/ logMessage("Glance:onUpdate: Caught exception " + e);
                  inside_temp = "N/A";
                }
                sentry = array[5];
                preconditioning = array[6];
                timestamp = array[7];
                text = array[8];
                if (text != null && text.equals("")) {
                    text = null;
                }
            }

            if (battery_level == null || battery_level.equals("N/A")) {
                if (text != null) {
                    status = text + timestamp;
                    text = null;
                }
                else {
                    var token = Storage.getValue("token");
                    var vehicle = Storage.getValue("vehicle");
                    status =  Ui.loadResource(token != null && vehicle != null ? Rez.Strings.label_waiting_data : Rez.Strings.label_launch_widget);
                }
            }
            else {
                var vehicleAsleep = (text != null && text.equals(Application.loadResource(Rez.Strings.label_asleep)));
                var chargeSuffix = "";

                if (_threeLines) {
                    if (responseCode == 200) {
                        text = inside_temp + sentry + preconditioning;
                    }
                    else if (vehicleAsleep) {
                        text = Application.loadResource(Rez.Strings.label_asleep) + preconditioning;
                    }
                }
                else {
                    text = null;

                    if (vehicleAsleep) {
                        chargeSuffix = "s";
                    }
                    else if (responseCode != 200) {
                        chargeSuffix = "?";
                    }
                }

                if (charging_state.equals("Charging")) {
                    chargeSuffix = "+";
                }

                status = battery_level + "%" + chargeSuffix + " / " + battery_range + (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? " miles" : " km") + timestamp;
            }
        }
        else {
            var token = Storage.getValue("token");
            var vehicle = Storage.getValue("vehicle");
            status =  Ui.loadResource(token != null && vehicle != null ? Rez.Strings.label_waiting_data : Rez.Strings.label_launch_widget);
        }

        var text1Width = dc.getTextWidthInPixels(vehicle_name.toUpper(), _usingFont);
        var text2Width = dc.getTextWidthInPixels(status, _usingFont);
        var text3Width = (text != null ? dc.getTextWidthInPixels(text, _usingFont) : 0);

        var longestTextWidth = text1Width;
        var longestTextWidthIndex = 1;
        if (longestTextWidth < text2Width) {
            longestTextWidth = text2Width;
            longestTextWidthIndex = 2;
        }
        if (longestTextWidth < text3Width) {
            longestTextWidthIndex = 3;
            longestTextWidth = text3Width;
        }

        var resetPos = (_prevText1Width != text1Width || _prevText2Width != text2Width || _prevText3Width != text3Width);

        if (_curPos1X == null || resetPos) {
            //DEBUG*/ logMessage("DC width/height: " + _dcWidth + "/" + _dcHeight + " resetPos: " + resetPos + " longest text width: " + longestTextWidth + " for line #" + longestTextWidthIndex);
            //DEBUG*/ logMessage("Showing " + vehicle_name.toUpper() + " | " +  status + " | " + text);
            _curPos1X = 0;
            _prevText1Width = text1Width;
            _scrollEndTimer = 0;
            _scrollStartTimer = 0;
            if (text1Width > _dcWidth) {
                _xDir1 = _steps;
            }
            else {
                _xDir1 = 0;
            }
        }
        if (_curPos2X == null || resetPos) {
            _curPos2X = 0;
            _prevText2Width = text2Width;
            _scrollEndTimer = 0;
            _scrollStartTimer = 0;
            if (text2Width > _dcWidth) {
                _xDir2 = _steps;
            }
            else {
                _xDir2 = 0;
            }
        }
        if (_curPos3X == null || resetPos) {
            _curPos3X = 0;
            _prevText3Width = text3Width;
            _scrollEndTimer = 0;
            _scrollStartTimer = 0;
            if (text3Width > _dcWidth) {
                _xDir3 = _steps;
            }
            else {
                _xDir3 = 0;
            }
        }

        if (text1Width > _dcWidth || text2Width > _dcWidth || text3Width > _dcWidth) {
            if (_scrollStartTimer > 20) {
                _curPos1X = _curPos1X - _xDir1;
                _curPos2X = _curPos2X - _xDir2;
                _curPos3X = _curPos3X - _xDir3;

                if (_curPos1X + text1Width < _dcWidth) {
                    _xDir1 = 0;
                    if (longestTextWidthIndex == 1) {
                    _scrollEndTimer = _scrollEndTimer + 1;              
                    }
                }
                if (_curPos2X + text2Width < _dcWidth) {
                    _xDir2 = 0;
                    if (longestTextWidthIndex == 2) {
                    _scrollEndTimer = _scrollEndTimer + 1;              
                    }
                }
                if (_curPos3X + text3Width < _dcWidth) {
                    if (longestTextWidthIndex == 3) {
                    _scrollEndTimer = _scrollEndTimer + 1;              
                    }
                    _xDir3 = 0;
                }
            }
            else {
                _scrollStartTimer = _scrollStartTimer + 1;
            }
        }

        // Draw the two/three rows of text on the glance widget
        dc.setColor(Gfx.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var spacing;
        if (text != null) {
            spacing = ((_dcHeight - _fontHeight * 3) / 4).toNumber();
        }
        else {
            spacing = ((_dcHeight - _fontHeight * 2) / 3).toNumber();
        }

        var y = spacing;
        dc.drawText(
            _curPos1X,
            y,
            _usingFont,
            vehicle_name.toUpper(),
            Graphics.TEXT_JUSTIFY_LEFT
        );

        y = (spacing * 2 + _fontHeight).toNumber();
        dc.drawText(
            _curPos2X,
            y,
            _usingFont,
            status,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        if (text != null) {
            y = (spacing * 3 + _fontHeight * 2).toNumber();
            dc.drawText(
            _curPos3X,
            y,
            _usingFont,
            text,
            Graphics.TEXT_JUSTIFY_LEFT
            );
        }

        if (_scrollEndTimer == 20) {
            _curPos1X = null;
            _curPos2X = null;
            _curPos3X = null;

            _scrollEndTimer = 0;
            _scrollStartTimer = 0;
        }
    }
}
