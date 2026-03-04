/// Generate a guix.yaml config file.
String generateConfig({
  required String projectName,
  required List<String> platforms,
  String flutterVersion = '3.24.5',
  String flutterChannel = 'stable',
  String checksumX64 = '',
  String checksumArm64 = '',
  // Android SDK fields (only used when platforms contains 'android')
  String cmdlineToolsBuild = '14742923',
  String cmdlineToolsSha256 = '',
  String platformVersion = 'android-34',
  String buildToolsVersion = '34.0.0',
  String ndkVersion = '23.1.7779620',
}) {
  final buffer = StringBuffer();
  buffer.writeln('# guix.yaml: reproducible build configuration');
  buffer.writeln('# Docs: https://pub.dev/packages/guix');
  buffer.writeln();
  buffer.writeln('project:');
  buffer.writeln('  name: $projectName');
  buffer.writeln();
  buffer.writeln('flutter:');
  buffer.writeln('  version: "$flutterVersion"');
  buffer.writeln('  channel: $flutterChannel');
  buffer.writeln('  checksums:');
  buffer.writeln('    x86_64: "$checksumX64"');
  buffer.writeln('    aarch64: "$checksumArm64"');
  buffer.writeln();
  buffer.writeln('guix:');
  buffer.writeln('  channels: guix/channels.scm');

  if (platforms.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('platforms:');
  }

  if (platforms.contains('linux')) {
    buffer.writeln('  linux:');
    buffer.writeln('    manifest: guix/linux.scm');
    buffer.writeln('    env:');
    buffer.writeln('      CC: clang');
    buffer.writeln('      CXX: clang++');
    buffer.writeln('    preserve:');
    buffer.writeln('      - DISPLAY');
    buffer.writeln('      - WAYLAND_DISPLAY');
    buffer.writeln('      - XAUTHORITY');
    buffer.writeln('      - XDG_RUNTIME_DIR');
    buffer.writeln('      - XDG_SESSION_TYPE');
    buffer.writeln('      - DBUS_SESSION_BUS_ADDRESS');
    buffer.writeln('    build:');
    buffer.writeln('      command: flutter build linux --release');
    buffer.writeln('      output: build/linux/release/bundle');
  }

  if (platforms.contains('android')) {
    buffer.writeln('  android:');
    buffer.writeln('    manifest: guix/android.scm');
    buffer.writeln('    sdk:');
    buffer.writeln('      cmdline_tools_build: "$cmdlineToolsBuild"');
    buffer.writeln('      cmdline_tools_sha256: "$cmdlineToolsSha256"');
    buffer.writeln('      platform_version: $platformVersion');
    buffer.writeln('      build_tools_version: "$buildToolsVersion"');
    buffer.writeln('      ndk_version: "$ndkVersion"');
    buffer.writeln('    build:');
    buffer.writeln('      command: flutter build apk --release');
    buffer.writeln('      output: build/app/outputs/flutter-apk/app-release.apk');
  }

  return buffer.toString();
}
