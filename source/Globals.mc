using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;

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

(:debug, :background)
function logMessage(message) {
	var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
	var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
	System.println(dateStr + " : " + message);
}

(:release, :background)
function logMessage(message) {
}


(:debug, :background)
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

