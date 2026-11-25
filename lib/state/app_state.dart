import 'dart:async';

import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../db/generation_engine.dart';
import '../models/models.dart';
import '../services/backup_service.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';

/// Holds everything the UI needs and knows how to reload itself from
/// Firestore. Kept dependency-free (no state management package) — screens
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
  List<TaxRate> taxRates = [];
  List<ExpenseHead> expenseHeads = [];
  List<ExpenseRecord> expenses = [];
  List<CashReceipt> cashReceipts = [];
  List<LedgerEntry> ledgerEntries = [];
  Map<String, double> ledgerBalances = {};

  double outstanding = 0;
  double cashReceivedTotal = 0;
  double expensesTotalAmount = 0;
  int overdueCount = 0;
  int dueThisWeek = 0;
  int activeTemplateCount = 0;
  int unreadNotifications = 0;
  List<RecurringTemplate> upcoming = [];
  Map<String, int> invoiceStatusCounts = {};
  List<MonthlyAmount> monthlyInvoiced = [];
  List<MonthlyAmount> monthlyExpenses = [];
  List<MonthlyAmount> monthlyCash = [];

  bool isLoading = false;
  String? lastError;
  Timer? _reloadTimer;
  bool _listening = false;

  void _onDatabaseChanged() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 150), () async {
      try {
        await reloadAll();
        lastError = null;
      } catch (error) {
        lastError = '$error';
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _reloadTimer?.cancel();
    if (_listening) _db.removeChangeListener(_onDatabaseChanged);
    super.dispose();
  }

  Future<void> bootstrap() async {
    if (!_listening) {
      _db.addChangeListener(_onDatabaseChanged);
      _listening = true;
    }
    try {
      await runGenerationCheck(silent: true);
    } catch (_) {
      lastError =
          'Recurring invoices could not be checked. Connect to the internet and refresh to try again.';
    }
    await reloadAll();
    await runBackupCheck();
  }

  Future<void> reloadAll() async {
    await Future.wait([
      reloadClients(),
      reloadTemplates(),
      reloadInvoices(),
      reloadDashboard(),
      reloadBusinessSettings(),
      reloadPaymentOptions(),
      reloadTaxRates(),
      reloadExpenseHeads(),
      reloadExpenses(),
      reloadCashReceipts(),
      reloadLedger(),
    ]);
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
      await Future.wait([
        reloadTemplates(),
        reloadInvoices(),
        reloadDashboard(),
        reloadLedger(),
      ]);
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
      _db.invoiceStatusCounts(),
      _db.monthlyInvoiceTotals(),
      _db.monthlyExpenseTotals(),
      _db.monthlyCashReceived(),
      _db.cashReceiptsTotal(),
      _db.expensesTotal(),
    ]);
    outstanding = results[0] as double;
    overdueCount = results[1] as int;
    dueThisWeek = results[2] as int;
    activeTemplateCount = results[3] as int;
    unreadNotifications = results[4] as int;
    upcoming = results[5] as List<RecurringTemplate>;
    notifications = results[6] as List<AppNotification>;
    invoiceStatusCounts = results[7] as Map<String, int>;
    monthlyInvoiced = results[8] as List<MonthlyAmount>;
    monthlyExpenses = results[9] as List<MonthlyAmount>;
    monthlyCash = results[10] as List<MonthlyAmount>;
    cashReceivedTotal = results[11] as double;
    expensesTotalAmount = results[12] as double;
    notifyListeners();
  }

  Future<void> markNotificationsRead() async {
    await _db.markAllNotificationsRead();
    await reloadDashboard();
  }

  Future<Client> addClient(Client client) async {
    final saved = await _db.insertClient(client);
    await reloadClients();
    return saved;
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

  Future<Client?> getClient(int? id) async {
    if (id == null) return null;
    return _db.getClient(id);
  }

  Future<void> addInvoice(InvoiceRecord invoice) async {
    await _db.insertInvoice(invoice);
    await Future.wait([
      reloadInvoices(),
      reloadDashboard(),
      reloadLedger(),
    ]);
  }

  Future<String> nextInvoiceNumber(String issueDate) async {
    return _db.nextInvoiceNumber(issueDate);
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

  Future<void> reloadTaxRates() async {
    taxRates = await _db.getTaxRates();
    notifyListeners();
  }

  Future<void> addTaxRate(TaxRate rate) async {
    await _db.insertTaxRate(rate);
    await reloadTaxRates();
  }

  Future<void> updateTaxRate(TaxRate rate) async {
    await _db.updateTaxRate(rate);
    await reloadTaxRates();
  }

  Future<void> deleteTaxRate(int id) async {
    await _db.deleteTaxRate(id);
    await reloadTaxRates();
  }

  TaxRate get defaultTaxRate {
    final zero = taxRates.where((t) => t.ratePercent == 0);
    if (zero.isNotEmpty) return zero.first;
    if (taxRates.isNotEmpty) return taxRates.first;
    return const TaxRate(name: 'No Tax', ratePercent: 0);
  }

  Future<void> reloadExpenseHeads() async {
    expenseHeads = await _db.getExpenseHeads();
    notifyListeners();
  }

  Future<void> addExpenseHead(ExpenseHead head) async {
    await _db.insertExpenseHead(head);
    await reloadExpenseHeads();
  }

  Future<void> updateExpenseHead(ExpenseHead head) async {
    await _db.updateExpenseHead(head);
    await reloadExpenseHeads();
  }

  Future<void> deleteExpenseHead(int id) async {
    await _db.deleteExpenseHead(id);
    await Future.wait(
        [reloadExpenseHeads(), reloadExpenses(), reloadDashboard()]);
  }

  Future<void> reloadExpenses() async {
    expenses = await _db.getExpenses();
    notifyListeners();
  }

  Future<void> addExpense(ExpenseRecord expense) async {
    await _db.insertExpense(expense);
    await Future.wait([
      reloadExpenses(),
      reloadLedger(),
      reloadDashboard(),
    ]);
  }

  Future<void> deleteExpense(int id) async {
    await _db.deleteExpense(id);
    await Future.wait([reloadExpenses(), reloadDashboard()]);
  }

  Future<void> reloadCashReceipts() async {
    cashReceipts = await _db.getCashReceipts();
    notifyListeners();
  }

  Future<void> addCashReceipt(CashReceipt receipt) async {
    await _db.insertCashReceipt(receipt);
    await Future.wait([
      reloadCashReceipts(),
      reloadLedger(),
      reloadDashboard(),
    ]);
  }

  Future<void> deleteCashReceipt(int id) async {
    await _db.deleteCashReceipt(id);
    await Future.wait([reloadCashReceipts(), reloadDashboard()]);
  }

  Future<void> reloadLedger() async {
    ledgerEntries = await _db.getLedgerEntries();
    ledgerBalances = await _db.ledgerAccountBalances();
    notifyListeners();
  }

  Future<List<LedgerEntry>> ledgerEntriesForAccount(String account) {
    return _db.getLedgerEntriesForAccount(account);
  }

  Future<({List<CashReceipt> receipts, List<ExpenseRecord> expenses})>
      cashReportForMonth(String monthKey) async {
    final results = await Future.wait([
      _db.getCashReceiptsForMonth(monthKey),
      _db.getExpensesForMonth(monthKey),
    ]);
    return (
      receipts: results[0] as List<CashReceipt>,
      expenses: results[1] as List<ExpenseRecord>,
    );
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

  /// Records a (possibly partial) payment against an invoice.
  Future<void> recordInvoicePayment({
    required InvoiceRecord invoice,
    required double amount,
    required String paymentDate,
    String method = 'Cash',
    String? notes,
  }) async {
    await _db.recordPayment(invoice.id!, amount, paymentDate, method, notes);

    await Future.wait([
      reloadInvoices(),
      reloadCashReceipts(),
      reloadLedger(),
      reloadDashboard(),
    ]);
  }

  Future<void> markInvoicePaid(int id) async {
    final invoice = await _db.getInvoice(id);
    if (invoice == null) return;
    final remaining = invoice.balanceDue;
    if (remaining <= 0) {
      await _db.setInvoiceStatus(id, InvoiceStatus.paid);
      await Future.wait([reloadInvoices(), reloadDashboard()]);
      return;
    }
    await recordInvoicePayment(
      invoice: invoice,
      amount: remaining,
      paymentDate: todayStr(),
      method: 'Full settlement',
      notes: 'Marked paid in full',
    );
  }

  Future<List<InvoicePayment>> getPaymentsForInvoice(int invoiceId) {
    return _db.getPaymentsForInvoice(invoiceId);
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
