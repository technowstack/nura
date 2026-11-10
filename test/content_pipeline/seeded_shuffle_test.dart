import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/seeded_shuffle.dart';

void main() {
  test('seededShuffle is deterministic and a permutation', () {
    final a = seededShuffle(List.generate(100, (i) => i), dailySeed);
    final b = seededShuffle(List.generate(100, (i) => i), dailySeed);
    expect(a, b);
    expect(a.toSet(), Set.of(List.generate(100, (i) => i)));
    expect(a, isNot(List.generate(100, (i) => i)));
  });

  test('seededShuffle does not mutate input', () {
    final input = [1, 2, 3, 4, 5];
    seededShuffle(input, dailySeed);
    expect(input, [1, 2, 3, 4, 5]);
  });

  // Golden locks the algorithm; do not change it without updating this.
  test('seededShuffle golden', () {
    expect(seededShuffle(List.generate(10, (i) => i), dailySeed), <int>[6, 9, 1, 8, 0, 3, 5, 7, 2, 4]);
  });
}
