using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application.Storage;
using Toybox.Application.Properties;
using Toybox.Time;
using Toybox.Time.Gregorian;

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
    var _showLaunch;

    function initialize() {
        GlanceView.initialize();
        gSettingsChanged = true;
    }

(:bkgnd32kb)
    function onShow() {
        var tokenCreatedAt = Storage.getValue("TokenCreatedAt");
        var tokenExpiresIn = Storage.getValue("TokenExpiresIn");
        var expired;
        if (tokenCreatedAt != null && tokenExpiresIn != null) {
    		var timeNow = Time.now().value();
		    expired = (timeNow > tokenCreatedAt + tokenExpiresIn);
        }
        else {
            expired = true;
        }
        _showLaunch = (Storage.getValue("token") == null || Storage.getValue("vehicle") == null || expired);
        
        _refreshTimer = new Timer.Timer();
        _refreshTimer.start(method(:refreshView), 50, true);

        resetSavedPosition();
    }

(:bkgnd64kb)
    function onShow() {
        var tokenCreatedAt = Storage.getValue("TokenCreatedAt");
        var tokenExpiresIn = Storage.getValue("TokenExpiresIn");
        var expired;
        if (tokenCreatedAt != null && tokenExpiresIn != null) {
    		var timeNow = Time.now().value();
		    expired = (timeNow > tokenCreatedAt + tokenExpiresIn);
        }
        else {
            expired = true;
        }

        var noToken = (Storage.getValue("token") == null);
        var noVehicle = (Storage.getValue("vehicle") == null);
        var noRefreshToken = (Properties.getValue("refreshToken") == null);
        _showLaunch = (expired || noToken || noVehicle || noRefreshToken);

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

        _xDir1 = 0;
        _xDir2 = 0;
        _xDir3 = 0;

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
        /*DEBUG*/ var showLog = false;

        if (gSettingsChanged) {
            /*DEBUG*/ showLog = true;
            gSettingsChanged = false;
            onLayout(dc);
        }

        var responseCode;
        var timestamp;
        var battery_level;
        var charging_state;
        var battery_range;
        var inside_temp;
        var sentry;
        var preconditioning;
        var shift_state;
        var vehicleAwake;

        var line1;
        var line2;
        var line3;

        line1 = Storage.getValue("vehicle_name");
        if (line1 != null) {
            line1 = line1.toUpper();
        }
        else {
            line1 = Ui.loadResource(Rez.Strings.vehicle);
        }

        //DEBUG*/ logMessage("Glance height=" + dc.getHeight());
        //DEBUG*/ logMessage("Glance width=" + dc.getWidth());
        //DEBUG*/ logMessage("Font height=" +  Graphics.getFontHeight(Graphics.FONT_TINY));

        var status = Storage.getValue("status");
        if (status != null && status instanceof Lang.Dictionary) { // Dictionary? Yep, new format. Otherwise wait until we get one.
            responseCode = status["responseCode"];
            timestamp = status["timestamp"];
            battery_level = status["battery_level"];
            charging_state = status["charging_state"];
            battery_range = status["battery_range"];
            inside_temp = status["inside_temp"];
            sentry = status["sentry"];
            preconditioning = status["preconditioning"];
            shift_state = status["shift_state"];
            vehicleAwake = status["vehicleAwake"];
        }

        var suffix = "";
        var txt;

        // Build our third line in case we need it
        if (inside_temp != null) {
            inside_temp = (System.getDeviceSettings().temperatureUnits == System.UNIT_METRIC ? inside_temp + "°C" : ((inside_temp * 9) / 5 + 32).format("%d") + "°F");
        }
        else {
            inside_temp = "";
        }
        if (sentry != null) {
            sentry = " " + Ui.loadResource(sentry ? Rez.Strings.label_s_on : Rez.Strings.label_s_off);
        }
        else {
            sentry = "";
        }
        if (preconditioning != null) {
            preconditioning = " " + Ui.loadResource(preconditioning ? Rez.Strings.label_p_on : Rez.Strings.label_p_off);
        }
        else {
            preconditioning = "";
        }

        // If responseCode is null, we don't have anything, ask to launch or wait for data (if we have tokens)
        if (responseCode == 200) {
            if (charging_state != null && charging_state.equals("Charging")) {
                suffix = "+";
            }
        }
        else if (responseCode == 408) {
            if (vehicleAwake != null && vehicleAwake.equals("asleep")) {
                txt = Ui.loadResource(Rez.Strings.label_asleep) + preconditioning;
                if (!_threeLines) {
                    suffix = "s";
                }
            }
            else {
                txt = Ui.loadResource(Rez.Strings.label_error) + responseCode + preconditioning;
            }
        }
        else if (responseCode == 401 || responseCode == null) {
            txt =  Ui.loadResource(_showLaunch ? Rez.Strings.label_launch_widget : Rez.Strings.label_waiting_data);
            if (!_threeLines) {
                line2 = txt;
            }
        }
        else {
            txt = Ui.loadResource(Rez.Strings.label_error) + responseCode;
        }

        // Build or main glance line
        if (battery_level != null && battery_range != null && line2 == null) {
            line2 = battery_level + "%" + suffix + " / " + (System.getDeviceSettings().distanceUnits == System.UNIT_METRIC ? (battery_range * 1.6).format("%d") + " km" : battery_range + " miles") + timestamp;

            if (txt == null && _threeLines) {
                if (shift_state != null && shift_state.equals("") == false && shift_state.equals("P") == false) { // We're moving
                    line3 = inside_temp + " " + Ui.loadResource(Rez.Strings.label_driving);
                }
                else {
                    line3 = inside_temp + sentry + preconditioning;
                }
            }
        }

        // Last chance to build line2
        if (line2 == null) {
            if (txt == null) {
                line2 =  Ui.loadResource(_showLaunch ? Rez.Strings.label_launch_widget : Rez.Strings.label_waiting_data);
            }
            else {
                line2 = txt;
            }
        }
        // And if we have a line2, see if we should also build line3
        else if (line3 == null && _threeLines) {
            line3 = txt;
        }

        var text1Width = dc.getTextWidthInPixels(line1, _usingFont);
        var text2Width = dc.getTextWidthInPixels(line2, _usingFont);
        var text3Width = (line3 != null ? dc.getTextWidthInPixels(line3, _usingFont) : 0);

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

        /*DEBUG*/ if (showLog) {
        //DEBUG*/   logMessage("DC width/height: " + _dcWidth + "/" + _dcHeight + " resetPos: " + resetPos + " longest text width: " + longestTextWidth + " for line #" + longestTextWidthIndex);
        /*DEBUG*/   logMessage("Showing " + line1 + " | " +  line2 + " | " + line3);
        /*DEBUG*/ }
        
        if (_curPos1X == null || _prevText1Width != text1Width || _prevText2Width != text2Width || _prevText3Width != text3Width) {
            resetSavedPosition();
            _curPos1X = 0;
            _curPos2X = 0;
            _curPos3X = 0;

            _prevText1Width = text1Width;
            if (text1Width > _dcWidth) {
                _xDir1 = _steps;
            }

            _prevText2Width = text2Width;
            if (text2Width > _dcWidth) {
                _xDir2 = _steps;
            }

            _prevText3Width = text3Width;
            if (text3Width > _dcWidth) {
                _xDir3 = _steps;
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
        if (line3 != null) {
            spacing = ((_dcHeight - _fontHeight * 3) / 4).toNumber();
        }
        else {
            spacing = ((_dcHeight - _fontHeight * 2) / 3).toNumber();
        }

        dc.drawText(
            _curPos1X,
            spacing,
            _usingFont,
            line1,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        dc.drawText(
            _curPos2X,
            (spacing * 2 + _fontHeight).toNumber(),
            _usingFont,
            line2,
            Graphics.TEXT_JUSTIFY_LEFT
        );

        if (line3 != null) {
            dc.drawText(
            _curPos3X,
            (spacing * 3 + _fontHeight * 2).toNumber(),
            _usingFont,
            line3,
            Graphics.TEXT_JUSTIFY_LEFT
            );
        }

        if (_scrollEndTimer == 20) {
            resetSavedPosition();
        }
    }
}
