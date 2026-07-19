import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../errors/app_exceptions.dart';

/// A NON-zero anchor rect for the iOS share sheet. iOS rejects a zero/unset
/// `sharePositionOrigin` — even on iPhone with newer share_plus — with
/// "argument must be set … must be non-zero and within coordinate space of source
/// view". A 1x1 rect at the screen centre is always valid; the iPhone sheet is
/// modal, so the anchor point is cosmetically irrelevant.
Rect shareOriginFor(BuildContext context) {
  final size = MediaQuery.of(context).size;
  return Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
}

/// Download PDF bytes via [fetch], save them to a temp file named [filename], and
/// open the share sheet. The download and the share are handled as two phases so a
/// share-sheet problem is never reported as a failed download.
///
/// Snackbars are shown for progress + errors. Returns true only when the share
/// sheet was invoked. Pass a plain filename like `Invoice_INV-001.pdf`.
Future<bool> downloadAndSharePdf(
  BuildContext context, {
  required Future<List<int>> Function() fetch,
  required String filename,
  required String shareText,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final origin = shareOriginFor(context); // capture before any await
  messenger.showSnackBar(const SnackBar(content: Text('Preparing PDF…')));

  File file;
  try {
    final bytes = await fetch();
    if (bytes.isEmpty) throw Exception('the server returned an empty file');
    final dir = await getTemporaryDirectory();
    final safe = filename.replaceAll(RegExp(r'[^\w.-]'), '_');
    file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    final raw = (e is AppException) ? e.message : e.toString();
    messenger.showSnackBar(SnackBar(content: Text('Could not download the PDF: ${raw.isNotEmpty ? raw : 'unknown error'}')));
    return false;
  }

  messenger.hideCurrentSnackBar();
  try {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: shareText,
      sharePositionOrigin: origin,
    );
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('PDF ready but the share sheet could not open: $e')));
    return false;
  }
}
