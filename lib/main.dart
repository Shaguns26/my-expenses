import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';

// ─────────────────────────────────────────
//  Model
// ─────────────────────────────────────────
class Expense {
  final String id;
  DateTime date;
  String category;
  String details;
  double amount;

  Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.details,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'category': category,
        'details': details,
        'amount': amount,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        date: DateTime.parse(json['date']),
        category: json['category'],
        details: json['details'],
        amount: (json['amount'] as num).toDouble(),
      );
}

// ─────────────────────────────────────────
//  Persistence
// ─────────────────────────────────────────
class AppFileManager {
  static const String _fileName = 'expense_tracker_data.json';

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<Map<String, dynamic>> readData() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        return jsonDecode(contents) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  Future<void> writeData(Map<String, dynamic> data) async {
    try {
      final file = await _getLocalFile();
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }
}

// ─────────────────────────────────────────
//  App entry
// ─────────────────────────────────────────
void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppFileManager _fileManager = AppFileManager();
  final Uuid _uuid = const Uuid();
  final PageController _pageController = PageController();

  List<Expense> _expenses = [];
  List<String> _categories = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  // Dashboard filter state
  String _currentFilter = 'Monthly';
  DateTime _currentDashboardPeriodStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _fileManager.readData();
    setState(() {
      _expenses = (data['expenses'] as List<dynamic>? ?? [])
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();
      _categories =
          (data['categories'] as List<dynamic>? ?? []).cast<String>();
      if (_categories.isEmpty) {
        _categories = [
          'Food',
          'Transport',
          'Entertainment',
          'Utilities',
          'Healthcare',
          'Miscellaneous'
        ];
      }
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    await _fileManager.writeData({
      'expenses': _expenses.map((e) => e.toJson()).toList(),
      'categories': _categories,
    });
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  // ── Dashboard helpers ──────────────────
  List<Expense> _getFilteredExpensesForDashboard() {
    final now = _currentDashboardPeriodStart;
    return _expenses.where((e) {
      switch (_currentFilter) {
        case 'Weekly':
          final start =
              now.subtract(Duration(days: now.weekday - 1));
          final startDate =
              DateTime(start.year, start.month, start.day);
          final endDate = startDate.add(const Duration(days: 6));
          return !e.date.isBefore(startDate) &&
              !e.date.isAfter(
                  endDate.add(const Duration(hours: 23, minutes: 59)));
        case 'Yearly':
          return e.date.year == now.year;
        default: // Monthly
          return e.date.year == now.year && e.date.month == now.month;
      }
    }).toList();
  }

  String _getPeriodDisplayText() {
    final now = _currentDashboardPeriodStart;
    switch (_currentFilter) {
      case 'Weekly':
        final start =
            now.subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d, y').format(end)}';
      case 'Yearly':
        return now.year.toString();
      default:
        return DateFormat('MMMM yyyy').format(now);
    }
  }

  void _navigatePeriod(int direction) {
    setState(() {
      switch (_currentFilter) {
        case 'Weekly':
          _currentDashboardPeriodStart = _currentDashboardPeriodStart
              .add(Duration(days: 7 * direction));
          break;
        case 'Yearly':
          _currentDashboardPeriodStart = DateTime(
              _currentDashboardPeriodStart.year + direction,
              _currentDashboardPeriodStart.month);
          break;
        default:
          final m = _currentDashboardPeriodStart.month + direction;
          _currentDashboardPeriodStart = DateTime(
              _currentDashboardPeriodStart.year + (m < 1 ? -1 : m > 12 ? 1 : 0),
              m < 1 ? 12 : m > 12 ? 1 : m);
      }
    });
  }

  void _updateExpenseCategories(String oldCat, String newCat) {
    for (var e in _expenses) {
      if (e.category == oldCat) e.category = newCat;
    }
  }

  // ── Edit / Delete expense ──────────────
  void _editExpense(Expense expense, String newDetails, double newAmount,
      String newCategory, DateTime newDate) {
    setState(() {
      expense.details = newDetails;
      expense.amount = newAmount;
      expense.category = newCategory;
      expense.date = newDate;
    });
    _saveData();
  }

  void _deleteExpense(Expense expense) {
    setState(() => _expenses.remove(expense));
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()))
          : Scaffold(
              appBar: AppBar(
                title: const Text('Expense Tracker'),
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              ),
              body: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _selectedIndex = i),
                children: [
                  // ── Tab 0: Dashboard ────────────────────
                  DashboardScreen(
                    expenses: _expenses,
                    categories: _categories,
                    currentFilter: _currentFilter,
                    onFilterChanged: (filter) => setState(() {
                      _currentFilter = filter;
                      _currentDashboardPeriodStart = DateTime.now();
                    }),
                    currentDashboardPeriodStart:
                        _currentDashboardPeriodStart,
                    getFilteredExpensesForDashboard:
                        _getFilteredExpensesForDashboard,
                    getPeriodDisplayText: _getPeriodDisplayText,
                    navigatePeriod: _navigatePeriod,
                  ),
                  // ── Tab 1: Add Expense ───────────────────
                  AddExpenseScreen(
                    categories: _categories,
                    uuidGenerator: _uuid,
                    onAddExpense: (expense) {
                      setState(() => _expenses.add(expense));
                      _saveData();
                      _pageController.jumpToPage(0);
                    },
                  ),
                  // ── Tab 2: Expenses list ─────────────────
                  ExpensesScreen(
                    expenses: _expenses,
                    categories: _categories,
                    onEditExpense: _editExpense,
                    onDeleteExpense: _deleteExpense,
                  ),
                  // ── Tab 3: Categories ────────────────────
                  CategoriesScreen(
                    categories: _categories,
                    onAddCategory: (cat) {
                      setState(() {
                        if (!_categories.contains(cat)) {
                          _categories.add(cat);
                          _saveData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Category "$cat" already exists!')));
                        }
                      });
                    },
                    onDeleteCategory: (cat) {
                      setState(() {
                        _categories.remove(cat);
                        for (var e in _expenses) {
                          if (e.category == cat) {
                            e.category = 'Miscellaneous';
                          }
                        }
                        if (!_categories.contains('Miscellaneous') &&
                            _expenses
                                .any((e) => e.category == 'Miscellaneous')) {
                          _categories.add('Miscellaneous');
                        }
                        _saveData();
                      });
                    },
                    onEditCategory: (oldCat, newCat) {
                      if (oldCat == newCat) return;
                      setState(() {
                        final idx = _categories.indexOf(oldCat);
                        if (idx != -1) {
                          _categories[idx] = newCat;
                          _updateExpenseCategories(oldCat, newCat);
                          _saveData();
                        }
                      });
                    },
                  ),
                ],
              ),
              bottomNavigationBar: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard), label: 'Dashboard'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.add_circle), label: 'Add Expense'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.list_alt), label: 'Expenses'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.category), label: 'Categories'),
                ],
                currentIndex: _selectedIndex,
                selectedItemColor: Theme.of(context).primaryColor,
                onTap: _onItemTapped,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────
//  Tab 0 – Dashboard (pie chart only)
// ─────────────────────────────────────────
class DashboardScreen extends StatelessWidget {
  final List<Expense> expenses;
  final List<String> categories;
  final String currentFilter;
  final ValueChanged<String> onFilterChanged;
  final DateTime currentDashboardPeriodStart;
  final List<Expense> Function() getFilteredExpensesForDashboard;
  final String Function() getPeriodDisplayText;
  final ValueChanged<int> navigatePeriod;

  const DashboardScreen({
    super.key,
    required this.expenses,
    required this.categories,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.currentDashboardPeriodStart,
    required this.getFilteredExpensesForDashboard,
    required this.getPeriodDisplayText,
    required this.navigatePeriod,
  });

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = getFilteredExpensesForDashboard();
    final double totalSpend =
        filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final Map<String, double> categoryTotals = {};
    for (var e in filteredExpenses) {
      categoryTotals.update(e.category, (v) => v + e.amount,
          ifAbsent: () => e.amount);
    }

    final List<Color> pieColors = [
      Colors.blue, Colors.green, Colors.red, Colors.purple,
      Colors.orange, Colors.teal, Colors.pink, Colors.brown,
      Colors.indigo, Colors.amber, Colors.cyan, Colors.deepOrange,
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Filter row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['Weekly', 'Monthly', 'Yearly'].map((filter) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: currentFilter == filter,
                  onSelected: (_) => onFilterChanged(filter),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Period navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => navigatePeriod(-1)),
              Text(getPeriodDisplayText(),
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => navigatePeriod(1)),
            ],
          ),
          const SizedBox(height: 8),
          // Total spend
          Text(
            'Total: ${NumberFormat.currency(symbol: 'Rs.', decimalDigits: 0).format(totalSpend)}',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Pie chart
          Expanded(
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: categoryTotals.isEmpty
                    ? Center(
                        child: Text(
                          'No expenses for this period.\nAdd some!',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : PieChart(
                        PieChartData(
                          sections: categoryTotals.entries.map((entry) {
                            final pct = totalSpend > 0
                                ? (entry.value / totalSpend) * 100
                                : 0.0;
                            final colorIdx =
                                categoryTotals.keys.toList().indexOf(entry.key) %
                                    pieColors.length;
                            return PieChartSectionData(
                              color: pieColors[colorIdx],
                              value: entry.value,
                              title:
                                  '${entry.key}\n${NumberFormat.currency(symbol: 'Rs.', decimalDigits: 0).format(entry.value)}\n(${pct.toStringAsFixed(1)}%)',
                              radius: 130,
                              titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 0,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Tab 1 – Add Expense
// ─────────────────────────────────────────
class AddExpenseScreen extends StatefulWidget {
  final List<String> categories;
  final Uuid uuidGenerator;
  final ValueChanged<Expense> onAddExpense;

  const AddExpenseScreen({
    super.key,
    required this.categories,
    required this.uuidGenerator,
    required this.onAddExpense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _detailsController = TextEditingController();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      widget.onAddExpense(Expense(
        id: widget.uuidGenerator.v4(),
        date: _selectedDate,
        category: _selectedCategory!,
        details: _detailsController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
      ));
      _amountController.clear();
      _detailsController.clear();
      setState(() {
        _selectedCategory = null;
        _selectedDate = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add New Expense',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                  labelText: 'Amount (Rs.)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee)),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter an amount';
                if (double.tryParse(v) == null) return 'Enter a valid number';
                if (double.parse(v) <= 0) return 'Amount must be positive';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _detailsController,
              decoration: const InputDecoration(
                  labelText: 'Details',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes)),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Please enter details' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category)),
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              validator: (v) =>
                  v == null ? 'Please select a category' : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text('Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  widget.categories.isNotEmpty ? _submitForm : null,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18)),
              child: const Text('Add Expense'),
            ),
            if (widget.categories.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Please add categories in the "Categories" tab first.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  Tab 2 – Expenses (view & edit all)
// ─────────────────────────────────────────
class ExpensesScreen extends StatefulWidget {
  final List<Expense> expenses;
  final List<String> categories;
  final Function(Expense, String, double, String, DateTime) onEditExpense;
  final ValueChanged<Expense> onDeleteExpense;

  const ExpensesScreen({
    super.key,
    required this.expenses,
    required this.categories,
    required this.onEditExpense,
    required this.onDeleteExpense,
  });

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _sortBy = 'Date (Newest)';
  String _filterCategory = 'All';

  List<Expense> get _displayedExpenses {
    List<Expense> list = List.from(widget.expenses);

    // category filter
    if (_filterCategory != 'All') {
      list = list.where((e) => e.category == _filterCategory).toList();
    }

    // sort
    switch (_sortBy) {
      case 'Date (Oldest)':
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'Amount (High–Low)':
        list.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'Amount (Low–High)':
        list.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      default: // Date (Newest)
        list.sort((a, b) => b.date.compareTo(a.date));
    }
    return list;
  }

  void _showEditDialog(Expense expense) {
    final amountCtrl =
        TextEditingController(text: expense.amount.toStringAsFixed(0));
    final detailsCtrl =
        TextEditingController(text: expense.details);
    String selCategory = widget.categories.contains(expense.category)
        ? expense.category
        : widget.categories.first;
    DateTime selDate = expense.date;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Edit Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Amount (Rs.)',
                      border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Details',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selCategory,
                  decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder()),
                  items: widget.categories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setDlg(() => selCategory = v ?? selCategory),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                      DateFormat('MMM d, yyyy').format(selDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDlg(() => selDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amount =
                    double.tryParse(amountCtrl.text.trim());
                final details = detailsCtrl.text.trim();
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Please enter a valid amount')));
                  return;
                }
                if (details.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Details cannot be empty')));
                  return;
                }
                widget.onEditExpense(
                    expense, details, amount, selCategory, selDate);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Expense updated!')));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Expense expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
            'Delete "${expense.details}" for ${NumberFormat.currency(symbol: 'Rs.', decimalDigits: 0).format(expense.amount)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.onDeleteExpense(expense);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense deleted.')));
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayedExpenses;
    final allCategories = ['All', ...widget.categories];
    final total = displayed.fold(0.0, (s, e) => s + e.amount);

    return Column(
      children: [
        // ── Controls bar ────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              // Category filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterCategory,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: allCategories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _filterCategory = v ?? 'All'),
                ),
              ),
              const SizedBox(width: 8),
              // Sort
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: [
                    'Date (Newest)',
                    'Date (Oldest)',
                    'Amount (High–Low)',
                    'Amount (Low–High)',
                  ]
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _sortBy = v ?? _sortBy),
                ),
              ),
            ],
          ),
        ),
        // ── Summary strip ───────────────────
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${displayed.length} expense(s)',
                  style: const TextStyle(color: Colors.grey)),
              Text(
                'Total: ${NumberFormat.currency(symbol: 'Rs.', decimalDigits: 0).format(total)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── List ────────────────────────────
        Expanded(
          child: displayed.isEmpty
              ? const Center(
                  child: Text('No expenses found.',
                      style: TextStyle(color: Colors.grey, fontSize: 16)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: displayed.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final expense = displayed[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: Text(
                          expense.category.isNotEmpty
                              ? expense.category[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        expense.details,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                          '${expense.category}  ·  ${DateFormat('MMM d, yyyy').format(expense.date)}',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            NumberFormat.currency(
                                    symbol: 'Rs.', decimalDigits: 0)
                                .format(expense.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 14),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                size: 20, color: Colors.blueAccent),
                            tooltip: 'Edit',
                            onPressed: () => _showEditDialog(expense),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 20, color: Colors.redAccent),
                            tooltip: 'Delete',
                            onPressed: () =>
                                _showDeleteDialog(expense),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  Tab 3 – Categories
// ─────────────────────────────────────────
class CategoriesScreen extends StatefulWidget {
  final List<String> categories;
  final ValueChanged<String> onAddCategory;
  final ValueChanged<String> onDeleteCategory;
  final Function(String, String) onEditCategory;

  const CategoriesScreen({
    super.key,
    required this.categories,
    required this.onAddCategory,
    required this.onDeleteCategory,
    required this.onEditCategory,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _newCategoryController =
      TextEditingController();

  void _showEditCategoryDialog(String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(
            controller: ctrl,
            decoration:
                const InputDecoration(labelText: 'Category Name'),
            autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Name cannot be empty!')));
                return;
              }
              if (newName != current &&
                  widget.categories.contains(newName)) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text('"$newName" already exists!')));
                return;
              }
              widget.onEditCategory(current, newName);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text('Manage Categories',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCategoryController,
                  decoration: const InputDecoration(
                      labelText: 'New Category',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final name = _newCategoryController.text.trim();
                  if (name.isNotEmpty) {
                    widget.onAddCategory(name);
                    _newCategoryController.clear();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: widget.categories.isEmpty
                ? const Center(child: Text('No categories yet.'))
                : ListView.builder(
                    itemCount: widget.categories.length,
                    itemBuilder: (context, index) {
                      final cat = widget.categories[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.label),
                          title: Text(cat),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blue),
                                onPressed: () =>
                                    _showEditCategoryDialog(cat),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () =>
                                    widget.onDeleteCategory(cat),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
