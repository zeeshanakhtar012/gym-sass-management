abstract class FingerprintScannerService {
  Future<bool> isScannerConnected();
  Future<List<int>?> enrollFingerprint();
  Future<bool> verifyFingerprint(List<int> template);
  Future<List<int>?> captureSingleScan();
  Future<void> disconnect();
}
