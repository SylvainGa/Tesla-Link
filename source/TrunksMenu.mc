using Toybox.WatchUi as Ui;


class TrunksMenuDelegate extends Ui.Menu2InputDelegate {
    var _controller;
    var _previous_stateMachineCounter;
	
    function initialize(controller) {
        Ui.Menu2InputDelegate.initialize();
        _controller = controller;
        _previous_stateMachineCounter = (_controller._stateMachineCounter > 1 ? 1 : _controller._stateMachineCounter); // Drop the wait to 0.1 second is it's over, otherwise keep the value already there
        _controller._stateMachineCounter = -1;
        logMessage("TrunksMenuDelegate: initialize, _stateMachineCounter was " + _previous_stateMachineCounter);
    }

    //! Handle a cancel event from the picker
    //! @return true if handled, false otherwise
    function onBack() {
        // Unless we missed data, restore _stateMachineCounter
        _controller._stateMachineCounter = (_controller._stateMachineCounter != -2 ? _previous_stateMachineCounter : 1);
        logMessage("TrunksMenuDelegate:onBack, returning _stateMachineCounter to " + _controller._stateMachineCounter);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    function onSelect(selected_item) {
        var item = selected_item.getId();

        logMessage("TrunksMenuDelegate:onSelect for " + selected_item.getLabel());

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

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _controller.actionMachine();
        return true;
    }
}
