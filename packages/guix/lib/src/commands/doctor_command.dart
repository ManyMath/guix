import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:guix/src/guix/guix_runner.dart';

class DoctorCommand extends Command<int> {
  @override
  final String name = 'doctor';

  @override
  final String description = 'Check prerequisites and configuration.';

  DoctorCommand() {
    argParser.addFlag('verbose', help: 'Show details for each check');
  }

  @override
  Future<int> run() async {
    final verbose = argResults!['verbose'] as bool ||
        (globalResults?['verbose'] as bool? ?? false);

    print('Guix Doctor');
    print('-' * 40);

    var issues = 0;
    final guix = GuixRunner(verbose: verbose);

    // Check: Guix installed
    final guixInstalled = await guix.isInstalled();
    if (guixInstalled) {
      final version = await guix.version();
      _pass('GNU Guix installed ($version)');
    } else {
      _fail('GNU Guix not found on PATH');
      _hint('Install Guix: https://guix.gnu.org/manual/en/html_node/Installation.html');
      issues++;
    }

    // Check: guix.yaml exists and is valid
    final configFile = File('guix.yaml');
    GuixConfig? config;
    if (configFile.existsSync()) {
      try {
        config = GuixConfig.load();
        _pass('guix.yaml found and valid');
      } on Exception catch (e) {
        _fail('guix.yaml has errors: $e');
        issues++;
      }
    } else {
      _fail('guix.yaml not found');
      _hint('Run: guix_dart init');
      issues++;
    }

    if (config == null) {
      print('');
      print('$issues issue(s) found. Fix the above before continuing.');
      return issues > 0 ? 1 : 0;
    }

    // Check: channels pinned
    final channelsFile = File(config.channelsPath);
    if (channelsFile.existsSync()) {
      final content = channelsFile.readAsStringSync();
      // Try to extract commit hash from channels.scm
      final commitMatch = RegExp(r'\(commit\s+"([a-f0-9]+)"\)').firstMatch(content);
      if (commitMatch != null) {
        final short = commitMatch.group(1)!.substring(0, 8);
        _pass('Channels pinned (${config.channelsPath}, commit $short)');
      } else {
        _pass('Channels file exists (${config.channelsPath})');
      }
    } else {
      _fail('Channels not pinned (${config.channelsPath} missing)');
      _hint('Run: guix_dart pin');
      issues++;
    }

    // Check: Flutter SDK
    final sdkDir = Directory('.flutter-sdk/flutter');
    if (sdkDir.existsSync()) {
      final versionFile = File('.flutter-sdk/flutter/version');
      if (versionFile.existsSync()) {
        final version = versionFile.readAsStringSync().trim();
        if (version == config.flutter.version) {
          _pass('Flutter SDK fetched ($version)');
        } else {
          _warn('Flutter SDK version mismatch (have: $version, want: ${config.flutter.version})');
          _hint('Run: guix_dart setup');
          issues++;
        }
      } else {
        _warn('Flutter SDK present but version file missing');
        issues++;
      }
    } else {
      _fail('Flutter SDK not fetched');
      _hint('Run: guix_dart setup');
      issues++;
    }

    // Check: checksums configured
    final hasX64 = config.flutter.checksumX64.isNotEmpty;
    final hasArm64 = config.flutter.checksumArm64.isNotEmpty;
    if (hasX64 || hasArm64) {
      _pass('Flutter SDK checksums configured');
    } else {
      _warn('Flutter SDK checksums not set (verification skipped)');
      _hint('Run guix_dart setup to see computed hashes, then add to guix.yaml');
    }

    // Check: per-platform manifests
    for (final entry in config.platforms.entries) {
      final name = entry.key;
      final platform = entry.value;
      if (File(platform.manifest).existsSync()) {
        _pass('$name manifest exists (${platform.manifest})');
      } else {
        _fail('$name manifest missing (${platform.manifest})');
        _hint('Run: guix_dart init $name');
        issues++;
      }

      // Check platform-specific SDKs
      if (name == 'android') {
        final androidSdk = Directory('.android-sdk/cmdline-tools');
        if (androidSdk.existsSync()) {
          _pass('Android SDK fetched');
        } else {
          _fail('Android SDK not fetched');
          _hint('Run: guix_dart setup android');
          issues++;
        }
      }
    }

    // Check: pubspec.lock
    if (File('pubspec.lock').existsSync()) {
      _pass('pubspec.lock present');
    } else {
      _warn('pubspec.lock missing (Dart dependencies not locked)');
    }

    print('');
    if (issues == 0) {
      print('No issues found.');
    } else {
      print('$issues issue(s) found.');
    }
    return issues > 0 ? 1 : 0;
  }

  void _pass(String msg) => print('[pass] $msg');
  void _fail(String msg) => print('[FAIL] $msg');
  void _warn(String msg) => print('[warn] $msg');
  void _hint(String msg) => print('       $msg');
}
