using Toybox.WatchUi as Ui;

class NoGlanceDelegate extends Ui.BehaviorDelegate {

    var _data;

    function initialize(data) {
        BehaviorDelegate.initialize();
        _data = data;
    }

    function onSelect() {
        var view = new MainView(_data);
        Ui.pushView(view, new MainDelegate(view, _data, view.method(:onReceive)), Ui.SLIDE_UP);
        return true;
    }

}