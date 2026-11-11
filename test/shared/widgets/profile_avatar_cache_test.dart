import 'package:flutter_test/flutter_test.dart';
import 'package:pileus/shared/widgets/profile_avatar_cache.dart';

void main() {
  test('the same picture has one key on any server address', () {
    final lan = profileAvatarCacheKey('http://10.0.0.204:8000/profile-avatar/p1?v=abc');
    final vpn = profileAvatarCacheKey('https://demo.example/profile-avatar/p1?v=abc');
    expect(lan, vpn);
    expect(lan,
        isNot(profileAvatarCacheKey('http://x/profile-avatar/p1?v=new')));
    expect(profileAvatarCacheKey('https://a.b/pic.jpg'), 'https://a.b/pic.jpg');
  });
}
