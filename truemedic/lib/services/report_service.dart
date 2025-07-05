import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fake_doctor_report.dart';
import '../models/report_category.dart';

class ReportService {
  final _supabase = Supabase.instance.client;

  // Get report categories
  Future<List<ReportCategory>> getReportCategories() async {
    final response = await _supabase
        .from('report_categories')
        .select()
        .eq('is_active', true)
        .order('name');

    return response.map((json) => ReportCategory.fromJson(json)).toList();
  }

  // Submit a fake doctor report
  Future<FakeDoctorReport> submitReport({
    String? reporterId,
    required String doctorBmdcNumber,
    required String reportType,
    required String description,
    List<String> evidenceUrls = const [],
    bool isAnonymous = false,
  }) async {
    final reportData = {
      'reporter_id': isAnonymous ? null : reporterId,
      'doctor_bmdc_number': doctorBmdcNumber,
      'report_type': reportType,
      'description': description,
      'evidence_urls': evidenceUrls,
      'is_anonymous': isAnonymous,
    };

    final response =
        await _supabase
            .from('fake_doctor_reports')
            .insert(reportData)
            .select()
            .single();

    return FakeDoctorReport.fromJson(response);
  }

  // Get user's reports
  Future<List<FakeDoctorReport>> getUserReports(String userId) async {
    final response = await _supabase
        .from('fake_doctor_reports')
        .select()
        .eq('reporter_id', userId)
        .order('created_at', ascending: false);

    return response.map((json) => FakeDoctorReport.fromJson(json)).toList();
  }

  // Get all reports (for admin)
  Future<List<FakeDoctorReport>> getAllReports({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _supabase.from('fake_doctor_reports').select();

    // Apply filter BEFORE sorting
    if (status != null) {
      query = query.eq('status', status);
    }

    // Now apply sorting and pagination
    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map((json) => FakeDoctorReport.fromJson(json)).toList();
  }

  // Update report status (for admin)
  Future<void> updateReportStatus(String reportId, String status) async {
    await _supabase
        .from('fake_doctor_reports')
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reportId);
  }
}
