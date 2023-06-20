using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Lang;
using Toybox.Application.Storage;
using Toybox.Application.Properties;
using Toybox.Complications;

(:background)
function getBoolProperty(key, defaultValue) {
	var value;
	var exception;

	try {
		exception = false;
		value = Properties.getValue(key);
	}
	catch (e) {
		exception = true;
		value = defaultValue;
	}

	if (exception) {
		try {
			Properties.setValue(key, defaultValue);
		}
		catch (e) {
		}
	}

	return validateBoolean(value, defaultValue);
}
(:background)
function validateNumber(value, defValue) {
	if (value == null || value instanceof Lang.Boolean) {
		return defValue;
	}

	try {
		value = value.toNumber();
		if (value == null) {
			value = defValue;
		}
	}
	catch (e) {
		value = defValue;
	}
	return value;
}

function validateFloat(value, defValue) {
	if (value == null || value instanceof Lang.Boolean) {
		return defValue;
	}

	try {
		value = value.toFloat();
		if (value == null) {
			value = defValue;
		}
	}
	catch (e) {
		value = defValue;
	}
	return value;
}

(:background)
function validateString(value, defValue) {
	if (value == null || value instanceof Lang.Boolean) {
		return defValue;
	}

	try {
		value = value.toString();
		if (value == null) {
			value = defValue;
		}
	}
	catch (e) {
		value = defValue;
	}
	return value;
}

(:background)
function validateBoolean(value, defValue) {
	if (value != null && value instanceof Lang.Boolean) {
		try {
			value = (value == true);
		}
		catch (e) {
			value = defValue;
		}
		return value;
	}
	else {
		return defValue;
	}
}

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

(:background, :bkgnd32kb)
function sendComplication(data) {
}

(:background, :bkgnd64kb)
function sendComplication(data) {
	if (Toybox has :Complications) {
		var value;
		var crystalTesla;
		try {
			crystalTesla = $.validateBoolean(Properties.getValue("CrystalTesla"), false);
		}
		catch (e) {
			crystalTesla = false;
		}

		var status = Storage.getValue("status");
		if (status == null) {
			status = {};
		}

		if (crystalTesla) {
			var arrayStore = new [7];

			// Go through the data we need from 'status' and if we have one in 'data', use that one instead of the one in 'status'. Null becomes empty string
			var arrayData = ["responseCode", "battery_level", "charging_state", "inside_temp", "sentry", "preconditioning", "vehicleAwake"];
			for (var i = 0; i < arrayData.size(); i++) {
				value = data.get(arrayData[i]);
				if (value != null) {
					arrayStore[i] = value;                        
				}
				else {
					arrayStore[i] = status.get(arrayData[i]);
					if (arrayStore[i] == null) {
						arrayStore[i] = "";
					}
				}
			}

			// Build the value we'll pass to the Complication
			value = arrayStore[0] + "|" + arrayStore[1] + "|" + arrayStore[2] + "|" + arrayStore[3] + "|" + arrayStore[4] + "|" + arrayStore[5] + "|" + arrayStore[6]; 
		}
		else {
			// Other than Crystal-Tesla watchface only gets the battery level
			value = data.get("battery_level");
			if (value == null) {
				value = $.validateNumber(data.get("battery_level"), 0);
			}
		}

		/*DEBUG*/ logMessage("Sending Complication: " + value);
		// Send it to whoever is listening
		var comp = {
			:value => value,
			:shortLabel => "TESLA",
			:longLabel => "TESLA-LINK",
			:units => "%",
		};
		try {
			Complications.updateComplication(0, comp);
		}
		catch (e) {}
	}
}

(:debug, :background)
function logMessage(message) {
	var clockTime = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
	var dateStr = clockTime.hour + ":" + clockTime.min.format("%02d") + ":" + clockTime.sec.format("%02d");
	System.println(dateStr + " : " + message);
}

/*DEBUG
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
