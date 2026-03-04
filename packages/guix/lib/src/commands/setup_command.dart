import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/guix_config.dart';

String flutterDownloadUrl(String version, String channel, String arch) {
  final archSuffix = arch == 'arm64' ? 'arm64_$version' : version;
  return 'https://storage.googleapis.com/flutter_infra_release/releases/'
      '$channel/linux/flutter_linux_$archSuffix-$channel.tar.xz';
}

class SetupCommand extends Command<int> {
  @override
  final String name = 'setup';

  @override
  final String description = 'Fetch Flutter SDK and platform-specific SDKs.';

  SetupCommand() {
    argParser
      ..addFlag('pinned', abbr: 'p', help: 'Use pinned Guix channels for SDK fetch environment');
  }

  @override
  Future<int> run() async {
    final config = GuixConfig.load();
    final platforms = argResults!.rest;

    // Determine which platforms to set up
    final targetPlatforms = platforms.isEmpty
        ? config.platformNames
        : platforms;

    // Always fetch Flutter SDK
    print('Setting up Flutter SDK ${config.flutter.version}...');
    final exitCode = await _fetchFlutter(config);
    if (exitCode != 0) return exitCode;

    // Fetch platform-specific SDKs
    for (final name in targetPlatforms) {
      final platform = config.platforms[name];
      if (platform == null) {
        stderr.writeln('Unknown platform: $name');
        stderr.writeln('Available: ${config.platformNames.join(', ')}');
        return 1;
      }
      if (platform.sdk.isNotEmpty) {
        print('Setting up $name SDK...');
        // Platform-specific SDK setup would go here
        // For Android, this would mirror fetch-android-sdk.sh
        print('  (platform SDK setup not yet implemented for $name)');
      }
    }

    print('Setup complete.');
    return 0;
  }

  Future<int> _fetchFlutter(GuixConfig config) async {
    final sdkDir = Directory('.flutter-sdk/flutter');
    if (sdkDir.existsSync()) {
      // Check version
      final versionFile = File('.flutter-sdk/flutter/version');
      if (versionFile.existsSync()) {
        final currentVersion = versionFile.readAsStringSync().trim();
        if (currentVersion == config.flutter.version) {
          print('  Flutter ${config.flutter.version} already present.');
          return 0;
        }
      }
    }

    // Detect architecture
    final archResult = await Process.run('uname', ['-m']);
    final uname = (archResult.stdout as String).trim();
    final arch = (uname == 'aarch64' || uname == 'arm64') ? 'arm64' : 'x64';

    final version = config.flutter.version;
    final channel = config.flutter.channel;
    final url = flutterDownloadUrl(version, channel, arch);

    print('  Downloading Flutter $version ($arch)...');
    print('  $url');

    // Download
    final tmpDir = Directory('.flutter-sdk');
    if (!tmpDir.existsSync()) tmpDir.createSync(recursive: true);

    final downloadResult = await Process.start(
      'curl', ['-fSL', '-o', '.flutter-sdk/flutter.tar.xz', url],
      mode: ProcessStartMode.inheritStdio,
    );
    final dlExit = await downloadResult.exitCode;
    if (dlExit != 0) {
      stderr.writeln('  Failed to download Flutter SDK.');
      return dlExit;
    }

    // Verify checksum if configured
    final expectedHash = arch == 'arm64'
        ? config.flutter.checksumArm64
        : config.flutter.checksumX64;
    if (expectedHash.isNotEmpty) {
      print('  Verifying SHA-256...');
      final shaResult = await Process.run(
        'sha256sum', ['.flutter-sdk/flutter.tar.xz'],
      );
      final computedHash = (shaResult.stdout as String).split(' ').first;
      if (computedHash != expectedHash) {
        stderr.writeln('  Checksum mismatch!');
        stderr.writeln('  Expected: $expectedHash');
        stderr.writeln('  Got:      $computedHash');
        return 1;
      }
    } else {
      // Print computed hash for user to add to config
      final shaResult = await Process.run(
        'sha256sum', ['.flutter-sdk/flutter.tar.xz'],
      );
      final computedHash = (shaResult.stdout as String).split(' ').first;
      print('  SHA-256: $computedHash');
      print('  (add this to guix.yaml checksums.$arch for verification)');
    }

    // Extract
    print('  Extracting...');
    if (sdkDir.existsSync()) sdkDir.deleteSync(recursive: true);
    final extractResult = await Process.start(
      'tar', ['xf', '.flutter-sdk/flutter.tar.xz', '-C', '.flutter-sdk/'],
      mode: ProcessStartMode.inheritStdio,
    );
    final extExit = await extractResult.exitCode;
    if (extExit != 0) {
      stderr.writeln('  Failed to extract Flutter SDK.');
      return extExit;
    }

    // Clean up archive
    File('.flutter-sdk/flutter.tar.xz').deleteSync();
    print('  Flutter $version ready at .flutter-sdk/flutter/');
    return 0;
  }
}
