import 'package:flutter/widgets.dart';

class S {
  S(this.context); final BuildContext context;
  bool get th => Localizations.localeOf(context).languageCode == 'th';
  String t(String en, String thai) => th ? thai : en;
  static S of(BuildContext context) => S(context);
}
