import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitalong/core/constants/achievements.dart';
import 'package:gitalong/core/constants/illustrations.dart';

void main() {
  group('Achievements', () {
    test('defines the 10 achievements from the spec, with unique keys', () {
      final keys = Achievements.all.map((a) => a.key).toList();
      expect(keys, hasLength(10));
      expect(keys.toSet(), hasLength(10));
      expect(keys, [
        'first_swipe',
        'explorer_50',
        'first_match',
        'matches_10',
        'icebreaker',
        'real_talk',
        'streak_3',
        'streak_7',
        'goal_crusher',
        'profile_complete',
      ]);
    });

    test('uses the illustrations from the spec', () {
      final art = {for (final a in Achievements.all) a.key: a.illustration};
      expect(art, {
        'first_swipe': 'seedling',
        'explorer_50': 'compass',
        'first_match': 'handshake',
        'matches_10': 'link',
        'icebreaker': 'speech_balloon',
        'real_talk': 'busts',
        'streak_3': 'fire',
        'streak_7': 'high_voltage',
        'goal_crusher': 'trophy',
        'profile_complete': 'hundred_points',
      });
    });

    test('every achievement has a title, a description and a known illustration', () {
      for (final a in Achievements.all) {
        expect(a.title.trim(), isNotEmpty, reason: a.key);
        expect(a.description.trim(), isNotEmpty, reason: a.key);
        expect(Illustrations.all, contains(a.illustration), reason: a.key);
      }
    });

    test('lookup by key and display order', () {
      expect(Achievements.byKey('streak_3')?.title, 'On fire');
      expect(Achievements.byKey('unknown'), isNull);
      expect(Achievements.orderOf('first_swipe'), 0);
      expect(Achievements.orderOf('profile_complete'), 9);
      expect(Achievements.orderOf('unknown'), Achievements.all.length);
    });

    test('the daily goal is 10 builders', () {
      expect(Achievements.dailyGoal, 10);
    });
  });

  group('Illustrations', () {
    test('names are unique and map to asset paths', () {
      expect(Illustrations.all.toSet(), hasLength(Illustrations.all.length));
      expect(
        Illustrations.path(Illustrations.octopus),
        'assets/illustrations/octopus.png',
      );
      expect(Illustrations.mascot, Illustrations.octopus);
    });

    // `flutter test` runs from the project root; skip if the assets folder
    // isn't reachable from the current directory.
    final dir = Directory('assets/illustrations');
    final skip = dir.existsSync()
        ? false
        : 'assets/illustrations not found from ${Directory.current.path}';

    test('every listed illustration exists on disk', () {
      for (final name in Illustrations.all) {
        expect(
          File(Illustrations.path(name)).existsSync(),
          isTrue,
          reason: '$name.png is missing',
        );
      }
    }, skip: skip);

    test('every achievement illustration exists on disk', () {
      for (final a in Achievements.all) {
        expect(
          File(Illustrations.path(a.illustration)).existsSync(),
          isTrue,
          reason: '${a.illustration}.png (${a.key}) is missing',
        );
      }
    }, skip: skip);

    test('every png in the folder is listed', () {
      final onDisk = dir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((name) => name.endsWith('.png'))
          .map((name) => name.substring(0, name.length - 4))
          .toSet();
      expect(onDisk, Illustrations.all.toSet());
    }, skip: skip);
  });
}
