import 'package:test/test.dart';
import 'package:guix/src/commands/setup_command.dart';

void main() {
  group('flutterDownloadUrl', () {
    test('x64 URL uses plain version', () {
      final url = flutterDownloadUrl('3.24.5', 'stable', 'x64');
      expect(url, endsWith('flutter_linux_3.24.5-stable.tar.xz'));
    });

    test('arm64 URL includes arm64_ prefix', () {
      final url = flutterDownloadUrl('3.24.5', 'stable', 'arm64');
      expect(url, endsWith('flutter_linux_arm64_3.24.5-stable.tar.xz'));
    });

    test('channel is embedded in URL path and suffix', () {
      final url = flutterDownloadUrl('3.24.5', 'beta', 'x64');
      expect(url, contains('/beta/linux/'));
      expect(url, endsWith('flutter_linux_3.24.5-beta.tar.xz'));
    });

    test('non-arm64 arch string falls back to x64 path', () {
      final url = flutterDownloadUrl('3.24.5', 'stable', 'x86_64');
      expect(url, endsWith('flutter_linux_3.24.5-stable.tar.xz'));
      expect(url, isNot(contains('arm64')));
    });
  });
}
