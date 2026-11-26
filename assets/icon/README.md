# Ikon Nura — konsep misykat

Warna (rujukan token Putaran 1.5): latar ext/hero #185A4B · gading #F8F7F3 / #E3D8C0 · emas #EBCB8B / #C9A45F · ceruk #124A3D / #0D3A30.
Semua bentuk bidang datar (path tunggal, fill-rule evenodd); tanpa gradasi, mask, clipPath, atau filter — aman dikonversi ke VectorDrawable.

- adaptive/foreground.svg, background.svg, monochrome.svg — 108×108 dp; simbol di dalam lingkaran aman Ø66.
- notification/ic_stat_nura.svg (+ PNG mdpi–xxxhdpi) — siluet putih, latar transparan.
- splash/splash_icon.svg — 288×288, simbol pas dalam Ø192 (splash Android 12+).
- play-store/icon-512.png — 512×512, persegi penuh, tanpa transparansi.
- legacy/ — PNG 48/72/96/144/192 untuk mipmap lama.

Pasang: konversi SVG ke VectorDrawable (Android Studio › New › Vector Asset), taruh di res/drawable, lalu res/mipmap-anydpi-v26/ic_launcher.xml memakai <background>, <foreground>, <monochrome>.
