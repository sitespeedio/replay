# Use a replay server to focus on front end perfomance

Google and Mozilla use replay proxies to make it easier to find performance regressions in Chrome/Firefox. You can also use a replay proxy to find regressions on your web page.

Read all about the setup in [the sitespeed.io WebPageReplay documentation](https://www.sitespeed.io/documentation/sitespeed.io/webpagereplay/).


Start by installing sitespeed.io and clone this repo:

1. `npm install -g sitespeed.io`
2. `git clone git@github.com:sitespeedio/replay.git`

Go into the cloned repo and then you can use our example configuration files to run the tests.

### Testing desktop

To run tests on desktop use the configuration file for desktop:


```bash
./replay.sh --config desktop.json https://www.sitespeed.io -n 5 -b firefox
```

## Testing Android
Running your tests on an Android you first need to [install ADB and prepare your phone for testing](https://www.sitespeed.io/documentation/sitespeed.io/mobile-phones/#prerequisites).

Then make sure you use the *android.json* configuration file and pass on *ANDROID=true* to the script. The script will then use the first attached Android phone it finds using *adb devices*.

```bash
ANDROID=true ./replay.sh --config android.json https://www.sitespeed.io -n 5 -b chrome
```

If you have multiple phones attached you probably want to run on a specific phone. You can choose phone by passing the DEVICE_SERIAL.

```bash
ANDROID=true DEVICE_SERIAL=ZY322GXR4B ./replay.sh --config android.json https://www.sitespeed.io -n 1 -b firefox