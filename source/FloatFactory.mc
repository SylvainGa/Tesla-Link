//
// Copyright 2015-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! Factory that controls which numbers can be picked
class FloatFactory extends WatchUi.PickerFactory {
    private var _start as Float;
    private var _stop as Float;
    private var _increment as Float;
    private var _formatString as String;
    private var _font as FontDefinition;

    //! Constructor
    //! @param start Float to start with
    //! @param stop Float to end with
    //! @param increment How far apart the numbers should be
    //! @param options Dictionary of options
    //! @option options :font The font to use
    //! @option options :format The Float format to display
    public function initialize(start as Float, stop as Float, increment as Float, options as {
        :font as FontDefinition,
        :format as String
    }) {
        PickerFactory.initialize();

        _start = start;
        _stop = stop;
        _increment = increment;

        var format = options.get(:format);
        if (format != null) {
            _formatString = format;
        } else {
            _formatString = "%d";
        }

        var font = options.get(:font);
        if (font != null) {
            _font = font;
        } else {
            _font = Graphics.FONT_NUMBER_MILD;
        }
    }

    //! Get the index of a Float item
    //! @param value The Float to get the index of
    //! @return The index of the Float
    public function getIndex(value as Float) as Float {
        return (value / _increment) - _start;
    }

    //! Generate a Drawable instance for an item
    //! @param index The item index
    //! @param selected true if the current item is selected, false otherwise
    //! @return Drawable for the item
    public function getDrawable(index as Float, selected as Boolean) as Drawable? {
        var value = getValue(index);
        var text = "No item";
        if (value instanceof Float) {
            text = value.format(_formatString);
        }
        return new WatchUi.Text({:text=>text, :color=>Graphics.COLOR_WHITE, :font=>_font,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }

    //! Get the value of the item at the given index
    //! @param index Index of the item to get the value of
    //! @return Value of the item
    public function getValue(index as Float) as Object? {
        return _start + (index * _increment);
    }

    //! Get the Float of picker items
    //! @return Float of items
    public function getSize() as Float {
        return (_stop - _start) / _increment + 1;
    }
}
