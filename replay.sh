#!/bin/bash
set -eu

## Script to run your Android device against WebPageReplay
#$ ANDROID=false ./replay.sh --config desktop.json https://www.sitespeed.io
#$ ANDROID=true DEVICE_SERIAL=ZY322GXR4B ./replay.sh --config android.json https://www.sitespeed.io

## We have WebPageReplay binaries for Mac and Linux
case "$OSTYPE" in
  darwin*)  OS="mac" ;; 
  linux*)   OS="linux" ;;
  *)        OS="unsupported" ;;
esac

if [ "$OS" == "unsupported" ]; then
    echo "Only Mac/Linux is supported at the moment"
    exit 1
fi

# You need to install sitespeed.io globally: npm install sitespeed.io -g
BROWSERTIME=sitespeed.io-wpr
SITESPEEDIO=sitespeed.io

# WebPageReplay setup
WPR_BINARY=./replay/"$OS"/wpr
WPR_CERT_FILE=./replay/wpr_cert.pem
WPR_KEY_FILE=./replay/wpr_key.pem
WPR_SCRIPTS=./replay/deterministic.js
WPR_HTTP_PORT=8085
WPR_HTTPS_PORT=8086
WPR_ARCHIVE=./archive.wprgo
WPR_RECORD_LOG=./wpr-record.log
WPR_REPLAY_LOG=./wpr-replay.log

# If you want to run the tests on a Android phone, add 
RUN_ON_ANDROID=${ANDROID:-false}

# Special setup when yoy run on an Android devic
if [ "$RUN_ON_ANDROID" = true ] 
then 
    FIRST_DEVICE=$(adb devices | grep -v "List" | awk 'NR==1{print $1}')
    FIRST_DEVICE=${FIRST_DEVICE:-'no_device'}
    if [ "$FIRST_DEVICE" == "no_device" ]
    then
        echo "Could not find a phone connected to the computer. Try with adb devices"
        exit 1
    fi

    DEVICE_SERIAL=${DEVICE_SERIAL:-$FIRST_DEVICE}
    if [ "$DEVICE_SERIAL" == "$FIRST_DEVICE" ]
    then
        echo "Use DEVICE_SERIAL to choose which phone to use"
    fi

    # Reverse the traffic for the android device back to the computer
    adb -s "$DEVICE_SERIAL" reverse tcp:"$WPR_HTTP_PORT" tcp:"$WPR_HTTP_PORT"
    adb -s "$DEVICE_SERIAL" reverse tcp:"$WPR_HTTPS_PORT" tcp:"$WPR_HTTPS_PORT"

    # Make sure to kill all subprocesses in exit
    trap "exit" INT TERM
    trap "kill 0; adb -s "$DEVICE_SERIAL" reverse --remove-all" EXIT
else
    trap "exit" INT TERM
    trap "kill 0" EXIT
fi

# Parameters used to start WebPageReplay
WPR_PARAMS="--http_port $WPR_HTTP_PORT --https_port $WPR_HTTPS_PORT --https_cert_file $WPR_CERT_FILE --https_key_file $WPR_KEY_FILE --inject_scripts $WPR_SCRIPTS $WPR_ARCHIVE"

# First step is recording your page
declare -i RESULT=0
echo "Start WebPageReplay Record logging to $WPR_RECORD_LOG"
$WPR_BINARY record $WPR_PARAMS > "$WPR_RECORD_LOG" 2>&1 &
RECORD_PID=$!
RESULT+=$?
sleep 3
"$BROWSERTIME" "$@"
RESULT+=$?

kill -2 $RECORD_PID
RESULT+=$?
wait $RECORD_PID
echo 'Stopped WebPageReplay record'

# If everything worked fine, replay the page
if [ $RESULT -eq 0 ]
then
    echo 'Start WebPageReplay Replay'
    "$WPR_BINARY" replay $WPR_PARAMS > "$WPR_REPLAY_LOG" 2>&1 &
    REPLAY_PID=$!
    if [ $? -eq 0 ]
    then
        echo 'Pre warm the Replay server with one access'
        sleep 10
        "$BROWSERTIME" "$@"
        sleep 10
        echo 'Run the test against WebPageReplay'
        "$SITESPEEDIO" "$@" &
        SITESPEEDIO_PID=$!
        wait $SITESPEEDIO_PID
    else
        echo "Replay server didn't start correctly, check the log $WPR_REPLAY_LOG" >&2
        exit 1
    fi
else
    echo "Recording or accessing the URL failed, will not replay" >&2
    exit 1
fi