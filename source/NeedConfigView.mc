using Toybox.WatchUi as Ui;

class NeedConfigView extends Ui.View {

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        setLayout(Rez.Layouts.NeedConfigLayout(dc));
    }

}
