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
        var center_x = dc.getWidth()/2;
        var center_y = dc.getHeight()/2;
        
        // Load our custom font if it's there, generally only for high res, high mem devices
        var font_montserrat;
        if (Rez has :Fonts && Rez.Fonts has :montserrat) {
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

            // We're loading the image layout
            setLayout(Rez.Layouts.DataScreenLayout(dc));
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            View.onUpdate(dc);
            
		    var lineText = new [8];
		    var lineValue = new [8];
            
            for (var i = 1; i <= 8; i++) {
                lineText[i - 1]  = View.findDrawableById("Line" + i + "Text");
                lineValue[i - 1] = View.findDrawableById("Line" + i + "Value");
            }

            // logMessage("DriveView:onUpdate: _viewOffset is " + _viewOffset);
            var lineData; 
			if (_viewOffset == 0) {
	            lineText[0].setText(Ui.loadResource(Rez.Strings.subview_label_drive_data_1_1));

	            lineData = $.validateString(_data._vehicle_data.get("drive_state").get("shift_state"), "");
	            lineText[2].setText(Ui.loadResource(Rez.Strings.subview_label_shift_state));
	            if (lineData.equals("") == false && lineData.equals("P") == false) {
		            lineValue[2].setText(lineData);
				}
				else {
					lineValue[2].setText("P");
				}
				
	            lineData = $.validateFloat(_data._vehicle_data.get("drive_state").get("speed"), 0.0);
	            lineText[3].setText(Ui.loadResource(Rez.Strings.subview_label_speed));
	            lineData *=  (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? 1.0 : 1.6);
	            lineValue[3].setText(lineData.toNumber() + (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE ? " miles" : " km"));

	            lineData = $.validateFloat(_data._vehicle_data.get("drive_state").get("heading"), 0.0);
	            lineText[4].setText(Ui.loadResource(Rez.Strings.subview_label_heading));
	            if (lineData != null) {
					var val = (lineData.toFloat() / 22.5) + .5;
					var arr = $.to_array(Ui.loadResource(Rez.Strings.subview_label_compass),",");

					lineData = arr[(val.toNumber() % 16)];
		            lineValue[4].setText(lineData);
				}
					
	            lineData = $.validateFloat(_data._vehicle_data.get("drive_state").get("power"), 0.0).format("%.1f");
	            lineText[5].setText(Ui.loadResource(Rez.Strings.subview_label_power));
                lineValue[5].setText(lineData);
			}
			
            for (var i = 0; i < 8; i++) {
                lineText[i].draw(dc);
                lineValue[i].draw(dc);
            }
        }
	}
}
