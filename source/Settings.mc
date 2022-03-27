using Toybox.Application as Application;
using Toybox.System as System;

//! Settings utility.
(:background)
module Settings {

    //! Store access token
    function setToken(token) {
        Application.getApp().setProperty("token", token);
    }

    //! Get access token
    function getToken() {
        var value = Application.getApp().getProperty("token");
        return value;
    }

    //! Store refresh token
    function setRefreshToken(token, expires_in, created_at) {
        Application.getApp().setProperty(REFRESH_TOKEN, token);
        Application.getApp().setProperty("TokenExpiresIn", expires_in);
        Application.getApp().setProperty("TokenCreatedAt", created_at);
    }

    //! Get auth token
    function getRefreshToken() {
        var value = Application.getApp().getProperty(REFRESH_TOKEN);
        return value;
    }

    // Settings name, see resources/settings/settings.xml
    const REFRESH_TOKEN = "refreshToken";
}
