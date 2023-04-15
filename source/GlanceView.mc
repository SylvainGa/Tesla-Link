using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

(:glance, :can_glance)
class GlanceView extends Ui.GlanceView {
  function initialize() {
    GlanceView.initialize();
  }

  (:bkgnd32kb)
  function onUpdate(dc) {
    // Retrieve the name of the vehicle if we have it, or the generic string otherwise
    var vehicle_name = Application.getApp().getProperty("vehicle_name");
    vehicle_name = (vehicle_name == null) ? Ui.loadResource(Rez.Strings.vehicle) : vehicle_name;
    var responseCode;
    var battery_level;
    var charging_state;
    var battery_range;
    var timestamp;
    var text;

    var status = Application.getApp().getProperty("status");
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
        status = battery_level + "%" + chargeSuffix + " / " + battery_range + timestamp;
      }
    }
    else {
        status = Ui.loadResource(Rez.Strings.label_launch_widget);
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

  (:bkgnd64kb)
  function onUpdate(dc) {
    // Retrieve the name of the vehicle if we have it, or the generic string otherwise
    var vehicle_name = Application.getApp().getProperty("vehicle_name");
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

    var status = Application.getApp().getProperty("status");
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
          var token = Application.getApp().getProperty("token");
          var vehicle = Application.getApp().getProperty("vehicle");
          status =  Ui.loadResource(token != null && vehicle != null ? Rez.Strings.label_waiting_data : Rez.Strings.label_launch_widget);
        }
      }
      else {
        var vehicleAsleep = (text != null && text.equals(Application.loadResource(Rez.Strings.label_asleep)));
        var chargeSuffix = "";

        if (threeLines) {
          if (responseCode == 200) {
            text = inside_temp + (sentry.equals("true") ? " S On" : " S Off") +  (preconditioning.equals("true") ? " P On" : " P Off");
          }
          else if (vehicleAsleep) {
            text = Application.loadResource(Rez.Strings.label_asleep) + (preconditioning.equals("true") ? " P On" : " P Off");
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

        status = battery_level + "%" + chargeSuffix + " / " + battery_range + timestamp;
      }
    }
    else {
      var token = Application.getApp().getProperty("token");
      var vehicle = Application.getApp().getProperty("vehicle");
      status =  Ui.loadResource(token != null && vehicle != null ? Rez.Strings.label_waiting_data : Rez.Strings.label_launch_widget);
    }

    /*DEBUG*/ logMessage("Showing " + vehicle_name.toUpper() + " | " +  status + " | " + text);

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
}