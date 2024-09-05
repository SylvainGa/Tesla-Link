# Tesla-Link Widget

Tesla Link Widget is a Garmin ConnectIQ widget for Tesla vehicle control.

**If you enjoy this maintained version of the app, you can support my work with a small donation:**
https://bit.ly/sylvainga

Based on the work of srwalter and paulobrien and posted with their blessing. Link to their github is at the end of this file.
My work includes enhancing the touch display interface, increasing the reliability of the communication, adding many features to the Option menu, adding the selection/order of the Option menu and adding data screens. I try to keep the application up to date with new features added by Tesla once they become available to the community.

<p align="center">
  <img src="https://github.com/SylvainGa/Tesla-Link/blob/master/blob/venu2.png?raw=true" />
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

If you want to have the widget translated to your language, contact me through email or github.

You can find more details on how to use the application by reading the [Operating Guide] (https://github.com/SylvainGa/Tesla-Link/blob/V9.0.0/Tesla-Link-OperatingGuide.pdf).

## Changelog since forking from srwalter:
V9.1.2 Added the following:
- Compiled with CIQ 7.3.0
- Added Enduro3 and new Fenix8 watches, including the Fenix E
- Small code optimisation for Telsa's complications

V9.1.1 Added the following:
- Added an indication that the vehicle is being awaken first when a command is sent while the vehicle is sleeping with Tessie Cache enabled.
- Similar to the Dog Mode watch view, the dog paw print icon color in the main view will change red if the temperature gets too high, the SoC gets below 25% or no data has been received from the vehicle in the last 2 minutes.
- Compiler hack to have the Enduro 2 showing as a supported device again. 

V9.1.0
- Climate icon on the main screen will display padlock in the center of the climate blades if keep mode is activated, a small tent for Camp mode and a dog paw print for Dog mode.
- New feature: Dog mode watch. Available only for watches that can run the app from the Activity wheel. Do NOT run the app from the Glance wheel since that wheel terminates the app after just a few minutes, unlike the Activity wheel which will leave the app running for as long as the user terminates it or the watch runs out of battery. This mode will change the display to just the time, the SoC, the inside temperature and how many seconds since the watch last received valid data from the car. If the SoC gets below 20%, the temperature gets above 25C (77F) or no data has been received for 2 minutes, for as long as these conditions are met, the watch will vibrate and emit a sound (whatever attention your watch has) every second. Use at your own risk. I can't be held responsible if the app fails to work as advertised and the climate fails in the car.

V9.0.0 Is the merging of the Legacy and Tessie app (so a new major version) in one app with some new additions. Beside this version to ring the bell that a new version is here, the Legacy app is now end of life. Head over to https://apps.garmin.com/apps/3ca805c7-b4e6-469e-a3fc-7a5c707fca54 to keep your app up to date in the future
- A drop down in the config is used to choose between Tesla, Tessie and Teslemetry as proxy (Teslemetry is new). You don't need to enter the URL anymore as they default to their optimal value. You can still make them point to something else if you prefer. I higly suggest you see the documentation on how to use.
- You can toggle the locking of the vehicle, lock it or unlock it when launched from complications (ie, a watch face like Crystal Tesla)
- Media volume adjustments as well as Play/Pause is now working in the Media panel! Still waiting for Tesla to activate the other commands :-(
- Reverted CIQ to 6.4.2 since it messed up sending Complications to the Crystal-Tesla watchface with CIQ 7.x. No features were lost with the downgrade.

V8.1.0
- Compiled with CIQ 7.1.1 to add the Forerunner 165 and 165m. 
- Fixed a crash in the preconditioning code and discrepencies between the SoC when running as a glance

V8.0.0 Replaced Tesla's Owners unsupported API for Tessie's Dev API. See documentation on how to use

V7.18.0 Fixed the 412 error message thanks to a post I saw in the teslamate GitHub

V7.17.1 Added the Descent Mk3 43mm and 51mm watches

V7.17.0 Added the following
- Option to hide the vehicle name to show more info in Glance view
- Fixed an issue with some country that do not allow the vehicle to be waken up by the API (require sending an SMS to the vehicle to wake it up). Now the vehicle will display to manually wake the vehicle. It's best to disable "Ask to wake vehicle when launched" in such a case. It's detected by receiving an error 403 (Forbidden) when the app tries to wake the vehicle.

V7.16.0 Add "Ask to wake vehicle when launched" for those that want the vehicle to be awaken as the app launch instead of asking to wake. Defaults to True

V7.15.1 Added the following
- Support for the VivoActive 5
- Long vehicle name displays over the SoC bar

V7.15.0 Added the following
- Separated the launch from complications from the upper left quadrant and added Turning on climate as an option when launched from a watch face (like Crystal Tesla) that supports launching Complications
- Venu3 and Venu3S as supported devices

V7.14.1 Fixed a crash in reading media control reported through ERA. Apparently, not all car have "media_info" available all the time. So need to accommodate for that.
- Made some changes to the function receiving the vehicle data to harden it against bad data and added a timeout in case we never receive our requested data back.

V7.14.0 Added the following
- Media controls through new Menu option 25. Usefull when the phone is in the car and you're not :-)
    For touch watches, you can skip back/forward, increase/decrease volume and toggle Play/Pause

    For button operated watch, you toggle between Skip control and Volume control by pressing Menu. You decrease volume/skip back with Page Down, increase volume/skip forward with Select and toggle Play/Pause with Page Up.

    Back button/gesture takes you out of the Media Control view

    The title of the song currently playing is shown at the top of the screen. Because of the shear size of data returned by the vehicle, it can be several seconds before a title change appears.

    If your watch supports Vibrate, once the command is sent to the vehicle, the watch will vibrate. It takes a few seconds for the command to be sent so wait, otherwise a red -101 will show up on the bottom on the screen saying the Bluetooth queue is full. 

    If an error is received, it will show in red on the bottom of the screen

- Glance and Charge sub view can dislay the rated, estimated and ideal range. Settable in Settings
- Hardened the reading of the Settings value.

V7.13.6 Fixed the following
- Vehicle name was no longer being displayed on the main view because Tesla modified the data returned by the API
- Fixed a crash reported by the ERA regarding too many timers.

V7.13.5 Added the following by requests
- Support for Epix Pro Gen2, Fenix7 Pro and Approach S70 watches
- If asked to press Start or Touch the screen to connect, don't ask to wakeup if asleep since we already did the conscious effort to connect by pressing Start or touching the screen.
- New setting: "Warn if the phone is not connect to the watch?". If set and the phone is too far from the watch, during a background process (every five minutes) and if the watch has at least 64 KB of background memory, it will popup over the watch face "Forgot phone?". If you say 'Yes', it launches the Tesla-Link app (which will simply display "Phone connection required"). If you say "No", it will return to the watch face. It's a "hack" to let you know that you might have forgotten your phone in your vehicle.

It also fxed the following
- French translation updated
- Montserrat font was missing the 'É' character.
- Potential crash if asked to vibrate but the watch doesn't support that feature

V7.13.4 Fixed the touch devices that got broken in V7.13.3.

V7.13.3 Fixed the following
- Fixed for Up/Down buttons not working when not launched from Glance on button only watches
- Fixed a crash when there is a collision in Complication Index between CIQ apps when updating Complication

V7.13.2 Fixed another bug when sending Complication to watch face other than Crystal-Tesla, reported through ERA

V7.13.1 Fixed a bug in sending Complication reported through ERA

V7.13.0 Added the following
- A new Propery called "Send enhanced Complications to Crystal-Tesla". If your device supports Complication and 64 KB or more of Background Memory, it will send its data to the Crystal-Tesla watch face so this one doesn't have to communicate with Tesla's server (no token required!).

V7.12.1 Added the following
- When launched from a watch face that supports launching Complications, vibrates the watch for 0.5 seconds to acknowledge the launch
- Fixed mix up of unit conversion in Glance

V7.12.0 Added the following
- Now supports Complications! Through complications, the battery SoC is sent to other apps and watch faces that also supports complications. If the app was launched from a Complication (either another app or from a watch face), the action selected for the holding of the upper left quadrant will be performed. If the car is sleeping, it will ask to wake it up first. The watch face that I maintain, Crystal-Tesla has been modified to support launch from Complication. It will still build its own Tesla-Info, which is more than just the battery SoC.
- Hardened the main view of data to be displayed in case some data received by the car is invalid or not of the expected type. 
- Fixes the -400 error after performing a command

V7.11.8 
- Fixed more crashes reported through Error Reporting Application (ERA) 
- Fixed error 401 not using the new token in glance
- Another (transparent) overhaul of the Glance code to hopefully fix the crashes on older watches. Let me know if it's unstable on your watch.

V7.11.7 Fixed more crashes reported through Error Reporting Application (ERA) and made more robust the validation of data sent by the vehicle. I wish Tesla would standardized the data it sends across all models/features/years.

V7.11.6 Fixed more crashes reported through Error Reporting Application (ERA) and optimized/made more robust the Glance, Data View and error reporting code.

V7.11.5 Fixed three crashes reported through Error Reporting Application (ERA)

V7.11.4 Fixed the following
- A crash when systems errors are received instead of data in the Glance code
- Fixed S On/Off P On/Off not showing 'On', just 'Off' in Glance
- Optimized the Glance scrolling code and made the scrolling speed more consistent across watches resolution

V7.11.3 Added the following *** Changes to the Settings means you'll need to reconfigure the app and reenter a refresh token if you use one.
- New algorithm for Glance text vertical placement
- Option in Settings to choose a smaller font for Glance text. Could allow a third line of text on some watch
- Option in Settings to allow for scrolling to continue until the text would clear the top or bottom of the screen. Useful if this App default position in Glance is at the top or bottom
- Brought the three lines of Glance code to the 32KB of Background memory watch. On many, if you select the small Glance font, it's enough to show that third line.

V7.11.2 Fixed the following
- Removed the requirement for vehicle scrolling to scroll the glance data
- Possible refresh token corruption while in Glance fixed

V7.11.1 Fixed a crash when only two lines to display in Glance under certain conditions

V7.11.0 Added the following
- Added new devices D2 Delta, D2 Delta PX, D2 Delta S, MARQ (Gen 2) Adventure, Athlete, Aviator, Captain and Golfer.
- New Glance code optimized for devices with just 32 KB of background memory. Although I have only ran it through the simulator (having no such device myself), it ran well. Keep in mind that this 32 KB is for all the CIQ apps with Glance activated, so you might be limited just this CIQ app in Glance mode. The main culprit is the huge 6 KB of data returned by the vehicle when awake.
- Glance mode always shows the latest charge and range, even when asleep.
- Awoken vehicle will show inside temperature, sentry (S) or preconditioning (P) in Glance view if Glance has three lines of display. It will show Driving instead if vehicle is in movement.
- Glance mode will display if an error is received instead of data on devices with three lines of display. Error 408 will only show up if received while the vehicle is awake. Error 401 will ask to launch the widget since our token is invalid and we were unable to refresh it.
- While in Glance, once the access token expires, devices with 64KB of background memory it will try to get a new one if the refresh token is valid.
- Glance will autoscroll if there is too much text to display. Unfortunately, it's not possible to adjust the size based on the position on screen. It's always the size in the middle.
- Brought back the version info to the Parameters screen using a different method that always shows the current version and not just the version when first installed.
- Changed the way the Menu options are selected and ordered. It's no longer 24 lists with 24 commands each, but a single comma separated value type field which by default has 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24 in it. See the Operating Guide (link in the Connect IQ page for the app) for a description of each. There are two main reasons for the change. First is the 24 lists took too much memory, which impacted functionality in Glance mode for watches with just 32 KB of backgPround memory. Second is whenever an update to the app is made and the parameters are reset, you simply need to copy/paste the values back in the field to restore to your liking instead of manually reselecting every list.
- Replaced all the now invalid since CIQ 4.2.0 getProperties/setProperties for their getValue/setValue equivalent. Hopefully this was the last issue with constant asking to login.

V7.10.2 Fixed the following
- Vehicle wouldn't go to sleep in Glance mode.

V7.10.1 Added the following
- Filled the Sentry circle with a grey dot when Sentry is off
- Removed the version info from the Parameters screen

V7.10.0 Added the following
- The Sentry icon has been updated from an eye to Tesla's red dot in a grey circle, similar to what you see in the app. The circle is permanent on screen and will be filled by a red dot when Sentry is on.
- An option named "Enable vehicle name scrolling" was added in the parameters to allow long vehicle name to scroll on screen instead of being clipped
- Rectangular watch with different width/lenght resolution was modified to put the name on top of the display, giving more room
- Many watch resolution formats were tweaked so everything is more evenly spaced on screen. I only have a Venue and simulate the other watches. If the appearance is odd on yours, send me a picture through email and I'll adjust.
- Version in the app parameters on the phone should display the correct version now
- Fixed an issue when the Internet is lost while trying to authenticate
- onHold will no longer vibrate it its action is 'Disabled'

V7.9.1 Some vehicles use 'P' for park in shift_state while others use a 'null'. Why make it simple when you can make it complicated :-/ Broke the upper left quadrant if it was 'P'. Now fixed.

V7.9.0 Added the following (beside the first four items, the others are more technical than anything else)
- The upper left quadrant icon has been modified to be like the pop up menu icon, except arrows will point to what action is to be performed and the status of the frunk, trunk, port and windows will be shown. Same for when the vehicle is in movement. Its icon will be modified accordingly to represent being in movement.
- The view defaults to the image view for all watches now, not just for touch screen ones. The text view is now deprecated as it's missing a lot of the visual cues that the image view is showing.
- The 'Back' icon for button operated watches has been updated
- Open Port menu item will expand to two menu items when the cable is locked but not charging, Start Charging and Unlock port.
- A tentative fix has been implemented for Glance aware watches that kept asking to login. A big thanks to Martin Smeaton for working with a debug version of the app to help me fix this issue. Hopefully the fix will work just as well on the release version of the app.
- Fixed an am/pm error when setting departure time
- The watch will try and delay sending a command until its last data poll is successful. A W 'tag' was added to the spinner symbols. This tag is added when at least a command is in the buffer queue. If it stays there for a few seconds, it means the watch is having issues talking to the vehicle.
- Added ? and ¿ as spinner symbols. These two indicate that an error was received by the watch instead of valid data.
- A '408' error counter is shown beside the number of seconds waiting when requesting data. That 408 error means Tesla's servers cannot talk to the car, either it doesn't have a good cellular/wifi coverage or it's asleep. Once it wakes up or coverage is better, the 408 errors stops. This is just to give a visual representation of what's going on and why the wait. Long pause between increments of this counter means Tesla's servers are taking a long time to respond. This disappears as soon as valid data is finally received.
- The upper left quadrant menu and the Option menu have been modified to use the Menu2 menu view instead of the old Menu view. This means that unlike Menu, Menu2 isn't limited to 16 items, so the 24 items can be listed.
- The version bump however, is hopefully transparent but is a major revamp of the code that handles the vehicle states and actions. Both events used to be in the same humongous routine that three timers would call for different reasons and codes needed to be added to prevent one timer from interfering with another. Now it only has one timer and a call queue with priorities handling the dispatchind of fetching vehicle state and performing actions. The use of discrete variables to flag actions has been replaced by a FIFO queue that can handle more than one command at a time and in the order they were given (currently used when setting seat's temperature for more than one seat at a time).
Also new to this version is an operating guide in PDF format. This should hopefully answer most questions you have about the features and operation of this app. You can find that guide here https://github.com/SylvainGa/Tesla-Link/blob/master/Tesla-Link%20-%20Operating%20Guide.pdf

V7.8.1 Added the following
- Fixed an issue with the screen blanking at start
- Fixed a rare crash that could happen if Bluetooth is lost while we're waiting to authenticate with Tesla's servers
- Made the waiting for data at start a bit more chatty so you know what's going on
- Added a vibrating confirmation when a hold action is detected.

V7.8.0 Added the following two new parameters options
- Quick return to main screen - Instead of waiting to see if the state of the vehicle has changed after a command is sent, return as soon as the command was processed. This means for example if you asked to lock the doors, the display will still show until the next vehicle data refresh that the car is unlocked but it also means you can send another command sooner.
- The default option for the upper left quadrant can be set within the parameters. After an app update, you won't need to change it to your prefered option through the watch.

V7.7.0 Added the following
- Brings touch screen "Hold" function. By holding your finger pressed to one of the four quadrants of the screen, it can perform other functions. You configure these through the app parameters on your phone. The options are
    - Upper Left quadrant : Frunk, Trunk, Port, Vent or Disabled (just like the menu). These will NOT ask to confirm the action and will perform it as soon as a Hold has been detected.
    - Upper Right quadrant : Toggle defrost or Disabled
    - Lower Left quadrant : Honk or Disabled
    - Lower Right quadrant: Homelink, Remote boombox (why not) or Disabled
    Default for each quadrant is Disabled
- The 'spinner' to show when a new set of data has been received now has two type, '+ -' and '/ \'. It's basically to differentiate if enhancedTouch is active "+ -" or not "/ \".
- Default is now Enabled for enhancedTouch 
- Made the display a bit more snappy, but don't expect much. There is only so much power these little CPU have and the car sends a lot of data to be processed
- If for some reason the access to the car itself is denied (no longer yours?), it will pop up a list of cars that you have access to choose from
- If you entered a wrong password when authenticating on the phone, it should now prompt you again instead of hanging
- Fixed a potential hang when turning on the steering wheel heater

V7.6.1 Compiled with Connect IQ 4.2.1 which added support for the Forerunner 265, 265s and 965. 

V7.6.0 Added the following
- Optimized the display of text messages and added more texts to be more descriptive of what's happening while waiting for the screen to show up
- Once an item of the menu has been choosing, you're automatically brought back to the main screen
- The lower right blade of the climate icon has a new icon, a fan (so yeah, a fan within a fan). While the 'waves' indicate that defrost was manually started, the 'fan' indicate that the defogging was manually started. Although it is still impossible to activate defogging remotely unfortunately
- The Climate keeper command has been added. The available options are : Off, On, Dog mode and Camp mode.

V7.5.0 Added the following
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
