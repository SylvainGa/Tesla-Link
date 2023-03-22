using Toybox.WatchUi as Ui;


class TrunksMenuDelegate extends Ui.Menu2InputDelegate {
    var _controller;
	
    function initialize(controller) {
        Ui.Menu2InputDelegate.initialize();
        _controller = controller;
        _controller._stateMachineCounter = -1;
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    function onBack() {
        _controller._stateMachineCounter = 1;
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onSelect(selected_item) {
        var item = selected_item.getId();

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

        _controller.actionMachine();
    }
}
