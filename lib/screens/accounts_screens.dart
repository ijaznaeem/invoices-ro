import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state_scope.dart';
import '../theme/app_theme.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';
import '../widgets/ledger_row.dart';
import '../widgets/searchable_dropdown.dart';
import '../widgets/status_pill.dart';
import 'money_sheets.dart';
import 'recurring_expenses_screen.dart';

class AccountsLedgerScreen extends StatefulWidget {
  const AccountsLedgerScreen({super.key});

  @override
  State<AccountsLedgerScreen> createState() => _AccountsLedgerScreenState();
}

class _AccountsLedgerScreenState extends State<AccountsLedgerScreen> {
  String? _selectedAccount;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final balances = state.ledgerBalances.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final accountOptions = balances
        .map((e) => SearchableOption<String>(
              value: e.key,
              label: e.key,
              subtitle:
                  '${e.value >= 0 ? 'Debit' : 'Credit'} ${money(e.value.abs())}',
            ))
        .toList();

    final filteredBalances = _selectedAccount == null
        ? balances
        : balances.where((e) => e.key == _selectedAccount).toList();

    final filteredRecent = _selectedAccount == null
        ? state.ledgerEntries
        : state.ledgerEntries
            .where((e) => e.account == _selectedAccount)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts ledger'),
        actions: [
          IconButton(
            tooltip: 'Cash report',
            icon: const Icon(Icons.summarize_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CashReportScreen()),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: RefreshIndicator(
          onRefresh: () => state.reloadLedger(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SearchableDropdown<String>(
                label: 'Select account',
                hint: 'All accounts',
                searchHint: 'Search accounts…',
                prefixIcon: Icons.account_balance_outlined,
                value: _selectedAccount,
                allowClear: true,
                clearLabel: 'Show all accounts',
                items: accountOptions,
                emptyMessage: 'No accounts match your search',
                onChanged: (account) {
                  setState(() => _selectedAccount = account);
                  if (account != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountHistoryScreen(
                          account: account,
                          balance: state.ledgerBalances[account] ?? 0,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                _selectedAccount == null
                    ? 'Search or tap an account to view its transaction history.'
                    : 'Showing $_selectedAccount. Clear the selection to see all.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Text('ACCOUNT BALANCES',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 8),
              if (balances.isEmpty)
                const EmptyState(
                  title: 'No postings yet',
                  subtitle:
                      'Create an invoice or record a payment to populate the ledger.',
                  icon: Icons.menu_book_outlined,
                )
              else if (filteredBalances.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No matching accounts.'),
                )
              else
                ...filteredBalances.map((entry) {
                  final value = entry.value;
                  final isDebit = value >= 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(entry.key),
                      subtitle:
                          Text(isDebit ? 'Debit balance' : 'Credit balance'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            money(value.abs()),
                            style: AppTheme.mono(
                              size: 14,
                              color: isDebit
                                  ? LedgerColors.primary
                                  : LedgerColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AccountHistoryScreen(
                            account: entry.key,
                            balance: value,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 18),
              Text(
                  _selectedAccount == null
                      ? 'RECENT ENTRIES'
                      : 'RECENT — ${_selectedAccount!.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 8),
              if (filteredRecent.isEmpty)
                const SizedBox.shrink()
              else
                ...filteredRecent.take(40).map((e) => LedgerRow(
                      overline: e.account,
                      title: e.description,
                      subtitle: formatDate(e.entryDate),
                      trailingFigure: e.debit > 0
                          ? 'Dr ${money(e.debit)}'
                          : 'Cr ${money(e.credit)}',
                      tick: e.debit > 0 ? LedgerTick.pending : LedgerTick.paid,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AccountHistoryScreen(
                            account: e.account,
                            balance: state.ledgerBalances[e.account] ?? 0,
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full debit/credit history for one ledger account, with running balance.
class AccountHistoryScreen extends StatefulWidget {
  final String account;
  final double balance;

  const AccountHistoryScreen({
    super.key,
    required this.account,
    required this.balance,
  });

  @override
  State<AccountHistoryScreen> createState() => _AccountHistoryScreenState();
}

class _AccountHistoryScreenState extends State<AccountHistoryScreen> {
  List<_HistoryLine> _lines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries =
        await AppStateScope.of(context).ledgerEntriesForAccount(widget.account);
    var running = 0.0;
    final lines = <_HistoryLine>[];
    for (final e in entries) {
      running += e.debit - e.credit;
      lines.add(_HistoryLine(entry: e, runningBalance: running));
    }
    // Newest first for reading
    setState(() {
      _lines = lines.reversed.toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = widget.balance >= 0;
    return Scaffold(
      appBar: AppBar(title: Text(widget.account)),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Card(
                      child: ListTile(
                        title: const Text('Current balance'),
                        subtitle:
                            Text(isDebit ? 'Debit balance' : 'Credit balance'),
                        trailing: Text(
                          money(widget.balance.abs()),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TRANSACTION HISTORY',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_lines.isEmpty)
                      const EmptyState(
                        title: 'No transactions',
                        subtitle: 'Nothing posted to this account yet.',
                        icon: Icons.receipt_long_outlined,
                      )
                    else
                      ..._lines.map((line) {
                        final e = line.entry;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        formatDate(e.entryDate),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                    Text(
                                      e.debit > 0
                                          ? 'Dr ${money(e.debit)}'
                                          : 'Cr ${money(e.credit)}',
                                      style: AppTheme.mono(
                                        size: 13,
                                        color: e.debit > 0
                                            ? LedgerColors.primary
                                            : LedgerColors.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  e.description,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Balance ${money(line.runningBalance.abs())}'
                                  '${line.runningBalance >= 0 ? ' Dr' : ' Cr'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HistoryLine {
  final LedgerEntry entry;
  final double runningBalance;
  const _HistoryLine({required this.entry, required this.runningBalance});
}

/// Monthly cash report: all cash receipts and expenses for a selected month.
class CashReportScreen extends StatefulWidget {
  const CashReportScreen({super.key});

  @override
  State<CashReportScreen> createState() => _CashReportScreenState();
}

class _CashReportScreenState extends State<CashReportScreen> {
  late DateTime _month;
  List<CashReceipt> _receipts = [];
  List<ExpenseRecord> _expenses = [];
  bool _loading = true;

  String get _monthKey =>
      '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}';

  String get _monthLabel {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[_month.month - 1]} ${_month.year}';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final report =
        await AppStateScope.of(context).cashReportForMonth(_monthKey);
    if (!mounted) return;
    setState(() {
      _receipts = report.receipts;
      _expenses = report.expenses;
      _loading = false;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select any day in the month',
    );
    if (picked == null) return;
    setState(() => _month = DateTime(picked.year, picked.month));
    await _load();
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final receiptTotal = _receipts.fold<double>(0, (s, r) => s + r.amount);
    final expenseTotal = _expenses.fold<double>(0, (s, e) => s + e.amount);
    final net = receiptTotal - expenseTotal;

    // Group expenses by head for the summary
    final byHead = <String, double>{};
    for (final e in _expenses) {
      final name = e.headName ?? 'Other';
      byHead[name] = (byHead[name] ?? 0) + e.amount;
    }
    final headRows = byHead.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Cash report')),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pickMonth,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: AppTheme.cardDecoration(context),
                        child: Column(
                          children: [
                            Text(
                              _monthLabel,
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'Tap to choose month',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _CashSummaryTile(
                                  label: 'Receipts',
                                  value: money(receiptTotal),
                                  color: LedgerColors.paid,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _CashSummaryTile(
                                  label: 'Expenses',
                                  value: money(expenseTotal),
                                  color: LedgerColors.overdue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _CashSummaryTile(
                            label: 'Net cash',
                            value: money(net),
                            color: net >= 0
                                ? LedgerColors.secondary
                                : LedgerColors.overdue,
                            wide: true,
                          ),
                          if (headRows.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Text(
                              'EXPENSES BY HEAD',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ...headRows.map((e) => Card(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(e.key),
                                    trailing: Text(money(e.value),
                                        style: AppTheme.mono(size: 13)),
                                  ),
                                )),
                          ],
                          const SizedBox(height: 18),
                          Text(
                            'CASH RECEIPTS (${_receipts.length})',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          if (_receipts.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No cash receipts this month.'),
                            )
                          else
                            ..._receipts.map((r) => LedgerRow(
                                  tick: LedgerTick.paid,
                                  overline: r.invoiceNumber ?? 'Standalone',
                                  title: r.receivedFrom,
                                  subtitle: formatDate(r.receiptDate) +
                                      (r.notes?.trim().isNotEmpty == true
                                          ? ' · ${r.notes}'
                                          : ''),
                                  trailingFigure: money(r.amount),
                                )),
                          const SizedBox(height: 18),
                          Text(
                            'EXPENSES (${_expenses.length})',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          const SizedBox(height: 8),
                          if (_expenses.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No expenses this month.'),
                            )
                          else
                            ..._expenses.map((e) => LedgerRow(
                                  tick: LedgerTick.overdue,
                                  overline: e.headName ?? 'Expense',
                                  title: e.notes?.trim().isNotEmpty == true
                                      ? e.notes!
                                      : e.headName ?? 'Expense',
                                  subtitle: formatDate(e.expenseDate),
                                  trailingFigure: money(e.amount),
                                )),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashSummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool wide;

  const _CashSummaryTile({
    required this.label,
    required this.value,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class CashReceiptsScreen extends StatelessWidget {
  const CashReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cash receipts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showIncomeSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add receipt'),
      ),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: RefreshIndicator(
          onRefresh: () => state.reloadCashReceipts(),
          child: state.cashReceipts.isEmpty
              ? ListView(
                  children: const [
                    EmptyState(
                      title: 'No cash receipts',
                      subtitle:
                          'Payments on invoices are logged here automatically. You can also add standalone receipts.',
                      icon: Icons.payments_outlined,
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                  itemCount: state.cashReceipts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.savings_outlined),
                            title: const Text('Total cash received'),
                            trailing: Text(
                              money(state.cashReceivedTotal),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      );
                    }
                    final receipt = state.cashReceipts[index - 1];
                    return LedgerRow(
                      tick: LedgerTick.paid,
                      overline: receipt.invoiceNumber ?? 'Standalone',
                      title: receipt.receivedFrom,
                      subtitle: formatDate(receipt.receiptDate) +
                          (receipt.notes?.trim().isNotEmpty == true
                              ? ' · ${receipt.notes}'
                              : ''),
                      trailingFigure: money(receipt.amount),
                      onTap: receipt.isStandalone
                          ? () => showIncomeSheet(context, existing: receipt)
                          : null,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            tooltip: 'Recurring expenses',
            icon: const Icon(Icons.autorenew_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const RecurringExpensesScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Manage heads',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpenseHeadsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: RefreshIndicator(
          onRefresh: () => state.reloadExpenses(),
          child: state.expenses.isEmpty
              ? ListView(
                  children: const [
                    EmptyState(
                      title: 'No expenses recorded',
                      subtitle:
                          'Track one-off spending, or tap the cycle icon to set up rent and other recurring costs.',
                      icon: Icons.money_off_csred_outlined,
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                  itemCount: state.expenses.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.trending_down_rounded),
                            title: const Text('Total expenses'),
                            trailing: Text(
                              money(state.expensesTotalAmount),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                      );
                    }
                    final expense = state.expenses[index - 1];
                    return LedgerRow(
                      tick: LedgerTick.overdue,
                      overline: expense.templateId != null
                          ? '${expense.headName ?? 'Expense'} · Recurring'
                          : expense.headName ?? 'Expense',
                      title: expense.notes?.trim().isNotEmpty == true
                          ? expense.notes!
                          : expense.headName ?? 'Expense',
                      subtitle: formatDate(expense.expenseDate),
                      trailingFigure: money(expense.amount),
                      onTap: () => showExpenseSheet(context, existing: expense),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class ExpenseHeadsScreen extends StatelessWidget {
  const ExpenseHeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Expense heads')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editHead(context),
        child: const Icon(Icons.add),
      ),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.expenseHeads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final head = state.expenseHeads[index];
            return Card(
              child: ListTile(
                title: Text(head.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editHead(context, head: head),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => state.deleteExpenseHead(head.id!),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _editHead(BuildContext context, {ExpenseHead? head}) async {
    final state = AppStateScope.of(context);
    final controller = TextEditingController(text: head?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(head == null ? 'Add expense head' : 'Edit expense head'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Head name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    if (head == null) {
      await state.addExpenseHead(ExpenseHead(name: result));
    } else {
      await state.updateExpenseHead(
          ExpenseHead(id: head.id, name: result, sortOrder: head.sortOrder));
    }
  }
}

class TaxRatesScreen extends StatelessWidget {
  const TaxRatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tax rates')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editRate(context),
        child: const Icon(Icons.add),
      ),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'These percentages appear as selectable options when creating invoices. “No Tax” (0%) is used by default.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...state.taxRates.map((rate) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(rate.name),
                    subtitle: Text('${rate.ratePercent}%'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editRate(context, rate: rate),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: rate.ratePercent == 0 &&
                                  state.taxRates
                                          .where((r) => r.ratePercent == 0)
                                          .length ==
                                      1
                              ? null
                              : () => state.deleteTaxRate(rate.id!),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _editRate(BuildContext context, {TaxRate? rate}) async {
    final state = AppStateScope.of(context);
    final nameController = TextEditingController(text: rate?.name ?? '');
    final percentController = TextEditingController(
        text: rate != null ? rate.ratePercent.toString() : '');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(rate == null ? 'Add tax rate' : 'Edit tax rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: percentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Rate %'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final name = nameController.text.trim();
    final percent = double.tryParse(percentController.text.trim());
    nameController.dispose();
    percentController.dispose();
    if (result != true || name.isEmpty || percent == null || percent < 0) {
      return;
    }
    if (rate == null) {
      await state.addTaxRate(TaxRate(name: name, ratePercent: percent));
    } else {
      await state.updateTaxRate(TaxRate(
        id: rate.id,
        name: name,
        ratePercent: percent,
        sortOrder: rate.sortOrder,
      ));
    }
  }
}
