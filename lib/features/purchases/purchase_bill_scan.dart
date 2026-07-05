import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/app_colors.dart';
import '../../data/network/api_client.dart';
import '../../data/repositories/ai_scan_repository.dart';
import '../auth/providers/auth_provider.dart';
import 'screens/purchase_create_screen.dart';

/// AI bill scanner entry — pick a photo (camera/gallery) of a vendor invoice,
/// run it through /api/ai/scan-vendor-bill, then open the New Purchase form
/// prefilled with the extracted vendor, header, line items and width allocations.
///
/// The backend performs the Bero-specific guards (buyer-GSTIN match, sales-invoice
/// detection, variant/width extraction); this surfaces those results/errors.
Future<void> launchBillScan(BuildContext context, WidgetRef ref) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(children: [
            Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Scan vendor bill', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(42, 0, 16, 8),
          child: Align(alignment: Alignment.centerLeft, child: Text('AI reads the vendor, invoice, items & GST', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted))),
        ),
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
          title: const Text('Take a photo'),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
          title: const Text('Choose from gallery'),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (source == null || !context.mounted) return;

  final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2400);
  if (picked == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ScanningDialog(),
  );

  final client = ApiClient.getInstance(onUnauthorized: () => ref.read(authProvider.notifier).logout());
  try {
    final scanned = await AiScanRepository(client).scanVendorBill(picked.path);
    // Build an inline data URL so the original image is stored with the purchase.
    String? dataUrl;
    try {
      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      dataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
    } catch (_) {/* image attach is optional */}

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close scanning dialog

    if (!scanned.hasItems && (scanned.vendorName == null || scanned.vendorName!.trim().isEmpty)) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not read this bill. Try a clearer, straight photo.')));
      return;
    }
    context.push('/purchases/create', extra: PurchasePrefill(scanned: scanned, imageDataUrl: dataUrl));
  } catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    final raw = (e is AppException) ? e.message : e.toString();
    final s = raw.toLowerCase();
    final msg = s.contains('sales invoice')
        ? 'This looks like your own sales invoice, not a vendor bill. Use the Sales scanner instead.'
        : (s.contains('gstin') && s.contains('match'))
            ? "The buyer GSTIN on this bill doesn't match your company. It may be addressed to a different firm."
            : s.contains('not configured')
                ? 'AI scanning isn\'t configured on the server yet.'
                : raw.isNotEmpty
                    ? 'Scan failed: $raw'
                    : 'Could not scan the bill.';
    messenger.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
  }
}

class _ScanningDialog extends StatelessWidget {
  const _ScanningDialog();
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary)),
          SizedBox(height: 16),
          Text('Reading the bill…', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Extracting vendor, items & GST', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}
