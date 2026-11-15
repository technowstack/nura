import 'package:get/get.dart';

import '../../../core/errors.dart';
import '../../../core/format_thousands.dart';
import '../../../core/ui_state.dart';
import '../../../data/models/hadith_book.dart';
import '../../../data/repositories/hadith_repository.dart';

/// Display model for one book row: the view only renders these strings.
class HadithBookItem {
  const HadithBookItem(this.book, this.countLabel);

  final HadithBook book;
  final String countLabel;
}

class HadithBooksController extends GetxController {
  final HadithRepository _hadith = Get.find();

  final books = Rx<UiState<List<HadithBookItem>>>(const UiLoading());

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void load() {
    books.value = const UiLoading();
    // Deferred so the loading state is rendered before the data.
    Future.microtask(_read);
  }

  Future<void> _read() async {
    try {
      final rows = [...await _hadith.listBooks()]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      books.value = rows.isEmpty
          ? const UiEmpty()
          : UiData([
              for (final b in rows)
                HadithBookItem(b, '${formatThousands(b.hadithCount)} hadis'),
            ]);
    } on ContentUnavailable {
      books.value = const UiError('Konten tidak dapat dibaca.');
    }
  }
}
