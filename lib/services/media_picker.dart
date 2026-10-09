import '../screens/complaints/complaint_draft.dart';

abstract interface class MediaPicker {
  Future<ComplaintAttachmentStub?> pick();
}

class MockMediaPicker implements MediaPicker {
  const MockMediaPicker();

  @override
  Future<ComplaintAttachmentStub?> pick() async =>
      const ComplaintAttachmentStub(
        name: 'attachment-placeholder.jpg',
        sizeBytes: 512 * 1024,
      );
}
