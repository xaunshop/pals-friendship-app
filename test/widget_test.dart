import 'package:flutter_test/flutter_test.dart';
import 'package:pals_friendship_app/config/app_config.dart';

void main() {
  test('app branding is configured centrally', () {
    expect(AppConfig.appName, isNotEmpty);
    expect(AppConfig.tagline, isNotEmpty);
  });
}
