using Toybox.WatchUi as Ui;
using Toybox.Timer;
using Toybox.Time;
using Toybox.System;
using Toybox.Communications as Communications;
using Toybox.Cryptography;
using Toybox.Graphics;

class ChargeDelegate extends Ui.BehaviorDelegate {
	var _view as ChargeView;
	var _controller;
	var _handler;
	
    function initialize(view as ChargeView, controller, handler) {
        BehaviorDelegate.initialize();

    	_view = view;
		_controller = controller;
        _handler = handler;
    }

    function onPreviousPage() {
    	_view._viewOffset -= 4;
    	if (_view._viewOffset < 0) {
			_view._viewOffset = 0;
    	}
	    _view.requestUpdate();
        return true;
    }

    function onNextPage() {
    	_view._viewOffset += 4;
    	if (_view._viewOffset > 4) {
			_view._viewOffset = 4;
    	}
	    _view.requestUpdate();
        return true;
    }

	function onMenu() {
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_handler.invoke(2); // Tell MainDelegate to show next subview

	    _view.requestUpdate();
        return true;
	}
	
    function onSwipe(swipeEvent) {
    	if (swipeEvent.getDirection() == 3) {
	    	onMenu();
    	}
        return true;
	}
	
    function onBack() {
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_controller._subView = null;
		_handler.invoke(0);
        return true;
    }

    function onTap(click) {
		Ui.popView(Ui.SLIDE_IMMEDIATE);
		_handler.invoke(0);
		_controller._subView = null;
        return true;
    }
}
