using Toybox.Background;
using Toybox.System;

(:background)
class MyServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        System.ServiceDelegate.initialize();
    }

    function onTemporalEvent() {
    }
}