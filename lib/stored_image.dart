import 'dart:convert';
import 'package:flutter/material.dart';

/// Persisted pictures are data URIs in SQLite/IndexedDB, never temporary blobs.
Image storedImage(
  String source, {
  double? width,
  double? height,
  int? cacheWidth,
  BoxFit? fit,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  if (source.startsWith('data:')) {
    return Image.memory(
      UriData.parse(source).contentAsBytes(),
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
  return Image.network(
    source,
    width: width,
    height: height,
    cacheWidth: cacheWidth,
    fit: fit,
    errorBuilder: errorBuilder,
  );
}

String imageDataUri(List<int> bytes, String mime) =>
    'data:$mime;base64,${base64Encode(bytes)}';
