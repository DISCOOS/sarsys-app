// The MIT License (MIT)
//
// Copyright (c) 2018 Alif Rachmawadi <arch@subosito.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
// Copied from https://github.com/subosito/simple_gravatar | 17. April 2021
//

import 'dart:convert';
import 'package:crypto/crypto.dart';

enum GravatarImage {
  nf, // 404
  mp, // mystery person
  identicon,
  monsterid,
  wavatar,
  retro,
  robohash,
  blank,
}

enum GravatarRating {
  g,
  pg,
  r,
  x,
}

class Gravatar {
  final String email;
  final String hash;

  Gravatar(this.email) : this.hash = _generateHash(email);

  static String _generateHash(String email) {
    String preparedEmail = email.trim().toLowerCase();
    return md5.convert(utf8.encode(preparedEmail)).toString();
  }

  String imageUrl({
    int size,
    GravatarImage defaultImage,
    bool forceDefault = false,
    bool fileExtension = false,
    GravatarRating rating,
  }) {
    String hashDigest = hash;
    Map<String, String> query = {};

    if (size != null) query['s'] = size.toString();
    if (defaultImage != null) query['d'] = _imageString(defaultImage);
    if (forceDefault) query['f'] = 'y';
    if (rating != null) query['r'] = _ratingString(rating);
    if (fileExtension) hashDigest += '.png';
    if (query.isEmpty) query = null;

    return Uri.https('www.gravatar.com', '/avatar/$hashDigest', query).toString();
  }

  String jsonUrl() {
    return Uri.https('www.gravatar.com', '/$hash.json').toString();
  }

  String qrUrl() {
    return Uri.https('www.gravatar.com', '/$hash.qr').toString();
  }

  String toString() {
    return imageUrl();
  }

  String _imageString(GravatarImage value) {
    switch (value) {
      case GravatarImage.nf:
        return '404';
      case GravatarImage.mp:
        return 'mp';
      case GravatarImage.identicon:
        return 'identicon';
      case GravatarImage.monsterid:
        return 'monsterid';
      case GravatarImage.wavatar:
        return 'wavatar';
      case GravatarImage.retro:
        return 'retro';
      case GravatarImage.robohash:
        return 'robohash';
      case GravatarImage.blank:
        return 'blank';
    }

    return '';
  }

  String _ratingString(GravatarRating value) {
    switch (value) {
      case GravatarRating.g:
        return 'g';
      case GravatarRating.pg:
        return 'pg';
      case GravatarRating.r:
        return 'r';
      case GravatarRating.x:
        return 'x';
    }

    return '';
  }
}
