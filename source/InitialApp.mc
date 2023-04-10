using Toybox.Application as App;
using Toybox.Background;

(:background)
class TeslaLink extends App.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getServiceDelegate(){
        return [ new MyServiceDelegate() ];
    }

    function onBackgroundData(data) {
    }  

(:glance)
    function getGlanceView() {
        return [ new GlanceView() ];
    }

    function getInitialView() {
    }
}
