import 'dart:math';

class ShareKeyGenerator {
  static String generateRandomShrekey() {
    const length = 16;
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    final shrekey = List.generate(
      length,
      (index) => chars[rand.nextInt(chars.length)],
    ).join("");
    return shrekey;
  }
}
