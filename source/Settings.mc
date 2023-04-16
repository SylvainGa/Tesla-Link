using Toybox.Application as Application;
using Toybox.System as System;
using Toybox.Application.Storage;
using Toybox.Application.Properties;

//! Settings utility.
module Settings {

    //! Store access token
    function setToken(token) {
        Storage.setValue("token", token);
    }

    //! Get access token
    function getToken() {
        var value = Storage.getValue("token");
        return value;
    }

    //! Store refresh token
    function setRefreshToken(token, expires_in, created_at) {
        Properties.setValue(REFRESH_TOKEN, token);
        Storage.setValue("TokenExpiresIn", expires_in);
        Storage.setValue("TokenCreatedAt", created_at);
    }

    //! Get auth token
    function getRefreshToken() {
        var value = Properties.getValue(REFRESH_TOKEN);
        return value;
    }

    // Settings name, see resources/settings/settings.xml
    const REFRESH_TOKEN = "refreshToken";
}
