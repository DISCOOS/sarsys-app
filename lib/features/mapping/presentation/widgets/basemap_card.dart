

import 'dart:io';

import 'package:SarSys/core/domain/models/BaseMap.dart';
import 'package:flutter/material.dart';

class BaseMapCard extends StatelessWidget {
  final BaseMap? map;

  BaseMapCard({this.map});

  Image toImage() {
    String basePath = "assets/mapspreview";
    // TODO: Check if file exists in filesystem before returning
    if (map!.previewFile != null && !map!.offline!) {
      // Online maps preview image is distributed in assets
      // Should be moved to documents folder if list of online maps is a downloadable config
      return Image(image: AssetImage("$basePath/${map!.previewFile}"));
    } else if (map!.previewFile != null && map!.offline!) {
      // Offline maps must be read from SDCard
      return Image.file(File(map!.previewFile!));
    } else {
      return Image(image: AssetImage("$basePath/missing.png"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      //clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.all(2.0),
      //elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: toImage(),
                ),
              ),
              Text(
                map!.description ?? map!.name!,
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            ]),
      ),
    );
  }
}
