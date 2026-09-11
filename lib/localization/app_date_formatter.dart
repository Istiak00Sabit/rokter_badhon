import 'package:get/get.dart';
import 'package:intl/intl.dart';

class AppDateFormatter {
  static String get _locale => Get.locale?.languageCode == 'en' ? 'en' : 'bn';

  static String short(DateTime value) =>
      DateFormat.yMMMd(_locale).format(value);

  static String long(DateTime value) =>
      DateFormat.yMMMMd(_locale).format(value);

  static String dateTime(DateTime value) =>
      DateFormat.yMMMMd(_locale).add_jm().format(value);
}
