import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';

class Expense {
  final String id;
  final DateTime date;
  String category;
  final String details;
  final double amount;

  Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.details,
    required this.amount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'category': category,
      'details': details,
      'amount': amount,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      date: DateTime.parse(json['date']),
      category: json['category'],
      details: json['details'],
      amount: json['amount'],
    );
  }
}

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
        final Map<String, dynamic> jsonMap = json.decode(contents);
        return jsonMap;
      }
    } catch (e) {
      debugPrint("Error reading data: $e");
    }
    return {
      'expenses': [],
      'categories': ['Food', 'Transport', 'Entertainment', 'Utilities', 'Rent']
    };
  }

  Future<void> writeData(List<Expense> expenses, List<String> categories) async {
    try {
      final file = await _getLocalFile();
      final Map<String, dynamic> data = {
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'categories': categories,
      };
      await file.writeAsString(json.encode(data));
    } catch (e) {
      debugPrint("Error writing data: $e");
    }
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  List<Expense> _expenses = [];
  List<String> _categories = [];
  bool _isLoading = true;
  final AppFileManager _appFileManager = AppFileManager();
  final Uuid _uuid = const Uuid();
  String _currentFilter = 'Month';
  DateTime _currentDashboardPeriodStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final data = await _appFileManager.readData();
    setState(() {
      _expenses = (data['expenses'] as List).map((e) => Expense.fromJson(e)).toList();
      _categories = (data['categories'] as List).cast<String>();
      if (_categories.isEmpty) _categories = ['Miscellaneous'];
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    await _appFileManager.writeData(_expenses, _categories);
  }

  void _updateExpenseCategories(String oldCategory, String newCategory) {
    setState(() {
      for (var expense in _expenses) {
        if (expense.category == oldCategory) expense.category = newCategory;
      }
      _saveData();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  List<Expense> _getFilteredExpensesForDashboard() {
    DateTime periodStart = _currentDashboardPeriodStart;
    DateTime normalizedStart;
    DateTime periodEnd;

    if (_currentFilter == 'Week') {
      normalizedStart = periodStart.subtract(Duration(days: periodStart.weekday - 1));
      normalizedStart = DateTime(normalizedStart.year, normalizedStart.month, normalizedStart.day);
      periodEnd = normalizedStart.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
    } else if (_currentFilter == 'Month') {
      normalizedStart = DateTime(periodStart.year, periodStart.month, 1);
      periodEnd = DateTime(periodStart.year, periodStart.month + 1, 0)
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));
    } else {
      normalizedStart = DateTime(periodStart.year, 1, 1);
      periodEnd = DateTime(periodStart.year + 1, 1, 1).subtract(const Duration(seconds: 1));
    }

    return _expenses.where((expense) {
      return expense.date.isAfter(normalizedStart.subtract(const Duration(seconds: 1))) &&
             expense.date.isBefore(periodEnd.add(const Duration(seconds: 1)));
    }).toList();
  }

  void _navigatePeriod(int direction) {
    setState(() {
      if (_currentFilter == 'Week') {
        _currentDashboardPeriodStart = _currentDashboardPeriodStart.add(Duration(days: 7 * direction));
      } else if (_currentFilter == 'Month') {
        _currentDashboardPeriodStart = DateTime(_currentDashboardPeriodStart.year, _currentDashboardPeriodStart.month + direction, 1);
      } else {
        _currentDashboardPeriodStart = DateTime(_currentDashboardPeriodStart.year + direction, 1, 1);
      }
    });
  }

  String _getPeriodDisplayText() {
    DateTime start = _currentDashboardPeriodStart;
    if (_currentFilter == 'Week') {
      DateTime weekStart = start.subtract(Duration(days: start.weekday - 1));
      DateTime weekEnd = weekStart.add(const Duration(days: 6));
      return '${DateFormat('MMM dd').format(weekStart)} - ${DateFormat('MMM dd, yyyy').format(weekEnd)}';
    } else if (_currentFilter == 'Month') {
      return DateFormat('MMMM yyyy').format(start);
    } else {
      return DateFormat('yyyy').format(start);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : Scaffold(
              appBar: AppBar(title: const Text('Expense Tracker')),
              body: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _selectedIndex = index),
                children: [
                  DashboardScreen(
                    expenses: _expenses,
                    categories: _categories,
                    currentFilter: _currentFilter,
                    onFilterChanged: (filter) => setState(() {
                      _currentFilter = filter;
                      _currentDashboardPeriodStart = DateTime.now();
                    }),
                    currentDashboardPeriodStart: _currentDashboardPeriodStart,
                    getFilteredExpensesForDashboard: _getFilteredExpensesForDashboard,
                    getPeriodDisplayText: _getPeriodDisplayText,
                    navigatePeriod: _navigatePeriod,
                  ),
                  AddExpenseScreen(
                    categories: _categories,
                    uuidGenerator: _uuid,
                    onAddExpense: (expense) {
                      setState(() => _expenses.add(expense));
                      _saveData();
                      _pageController.jumpToPage(0);
                    },
                  ),
                  CategoriesScreen(
                    categories: _categories,
                    onAddCategory: (category) {
                      setState(() {
                        if (!_categories.contains(category)) {
                          _categories.add(category);
                          _saveData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Category "$category" already exists!')),
                          );
                        }
                      });
                    },
                    onDeleteCategory: (category) {
                      setState(() {
                        _categories.remove(category);
                        for (var expense in _expenses) {
                          if (expense.category == category) expense.category = 'Miscellaneous';
                        }
                        if (!_categories.contains('Miscellaneous') && _expenses.any((e) => e.category == 'Miscellaneous')) {
                          _categories.add('Miscellaneous');
                        }
                        _saveData();
                      });
                    },
                    onEditCategory: (oldCategory, newCategory) {
                      if (oldCategory == newCategory) return;
                      setState(() {
                        int index = _categories.indexOf(oldCategory);
                        if (index != -1) {
                          _categories[index] = newCategory;
                          _updateExpenseCategories(oldCategory, newCategory);
                          _saveData();
                        }
                      });
                    },
                  ),
                ],
              ),
              bottomNavigationBar: BottomNavigationBar(
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                  BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Add Expense'),
                  BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Categories'),
                ],
                currentIndex: _selectedIndex,
                selectedItemColor: Theme.of(context).primaryColor,
                onTap: _onItemTapped,
              ),
            ),
    );
  }
}

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
    final double totalSpend = filteredExpenses.fold(0.0, (sum, item) => sum + item.amount);
    final Map<String, double> categoryTotals = {};
    for (var expense in filteredExpenses) {
      categoryTotals.update(expense.category, (value) => value + expense.amount, ifAbsent: () => expense.amount);
    }

    final List<Color> pieColors = [
      Colors.blue, Colors.green, Colors.red, Colors.purple,
      Colors.orange, Colors.teal, Colors.pink, Colors.brown,
      Colors.indigo, Colors.amber, Colors.cyan, Colors.deepOrange,
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Week', label: Text('Week'), icon: Icon(Icons.calendar_view_week)),
              ButtonSegment(value: 'Month', label: Text('Month'), icon: Icon(Icons.calendar_view_month)),
              ButtonSegment(value: 'Year', label: Text('Year'), icon: Icon(Icons.calendar_today)),
            ],
            selected: {currentFilter},
            onSelectionChanged: (newSelection) {
              if (newSelection.isNotEmpty) onFilterChanged(newSelection.first);
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.arrow_left), onPressed: () => navigatePeriod(-1)),
              Expanded(
                child: Text(getPeriodDisplayText(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(icon: const Icon(Icons.arrow_right), onPressed: () => navigatePeriod(1)),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Total Spend:', style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    NumberFormat.currency(symbol: 'Rs.', decimalDigits: 2).format(totalSpend),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: categoryTotals.isEmpty
                    ? Center(child: Text('No expenses for this period. Add some!', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center))
                    : PieChart(
                        PieChartData(
                          sections: categoryTotals.entries.map((entry) {
                            final double percentage = totalSpend > 0 ? (entry.value / totalSpend) * 100 : 0;
                            final int colorIndex = categoryTotals.keys.toList().indexOf(entry.key) % pieColors.length;
                            return PieChartSectionData(
                              color: pieColors[colorIndex],
                              value: entry.value,
                              title: '${entry.key}\n${NumberFormat.currency(symbol: 'Rs.', decimalDigits: 0).format(entry.value)} (${percentage.toStringAsFixed(0)}%)',
                              radius: 80,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              titlePositionPercentageOffset: 0.55,
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          startDegreeOffset: -90,
                          borderData: FlBorderData(show: false),
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

class AddExpenseScreen extends StatefulWidget {
  final List<String> categories;
  final ValueChanged<Expense> onAddExpense;
  final Uuid uuidGenerator;

  const AddExpenseScreen({super.key, required this.categories, required this.onAddExpense, required this.uuidGenerator});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) _selectedCategory = widget.categories.first;
  }

  bool _isValidCategory(String? category) => category != null && widget.categories.contains(category);

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) setState(() => _selectedDate = picked);
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      final newExpense = Expense(
        id: widget.uuidGenerator.v4(),
        date: _selectedDate,
        category: _selectedCategory!,
        details: _detailsController.text,
        amount: double.parse(_amountController.text),
      );
      widget.onAddExpense(newExpense);
      _amountController.clear();
      _detailsController.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _selectedCategory = widget.categories.isNotEmpty ? widget.categories.first : null;
      });
    }
  }

  @override
  void didUpdateWidget(covariant AddExpenseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isValidCategory(_selectedCategory) && widget.categories.isNotEmpty) {
      setState(() => _selectedCategory = widget.categories.first);
    } else if (widget.categories.isEmpty) {
      setState(() => _selectedCategory = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (Rs.)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter an amount';
                if (double.tryParse(value) == null) return 'Please enter a valid number';
                if (double.parse(value) <= 0) return 'Amount must be positive';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _detailsController,
              decoration: const InputDecoration(labelText: 'Details (e.g., Coffee at Starbucks)', border: OutlineInputBorder()),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter details';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: widget.categories.map((category) => DropdownMenuItem(value: category, child: Text(category))).toList(),
              onChanged: (String? newValue) => setState(() => _selectedCategory = newValue),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please select a category';
                return null;
              },
              hint: const Text('Select a category'),
              isExpanded: true,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
              shape: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _selectedCategory != null && widget.categories.isNotEmpty ? _submitForm : null,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 18)),
              child: const Text('Add Expense'),
            ),
            if (widget.categories.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Please add categories in the "Categories" tab first.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CategoriesScreen extends StatefulWidget {
  final List<String> categories;
  final ValueChanged<String> onAddCategory;
  final ValueChanged<String> onDeleteCategory;
  final Function(String oldCategory, String newCategory) onEditCategory;

  const CategoriesScreen({super.key, required this.categories, required this.onAddCategory, required this.onDeleteCategory, required this.onEditCategory});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _newCategoryController = TextEditingController();

  void _showEditCategoryDialog(BuildContext context, String currentCategory) {
    final TextEditingController editController = TextEditingController(text: currentCategory);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Category'),
        content: TextField(controller: editController, decoration: const InputDecoration(labelText: 'Category Name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = editController.text.trim();
              if (newName.isNotEmpty) {
                if (newName != currentCategory) {
                  if (!widget.categories.contains(newName)) {
                    widget.onEditCategory(currentCategory, newName);
                    Navigator.of(ctx).pop();
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Category "$newName" already exists!')));
                  }
                } else {
                  Navigator.of(ctx).pop();
                }
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Category name cannot be empty!')));
              }
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCategoryController,
                  decoration: const InputDecoration(labelText: 'New Category Name', border: OutlineInputBorder()),
                  onSubmitted: (_) {
                    if (_newCategoryController.text.trim().isNotEmpty) {
                      widget.onAddCategory(_newCategoryController.text.trim());
                      _newCategoryController.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  if (_newCategoryController.text.trim().isNotEmpty) {
                    widget.onAddCategory(_newCategoryController.text.trim());
                    _newCategoryController.clear();
                  }
                },
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: widget.categories.isEmpty
                ? const Center(child: Text('No categories added yet.'))
                : ListView.builder(
                    itemCount: widget.categories.length,
                    itemBuilder: (context, index) {
                      final category = widget.categories[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(category),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showEditCategoryDialog(context, category),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Category'),
                                      content: Text('Are you sure you want to delete "$category"? Expenses will be re-assigned to "Miscellaneous".'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                        ElevatedButton(
                                          onPressed: () {
                                            widget.onDeleteCategory(category);
                                            Navigator.of(ctx).pop();
                                          },
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
