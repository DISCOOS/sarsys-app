import 'package:flutter/material.dart';

/// Flutter icons SarSysIcons
/// Copyright (C) 2019 by original authors @ fluttericon.com, fontello.com
/// This font was generated by FlutterIcon.com, which is derived from Fontello.
///
/// To use this font, place it in your fonts/ directory and include the
/// following in your pubspec.yaml
///
/// flutter:
///   fonts:
///    - family:  SarSysIcons
///      fonts:
///       - asset: fonts/SarSys.ttf
///
///
///
import 'package:flutter/widgets.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class SarSysIcons {
  SarSysIcons._();

  static const _kFontFam = 'SarSysIcons';

  static const IconData forf = const IconData(0xe800, fontFamily: _kFontFam);
  static const IconData nak = const IconData(0xe801, fontFamily: _kFontFam);
  static const IconData nfs = const IconData(0xe802, fontFamily: _kFontFam);
  static const IconData nrh = const IconData(0xe803, fontFamily: _kFontFam);
  static const IconData nrrl = const IconData(0xe804, fontFamily: _kFontFam);
  static const IconData rkh = const IconData(0xe805, fontFamily: _kFontFam);
  static const IconData sbg1 = const IconData(0xe806, fontFamily: _kFontFam);
  static const IconData sbg2 = const IconData(0xe807, fontFamily: _kFontFam);
  static const IconData google = const IconData(0xe807, fontFamily: _kFontFam);

  static Icon of(
    String prefix, {
    double size = 8.0,
    bool withColor = true,
  }) {
    switch (prefix) {
      case "61":
        return Icon(
          rkh,
          color: withColor ? Color(0xffd42b1e) : null,
          size: size,
        );
      case "62":
        return Icon(
          nfs,
          color: withColor ? Color(0xff30a650) : null,
          size: size,
        );
      case "63":
        return Icon(
          nrh,
          color: withColor ? Color(0xff3d77dd) : null,
          size: size,
        );
      case "645":
        return Icon(
          nak,
          color: withColor ? Color(0xff294fa2) : null,
          size: size,
        );
      case "647":
        return Icon(
          sbg1,
          color: withColor ? Color(0xffbc352f) : null,
          size: size,
        );
      case "649":
        return Icon(
          nrrl,
          color: withColor ? Color(0xff2e5596) : null,
          size: size,
        );
      default:
        return Icon(
          MdiIcons.graph,
          size: size * 2.5,
        );
    }
  }
}
