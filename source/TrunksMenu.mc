using Toybox.WatchUi as Ui;


class TrunksMenuDelegate extends Ui.MenuInputDelegate {
    var _controller;
	
    function initialize(controller) {
        Ui.MenuInputDelegate.initialize();
        _controller = controller;
    }

    function onMenuItem(item) {
        if (item == :open_frunk) {
        	_controller._open_frunk = true;
        	_controller._bypass_confirmation = true;
        } else if (item == :open_trunk) {
        	_controller._open_trunk = true;
        	_controller._bypass_confirmation = true;
        } else if (item == :open_port) {
        	_controller._open_port = true;
        } else if (item == :close_port) {
        	_controller._close_port = true;
        } else if (item == :toggle_charge) {
        	_controller._toggle_charging_set = true;
        } else if (item == :vent) {
        	_controller._vent = true;
        	_controller._bypass_confirmation = true;
        }

        _controller.stateMachine();
    }
}
