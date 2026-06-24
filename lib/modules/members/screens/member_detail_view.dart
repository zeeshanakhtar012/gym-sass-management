import 'dart:io';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/helpers/formatters.dart';
import '../controllers/member_model.dart';
import '../controllers/member_stats.dart';
import '../controllers/member_repository.dart';
import '../controllers/member_list_controller.dart';
import 'member_form_view.dart';
import '../../../widgets/popups/app_popup.dart';

class MemberDetailView extends StatefulWidget {
  final MemberModel? member;
  final String gymId;
  const MemberDetailView({super.key, this.member, this.gymId = ''});

  @override
  State<MemberDetailView> createState() => _MemberDetailViewState();
}

class _MemberDetailViewState extends State<MemberDetailView> {
  final MemberRepository _repository = Get.find<MemberRepository>();
  late final MemberModel _member;
  MemberStats? _stats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _member = widget.member ?? (Get.arguments as MemberModel);
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _repository.getMemberStats(_member.memberId);
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
    } catch (_) {
      setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = _member;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              onPressed: () => Get.back(),
            ),
            title: Text(member.fullName),
            actions: [
              IconButton(
                icon: const Icon(PhosphorIconsRegular.downloadSimple),
                tooltip: 'Download PDF Report',
                onPressed: () => _downloadMemberPdf(member),
              ),
            ],
            bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Attendance'),
              Tab(text: 'Payments'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOverviewTab(member),
            _buildAttendanceTab(member),
            _buildPaymentsTab(member),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(MemberModel member) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(member),
          const SizedBox(height: AppSpacing.md),
          if (_isLoadingStats)
            const Center(child: CircularProgressIndicator())
          else if (_stats != null)
            _buildStatsGrid(_stats!),
          const SizedBox(height: AppSpacing.md),
          _buildPersonalInfoCard(member),
          const SizedBox(height: AppSpacing.md),
          _buildMembershipCard(member),
          const SizedBox(height: AppSpacing.md),
          _buildPhysicalStatsCard(member),
          if (member.qrData != null && member.qrData!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildQrDataCard(member),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildActionButtons(member),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(MemberModel member) {
    final expiryDays = member.expiryDate != null
        ? DateTime.parse(member.expiryDate!).difference(DateTime.now()).inDays
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _buildAvatar(member, radius: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName, style: AppTextStyles.headingMd),
                  if (member.phone != null)
                    Text(
                      Formatters.phone(member.phone!),
                      style: AppTextStyles.bodySm,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildStatusBadge(member.status),
                ],
              ),
            ),
            if (expiryDays != null)
              Column(
                children: [
                  Text(
                    expiryDays >= 0 ? '$expiryDays' : '---',
                    style: AppTextStyles.displayLg.copyWith(
                      color: expiryDays < 0
                          ? AppColors.danger
                          : AppColors.primary,
                      fontSize: 28,
                    ),
                  ),
                  Text(
                    expiryDays >= 0 ? 'days left' : 'expired',
                    style: AppTextStyles.bodySm.copyWith(
                      color: expiryDays < 0 ? AppColors.danger : null,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(MemberStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance Summary', style: AppTextStyles.headingSm),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _miniStat(
                  'This Month',
                  '${stats.currentMonthAttendance}',
                  AppColors.primary,
                ),
                _miniStat(
                  'Last Month',
                  '${stats.previousMonthAttendance}',
                  AppColors.info,
                ),
                _miniStat(
                  'Lifetime',
                  '${stats.lifetimeAttendance}',
                  AppColors.success,
                ),
                _miniStat(
                  'Avg/Month',
                  stats.avgVisitsPerMonth.toStringAsFixed(1),
                  AppColors.info,
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Text('Payment Summary', style: AppTextStyles.headingSm),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _miniStat(
                  'Total Paid',
                  Formatters.currency(stats.totalPaid),
                  AppColors.success,
                ),
                _miniStat(
                  'Total Due',
                  Formatters.currency(stats.totalDue),
                  AppColors.warning,
                ),
                _miniStat(
                  'Last Payment',
                  stats.lastPaymentDate != null
                      ? Formatters.shortDate(stats.lastPaymentDate)
                      : 'N/A',
                  AppColors.info,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      width: (Get.width - AppSpacing.md * 4) / 2,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.headingSm.copyWith(color: color, fontSize: 18),
          ),
          Text(label, style: AppTextStyles.bodySm),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard(MemberModel member) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.userCircle,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Personal Information', style: AppTextStyles.headingSm),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _detailRow(
              PhosphorIconsRegular.user,
              'Father Name',
              member.fatherName ?? '-',
            ),
            _detailRow(
              PhosphorIconsRegular.identificationCard,
              'CNIC',
              member.cnic ?? '-',
            ),
            _detailRow(
              PhosphorIconsRegular.genderIntersex,
              'Gender',
              member.gender ?? '-',
            ),
            _detailRow(
              PhosphorIconsRegular.calendar,
              'Joining Date',
              member.dob != null
                  ? Formatters.shortDate(DateTime.tryParse(member.dob!))
                  : '-',
            ),
            _detailRow(PhosphorIconsRegular.mapPin, 'Address', member.address ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipCard(MemberModel member) {
    final expiryDays = member.expiryDate != null
        ? DateTime.parse(member.expiryDate!).difference(DateTime.now()).inDays
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.identificationBadge,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Membership', style: AppTextStyles.headingSm),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _detailRow(PhosphorIconsRegular.tag, 'Package', member.packageId ?? '-'),
            _detailRow(
              PhosphorIconsRegular.calendar,
              'Start Date',
              member.startDate != null
                  ? Formatters.shortDate(DateTime.tryParse(member.startDate!))
                  : '-',
            ),
            _detailRow(
              PhosphorIconsRegular.clock,
              'Expiry Date',
              member.expiryDate != null
                  ? Formatters.shortDate(DateTime.tryParse(member.expiryDate!))
                  : '-',
            ),
            _detailRow(
              PhosphorIconsRegular.hourglass,
              'Remaining',
              expiryDays != null ? Formatters.remainingDays(expiryDays) : '-',
              valueColor: expiryDays != null && expiryDays < 0
                  ? AppColors.danger
                  : null,
            ),
            _detailRow(
              PhosphorIconsRegular.calendar,
              'Registered',
              Formatters.shortDate(DateTime.tryParse(member.registrationDate)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysicalStatsCard(MemberModel member) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.heart,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Physical Stats', style: AppTextStyles.headingSm),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            _detailRow(
              PhosphorIconsRegular.ruler,
              'Height',
              member.height != null ? '${member.height} cm' : '-',
            ),
            _detailRow(
              PhosphorIconsRegular.scales,
              'Weight',
              member.weight != null ? '${member.weight} kg' : '-',
            ),
            _detailRow(
              PhosphorIconsRegular.heart,
              'BMI',
              member.bmi != null ? member.bmi!.toStringAsFixed(1) : '-',
            ),
            _detailRow(
              PhosphorIconsRegular.target,
              'Fitness Goal',
              member.fitnessGoal ?? '-',
            ),
            _detailRow(
              PhosphorIconsRegular.fingerprint,
              'Fingerprint',
              member.fingerprintImage != null ? 'Registered' : 'Not Registered',
              valueColor: member.fingerprintImage != null
                  ? AppColors.success
                  : AppColors.textSecondaryD,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrDataCard(MemberModel member) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.qrCode,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('QR Data', style: AppTextStyles.headingSm),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: SelectableText(
                member.qrData!,
                style: AppTextStyles.bodyMd.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(MemberModel member) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditForm(member),
                    icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.info,
                      side: const BorderSide(color: AppColors.info),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(member),
                    icon: const Icon(PhosphorIconsRegular.trash, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markAttendance(member),
                    icon: const Icon(PhosphorIconsRegular.fingerprint, size: 18),
                    label: const Text('Mark Attendance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewPayments(member),
                    icon: const Icon(PhosphorIconsRegular.coin, size: 18),
                    label: const Text('View Payments'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _downloadMemberPdf(member),
                icon: const Icon(PhosphorIconsRegular.downloadSimple, size: 18),
                label: const Text('Download PDF Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondaryD),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 100,
            child: Text('$label:', style: AppTextStyles.bodySm),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMd.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab(MemberModel member) {
    return _stats != null
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Details',
                          style: AppTextStyles.headingSm,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _detailRow(
                          PhosphorIconsRegular.calendarCheck,
                          'This Month',
                          '${_stats!.currentMonthAttendance}',
                        ),
                        _detailRow(
                          PhosphorIconsRegular.calendar,
                          'Last Month',
                          '${_stats!.previousMonthAttendance}',
                        ),
                        _detailRow(
                          PhosphorIconsRegular.clock,
                          'Lifetime',
                          '${_stats!.lifetimeAttendance}',
                        ),
                        _detailRow(
                          PhosphorIconsRegular.trendUp,
                          'Avg/Month',
                          _stats!.avgVisitsPerMonth.toStringAsFixed(1),
                        ),
                        if (_stats!.lastVisit != null)
                          _detailRow(
                            PhosphorIconsRegular.clock,
                            'Last Visit',
                            Formatters.shortDate(_stats!.lastVisit),
                          ),
                        _detailRow(
                          PhosphorIconsRegular.checkCircle,
                          'Attendance %',
                          Formatters.attendancePercent(
                            _stats!.lifetimeAttendance,
                            _stats!.totalVisits,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : const Center(child: Text('No attendance data available'));
  }

  Widget _buildPaymentsTab(MemberModel member) {
    return _stats != null
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Details', style: AppTextStyles.headingSm),
                        const SizedBox(height: AppSpacing.md),
                        _detailRow(
                          PhosphorIconsRegular.coin,
                          'Total Paid',
                          Formatters.currency(_stats!.totalPaid),
                        ),
                        _detailRow(
                          PhosphorIconsRegular.warningCircle,
                          'Total Due',
                          Formatters.currency(_stats!.totalDue),
                        ),
                        if (_stats!.lastPaymentDate != null)
                          _detailRow(
                            PhosphorIconsRegular.calendar,
                            'Last Payment',
                            Formatters.shortDate(_stats!.lastPaymentDate),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : const Center(child: Text('No payment data available'));
  }

  Future<void> _downloadMemberPdf(MemberModel member) async {
    log('[MemberDetail] _downloadMemberPdf called for ${member.memberId}');
    try {
      final db = await DatabaseHelper.instance.database;

      final attendanceRows = await db.query('attendance',
        where: 'member_id = ?',
        whereArgs: [member.memberId],
        orderBy: 'date DESC',
        limit: 200,
      );

      final paymentRows = await db.query('payments',
        where: 'member_id = ?',
        whereArgs: [member.memberId],
        orderBy: 'payment_date DESC',
        limit: 200,
      );

      final nowStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

      final pdf = pw.Document();

      // Page 1: Overview — personal info, membership, stats
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text('Member Report',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text(member.fullName,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Generated: $nowStr',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
              pw.Divider(),

              pw.Header(level: 1, text: 'Personal Information'),
              _pdfRow('Name', member.fullName),
              _pdfRow('Father Name', member.fatherName ?? '-'),
              _pdfRow('Phone', member.phone ?? '-'),
              _pdfRow('CNIC', member.cnic ?? '-'),
              _pdfRow('Gender', member.gender ?? '-'),
              _pdfRow('Address', member.address ?? '-'),
              _pdfRow('Registered', Formatters.shortDate(DateTime.tryParse(member.registrationDate))),
              pw.SizedBox(height: 8),

              pw.Header(level: 1, text: 'Membership'),
              _pdfRow('Package', member.packageId ?? '-'),
              _pdfRow('Status', member.status.toUpperCase()),
              _pdfRow('Start Date', member.startDate != null ? Formatters.shortDate(DateTime.tryParse(member.startDate!)) : '-'),
              _pdfRow('Expiry Date', member.expiryDate != null ? Formatters.shortDate(DateTime.tryParse(member.expiryDate!)) : '-'),
              if (member.expiryDate != null)
                _pdfRow('Remaining', Formatters.remainingDays(
                    DateTime.parse(member.expiryDate!).difference(DateTime.now()).inDays)),
              pw.SizedBox(height: 8),

              pw.Header(level: 1, text: 'Physical Stats'),
              _pdfRow('Height', member.height != null ? '${member.height} cm' : '-'),
              _pdfRow('Weight', member.weight != null ? '${member.weight} kg' : '-'),
              _pdfRow('BMI', member.bmi != null ? member.bmi!.toStringAsFixed(1) : '-'),
              _pdfRow('Fitness Goal', member.fitnessGoal ?? '-'),
              pw.SizedBox(height: 8),

              if (_stats != null) ...[
                pw.Header(level: 1, text: 'Attendance Summary'),
                _pdfRow('This Month', '${_stats!.currentMonthAttendance}'),
                _pdfRow('Last Month', '${_stats!.previousMonthAttendance}'),
                _pdfRow('Lifetime', '${_stats!.lifetimeAttendance}'),
                _pdfRow('Avg / Month', _stats!.avgVisitsPerMonth.toStringAsFixed(1)),
                if (_stats!.lastVisit != null)
                  _pdfRow('Last Visit', Formatters.shortDate(_stats!.lastVisit)),
                _pdfRow('Attendance %', Formatters.attendancePercent(
                    _stats!.lifetimeAttendance, _stats!.totalVisits)),
                pw.SizedBox(height: 8),

                pw.Header(level: 1, text: 'Payment Summary'),
                _pdfRow('Total Paid', Formatters.currency(_stats!.totalPaid)),
                _pdfRow('Total Due', Formatters.currency(_stats!.totalDue)),
                if (_stats!.lastPaymentDate != null)
                  _pdfRow('Last Payment', Formatters.shortDate(_stats!.lastPaymentDate)),
              ],
            ];
          },
        ),
      );

      // Page 2: Attendance records
      if (attendanceRows.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(32),
            build: (context) => [
              pw.Header(level: 1, text: 'Attendance Records'),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: pw.TextStyle(fontSize: 9),
                headers: ['Date', 'Check In', 'Check Out', 'Method'],
                data: attendanceRows.map((r) => [
                  r['date'] as String? ?? '',
                  (r['check_in'] as String? ?? '').substring(0, 5),
                  r['check_out'] != null
                      ? (r['check_out'] as String).substring(0, 5)
                      : '-',
                  r['method'] as String? ?? 'manual',
                ]).toList(),
              ),
            ],
          ),
        );
      }

      // Page 3: Payment records
      if (paymentRows.isNotEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(32),
            build: (context) => [
              pw.Header(level: 1, text: 'Payment Records'),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: pw.TextStyle(fontSize: 9),
                headers: ['Date', 'Method', 'Amount', 'Discount', 'Tax', 'Total', 'Remarks'],
                data: paymentRows.map((p) => [
                  p['payment_date'] as String? ?? '',
                  p['method'] as String? ?? '-',
                  Formatters.currency(p['amount'] as int? ?? 0),
                  Formatters.currency(p['discount'] as int? ?? 0),
                  Formatters.currency(p['tax'] as int? ?? 0),
                  Formatters.currency(p['total'] as int? ?? 0),
                  p['remarks'] as String? ?? '',
                ]).toList(),
              ),
            ],
          ),
        );
      }

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${member.fullName.replaceAll(' ', '_')}_Report.pdf',
      );
      log('[MemberDetail] _downloadMemberPdf successful');
    } catch (e, stack) {
      log('[MemberDetail] _downloadMemberPdf failed: $e');
      log('[MemberDetail] stack: $stack');
      AppPopup.error('Failed to generate PDF: $e');
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildAvatar(MemberModel member, {double radius = 24}) {
    if (member.photoPath != null && member.photoPath!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(member.photoPath!)),
        onBackgroundImageError: (_, __) {},
        child: const Icon(PhosphorIconsRegular.user),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySurface,
      child: const Icon(PhosphorIconsRegular.user, color: AppColors.primary),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = AppColors.success;
      case 'expired':
        color = AppColors.danger;
      case 'paused':
        color = AppColors.warning;
      case 'blocked':
        color = AppColors.neutralGray;
      default:
        color = AppColors.neutralGray;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        status.toUpperCase(),
        style: AppTextStyles.bodySm.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _markAttendance(MemberModel member) async {
    final db = await DatabaseHelper.instance.database;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateFormat('HH:mm').format(DateTime.now());

    final existing = await db.query('attendance',
      where: 'gym_id = ? AND member_id = ? AND date = ? AND check_out IS NULL',
      whereArgs: [widget.gymId, member.memberId, today],
    );

    if (existing.isNotEmpty) {
      final checkedInAt = existing.first['check_in'] as String? ?? '';
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Already Checked In'),
          content: Text(
            '${member.fullName} checked in at $checkedInAt.\nDo you want to check out?',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              style: TextButton.styleFrom(foregroundColor: AppColors.warning),
              child: const Text('Check Out'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await db.update(
          'attendance',
          {'check_out': now},
          where: 'attendance_id = ?',
          whereArgs: [existing.first['attendance_id']],
        );
        AppPopup.success('${member.fullName} checked out at $now');
      }
    } else {
      await db.insert('attendance', {
        'gym_id': widget.gymId,
        'member_id': member.memberId,
        'date': today,
        'check_in': now,
        'method': 'manual',
        'created_at': DateTime.now().toIso8601String(),
      });
      AppPopup.success('${member.fullName} checked in at $now');
    }
  }

  void _viewPayments(MemberModel member) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('payments',
      where: 'member_id = ?',
      whereArgs: [member.memberId],
      orderBy: 'created_at DESC',
    );

    if (rows.isEmpty) {
      AppPopup.info('No payment records found for ${member.fullName}');
      return;
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payments', style: AppTextStyles.headingSm),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.x, size: 20),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              member.fullName,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondaryD,
              ),
            ),
            const Divider(height: AppSpacing.lg),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final p = rows[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySurface,
                        child: Icon(
                          PhosphorIconsRegular.coin,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        Formatters.currency(p['total'] as int? ?? 0),
                        style: AppTextStyles.bodyMd.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${p['method'] ?? '-'}  •  ${Formatters.shortDate(DateTime.tryParse(p['payment_date'] as String? ?? ''))}',
                        style: AppTextStyles.bodySm,
                      ),
                      trailing: p['remarks'] != null && (p['remarks'] as String).isNotEmpty
                          ? Tooltip(
                              message: p['remarks'] as String,
                              child: Icon(
                                PhosphorIconsRegular.note,
                                size: 16,
                                color: AppColors.textSecondaryD,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(MemberModel member) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Member'),
        content: Text(
          'Are you sure you want to delete "${member.fullName}"?\nAll related data will be permanently removed.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Get.back();
              Get.find<MemberListController>().deleteMember(member.memberId);
              Get.back();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openEditForm(MemberModel member) async {
    final result = await Get.to(
      () => MemberFormView(gymId: widget.gymId, member: member),
    );
    if (result == true) {
      setState(() {});
      _loadStats();
    }
  }
}
