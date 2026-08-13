class AndroidNotificationPayload {
  const AndroidNotificationPayload({
    required this.packageName,
    required this.appName,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.notificationKey = '',
    this.subText = '',
    this.bigText = '',
    this.textLines = const [],
    this.channelId = '',
    this.postTime,
    this.notificationId,
    this.tag = '',
    this.ticker = '',
    this.extras = const {},
    this.result = '',
  });

  final String packageName;
  final String appName;
  final String notificationKey;
  final String title;
  final String body;
  final String subText;
  final String bigText;
  final List<String> textLines;
  final String channelId;
  final DateTime? postTime;
  final int? notificationId;
  final String tag;
  final String ticker;
  final Map<String, String> extras;
  final String result;
  final DateTime receivedAt;

  bool get hasContent =>
      title.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      subText.trim().isNotEmpty ||
      bigText.trim().isNotEmpty ||
      textLines.any((line) => line.trim().isNotEmpty) ||
      ticker.trim().isNotEmpty;

  String get displayBody {
    if (body.trim().isNotEmpty) {
      return body;
    }
    if (bigText.trim().isNotEmpty) {
      return bigText;
    }
    if (textLines.isNotEmpty) {
      return textLines.join('\n');
    }
    return subText;
  }

  String get dedupeHash {
    final input = [
      packageName.trim().toLowerCase(),
      notificationKey.trim(),
      title.trim(),
      displayBody.trim(),
      receivedAt.millisecondsSinceEpoch.toString(),
    ].join('|');
    var hash = 0xcbf29ce484222325;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  factory AndroidNotificationPayload.fromPlatformMap(
    Map<Object?, Object?> map,
  ) {
    final receivedAtMillis = map['receivedAtMillis'];
    final postTimeMillis = map['postTimeMillis'];

    return AndroidNotificationPayload(
      packageName: _readString(map, 'packageName'),
      appName: _readString(map, 'appName'),
      notificationKey: _readString(map, 'notificationKey'),
      title: _readString(map, 'title'),
      body: _readString(map, 'body'),
      subText: _readString(map, 'subText'),
      bigText: _readString(map, 'bigText'),
      textLines: _readStringList(map, 'textLines'),
      channelId: _readString(map, 'channelId'),
      postTime: postTimeMillis is int
          ? DateTime.fromMillisecondsSinceEpoch(postTimeMillis)
          : null,
      notificationId: _readInt(map, 'notificationId'),
      tag: _readString(map, 'tag'),
      ticker: _readString(map, 'ticker'),
      extras: _readStringMap(map, 'extras'),
      result: _readString(map, 'result'),
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        receivedAtMillis is int ? receivedAtMillis : 0,
      ),
    );
  }

  Map<String, Object?> toPlatformMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'notificationKey': notificationKey,
      'title': title,
      'body': body,
      'subText': subText,
      'bigText': bigText,
      'textLines': textLines,
      'channelId': channelId,
      'postTimeMillis': postTime?.millisecondsSinceEpoch,
      'notificationId': notificationId,
      'tag': tag,
      'ticker': ticker,
      'extras': extras,
      'result': result,
      'receivedAtMillis': receivedAt.millisecondsSinceEpoch,
    };
  }

  static String _readString(Map<Object?, Object?> map, String key) {
    final value = map[key];
    return value is String ? value : '';
  }

  static int? _readInt(Map<Object?, Object?> map, String key) {
    final value = map[key];
    return value is int ? value : null;
  }

  static Map<String, String> _readStringMap(
    Map<Object?, Object?> map,
    String key,
  ) {
    final value = map[key];
    if (value is! Map<Object?, Object?>) {
      return const {};
    }

    return value.map(
      (key, value) => MapEntry(key?.toString() ?? '', value?.toString() ?? ''),
    )..removeWhere((key, _) => key.isEmpty);
  }

  static List<String> _readStringList(Map<Object?, Object?> map, String key) {
    final value = map[key];
    if (value is! List<Object?>) {
      return const [];
    }

    return value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }
}
