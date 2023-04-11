using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

(:glance, :can_glance)
class GlanceView extends Ui.GlanceView {
  var _data;

  function initialize(data) {
    _data = data;

    GlanceView.initialize();
  }

  (:bkgnd64kb)
  function onUpdate(dc) {
    // Retrieve the name of the vehicle if we have it, or the generic string otherwise
    var vehicle_name = Application.getApp().getProperty("vehicle_name");
    vehicle_name = (vehicle_name == null) ? Ui.loadResource(Rez.Strings.vehicle) : vehicle_name;

    var status = Application.getApp().getProperty("status");
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

    if (status != null) {
      var array = to_array(status, "|");

      var responseCode = array[0].toNumber();
      var battery_level = array[1];
      var charging_state = array[2];
      var battery_range = array[3];
      var inside_temp = array[4];
			inside_temp = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? ((inside_temp.toNumber()*9/5) + 32) + "°F" : inside_temp.toNumber() + "°C";
      var sentry = array[5];
      var preconditioning = array[6];
      var suffix = array[7];
      text = array[8];
      if (text != null && text.equals(" ")) {
        text = null;
      }

      if (charging_state == null || battery_level.equals("N/A")) {
        if (text != null) {
          status = text;
          text = null;
        }
        else {
          status = Ui.loadResource(Rez.Strings.label_waiting_data);
        }
      }
      else {
        var chargeSuffix = "";
        if (_data._vehicle_awake == false && threeLines == false) {
          chargeSuffix = "s";
        }
        else if (responseCode != 200 && threeLines == false) {
          chargeSuffix = "?";
        }
        else if (charging_state.equals("Charging")) {
          chargeSuffix = "+";
        }

        if (text == null && responseCode == 200 && threeLines) {
          text = inside_temp + (sentry.equals("true") ? " S On" : " S Off") +  (preconditioning.equals("true") ? " P On" : " P Off");
        }

        status = battery_level + "%" + chargeSuffix + " / " + battery_range + suffix;
      }
    }
    else {
      status =  Ui.loadResource(Rez.Strings.label_waiting_data);
    }

    if (threeLines == false) {
      text = null;
    }

    // Draw the two rows of text on the glance widget
    dc.setColor(Gfx.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    var y = (text != null || threeLines == false ? 0 : (Graphics.getFontHeight(Graphics.FONT_TINY) * 0.5).toNumber());
    dc.drawText(
      0,
      y,
      Graphics.FONT_TINY,
      vehicle_name.toUpper(),
      Graphics.TEXT_JUSTIFY_LEFT
    );

    y = (text != null || threeLines == false ? Graphics.getFontHeight(Graphics.FONT_TINY) : (Graphics.getFontHeight(Graphics.FONT_TINY) * 1.5).toNumber());
    dc.drawText(
      0,
      y,
      Graphics.FONT_TINY,
      status,
      Graphics.TEXT_JUSTIFY_LEFT
    );

    if (text != null) {
      y = Graphics.getFontHeight(Graphics.FONT_TINY) * 2;
      dc.drawText(
        0,
        y,
        Graphics.FONT_TINY,
        text,
        Graphics.TEXT_JUSTIFY_LEFT
      );
    }
  }

  (:bkgnd32kb)
  function onUpdate(dc) {
    // Retrieve the name of the vehicle if we have it, or the generic string otherwise
    var vehicle_name = Application.getApp().getProperty("vehicle_name");
    vehicle_name = (vehicle_name == null) ? Ui.loadResource(Rez.Strings.vehicle) : vehicle_name;
    var text;

    var status = Application.getApp().getProperty("status");
    if (status != null) {
      var array = to_array(status, "|");

      var responseCode = array[0].toNumber();
      var battery_level = array[1];
      var charging_state = array[2];
      var battery_range = array[3];
      var suffix = array[4];
      text = array[5];
      if (text != null && text.equals(" ")) {
        text = null;
      }

      if (charging_state == null || battery_level.equals("N/A")) {
        if (text != null) {
          status = text;
        }
        else {
          status = Ui.loadResource(Rez.Strings.label_waiting_data);
        }
      }
      else {
        var chargeSuffix = "";
        if (_data._vehicle_awake == false) {
          chargeSuffix = "s";
        }
        else if (responseCode != 200) {
          chargeSuffix = "?";
        }
        else if (charging_state.equals("Charging")) {
          chargeSuffix = "+";
        }
        status = battery_level + "%" + chargeSuffix + " / " + battery_range + suffix;
      }
    }
    else {
      status =  Ui.loadResource(Rez.Strings.label_waiting_data);
    }

    // Draw the two rows of text on the glance widget
    dc.setColor(Gfx.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(
      0,
      (dc.getHeight() / 8) * 2,
      Graphics.FONT_TINY,
      vehicle_name.toUpper(),
      Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
    );

    dc.drawText(
      0,
      (dc.getHeight() / 8) * 6,
      Graphics.FONT_TINY,
      status,
      Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
    );
  }
}