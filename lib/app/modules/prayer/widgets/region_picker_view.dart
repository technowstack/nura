import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/prayer_region.dart';
import '../../../data/models/prayer_regions.dart';
import '../controllers/region_picker_controller.dart';

/// Temporary region picker (D8): province, then kab/kota, or search by name.
/// Pops with the chosen [PrayerRegion].
class RegionPickerView extends StatelessWidget {
  const RegionPickerView({required this.regions, super.key});

  final PrayerRegions regions;

  @override
  Widget build(BuildContext context) => GetBuilder<RegionPickerController>(
    init: RegionPickerController(regions),
    builder: (c) => PopScope(
      canPop: c.province == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.back();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(c.province ?? 'Pilih wilayah')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(NuraSpace.s16),
              child: TextField(
                onChanged: c.setQuery,
                decoration: const InputDecoration(
                  prefixIcon: NuraIcon(NuraIcons.search),
                  hintText: 'Cari kota atau kabupaten',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(child: _list(context, c)),
          ],
        ),
      ),
    ),
  );

  Widget _list(BuildContext context, RegionPickerController c) {
    void pick(PrayerRegion r) => Navigator.of(context).pop(r);
    if (c.searching) {
      final rs = c.results;
      if (rs.isEmpty) {
        return const EmptyState(title: 'Wilayah tidak ditemukan');
      }
      return ListView.builder(
        itemCount: rs.length,
        itemBuilder: (_, i) =>
            _tile(rs[i].kabkota, () => pick(rs[i]), subtitle: rs[i].provinsi),
      );
    }
    if (c.province == null) {
      final ps = c.provinces;
      return ListView.builder(
        itemCount: ps.length,
        itemBuilder: (_, i) => _tile(
          ps[i],
          () => c.openProvince(ps[i]),
          trailing: const NuraIcon(NuraIcons.chevronRight),
        ),
      );
    }
    final ks = c.kabkota;
    return ListView.builder(
      itemCount: ks.length,
      itemBuilder: (_, i) => _tile(ks[i].kabkota, () => pick(ks[i])),
    );
  }

  Widget _tile(
    String title,
    VoidCallback onTap, {
    String? subtitle,
    Widget? trailing,
  }) => ListTile(
    minTileHeight: 56,
    contentPadding: const EdgeInsets.symmetric(horizontal: NuraSpace.s16),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: trailing,
    onTap: onTap,
  );
}
