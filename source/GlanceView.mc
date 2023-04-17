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
  
  function initialize() {
    GlanceView.initialize();
  }

	function onShow() {
    _refreshTimer = new Timer.Timer();
    _refreshTimer.start(method(:refreshView), 50, true);

    _curPos1X = null;
    _curPos2X = null;
    _curPos3X = null;
    _prevText1Width = 0;
    _prevText2Width = 0;
    _prevText3Width = 0;

    _scrollStartTimer = 0;
    _scrollEndTimer = 0;
	}
	
	function onHide() {
    if (_refreshTimer) {
  		_refreshTimer.stop();
  		_refreshTimer = null;
    }
	}

	function refreshView() {
    Ui.requestUpdate();
	}

  function onUpdate(dc) {
    // Retrieve the name of the vehicle if we have it, or the generic string otherwise
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
    var threeLines;

    //DEBUG*/ logMessage("Glance height=" + dc.getHeight());
    //DEBUG*/ logMessage("Glance width=" + dc.getWidth());
    //DEBUG*/ logMessage("Font height=" +  Graphics.getFontHeight(Graphics.FONT_TINY));

    var font_used = (Properties.getValue("smallfontsize") ? Graphics.FONT_XTINY : Graphics.FONT_TINY);
    var height = dc.getHeight();
    var font_height = Graphics.getFontHeight(font_used);
    
    if (height / font_height >= 3.0) {
      threeLines = true;
    }
    else {
      threeLines = false;
    }

    var status = Storage.getValue("status");
    if (status != null && status.equals("") == false) {
      var array = to_array(status, "|");

      if (array.size() == 9) {
        responseCode = array[0].toNumber();
        battery_level = array[1];
        charging_state = array[2];
        battery_range = (array[3].toNumber() * (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6)).toNumber();
        inside_temp = array[4].toNumber();
        inside_temp = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? ((inside_temp * 9 / 5) + 32) + "°F" : inside_temp + "°C";
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

        if (threeLines) {
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

    var screenShape = System.getDeviceSettings().screenShape;
    var textMaxWidth = dc.getWidth();
    if (screenShape == System.SCREEN_SHAPE_ROUND && Properties.getValue("scrollclearsedge") == true) {
      var rad = Math.asin(height.toFloat() * (text != null ? 1.0 : 0.8) / textMaxWidth.toFloat());
      textMaxWidth = (Math.cos(rad) * textMaxWidth.toFloat()).toNumber();
    }

    var text1Width = dc.getTextWidthInPixels(vehicle_name.toUpper(), font_used);
    var text2Width = dc.getTextWidthInPixels(status, font_used);
    var text3Width = (text != null ? dc.getTextWidthInPixels(text, font_used) : 0);

    var biggestTextWidth = text1Width;
    var biggestTextWidthIndex = 1;
    if (biggestTextWidth < text2Width) {
      biggestTextWidth = text2Width;
      biggestTextWidthIndex = 2;
    }
    if (biggestTextWidth < text3Width) {
      biggestTextWidthIndex = 3;
      biggestTextWidth = text3Width;
    }

    if (_curPos1X == null || _prevText1Width != text1Width) {
      /*DEBUG*/ logMessage("DC width: " + dc.getWidth() + "max allowed: " + textMaxWidth + " text width: " + biggestTextWidth + " for line " + biggestTextWidthIndex);
      /*DEBUG*/ logMessage("Showing " + vehicle_name.toUpper() + " | " +  status + " | " + text);
      _curPos1X = 0;
      _prevText1Width = text1Width;
      _scrollEndTimer = 0;
      _scrollStartTimer = 0;
      if (text1Width > textMaxWidth) {
        _xDir1 = -2;
      }
      else {
        _xDir1 = 0;
      }
    }
    if (_curPos2X == null || _prevText2Width != text2Width) {
        _curPos2X = 0;
        _prevText2Width = text2Width;
        _scrollEndTimer = 0;
        _scrollStartTimer = 0;
        if (text2Width > textMaxWidth) {
          _xDir2 = -2;
        }
        else {
          _xDir2 = 0;
        }
    }
    if (_curPos3X == null || _prevText3Width != text3Width) {
        _curPos3X = 0;
        _prevText3Width = text3Width;
        _scrollEndTimer = 0;
        _scrollStartTimer = 0;
        if (text3Width > textMaxWidth) {
          _xDir3 = -2;
        }
        else {
          _xDir3 = 0;
        }
    }

    if (text1Width > textMaxWidth || text2Width > textMaxWidth || text3Width > textMaxWidth) {
      if (_scrollStartTimer > 20) {
        _curPos1X = _curPos1X + _xDir1;
        _curPos2X = _curPos2X + _xDir2;
        _curPos3X = _curPos3X + _xDir3;

        if (_curPos1X + text1Width < textMaxWidth) {
          _xDir1 = 0;
          if (biggestTextWidthIndex == 1) {
            _scrollEndTimer = _scrollEndTimer + 1;              
          }
        }
        if (_curPos2X + text2Width < textMaxWidth) {
          _xDir2 = 0;
          if (biggestTextWidthIndex == 2) {
            _scrollEndTimer = _scrollEndTimer + 1;              
          }
        }
        if (_curPos3X + text3Width < textMaxWidth) {
          if (biggestTextWidthIndex == 3) {
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
      spacing = ((height - font_height * 3) / 4).toNumber();
    }
    else {
      spacing = ((height - font_height * 2) / 3).toNumber();
    }

    var y = spacing;
    dc.drawText(
      _curPos1X,
      y,
      font_used,
      vehicle_name.toUpper(),
      Graphics.TEXT_JUSTIFY_LEFT
    );

    y = (spacing * 2 + font_height).toNumber();
    dc.drawText(
      _curPos2X,
      y,
      font_used,
      status,
      Graphics.TEXT_JUSTIFY_LEFT
    );

    if (text != null) {
      y = (spacing * 3 + font_height * 2).toNumber();
      dc.drawText(
        _curPos3X,
        y,
        font_used,
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