using Toybox.Application as Application;
using Toybox.System as System;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

//! Settings utility.
module Settings {

    //! Store access token
    function setToken(token, expires_in, created_at) {
        Storage.setValue("token", token);
        Storage.setValue("TokenExpiresIn", expires_in);
        Storage.setValue("TokenCreatedAt", created_at);
    }

    //! Get access token
    function getToken() {
        var value = Storage.getValue("token");
        return value;
    }

    //! Store refresh token
    function setRefreshToken(token) {
        if (token == null || token.equals("")) {
            /*DEBUG*/ logMessage("Reseting the refresh token!");
        }
        Properties.setValue(REFRESH_TOKEN, token);
    }

    //! Get auth token
    function getRefreshToken() {
        var value = Properties.getValue(REFRESH_TOKEN);
        return value;
    }

    // Settings name, see resources/settings/settings.xml
    const REFRESH_TOKEN = "refreshToken";
}
