# todo: look at https://github.com/budtmo/docker-android but do we trust them
FROM ubuntu:latest

RUN apt-get update
RUN apt-get install -qy unzip
# sdkmanager requires 21 jre, we build on old jdk because we target old droid. (not sure latter is necessary)
RUN apt-get install -qy openjdk-11-jdk-headless openjdk-21-jre-headless

# https://developer.android.com/studio/install#64bit-libs
# RUN apt-get install -qy libc6:i386 libncurses5:i386 libstdc++6:i386 lib32z1 libbz2-1.0:i386

WORKDIR /droid
# wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip .
ARG CLI_TOOLS=commandlinetools-linux-11076708_latest.zip
COPY ${CLI_TOOLS} .
RUN unzip $CLI_TOOLS

ENV ANDROID_HOME /droid
ENV ANDROID_SDK_ROOT /droid
ENV PATH ${PATH}:/droid/cmdline-tools/bin

RUN yes | sdkmanager --sdk_root=$(realpath .) --install "platforms;android-28" "build-tools;26.0.3" "ndk;26.2.11394342"

RUN apt-get update
RUN apt-get install -qy golang-1.21-go
ENV PATH ${PATH}:/usr/lib/go-1.21/bin:/root/go/bin

RUN go install golang.org/x/mobile/cmd/gomobile@latest
RUN gomobile init

RUN ANDROID_NDK=/droid/ndk/26.2.11394342 KEEP_TFLITE_SRC=1 etc/android/build-tflite.sh 
# todo: now set CGO_CFLAGS to find tensorflow headers, and also add 'keep' setting to build-tflite

# todo move up
# deps for tflite build
RUN apt install make curl patch cmake git python3

# for x264
RUN apt install nasm

CGO_CFLAGS="-I /root/tensorflow/tensorflow-2.12.0" \
    PLATFORM_NDK_ROOT=/droid/ndk/26.2.11394342/ \
    NDK_ROOT=/droid/ndk/26.2.11394342/ \
    make droid-rdk.aar
