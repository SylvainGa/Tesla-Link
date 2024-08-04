using Toybox.WatchUi as Ui;
using Toybox.Graphics;
using Toybox.Application.Storage;

class DogModeDelegate extends Ui.BehaviorDelegate {
    var _view;
    var _controller;
    var _vehicle;
    var _useTouch;
    var _previous_stateMachineCounter;
    var _fontHeight;
    var _handler;

    function initialize(view, controller, previous_stateMachineCounter, handler) {
        BehaviorDelegate.initialize();
        _view = view;
        _controller = controller;
        _previous_stateMachineCounter = previous_stateMachineCounter;
    }

    function onBack() {
        var view = new Ui.Confirmation(Ui.loadResource(Rez.Strings.label_leave_dog_mode));
        var delegate = new SimpleConfirmDelegate(method(:LeaveDogMode), method(:StayDogMode));
        _controller._subViewExitCounter = 150;
        Ui.pushView(view, delegate, Ui.SLIDE_UP);
        // Unless we missed data, restore _stateMachineCounter
        return true;
    }

    function LeaveDogMode()
    {
        _controller._stateMachineCounter = (_controller._stateMachineCounter != -2 ? _previous_stateMachineCounter : 1);
        _controller._subView = null;
        _controller._subViewExitCounter = 0;
        //DEBUG 2023-10-02*/ logMessage("DogModeDelegate:onBack, returning _stateMachineCounter to " + _controller._stateMachineCounter);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function StayDogMode()
    {
        return true;
    }
}
