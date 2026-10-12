import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/app_state_scope.dart';
import '../util/currency_utils.dart';
import '../util/date_utils.dart';
import '../widgets/ledger_row.dart';
import '../widgets/status_pill.dart';
import 'accounts_screens.dart';
import 'money_sheets.dart';
import 'recurring_expenses_screen.dart';

/// Income and expenses for a selected month — the daily money tab.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  late DateTime _month;

  String get _monthKey => monthKey(_month);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final showingExpenses = state.moneyTabIndex == 1;
    final receipts = state.cashReceipts
        .where((r) => inMonth(r.receiptDate, _monthKey))
        .toList();
    final expenses =
        state.expenses.where((e) => inMonth(e.expenseDate, _monthKey)).toList();
    final inTotal = receipts.fold<double>(0, (s, r) => s + r.amount);
    final outTotal = expenses.fold<double>(0, (s, e) => s + e.amount);

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      monthTitle(_month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('In'),
                    icon: Icon(Icons.south_west_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('Out'),
                    icon: Icon(Icons.north_east_rounded, size: 18),
                  ),
                ],
                selected: {state.moneyTabIndex},
                onSelectionChanged: (value) =>
                    state.setMoneyTabIndex(value.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      showingExpenses
                          ? 'Spent ${money(outTotal)}'
                          : 'Collected ${money(inTotal)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CashReportScreen()),
                    ),
                    child: const Text('Report'),
                  ),
                  if (showingExpenses) ...[
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
                      tooltip: 'Expense heads',
                      icon: const Icon(Icons.category_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExpenseHeadsScreen()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => Future.wait([
                  state.reloadCashReceipts(),
                  state.reloadExpenses(),
                  state.reloadDashboard(),
                ]),
                child: showingExpenses
                    ? _ExpenseList(
                        expenses: expenses,
                        onTap: (e) => _expenseActions(context, state, e),
                      )
                    : _IncomeList(
                        receipts: receipts,
                        onTap: (r) => _incomeActions(context, state, r),
                      ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'money_fab',
            onPressed: () => showingExpenses
                ? showExpenseSheet(context)
                : showIncomeSheet(context),
            icon: const Icon(Icons.add),
            label: Text(showingExpenses ? 'Add expense' : 'Add income'),
          ),
        ),
      ],
    );
  }

  Future<void> _incomeActions(
      BuildContext context, AppState state, CashReceipt receipt) async {
    if (!receipt.isStandalone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            receipt.invoiceNumber == null
                ? 'This came from an invoice payment. Adjust it from the invoice.'
                : 'Payment on ${receipt.invoiceNumber}. Adjust it from the invoice.',
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(receipt.receivedFrom,
                  style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(
                  '${formatDate(receipt.receiptDate)} · ${money(receipt.amount)}'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheet);
                showIncomeSheet(context, existing: receipt);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(sheet);
                final ok = await confirmDelete(
                  context,
                  title: 'Delete this income?',
                  body: 'The cash ledger posting will be reversed.',
                );
                if (ok) await state.deleteCashReceipt(receipt.id!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _expenseActions(
      BuildContext context, AppState state, ExpenseRecord expense) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                expense.notes?.trim().isNotEmpty == true
                    ? expense.notes!
                    : expense.headName ?? 'Expense',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(
                  '${formatDate(expense.expenseDate)} · ${money(expense.amount)}'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(sheet);
                showExpenseSheet(context, existing: expense);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(sheet);
                final ok = await confirmDelete(
                  context,
                  title: 'Delete this expense?',
                  body: 'The cash ledger posting will be reversed.',
                );
                if (ok) await state.deleteExpense(expense.id!);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeList extends StatelessWidget {
  final List<CashReceipt> receipts;
  final ValueChanged<CashReceipt> onTap;

  const _IncomeList({required this.receipts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      return ListView(
        children: const [
          EmptyState(
            title: 'No income this month',
            subtitle:
                'Invoice payments land here automatically. Add standalone income anytime.',
            icon: Icons.payments_outlined,
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: receipts.length,
      itemBuilder: (context, index) {
        final receipt = receipts[index];
        return LedgerRow(
          tick: LedgerTick.paid,
          overline: receipt.invoiceNumber ?? 'Income',
          title: receipt.receivedFrom,
          subtitle: formatDate(receipt.receiptDate) +
              (receipt.notes?.trim().isNotEmpty == true
                  ? ' · ${receipt.notes}'
                  : ''),
          trailingFigure: money(receipt.amount),
          onTap: () => onTap(receipt),
        );
      },
    );
  }
}

class _ExpenseList extends StatelessWidget {
  final List<ExpenseRecord> expenses;
  final ValueChanged<ExpenseRecord> onTap;

  const _ExpenseList({required this.expenses, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return ListView(
        children: const [
          EmptyState(
            title: 'No expenses this month',
            subtitle:
                'Record a purchase, or set up rent and other recurring costs.',
            icon: Icons.money_off_csred_outlined,
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
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
          onTap: () => onTap(expense),
        );
      },
    );
  }
}
