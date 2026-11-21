/// User-facing revelation place; empty for unknown values so callers can hide it.
String revelationLabel(String revelation) => switch (revelation) {
  'makkiyah' => 'Makkiyah',
  'madaniyah' => 'Madaniyah',
  _ => '',
};
