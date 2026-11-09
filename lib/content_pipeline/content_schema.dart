const int contentSchemaVersion = 1;

const int dailyHadithMaxLength = 400;

/// Slug to display name, in `sort_order`.
const Map<String, String> hadithBookNames = {
  'bukhari': 'Shahih Bukhari',
  'muslim': 'Shahih Muslim',
  'abu-daud': 'Sunan Abu Daud',
  'tirmidzi': 'Sunan Tirmidzi',
  'nasai': "Sunan Nasa'i",
  'ibnu-majah': 'Sunan Ibnu Majah',
  'ahmad': 'Musnad Ahmad',
  'malik': "Muwatha' Malik",
  'darimi': 'Sunan Darimi',
};

const List<String> contentSchemaDdl = [
  '''
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''',
  '''
CREATE TABLE surah (
  number       INTEGER PRIMARY KEY,
  name_arab    TEXT NOT NULL,
  name_latin   TEXT NOT NULL,
  name_id      TEXT NOT NULL,
  ayah_count   INTEGER NOT NULL,
  revelation   TEXT NOT NULL
)''',
  '''
CREATE TABLE ayah (
  id                  INTEGER PRIMARY KEY,
  surah_number        INTEGER NOT NULL REFERENCES surah(number),
  ayah_number         INTEGER NOT NULL,
  arab                TEXT NOT NULL,
  translation_id      TEXT NOT NULL,
  tafsir_kemenag      TEXT NOT NULL,
  UNIQUE (surah_number, ayah_number)
)''',
  '''
CREATE TABLE juz (
  number        INTEGER PRIMARY KEY,
  start_surah   INTEGER NOT NULL,
  start_ayah    INTEGER NOT NULL,
  end_surah     INTEGER NOT NULL,
  end_ayah      INTEGER NOT NULL
)''',
  '''
CREATE TABLE hadith_book (
  slug          TEXT PRIMARY KEY,
  name          TEXT NOT NULL,
  hadith_count  INTEGER NOT NULL,
  sort_order    INTEGER NOT NULL
)''',
  '''
CREATE TABLE hadith (
  id                  INTEGER PRIMARY KEY,
  book_slug           TEXT NOT NULL REFERENCES hadith_book(slug),
  number              INTEGER NOT NULL,
  arab                TEXT NOT NULL,
  translation_id      TEXT NOT NULL,
  translation_length  INTEGER NOT NULL,
  UNIQUE (book_slug, number)
)''',
  '''
CREATE VIRTUAL TABLE ayah_fts USING fts5(
  arab, translation,
  content='', tokenize='unicode61'
)''',
  '''
CREATE VIRTUAL TABLE hadith_fts USING fts5(
  arab, translation,
  content='', tokenize='unicode61'
)''',
  '''
CREATE TABLE daily_ayah (
  seq      INTEGER PRIMARY KEY,
  ayah_id  INTEGER NOT NULL REFERENCES ayah(id)
)''',
  '''
CREATE TABLE daily_hadith (
  seq        INTEGER PRIMARY KEY,
  hadith_id  INTEGER NOT NULL REFERENCES hadith(id)
)''',
];
