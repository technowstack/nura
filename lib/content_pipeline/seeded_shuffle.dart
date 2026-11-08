const int dailySeed = 20261109;

// mulberry32; own PRNG because dart:math Random is not stable across versions.
int _next(List<int> state) {
  state[0] = (state[0] + 0x6D2B79F5) & 0xFFFFFFFF;
  var t = state[0];
  t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF;
  t = (t ^ (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF;
  return (t ^ (t >> 14)) & 0xFFFFFFFF;
}

List<T> seededShuffle<T>(List<T> items, int seed) {
  final out = List<T>.of(items);
  final state = [seed & 0xFFFFFFFF];
  for (var i = out.length - 1; i >= 1; i--) {
    final j = _next(state) % (i + 1);
    final tmp = out[i];
    out[i] = out[j];
    out[j] = tmp;
  }
  return out;
}
