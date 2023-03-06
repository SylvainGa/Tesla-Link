using Toybox.Graphics;
using Toybox.WatchUi;
import Toybox.Lang;

class WordFactory extends WatchUi.PickerFactory {
    var mWords;
    var mFont;

    function initialize(words) {
        PickerFactory.initialize();

        mWords = words;
        mFont = Graphics.FONT_SMALL;
    }

    public function getIndex(value as String or Symbol) as Number {
        if (value instanceof String) {
            for (var i = 0; i < mWords.size(); i++) {
                if (value.equals(WatchUi.loadResource(mWords[i]))) {
                    return i;
                }
            }
        } else {
            for (var i = 0; i < mWords.size(); i++) {
                if (mWords[i].equals(value)) {
                    return i;
                }
            }
        }

        return 0;
    }

    function getSize() {
        return mWords.size();
    }

    function getValue(index) {
        return mWords[index];
    }

    function getDrawable(index, selected) {
        return new WatchUi.Text({:text=>mWords[index], :color=>Graphics.COLOR_WHITE, :font=>mFont, :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }
}
