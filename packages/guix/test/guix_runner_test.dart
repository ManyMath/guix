import 'package:test/test.dart';
import 'package:guix/src/guix/guix_runner.dart';

void main() {
  group('GuixRunner.shellArgs', () {
    final runner = GuixRunner();

    test('returns plain shell args when no channelsFile', () {
      final args = runner.shellArgs(manifest: 'guix/linux.scm');
      expect(args, ['shell', '-m', 'guix/linux.scm']);
    });

    test('wraps with time-machine when channelsFile provided', () {
      final args = runner.shellArgs(
        manifest: 'guix/linux.scm',
        channelsFile: 'guix/channels.scm',
      );
      expect(args, [
        'time-machine', '-C', 'guix/channels.scm',
        '--', 'shell', '-m', 'guix/linux.scm',
      ]);
    });

    test('time-machine args have correct positional structure', () {
      final args = runner.shellArgs(
        manifest: 'guix/android.scm',
        channelsFile: 'pinned.scm',
      );
      // time-machine must come first, channels flag before --, shell after --
      expect(args.first, 'time-machine');
      final dashDash = args.indexOf('--');
      expect(dashDash, greaterThan(0));
      expect(args.sublist(dashDash + 1), ['shell', '-m', 'guix/android.scm']);
    });

    test('plain shell args do not include time-machine', () {
      final args = runner.shellArgs(manifest: 'guix/linux.scm');
      expect(args, isNot(contains('time-machine')));
    });
  });

  group('GuixRunner.enterShellBashArgs', () {
    final runner = GuixRunner();

    test('returns plain bash when no flutterSdkPath', () {
      final args = runner.enterShellBashArgs(null);
      expect(args, ['--', 'bash']);
    });

    test('prepends flutter bin to PATH when flutterSdkPath provided', () {
      final args = runner.enterShellBashArgs('/home/user/.flutter-sdk/flutter');
      expect(args, [
        '--', 'bash', '-c',
        'export PATH="/home/user/.flutter-sdk/flutter/bin:\$PATH"; exec bash',
      ]);
    });

    test('uses bash -c invocation with exec bash at end when path provided', () {
      final args = runner.enterShellBashArgs('/opt/flutter');
      final cIndex = args.indexOf('-c');
      expect(cIndex, greaterThan(0));
      final shellCmd = args[cIndex + 1];
      expect(shellCmd, endsWith('exec bash'));
    });
  });
}
