import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:guix/src/commands/build_command.dart';

GuixConfig _configFromYaml(String yaml) =>
    GuixConfig.fromYaml(loadYaml(yaml) as YamlMap);

void main() {
  group('BuildCommand arg parser', () {
    late BuildCommand command;

    setUp(() {
      command = BuildCommand();
    });

    test('--pinned flag defaults to true', () {
      final results = command.argParser.parse([]);
      expect(results['pinned'], isTrue);
    });

    test('--pinned can be negated with --no-pinned', () {
      final results = command.argParser.parse(['--no-pinned']);
      expect(results['pinned'], isFalse);
    });

    test('-p is abbreviation for --pinned', () {
      // -p with no negation just sets it to true (same as default)
      final results = command.argParser.parse(['-p']);
      expect(results['pinned'], isTrue);
    });

    test('--profile accepts a value', () {
      final results = command.argParser.parse(['--profile', 'staging']);
      expect(results['profile'], 'staging');
    });

    test('-P is abbreviation for --profile', () {
      final results = command.argParser.parse(['-P', 'staging']);
      expect(results['profile'], 'staging');
    });

    test('--profile defaults to null when not specified', () {
      final results = command.argParser.parse([]);
      expect(results['profile'], isNull);
    });
  });

  group('BuildCommand profile resolution logic', () {
    test('profile resolves to base platform manifest with profile command', () {
      final config = _configFromYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
profiles:
  staging:
    platform: linux
    command: flutter build linux --release --dart-define=FLAVOR=staging
    output: build/linux/staging/bundle
''');

      // When profileName is "staging", resolvedName becomes "staging"
      // platformFor("staging") should resolve via the profile
      final resolved = config.platformFor('staging');
      expect(resolved, isNotNull);
      expect(resolved!.manifest, 'guix/linux.scm');
      expect(resolved.buildCommand,
          'flutter build linux --release --dart-define=FLAVOR=staging');
      expect(resolved.buildOutput, 'build/linux/staging/bundle');
    });

    test('direct platform name resolves without profile', () {
      final config = _configFromYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
''');

      final resolved = config.platformFor('linux');
      expect(resolved, isNotNull);
      expect(resolved!.buildCommand, 'flutter build linux --release');
    });

    test('unknown platform name returns null', () {
      final config = _configFromYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
''');

      expect(config.platformFor('windows'), isNull);
    });

    test('fallback: when profile not found, build uses target from platforms',
        () {
      // In BuildCommand.run(): resolvedName = profileName ?? target
      // config.platformFor(resolvedName) ?? config.platforms[target]
      // If profileName is null, resolvedName == target, and it looks up directly
      final config = _configFromYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  android:
    manifest: guix/android.scm
    build:
      command: flutter build apk --release
      output: build/app/outputs/flutter-apk/app-release.apk
''');

      // Simulating: target = "android", profileName = null
      // resolvedName = null ?? "android" = "android"
      final resolvedName = null ?? 'android';
      final platform =
          config.platformFor(resolvedName) ?? config.platforms['android'];
      expect(platform, isNotNull);
      expect(platform!.manifest, 'guix/android.scm');
      expect(platform.buildCommand, 'flutter build apk --release');
    });

    test('profile overrides command but inherits env, preserve, and sdk', () {
      final config = _configFromYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  linux:
    manifest: guix/linux.scm
    env:
      CC: clang
    preserve:
      - DISPLAY
    build:
      command: flutter build linux --release
      output: build/linux/release/bundle
profiles:
  debug:
    platform: linux
    command: flutter build linux --debug
''');

      final resolved = config.platformFor('debug');
      expect(resolved, isNotNull);
      expect(resolved!.buildCommand, 'flutter build linux --debug');
      // Inherits base platform env and preserve
      expect(resolved.env['CC'], 'clang');
      expect(resolved.preserve, contains('DISPLAY'));
      // Falls back to base output since profile.output is null
      expect(resolved.buildOutput, 'build/linux/release/bundle');
    });

    test('pinned flag determines channels file', () {
      final config = _configFromYaml('''
project:
  name: test_app
flutter:
  version: "3.24.5"
  channel: stable
guix:
  channels: guix/channels.scm
platforms:
  linux:
    manifest: guix/linux.scm
    build:
      command: flutter build linux --release
      output: build/
''');

      // Build defaults to pinned mode, so channelsFile = config.channelsPath.
      final pinned = BuildCommand().argParser.parse([])['pinned'] as bool;
      final channelsFile = pinned ? config.channelsPath : null;
      expect(channelsFile, 'guix/channels.scm');

      // Explicit --no-pinned mode leaves channelsFile unset.
      final notPinned =
          BuildCommand().argParser.parse(['--no-pinned'])['pinned'] as bool;
      final noChannels = notPinned ? config.channelsPath : null;
      expect(noChannels, isNull);
    });
  });
}
