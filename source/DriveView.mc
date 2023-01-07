using Toybox.Background;
using Toybox.WatchUi as Ui;
using Toybox.System;
using Toybox.Time;

class DriveView extends Ui.View {
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
        setLayout(Rez.Layouts.DataScreenLayout(dc));
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
			//Application.getApp().setProperty("imperial", System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE);

            // We're loading the image layout
            setLayout(Rez.Layouts.DataScreenLayout(dc));
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            View.onUpdate(dc);
            
            var title = View.findDrawableById("Title");
		    var lineText = new [8];
		    var lineValue = new [8];
            
            for (var i = 1; i <= 8; i++) {
                lineText[i - 1]  = View.findDrawableById("Line" + i + "Text");
                lineValue[i - 1] = View.findDrawableById("Line" + i + "Value");
            }

// logMessage("_viewOffset is " + _viewOffset);
            var lineData; 
			if (_viewOffset == 0) {
	            lineText[0].setText(Ui.loadResource(Rez.Strings.subview_label_drive_data_1_1));

	            lineData = _data._vehicle_data.get("drive_state").get("shift_state");
	            lineText[2].setText(Ui.loadResource(Rez.Strings.subview_label_shift_state));
	            if (lineData != null) {
		            lineValue[2].setText(lineData.toString());
				}
				else {
					lineValue[2].setText("Parked");
				}
				
	            lineData = _data._vehicle_data.get("drive_state").get("speed");
	            lineText[3].setText(Ui.loadResource(Rez.Strings.subview_label_speed));
				if (lineData == null) {
					lineData = 0;
				}
	            lineData *=  (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6);
	            lineValue[3].setText(lineData.toNumber().toString() + (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? " miles" : " km"));

	            lineData = _data._vehicle_data.get("drive_state").get("heading").toFloat();
	            lineText[4].setText(Ui.loadResource(Rez.Strings.subview_label_heading));
	            if (lineData != null) {
					var val = (lineData.toFloat() / 22.5) + .5;
					var arr = toArray(Ui.loadResource(Rez.Strings.subview_label_compass),",");

					lineData = arr[(val.toNumber() % 16)];
		            lineValue[4].setText(lineData.toString());
				}
					
	            lineData = _data._vehicle_data.get("drive_state").get("power").toFloat();
	            lineText[5].setText(Ui.loadResource(Rez.Strings.subview_label_power));
	            if (lineData != null) {
		            lineValue[5].setText(lineData.toString());
		        }
			}
			
            for (var i = 0; i < 8; i++) {
                lineText[i].draw(dc);
                lineValue[i].draw(dc);
            }
        }
	}

	function toArray(string, splitter) {
		var array = new [16]; //Use maximum expected length
		var index = 0;
		var location;

		do {
			location = string.find(splitter);
			if (location != null) {
				array[index] = string.substring(0, location);
				string = string.substring(location + 1, string.length());
				index++;
			}
		} while (location != null);

		array[index] = string;
		
		var result = new [index];
		for (var i = 0; i < index; i++) {
			result = array;
		}
		return result;
	}
}
