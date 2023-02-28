# Tesla-Link Widget

Tesla Link Widget is a Garmin ConnectIQ widget for Tesla vehicle control.

**If you enjoy this maintained version of the app, you can support my work with a small donation:**
https://bit.ly/sylvainga

Based on the work of srwalter and paulobrien and posted with their blessing. Link to their github is at the end of this file.
My work includes enhancing the touch display interface, increasing the reliability of the communication, adding many features to the Option menu, adding the selection/order of the Option menu and adding data screens. I try to keep the application up to date with new features added by Tesla once they become available to the community.

<p align="center">
  <img src="https://github.com/SylvainGa/Tesla-Link/blob/develop/blob/venu2.png?raw=true" />
</p>

**Keep in mind the Tesla API that the community is using is unsupported by Tesla and can be revoked/modified by them as they see fit.**

## Installation

Install the widget from the [Connect IQ Store](https://apps.garmin.com/en-US/apps/3ca805c7-b4e6-469e-a3fc-7a5c707fca54).

## Description

Tesla Link Widget allows you to quickly see and control your Tesla vehicle.

It is designed to load very fast and work reliably.

Features include:

- displaying battery charge (as a number and graphically)
- control climate and remotely operate the door locks, frunk, trunk, charge port from the main screen and a plethora of other commands for the Menu option.
- support for temperatures in Celsius and Fahrenheit (follows your watch settings)
- support for miles or kilometers for distance (follows your watch settings)
- text and graphics display modes to suit your device
- touch and button based controls to suit your device
- battery status in glance view with background service on supported devices
- Subview for the charge, vehicle and climate data to see additionnal data not provided by the Tesla App

Please raise an issue if anything doesn't work correctly, or if you use an unsupported Garmin device, via the [Github issues page](https://github.com/SylvainGa/Tesla-Link/issues).

If you like the widget, please consider [leaving a positive review](https://apps.garmin.com/en-US/apps/3ca805c7-b4e6-469e-a3fc-7a5c707fca54).

## Changelog since forking from srwalter:

V7.5.0  Added the following
- Optimized the Glance/background code to only load on glance enabled watch, giving some breathing space for older devices
- Like before, glance data is updated at 5 minutes intervals when in Glance mode, but when the main view is active, Glance data is kept up to date
- Optimized the drawing of the climate symbol to accommodate more options which are independent of one another. The following can appear whether the cabin climate is off, cooling or heating
  - The 'waves' on the upper right blade means battery is preconditioning
  - The 'waves' on the upper left blade means defrost was automatically turned on
  - The 'waves' on the lower left blade means the rear defrost is on
  - The 'waves' on the lower right blade means defrost was manually activated
- Removed the request to press a key to launch the app on non touch, non Glance devices. One less step before interacting with the car!

Regarding Glance, keep in mind that when the watch boot, it will take some time for the Glance code to authenticate to the car (cannot do multiple calls per iteration of the Glance code) and retrieve its first set of data. One way to circumvent this is to launch the app, which will update the data right away. Going back to the Glance mode will reactivate its 5 minutes view refresh (limitation imposed by Garmin) but with the most recent data.

V7.4.2 Fixed the repeated prompt to login and new way of detecting if heating or cooling

V7.4.1 Fixed corruption in the Swedish language file

V7.4.0 Added the following items
- Remote Boombox under Menu (you need to move it into one of the available 16 slots from your phone using the widget parameters)
- Glance fetches less data so hopefully it will help for watches with less memory available for glance
- Glance will ask you to launch the widget if it it's authenticated
- The Trunk, Frunck, Charge port and Vent command will show the current operation to be performed, like Open or Close
- The Charge port command now has some logic. If it's closed, the option will be to open it. If it's open without a cable inserted, the option will be to close it. If it's charging, the option will be to stop charging. If it's plugged but not charging, the option will be to unlock it.
- Sweden language has been updated. A big thank you to Anders Zimdahl for the updated translation.

V7.3.6.Choosing a different vehicle from the list should now work. If you're at the confirmation for waking, choosing 'No' will bring you to the selection of a vehicle.

V7.3.5 Added support for Forerunner 245 Music, all version of the Forerunner 255 and all version of the Venu SQ 2.

V7.3.4 Oops, Homelink was missing the 406 fix.

V7.3.3 Error 406 / -2 should be fixed now (at least, until Tesla modifies the communication protocol again).

V7.3.2 Replaced the saved variable for Metric/Imperial to query the watch for the current setting. Bug fix for the 406 error.

V7.3.1 Addition of the Forerunner 955 / Solar

V7.3.0 Adds German translation. Thank you Sebastian Schubert for the translation.
- If someone wants to help by translating it in their language, just reach out and I'll see what can be done.

V7.2.0 Added support for Teslas in China. These needs different Tesla servers domain name than the rest of the world. These can be changed through the phone app.
- The default API and AUTH servers are owner-api.teslamotors.com and auth.tesla.com respectively.
- For China, they are owner-api.vn.cloud.tesla.cn and auth.tesla.cn

V7.1.3 Added a new application setting 'Use Touch'. It's meant for watches that has both buttons and a touchscreen. It gives the users the choice of one over the other.

V7.1.2 Fixed for button operated watches that cycles between widgets instead of performing the actions of the left side buttons. You'll unfortunately have to do an extra step to get the main screen. Sorry, it's a limitation of Garmin's API

V7.1.1 Minor corrections
- Replaced Options for Menu.
- Fixed glance displaying always in miles. Now follows what the watch is set to.
- Fixed Climate view temp strings too long
- Fixed charge view showing estimated battery range instead of battery range

V7.1.0 Added Homelink under Menu. New method to detect if the climate is heating or cooling.

V7.0.1 Added support for D2 Air X10, D2 Mach 1 and Venu2 Plus

V7.0.0 Here's what's my version brings new (first release since it was forked from srwalter):
- Enhanced the touch display interface by adding touch points for vehicle selection, set sentry, set scheduled departure, set charge amp or limit and set inside temperature,
- Increased the reliability of the communication
- Added the following features to the Option menu
  - Activate Defrost
  - Activate Seat Heat
  - Activate Steering Wheel Heat
  - Set Charging Limit
  - Set Charging Amps
  - Set Inside Temperature
  - Set Schedule Departure
  - Set Sentry
  - Vent windows
- Added the selection/order of the Option menu through the phone's app parameters
- Added Charges, Climate and Drive data screens to display many stats about the car
- Added a popup menu to the trunk menu to select either Frunk, Trunk, Charge port or Vent
- Added support for Hansshow Powered Frunk.
- Ask to wake the car when launching and the car is asleep to prevent inadvertently waking the car.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Many thanks to those who have contributed to the development of the Quick Tesla version, including [srwalter](https://github.com/srwalter), [paulobrien](https://github.com/paulobrien), [danielsiwiec](https://github.com/danielsiwiec), [hobbe](https://github.com/hobbe) and [Artaud](https://github.com/Artaud)! 

## License
[MIT](https://choosealicense.com/licenses/mit/)

## Other Licenses
Some devices use [the Montserrat font by Julieta Ulanovsk](https://github.com/JulietaUla/Montserrat). Please see the included file 'montserrat-ofl.txt' for full licensing information.
