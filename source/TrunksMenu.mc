using Toybox.WatchUi as Ui;


class TrunksMenuDelegate extends Ui.MenuInputDelegate {
    var _controller;
	
    function initialize(controller) {
        Ui.MenuInputDelegate.initialize();
        _controller = controller;
    }

    function onMenuItem(item) {
        if (item == :frunk) {
        	_controller._open_frunk = true;
        	_controller._bypass_confirmation = true;
        } else if (item == :trunk) {
        	_controller._open_trunk = true;
        	_controller._bypass_confirmation = true;
        } else if (item == :port) {
        	_controller._open_port = true;
        } else if (item == :vent) {
        	_controller._vent = true;
        }

        _controller.stateMachine();
    }
}
