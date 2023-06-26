# flutterpi_tool
A tool to make developing &amp; distributing flutter apps for https://github.com/ardera/flutter-pi easier.

## Usage
```
$ flutterpi_tool --help
A tool to make development & distribution of flutter-pi apps easier.

Usage: flutterpi_tool <command> [arguments]

Global options:
-h, --help       Print this usage information.

Other options
    --verbose    Enable verbose logging.

Available commands:
  build   Builds a flutter-pi asset bundle.

Run "flutterpi_tool help <command>" for more information about a command.
```

```
$ flutterpi_tool help build
Builds a flutter-pi asset bundle.

Usage: flutterpi_tool build [arguments]
-h, --help                       Print this usage information.

Runtime mode options (Defaults to debug. At most one can be specified)
    --debug                      Build for debug mode.
    --profile                    Build for profile mode.
    --release                    Build for release mode.
    --debug-unoptimized          Build for debug mode and use unoptimized engine. (For stepping through engine code)

Target options
    --arch=<target arch>         The target architecture to build for.

          [arm] (default)        Build for 32-bit ARM. (armv7-linux-gnueabihf)
          [arm64]                Build for 64-bit ARM. (aarch64-linux-gnu)

    --cpu=<target cpu>           If specified, uses an engine tuned for the given CPU. An engine tuned for one CPU will likely not work on other CPUs.

          [generic] (default)    Don't use a tuned engine. The generic engine will work on all CPUs of the specified architecture.
          [pi3]                  Use a Raspberry Pi 3 tuned engine. (-mcpu=cortex-a53 -mtune=cortex-a53)
          [pi4]                  Use a Raspberry Pi 4 tuned engine. (-mcpu=cortex-a72+nocrypto -mtune=cortex-a72)

Run "flutterpi_tool help" to see global options.
```

## Example usage
```
$ flutter create hello_world
$ cd hello_world
$ flutterpi_tool build --arch=arm --cpu=pi4 --release
$ rsync -a --info=progress2 ./build/flutter_assets/ my-pi4:/home/pi/hello_world_app
$ ssh my-pi4 flutter-pi --release /home/pi/hello_world_app
```
