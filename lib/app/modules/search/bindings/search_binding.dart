import 'package:get/get.dart';

import '../controllers/search_results_controller.dart';
import '../search_args.dart';

class SearchBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments;
    final searchArgs = args is SearchArgs
        ? args
        : const SearchArgs(SearchScope.quran);
    Get.lazyPut<SearchResultsController>(
      () => SearchResultsController(searchArgs),
    );
  }
}
