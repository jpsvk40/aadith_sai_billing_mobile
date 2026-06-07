import '../network/api_client.dart';
import '../models/scanned_bill_model.dart';
import '../../core/constants/api_constants.dart';

class AiScanRepository {
  final ApiClient _client;
  AiScanRepository(this._client);

  /// Uploads a bill image to the AI scanner and returns the extracted fields.
  Future<ScannedBill> scanVendorBill(String filePath) async {
    final data = await _client.uploadFile(ApiConstants.scanVendorBill, filePath);
    return ScannedBill.fromJson(data as Map<String, dynamic>);
  }
}
