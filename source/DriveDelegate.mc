using Toybox.WatchUi as Ui;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Communications as Communications;
using Toybox.Cryptography;
using Toybox.Graphics;

class DriveDelegate extends Ui.BehaviorDelegate {
	var _view as DriveView;
    var _handler;
	
    function initialize(view as DriveView, handler) {
        BehaviorDelegate.initialize();

    	_view = view;
        _handler = handler;
    }

    function onPreviousPage() {
		//DEBUG*/ logMessage("DriveDelegate: onPreviousPage");
    	_view._viewOffset -= 4;
    	if (_view._viewOffset < 0) {
			_view._viewOffset = 0;
    	}
	    _view.requestUpdate();
        return true;
    }

    function onNextPage() {
		//DEBUG*/ logMessage("DriveDelegate: onNextPage");
    	_view._viewOffset += 4;
    	if (_view._viewOffset > 0) { // One page but coded to accept more if required
			_view._viewOffset = 0;
    	}
	    _view.requestUpdate();
        return true;
    }

	function onMenu() {
		//DEBUG*/ logMessage("DriveDelegate: onMenu invoking next view");
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_handler.invoke(4); // Tell MainDelegate to show next subview

	    _view.requestUpdate();
        return true;
	}
	
    function onSwipe(swipeEvent) {
		//DEBUG*/ logMessage("DriveDelegate: onSwipe got a " + swipeEvent.getDirection());
    	if (swipeEvent.getDirection() == 3) {
	    	onMenu();
    	}
        return true;
	}
	
    function onBack() {
		//DEBUG*/ logMessage("DriveDelegate: onBack invoking main view");
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_handler.invoke(0);
        return true;
    }

    function onTap(click) {
		//DEBUG*/ logMessage("DriveDelegate: onTap calling onMenu");
		onMenu();
        return true;
    }
}
