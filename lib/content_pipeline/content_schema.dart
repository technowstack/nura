const int contentSchemaVersion = 2;

/// Source texts at or above this many UTF-8 bytes were cut off at 16,384
/// bytes in the source data (19 of 38,102 hadith); they never become daily
/// content.
const int kSourceTruncationBytes = 16374;

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
  list        TEXT    NOT NULL CHECK (list IN ('default','all')),
  seq         INTEGER NOT NULL,
  hadith_id   INTEGER NOT NULL REFERENCES hadith(id),
  arab_start  INTEGER NOT NULL,
  arab_end    INTEGER NOT NULL,
  tr_start    INTEGER NOT NULL,
  tr_end      INTEGER NOT NULL,
  PRIMARY KEY (list, seq)
)''',
];
