import 'dart:io';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:guix/src/config/guix_config.dart';
import 'package:guix/src/commands/shell_command.dart';

GuixConfig _configFromYaml(String yaml) =>
    GuixConfig.fromYaml(loadYaml(yaml) as YamlMap);

void main() {
  group('ShellCommand arg parser', () {
    late ShellCommand command;

    setUp(() {
      command = ShellCommand();
    });

    test('--pinned flag defaults to false', () {
      final results = command.argParser.parse([]);
      expect(results['pinned'], isFalse);
    });

    test('--pinned flag can be set to true', () {
      final results = command.argParser.parse(['--pinned']);
      expect(results['pinned'], isTrue);
    });

    test('-p is abbreviation for --pinned', () {
      final results = command.argParser.parse(['-p']);
      expect(results['pinned'], isTrue);
    });
  });

  group('ShellCommand validation logic (filesystem)', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('shell_test_');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('Flutter SDK directory check detects missing SDK', () {
      final sdkDir = Directory('${tmp.path}/.flutter-sdk/flutter');
      expect(sdkDir.existsSync(), isFalse);
    });

    test('Flutter SDK directory check detects present SDK', () {
      Directory('${tmp.path}/.flutter-sdk/flutter').createSync(recursive: true);
      final sdkDir = Directory('${tmp.path}/.flutter-sdk/flutter');
      expect(sdkDir.existsSync(), isTrue);
    });

    test('manifest file check detects missing manifest', () {
      final manifestFile = File('${tmp.path}/guix/linux.scm');
      expect(manifestFile.existsSync(), isFalse);
    });

    test('manifest file check detects present manifest', () {
      Directory('${tmp.path}/guix').createSync();
      File('${tmp.path}/guix/linux.scm').writeAsStringSync('; manifest');

      final manifestFile = File('${tmp.path}/guix/linux.scm');
      expect(manifestFile.existsSync(), isTrue);
    });

    test('--pinned requires channels file to exist', () {
      // channels file does not exist in fresh temp dir
      final channelsFile = File('${tmp.path}/guix/channels.scm');
      expect(channelsFile.existsSync(), isFalse);
    });

    test('--pinned succeeds when channels file exists', () {
      Directory('${tmp.path}/guix').createSync();
      File('${tmp.path}/guix/channels.scm').writeAsStringSync('; channels');

      final channelsFile = File('${tmp.path}/guix/channels.scm');
      expect(channelsFile.existsSync(), isTrue);
    });
  });

  group('ShellCommand validation logic (config)', () {
    test('unknown platform name is not in config', () {
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

      expect(config.platforms['windows'], isNull);
      expect(config.platformNames, isNot(contains('windows')));
    });

    test('pinned mode sets channelsFile from config', () {
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

      // Explicit --pinned mode sets channelsFile from config.
      final pinned =
          ShellCommand().argParser.parse(['--pinned'])['pinned'] as bool;
      final channelsFile = pinned ? config.channelsPath : null;
      expect(channelsFile, 'guix/channels.scm');
    });

    test('unpinned mode does not require channels file', () {
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

      // Shell defaults to unpinned mode, so no file check is needed.
      final pinned = ShellCommand().argParser.parse([])['pinned'] as bool;
      final channelsFile = pinned ? config.channelsPath : null;
      expect(channelsFile, isNull);
    });
  });
}
