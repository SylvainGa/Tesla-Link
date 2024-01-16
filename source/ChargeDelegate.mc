using Toybox.WatchUi as Ui;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Communications as Communications;
using Toybox.Cryptography;
using Toybox.Graphics;

class ChargeDelegate extends Ui.BehaviorDelegate {
	var _view as ChargeView;
	var _handler;
	
    function initialize(view as ChargeView, handler) {
        BehaviorDelegate.initialize();

    	_view = view;
        _handler = handler;
    }

    function onPreviousPage() {
		//DEBUG*/ logMessage("ChargeDelegate: onPreviousPage");
    	_view._viewOffset -= 4;
    	if (_view._viewOffset < 0) {
			_view._viewOffset = 0;
    	}
	    _view.requestUpdate();
        return true;
    }

    function onNextPage() {
		//DEBUG*/ logMessage("ChargeDelegate: onNextPage");
    	_view._viewOffset += 4;
    	if (_view._viewOffset > 4) {
			_view._viewOffset = 4;
    	}
	    _view.requestUpdate();
        return true;
    }

	function onMenu() {
		//DEBUG*/ logMessage("ChargeDelegate: onMenu invoking next view");
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_handler.invoke(2); // Tell MainDelegate to show next subview

	    _view.requestUpdate();
        return true;
	}
	
    function onSwipe(swipeEvent) {
		//DEBUG*/ logMessage("ChargeDelegate: onSwipe got a " + swipeEvent.getDirection());
    	if (swipeEvent.getDirection() == 3) {
	    	onMenu();
    	}
        return true;
	}
	
    function onFlick(flickEvent) {
		//DEBUG*/ logMessage("ChargeDelegate: onFlick got a " + flickEvent.getDirection());
        return false;
	}
	
    function onDrag(dragEvent) {
		//DEBUG*/ logMessage("ChargeDelegate: onDrag got a " + dragEvent.getType());
        return false;
	}
	
    function onBack() {
		//DEBUG*/ logMessage("ChargeDelegate: onBack invoking main view");
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_handler.invoke(0);
        return true;
    }

    function onTap(click) {
		//DEBUG*/ logMessage("ChargeDelegate: onTap calling onMenu");
		onMenu();
        return true;
    }
}
