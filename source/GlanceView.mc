using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

(:glance, :can_glance, :bkgnd32kb)
class GlanceView extends Ui.GlanceView {
  var _curPos1X;
  var _curPos2X;
  var _xDir1;
  var _xDir2;
  var _refreshTimer;
  var _scrollStartTimer;
  var _scrollEndTimer;
  var _prevText1Width;
  var _prevText2Width;
  
  function initialize() {
    GlanceView.initialize();
  }

	function onShow() {
		if (Properties.getValue("titleScrolling")) {
  		_refreshTimer = new Timer.Timer();
			_refreshTimer.start(method(:refreshView), 50, true);
		}

    _curPos1X = null;
    _curPos2X = null;
    _prevText1Width = 0;
    _prevText2Width = 0;

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
    var timestamp;
    var text;

    var status = Storage.getValue("status");
    if (status != null && status.equals("") == false) {
      var array = to_array(status, "|");

      if (array.size() == 6) {
        responseCode = array[0].toNumber();
        battery_level = array[1];
        charging_state = array[2];
        battery_range = (array[3].toNumber() * (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6)).toNumber();
        timestamp = array[4];
        text = array[5];
        if (text != null && text.equals("")) {
          text = null;
        }
      }

      if (battery_level == null || battery_level.equals("N/A")) {
        if (text != null) {
          status = text + timestamp;
        }
        else {
          status = Ui.loadResource(Rez.Strings.label_launch_widget);
        }
      }
      else {
        var chargeSuffix = "";
        if (responseCode == 408) {
          chargeSuffix = "s";
        }
        else if (responseCode != 200) {
          chargeSuffix = "?";
        }
        else if (charging_state.equals("Charging")) {
          chargeSuffix = "+";
        }
        status = battery_level + "%" + chargeSuffix + " / " + battery_range + (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? " miles" : " km") + timestamp;
      }
    }
    else {
        status = Ui.loadResource(Rez.Strings.label_launch_widget);
    }

    var textMaxWidth = dc.getWidth();

    var text1Width = dc.getTextWidthInPixels(vehicle_name.toUpper(), Graphics.FONT_TINY);
    var text2Width = dc.getTextWidthInPixels(status, Graphics.FONT_TINY);

    //var textMaxWidth = (2 * radius * Math.sin(Math.toRadians(2 * Math.toDegrees(Math.acos(1 - (15.0 / radius)))) / 2)).toNumber();
    if (_curPos1X == null || _prevText1Width != text1Width) {
        _curPos1X = 0;
        _prevText1Width = text1Width;
        _scrollEndTimer = 0;
        _scrollStartTimer = 0;
        if (text1Width > textMaxWidth) {
          _xDir1 = -1;
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
          _xDir2 = -1;
        }
        else {
          _xDir2 = 0;
        }
    }

    var biggestTextWidthIndex;
    if (text1Width > text2Width) {
      biggestTextWidthIndex = 1;
    }
    else {
      biggestTextWidthIndex = 2;
    }

    if (text1Width > textMaxWidth || text2Width > textMaxWidth) {
      if (_scrollStartTimer > 20) {
        _curPos1X = _curPos1X + _xDir1;
        _curPos2X = _curPos2X + _xDir2;

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
      }
      else {
        _scrollStartTimer = _scrollStartTimer + 1;
      }
    }

    // Draw the two rows of text on the glance widget
    dc.setColor(Gfx.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(
      _curPos1X,
      (dc.getHeight() / 8) * 2,
      Graphics.FONT_TINY,
      vehicle_name.toUpper(),
      Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
    );

    dc.drawText(
      _curPos2X,
      (dc.getHeight() / 8) * 6,
      Graphics.FONT_TINY,
      status,
      Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
    );

    if (_scrollEndTimer == 20) {
      _curPos1X = null;
      _curPos2X = null;

      _scrollEndTimer = 0;
      _scrollStartTimer = 0;
    }
  }
}

(:glance, :can_glance, :bkgnd64kb)
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
		if (Properties.getValue("titleScrolling")) {
  		_refreshTimer = new Timer.Timer();
			_refreshTimer.start(method(:refreshView), 50, true);
		}

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
    //DEBUG*/ logMessage("Font height=" +  Graphics.getFontHeight(Graphics.FONT_TINY));

    if (dc.getHeight() / Graphics.getFontHeight(Graphics.FONT_TINY) >= 3.0) {
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

    //DEBUG*/ logMessage("Showing " + vehicle_name.toUpper() + " | " +  status + " | " + text);

    var textMaxWidth = dc.getWidth();

    var text1Width = dc.getTextWidthInPixels(vehicle_name.toUpper(), Graphics.FONT_TINY);
    var text2Width = dc.getTextWidthInPixels(status, Graphics.FONT_TINY);
    var text3Width = (text != null ? dc.getTextWidthInPixels(text, Graphics.FONT_TINY) : 0);

    //var textMaxWidth = (2 * radius * Math.sin(Math.toRadians(2 * Math.toDegrees(Math.acos(1 - (15.0 / radius)))) / 2)).toNumber();
    if (_curPos1X == null || _prevText1Width != text1Width) {
        _curPos1X = 0;
        _prevText1Width = text1Width;
        _scrollEndTimer = 0;
        _scrollStartTimer = 0;
        if (text1Width > textMaxWidth) {
          _xDir1 = -1;
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
          _xDir2 = -1;
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
          _xDir3 = -1;
        }
        else {
          _xDir3 = 0;
        }
    }

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
    var y = (text != null || threeLines == false ? 0 : (Graphics.getFontHeight(Graphics.FONT_TINY) * 0.5).toNumber());
    dc.drawText(
      _curPos1X,
      y,
      Graphics.FONT_TINY,
      vehicle_name.toUpper(),
      Graphics.TEXT_JUSTIFY_LEFT
    );

    y = (text != null || threeLines == false ? Graphics.getFontHeight(Graphics.FONT_TINY) : (Graphics.getFontHeight(Graphics.FONT_TINY) * 1.5).toNumber());
    dc.drawText(
      _curPos2X,
      y,
      Graphics.FONT_TINY,
      status,
      Graphics.TEXT_JUSTIFY_LEFT
    );

    if (text != null) {
      y = Graphics.getFontHeight(Graphics.FONT_TINY) * 2;
      dc.drawText(
        _curPos3X,
        y,
        Graphics.FONT_TINY,
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