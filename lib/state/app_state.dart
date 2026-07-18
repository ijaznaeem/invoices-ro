import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../db/generation_engine.dart';
import '../models/models.dart';
import '../services/backup_service.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';

/// Holds everything the UI needs and knows how to reload itself from
/// SQLite. Kept dependency-free (no state management package) — screens
/// listen to this via [AppStateScope] further down the widget tree.
class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  late final GenerationEngine _engine = GenerationEngine(_db);

  List<Client> clients = [];
  List<RecurringTemplate> templates = [];
  List<InvoiceRecord> invoices = [];
  List<AppNotification> notifications = [];
  String invoiceFilter = 'All';
  BusinessSettings businessSettings = const BusinessSettings();
  List<PaymentOption> paymentOptions = [];

  double outstanding = 0;
  int overdueCount = 0;
  int dueThisWeek = 0;
  int activeTemplateCount = 0;
  int unreadNotifications = 0;
  List<RecurringTemplate> upcoming = [];

  bool isLoading = false;

  Future<void> bootstrap() async {
    await runGenerationCheck(silent: true);
    await Future.wait([
      reloadClients(),
      reloadTemplates(),
      reloadInvoices(),
      reloadDashboard(),
      reloadBusinessSettings(),
      reloadPaymentOptions(),
    ]);
    await runBackupCheck();
  }

  Future<void> runBackupCheck() async {
    try {
      await BackupService.instance.createBackupIfDue();
    } catch (error) {
      debugPrint('Automatic backup failed: $error');
    }
  }

  Future<int> runGenerationCheck({bool silent = false}) async {
    final generated = await _engine.run();
    if (!silent) {
      await Future.wait(
          [reloadTemplates(), reloadInvoices(), reloadDashboard()]);
    }
    return generated;
  }

  Future<void> reloadClients() async {
    clients = await _db.getClients();
    notifyListeners();
  }

  Future<void> reloadTemplates() async {
    templates = await _db.getTemplates();
    notifyListeners();
  }

  Future<void> reloadInvoices() async {
    invoices = await _db.getInvoices(status: invoiceFilter);
    notifyListeners();
  }

  Future<void> setInvoiceFilter(String status) async {
    invoiceFilter = status;
    await reloadInvoices();
  }

  Future<void> reloadDashboard() async {
    final today = todayStr();
    final weekOut = addDays(today, 7);
    final results = await Future.wait([
      _db.outstandingTotal(),
      _db.overdueCount(today),
      _db.dueThisWeekCount(today, weekOut),
      _db.activeTemplatesCount(),
      _db.countUnreadNotifications(),
      _db.upcomingTemplates(),
      _db.getNotifications(),
    ]);
    outstanding = results[0] as double;
    overdueCount = results[1] as int;
    dueThisWeek = results[2] as int;
    activeTemplateCount = results[3] as int;
    unreadNotifications = results[4] as int;
    upcoming = results[5] as List<RecurringTemplate>;
    notifications = results[6] as List<AppNotification>;
    notifyListeners();
  }

  Future<void> markNotificationsRead() async {
    await _db.markAllNotificationsRead();
    await reloadDashboard();
  }

  Future<void> addClient(Client client) async {
    await _db.insertClient(client);
    await reloadClients();
  }

  Future<void> updateClient(Client client) async {
    await _db.updateClient(client);
    await Future.wait([
      reloadClients(),
      reloadTemplates(),
      reloadInvoices(),
      reloadDashboard(),
    ]);
  }

  Future<void> deleteClient(int id) async {
    await _db.deleteClient(id);
    await Future.wait([
      reloadClients(),
      reloadTemplates(),
      reloadInvoices(),
      reloadDashboard(),
    ]);
  }

  Future<Client?> getClient(int id) async {
    return _db.getClient(id);
  }

  Future<void> reloadBusinessSettings() async {
    businessSettings = await _db.getBusinessSettings();
    setMoneyCurrency(businessSettings.currencySymbol);
    notifyListeners();
  }

  Future<void> saveBusinessSettings(BusinessSettings settings) async {
    await _db.saveBusinessSettings(settings);
    await reloadBusinessSettings();
  }

  Future<void> reloadPaymentOptions() async {
    paymentOptions = await _db.getPaymentOptions();
    notifyListeners();
  }

  Future<void> addPaymentOption(PaymentOption option) async {
    await _db.insertPaymentOption(option);
    await reloadPaymentOptions();
  }

  Future<void> updatePaymentOption(PaymentOption option) async {
    await _db.updatePaymentOption(option);
    await reloadPaymentOptions();
  }

  Future<void> deletePaymentOption(int id) async {
    await _db.deletePaymentOption(id);
    await reloadPaymentOptions();
  }

  Future<void> addTemplate(RecurringTemplate template) async {
    await _db.insertTemplate(template);
    await Future.wait([reloadTemplates(), reloadDashboard()]);
  }

  Future<void> toggleTemplateStatus(RecurringTemplate template) async {
    final next = template.status == TemplateStatus.active
        ? TemplateStatus.paused
        : TemplateStatus.active;
    await _db.updateTemplateStatus(template.id!, next);
    await Future.wait([reloadTemplates(), reloadDashboard()]);
  }

  Future<void> deleteTemplate(int id) async {
    await _db.deleteTemplate(id);
    await Future.wait([reloadTemplates(), reloadDashboard()]);
  }

  Future<void> markInvoicePaid(int id) async {
    await _db.setInvoiceStatus(id, InvoiceStatus.paid);
    await Future.wait([reloadInvoices(), reloadDashboard()]);
  }

  Future<void> cancelInvoice(int id) async {
    await _db.setInvoiceStatus(id, InvoiceStatus.cancelled);
    await Future.wait([reloadInvoices(), reloadDashboard()]);
  }

  Future<void> updateInvoice(InvoiceRecord invoice) async {
    await _db.updateInvoice(invoice);
    await Future.wait([reloadInvoices(), reloadDashboard()]);
  }
}
