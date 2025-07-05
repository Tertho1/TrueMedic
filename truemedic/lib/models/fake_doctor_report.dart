class FakeDoctorReport {
  final String id;
  final String? reporterId;
  final String doctorBmdcNumber;
  final String reportType;
  final String description;
  final List<String> evidenceUrls;
  final String status;
  final bool isAnonymous;
  final DateTime createdAt;
  final DateTime updatedAt;

  FakeDoctorReport({
    required this.id,
    this.reporterId,
    required this.doctorBmdcNumber,
    required this.reportType,
    required this.description,
    required this.evidenceUrls,
    required this.status,
    required this.isAnonymous,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FakeDoctorReport.fromJson(Map<String, dynamic> json) {
    return FakeDoctorReport(
      id: json['id'],
      reporterId: json['reporter_id'],
      doctorBmdcNumber: json['doctor_bmdc_number'],
      reportType: json['report_type'],
      description: json['description'],
      evidenceUrls: List<String>.from(json['evidence_urls'] ?? []),
      status: json['status'],
      isAnonymous: json['is_anonymous'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reporter_id': reporterId,
      'doctor_bmdc_number': doctorBmdcNumber,
      'report_type': reportType,
      'description': description,
      'evidence_urls': evidenceUrls,
      'is_anonymous': isAnonymous,
    };
  }
}