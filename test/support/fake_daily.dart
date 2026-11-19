import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';

DailyContent fakeAyah(int day) => DailyContent(
  kind: DailyKind.ayah,
  arab: 'فَإِنَّ مَعَ ٱلْعُسْرِ يُسْرًا',
  translation: 'Ayat hari $day',
  reference: 'QS. Asy-Syarh: $day',
  deepLink: 'nura://ayah/94/$day',
  ayahRef: AyahRef(94, day),
  surahNameArab: 'ٱلشَّرْحِ',
);

DailyContent fakeHadith(int day, HadithSource source) => DailyContent(
  kind: DailyKind.hadith,
  arab: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ',
  translation: 'Hadis hari $day (${source.value})',
  reference: 'HR. Shahih Bukhari No. $day',
  deepLink: 'nura://hadith/bukhari/$day',
  hadithRef: HadithRef('bukhari', day),
);

class FakeDailyContentRepository implements DailyContentRepository {
  bool withAyah = true;
  bool withHadith = true;
  Object? failure;
  int calls = 0;

  @override
  bool get hasAyah => withAyah;

  @override
  DailyContent? ayahFor(DateTime localDate) {
    calls++;
    if (failure case final f?) throw f;
    return withAyah ? fakeAyah(localDate.day) : null;
  }

  @override
  DailyContent? hadithFor(DateTime localDate, HadithSource source) {
    if (failure case final f?) throw f;
    return withHadith ? fakeHadith(localDate.day, source) : null;
  }
}

class FakeDailySettingsStore implements DailySettingsStore {
  @override
  HadithSource hadithSource = HadithSource.defaultBm;

  @override
  void setHadithSource(HadithSource s) => hadithSource = s;

  @override
  bool notifyEnabled = false;

  @override
  void setNotifyEnabled(bool v) => notifyEnabled = v;

  @override
  String notifyTime = '06:00';

  @override
  void setNotifyTime(String t) => notifyTime = t;
}
