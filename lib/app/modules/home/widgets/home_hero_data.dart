import 'package:flutter/widgets.dart';

class HeroPrayerTime {
  const HeroPrayerTime({
    required this.name,
    required this.time,
    required this.icon,
  });

  final String name;
  final String time;
  final IconData icon;
}

/// What the Beranda hero shows. [times] is empty until a schedule exists;
/// then [emptyText] explains why (never invented times).
class HomeHeroData {
  const HomeHeroData({
    required this.locationLabel,
    required this.hijriDate,
    required this.clock,
    this.countdownText,
    this.times = const [],
    this.nextIndex,
    this.approximate = false,
    this.emptyText = 'Jadwal belum tersedia',
  });

  final String locationLabel;
  final String hijriDate;
  final String clock;
  final String? countdownText;
  final List<HeroPrayerTime> times;
  final int? nextIndex;
  final bool approximate;
  final String emptyText;
}

/// The saved reading position with its surah names resolved.
class LastReadInfo {
  const LastReadInfo({
    required this.surah,
    required this.ayah,
    required this.nameArab,
    required this.nameLatin,
  });

  final int surah;
  final int ayah;
  final String nameArab;
  final String nameLatin;
}
