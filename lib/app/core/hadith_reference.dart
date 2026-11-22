/// Slug to short book name used in hadith references (owner decision
/// 2026-11-23), e.g. "Bukhari" in "HR. Bukhari No. 1".
const Map<String, String> hadithBookNamesShort = {
  'bukhari': 'Bukhari',
  'muslim': 'Muslim',
  'abu-daud': 'Abu Daud',
  'tirmidzi': 'Tirmidzi',
  'nasai': "Nasa'i",
  'ibnu-majah': 'Ibnu Majah',
  'ahmad': 'Ahmad',
  'malik': 'Malik',
  'darimi': 'Darimi',
};

/// `HR. <short name> No. <n>`; an unknown slug is shown as is.
String hadithReference(String slug, int number) =>
    'HR. ${hadithBookNamesShort[slug] ?? slug} No. $number';
