import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:guix/src/config/project_config.dart';

class DoctorCommand extends Command<int> {
  @override
  final String name = 'doctor';

  @override
  final String description = 'Check prerequisites and configuration.';

  @override
  Future<int> run() async {
    print('Guix Doctor');
    print('-' * 40);

    var issues = 0;

    // Check: Guix installed
    try {
      final result = await Process.run('guix', ['--version']);
      if (result.exitCode == 0) {
        final version = (result.stdout as String).split('\n').first.trim();
        _pass('GNU Guix installed ($version)');
      } else {
        _fail('GNU Guix not working');
        issues++;
      }
    } on ProcessException {
      _fail('GNU Guix not found on PATH');
      _hint('Install: https://guix.gnu.org/manual/en/html_node/Installation.html');
      issues++;
    }

    // Check: project config
    ProjectConfig? config;
    try {
      config = ProjectConfig.load();
    } catch (e) {
      _fail('Could not load project config: $e');
      issues++;
    }

    if (config == null) {
      print('\n$issues issue(s) found.');
      return 1;
    }

    // Check: guix scripts directory
    if (config.hasScripts) {
      _pass('Scripts directory found (${config.guixDir}/scripts/)');
    } else {
      _fail('Scripts directory missing (${config.guixDir}/scripts/)');
      _hint('Add guix-flutter-scripts via git subtree');
      issues++;
    }

    // Check: flutter_version.env
    if (config.flutter.version.isNotEmpty) {
      _pass('Flutter version pinned (${config.flutter.version})');
    } else {
      _fail('flutter_version.env missing or empty');
      _hint('Run: guix_dart init');
      issues++;
    }

    // Check: channels pinned
    final channelsFile = File(config.channelsPath);
    if (channelsFile.existsSync()) {
      final content = channelsFile.readAsStringSync();
      final match = RegExp(r'\(commit\s+"([a-f0-9]+)"\)').firstMatch(content);
      if (match != null) {
        final short = match.group(1)!;
        _pass('Channels pinned (commit ${short.substring(0, 8)}...)');
      } else {
        _pass('Channels file exists');
      }
    } else {
      _fail('Channels not pinned');
      _hint('Run: guix_dart pin');
      issues++;
    }

    // Check: Flutter SDK fetched
    final sdkDir = Directory(p.join(config.projectRoot, '.flutter-sdk', 'flutter'));
    if (sdkDir.existsSync()) {
      final versionFile = File(p.join(sdkDir.path, 'version'));
      if (versionFile.existsSync()) {
        final version = versionFile.readAsStringSync().trim();
        if (version == config.flutter.version) {
          _pass('Flutter SDK fetched ($version)');
        } else {
          _warn('Flutter SDK version mismatch (have $version, want ${config.flutter.version})');
          _hint('Run: guix_dart setup');
          issues++;
        }
      } else {
        _warn('Flutter SDK present but version unknown');
      }
    } else {
      _fail('Flutter SDK not fetched');
      _hint('Run: guix_dart setup');
      issues++;
    }

    // Check: checksums configured
    if (config.flutter.sha256X64.isNotEmpty || config.flutter.sha256Arm64.isNotEmpty) {
      _pass('Flutter SDK checksums configured');
    } else {
      _warn('Flutter SDK checksums not set (verification skipped)');
    }

    // Check: platform manifests
    for (final platform in config.platforms) {
      final manifest = File(p.join(config.manifestsPath, '$platform.scm'));
      if (manifest.existsSync()) {
        _pass('$platform manifest exists');
      } else {
        _fail('$platform manifest missing');
        issues++;
      }

      // Check for corresponding scripts
      if (config.hasShellScript(platform)) {
        _pass('$platform shell script exists');
      } else {
        _warn('$platform shell script missing (shell-$platform.sh)');
      }
    }

    // Check: Android SDK (if android platform exists)
    if (config.platforms.contains('android')) {
      final androidSdk = Directory(p.join(config.projectRoot, '.android-sdk', 'cmdline-tools'));
      if (androidSdk.existsSync()) {
        _pass('Android SDK fetched');
      } else {
        _fail('Android SDK not fetched');
        _hint('Run: guix_dart setup android');
        issues++;
      }
    }

    // Check: pubspec.lock
    if (File(p.join(config.projectRoot, 'pubspec.lock')).existsSync()) {
      _pass('pubspec.lock present');
    } else {
      _warn('pubspec.lock missing');
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
