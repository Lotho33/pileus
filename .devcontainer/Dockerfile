FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip \
    build-essential clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libglu1-mesa \
    libasound2-dev libmpv-dev libasound2-plugins \
    libgl1-mesa-dri mesa-vulkan-drivers \
    libegl-mesa0 libglx-mesa0 libgbm1 libgl1 libegl1 libgles2 \
    potrace \
    && rm -rf /var/lib/apt/lists/*

# There's no real ALSA card in this container (sound goes out through the
# mounted PulseAudio socket, see devcontainer.json's PULSE_SERVER/-v flags)
# — without this, anything that probes ALSA's "default" device directly
# (not everything does; media_kit's own audio path already goes through
# Pulse and works regardless) fails with "cannot find card '0'" /
# "Invalid CTL default" noise on every launch. Point ALSA's default at the
# pulse plugin (from libasound2-plugins above) instead of a hardware card.
RUN printf 'pcm.!default {\n  type pulse\n}\nctl.!default {\n  type pulse\n}\n' > /etc/asound.conf

RUN git clone -b stable --depth 1 https://github.com/flutter/flutter.git /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"
ENV FLUTTER_ROOT="/opt/flutter"

RUN git config --global --add safe.directory /opt/flutter \
    && flutter config --no-analytics

RUN apt-get update && apt-get install -y --no-install-recommends \
    openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
ENV ANDROID_HOME="/opt/android-sdk"
ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV PATH="${PATH}:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/cmdline-tools/latest/bin"

# Android cmdline-tools + platform-tools (this is where `adb` actually comes
# from) + the exact platform/build-tools android/app/build.gradle.kts
# targets (compileSdk 36) — installed at image build time so a real-device
# `flutter run -d <id>` doesn't hit a slow first-run SDK download, and so
# `adb`/`flutter devices` work at all. Note devcontainer.json's
# ANDROID_ADB_SERVER_ADDRESS/PORT (127.0.0.1:5037): with --network=host that
# points this container's adb *client* at an adb *server* running on the
# host, not one started in here — pair/connect the TV with `adb` on the
# host (USB or `adb connect <tv-ip>:5555` for wireless debugging) and this
# container's tooling sees it through that shared server automatically.
# cmdline-tools insists on unpacking into its own "cmdline-tools/latest"
# subdirectory, not directly into $ANDROID_HOME — hence the mv below.
RUN mkdir -p "${ANDROID_HOME}/cmdline-tools" \
    && curl -fsSL -o /tmp/cmdline-tools.zip \
       https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    && unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_HOME}/cmdline-tools" \
    && mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest" \
    && rm /tmp/cmdline-tools.zip \
    && yes | "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null \
    && "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" \
       "platform-tools" "platforms;android-36" "build-tools;36.0.0" \
    && flutter config --android-sdk "${ANDROID_HOME}"

# GTK's native Wayland path crashes `flutter run -d linux` on the host this
# devcontainer runs on (FlutterEngineRemoveView kInvalidArguments on
# shutdown, on top of an unrelated amdgpu/Mesa Wayland GPU lockup) — X11/
# XWayland is what actually runs stably here. Set as an image-level ENV
# (not just devcontainer.json's remoteEnv) so it applies to every shell in
# the container, including a plain `docker exec`, not only sessions the Dev
# Containers extension attaches to.
ENV GDK_BACKEND="x11"
