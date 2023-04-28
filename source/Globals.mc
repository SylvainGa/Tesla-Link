using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;

(:background)
function validateNumber(value) {
	if (value == null || value instanceof Lang.Boolean) {
		return 0;
	}

	try {
		value = value.toNumber();
		if (value == null) {
			value = 0;
		}
	}
	catch (e) {
		value = 0;
	}
	return value;
}

function validateFloat(value) {
	if (value == null || value instanceof Lang.Boolean) {
		return 0.0;
	}

	try {
		value = value.toFloat();
		if (value == null) {
			value = 0.0;
		}
	}
	catch (e) {
		value = 0.0;
	}
	return value;
}

(:background)
function validateString(value) {
	if (value == null || value instanceof Lang.Boolean) {
		return "";
	}

	try {
		value = value.toString();
		if (value == null) {
			value = "";
		}
	}
	catch (e) {
		value = "";
	}
	return value;
}

(:background)
function validateBoolean(value) {
	if (value != null && value instanceof Lang.Boolean) {
		try {
			value = (value == true);
		}
		catch (e) {
			value = false;
		}
		return value;
	}
	else {
		return false;
	}
}
//DEBUG
(:debug, :background)
function logMessage(message) {
	var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
	var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
	System.println(dateStr + " : " + message);
}

(:release, :background)
function logMessage(message) {
}
(:release, :background)
function logMessageAndData(message, data) {
}

(:debug, :background)
function logMessageAndData(message, data) {
	if (data == null) {
		logMessage(message + "No DATA");
	}
	else {
		var token = data["token"];
		if (token != null) {
			token = token.substring(0, 10);
		}
		var refreshToken = data["refreshToken"];
		if (refreshToken != null) {
			refreshToken = refreshToken.substring(0, 10);
		}
		// var TokenExpiresIn = data["TokenExpiresIn"];
		// var TokenCreatedAt = data["TokenCreatedAt"];
		var responseCode = data["responseCode"];
		var status = data["status"];
		var timestamp = data["timestamp"];
		var vehicleAwake = data["vehicleAwake"];

		logMessage(message + " responseCode=" + responseCode + " status=" + status + " timestamp=" + timestamp + " token=" + token + " refreshToken=" + refreshToken + " vehicleAwake=" + vehicleAwake);
	}
}
//DEBUG*/

function to_array(string, splitter) {
	var array = new [30]; //Use maximum expected length
	var index = 0;
	var location;

	do {
		location = string.find(splitter);
		if (location != null) {
			array[index] = string.substring(0, location);
			string = string.substring(location + 1, string.length());
			index++;
		}
	} while (location != null);

	array[index] = string;

	var result = new [index + 1];
	for (var i = 0; i <= index; i++) {
		result[i] = array[i];
	}
	return result;
}
