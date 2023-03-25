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
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_FRUNK, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
        } else if (item == :open_trunk) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_TRUNK, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
        } else if (item == :open_port) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_OPEN_PORT, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
        } else if (item == :close_port) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_CLOSE_PORT, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
        } else if (item == :toggle_charge) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_TOGGLE_CHARGE, "Option" => ACTION_OPTION_NONE, "Value" => 0, "Tick" => System.getTimer()});
        } else if (item == :vent) {
            _controller._pendingActionRequests.add({"Action" => ACTION_TYPE_VENT, "Option" => ACTION_OPTION_BYPASS_CONFIRMATION, "Value" => 0, "Tick" => System.getTimer()});
        }

        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
