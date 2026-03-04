import 'package:test/test.dart';
import 'package:guix/src/templates/config_template.dart';

void main() {
  group('generateConfig', () {
    test('includes project name', () {
      final yaml = generateConfig(projectName: 'my_wallet', platforms: ['linux']);
      expect(yaml, contains('name: my_wallet'));
    });

    test('includes flutter version', () {
      final yaml = generateConfig(
        projectName: 'app',
        platforms: ['linux'],
        flutterVersion: '3.27.1',
      );
      expect(yaml, contains('version: "3.27.1"'));
    });

    test('defaults flutter version to 3.24.5', () {
      final yaml = generateConfig(projectName: 'app', platforms: ['linux']);
      expect(yaml, contains('version: "3.24.5"'));
    });

    test('includes linux platform when requested', () {
      final yaml = generateConfig(projectName: 'app', platforms: ['linux']);
      expect(yaml, contains('linux:'));
      expect(yaml, contains('manifest: guix/linux.scm'));
      expect(yaml, contains('flutter build linux --release'));
    });

    test('includes android platform when requested', () {
      final yaml = generateConfig(projectName: 'app', platforms: ['android']);
      expect(yaml, contains('android:'));
      expect(yaml, contains('manifest: guix/android.scm'));
      expect(yaml, contains('flutter build apk --release'));
    });

    test('omits android section when only linux requested', () {
      final yaml = generateConfig(projectName: 'app', platforms: ['linux']);
      expect(yaml, isNot(contains('android:')));
    });

    test('omits linux section when only android requested', () {
      final yaml = generateConfig(projectName: 'app', platforms: ['android']);
      expect(yaml, isNot(contains('linux:')));
    });

    test('includes both platforms when both requested', () {
      final yaml = generateConfig(projectName: 'app', platforms: ['linux', 'android']);
      expect(yaml, contains('linux:'));
      expect(yaml, contains('android:'));
    });

    test('output is valid YAML with channels path', () {
      final yaml = generateConfig(projectName: 'app', platforms: ['linux']);
      expect(yaml, contains('channels: guix/channels.scm'));
    });

    test('empty platforms list produces no platforms section', () {
      final yaml = generateConfig(projectName: 'app', platforms: []);
      expect(yaml, isNot(contains('platforms:')));
      expect(yaml, isNot(contains('linux:')));
      expect(yaml, isNot(contains('android:')));
    });
  });
}
