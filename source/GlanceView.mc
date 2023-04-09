using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

(:glance, :can_glance)
class GlanceView extends Ui.GlanceView {
	
  function initialize() {
    GlanceView.initialize();
  }

  function onUpdate(dc) {
    // Retrieve the name of the vehicle if we have it, or the generic string otherwise
    var vehicle_name = Application.getApp().getProperty("vehicle_name");
    var status = Application.getApp().getProperty("status");
    vehicle_name = (vehicle_name == null) ? Ui.loadResource(Rez.Strings.vehicle) : vehicle_name;

    if (status != null) {
      var array = to_array(status, "|");

      //var responseCode = array[0].toNumber();
      var battery_level = array[1];
      var charging_state = array[2];
      var battery_range = array[3];
      var suffix = array[4];
      var text = array[5];

      // Check ig we have bad data, if so, say we're waiting for data
      if (text == null || charging_state == null || battery_level.equals("N/A")) {
        status =  Ui.loadResource(Rez.Strings.label_waiting_data);
      }
      else {
        status = battery_level + "%" + (charging_state.equals("Charging") ? "+" : "") + " / " + battery_range + suffix + text;
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