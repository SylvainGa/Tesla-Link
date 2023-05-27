using Toybox.WatchUi as Ui;

class NoGlanceDelegate extends Ui.BehaviorDelegate {

    var _data;

    function initialize(data) {
        BehaviorDelegate.initialize();
        _data = data;
    }

    function onSelect() {
        var view = new MainView(_data);
        var delegate = new MainDelegate(view, _data, view.method(:onReceive));
        delegate._wakeWasConfirmed = true;
        Ui.pushView(view, delegate, Ui.SLIDE_UP);
        return true;
    }

}