using Toybox.WatchUi as Ui;

class SimpleConfirmDelegate extends Ui.ConfirmationDelegate {
    var _on_confirmYes;
    var _on_confirmNo;

    function initialize(on_confirmYes, on_confirmNo) {
        ConfirmationDelegate.initialize();

        _on_confirmYes = on_confirmYes;
        _on_confirmNo = on_confirmNo;
    }

    function onResponse(response) {
        if (_on_confirmYes != null && response == CONFIRM_YES) {
            _on_confirmYes.invoke();
        } else if (_on_confirmNo != null && response == CONFIRM_NO) {
            _on_confirmNo.invoke();
        }
    }
}
