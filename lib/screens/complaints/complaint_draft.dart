import '../../core/enums/complaint_category.dart';
import '../../core/enums/complaint_priority.dart';

class ComplaintAttachmentStub {
  const ComplaintAttachmentStub({
    required this.name,
    required this.sizeBytes,
    this.kind = 'image',
  });

  final String name;
  final int sizeBytes;
  final String kind;
}

class ComplaintDraft {
  const ComplaintDraft({
    this.propertyId,
    this.propertyName,
    this.unitId,
    this.unitNumber,
    this.tenantId,
    this.tenantName,
    this.category,
    this.title = '',
    this.description = '',
    this.priority = ComplaintPriority.medium,
    this.preferredVisitDate,
    this.preferredVisitSlot,
    this.attachments = const [],
    this.contactPhone = '',
  });

  final String? propertyId;
  final String? propertyName;
  final String? unitId;
  final String? unitNumber;
  final String? tenantId;
  final String? tenantName;
  final ComplaintCategory? category;
  final String title;
  final String description;
  final ComplaintPriority priority;
  final DateTime? preferredVisitDate;
  final String? preferredVisitSlot;
  final List<ComplaintAttachmentStub> attachments;
  final String contactPhone;

  ComplaintDraft copyWith({
    String? propertyId,
    String? propertyName,
    String? unitId,
    String? unitNumber,
    String? tenantId,
    String? tenantName,
    ComplaintCategory? category,
    String? title,
    String? description,
    ComplaintPriority? priority,
    DateTime? preferredVisitDate,
    String? preferredVisitSlot,
    List<ComplaintAttachmentStub>? attachments,
    String? contactPhone,
  }) => ComplaintDraft(
    propertyId: propertyId ?? this.propertyId,
    propertyName: propertyName ?? this.propertyName,
    unitId: unitId ?? this.unitId,
    unitNumber: unitNumber ?? this.unitNumber,
    tenantId: tenantId ?? this.tenantId,
    tenantName: tenantName ?? this.tenantName,
    category: category ?? this.category,
    title: title ?? this.title,
    description: description ?? this.description,
    priority: priority ?? this.priority,
    preferredVisitDate: preferredVisitDate ?? this.preferredVisitDate,
    preferredVisitSlot: preferredVisitSlot ?? this.preferredVisitSlot,
    attachments: attachments ?? this.attachments,
    contactPhone: contactPhone ?? this.contactPhone,
  );
}
