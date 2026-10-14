import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ExpenseProvider()..loadData(),
      child: const ExpenseTrackerApp(),
    ),
  );
}

// -----------------------------------------------------------------------------
// 1. DATA MODEL & JSON SERIALIZATION
// -----------------------------------------------------------------------------
class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        category: json['category'],
      );
}

// -----------------------------------------------------------------------------
// 2. STATE MANAGEMENT & PERSISTENCE (Browser localStorage mapping)
// -----------------------------------------------------------------------------
class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  double _monthlyBudget = 1000.0;
  bool _isDark = false;

  List<Expense> get expenses => [..._expenses];
  double get monthlyBudget => _monthlyBudget;
  bool get isDark => _isDark;

  double get totalSpent =>
      _expenses.fold(0.0, (sum, item) => sum + item.amount);

  void toggleTheme(bool value) {
    _isDark = value;
    _saveThemePref();
    notifyListeners();
  }

  void setBudget(double value) {
    _monthlyBudget = value;
    _saveBudgetPref();
    notifyListeners();
  }

  void addExpense(String title, double amount, String category, DateTime date) {
    final newExpense = Expense(
      id: DateTime.now().toIso8601String(),
      title: title,
      amount: amount,
      date: date,
      category: category,
    );
    _expenses.insert(0, newExpense);
    _saveExpenses();
    notifyListeners();
  }

  void deleteExpense(String id) {
    _expenses.removeWhere((item) => item.id == id);
    _saveExpenses();
    notifyListeners();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('isDark') ?? false;
    _monthlyBudget = prefs.getDouble('monthlyBudget') ?? 1000.0;

    final String? rawData = prefs.getString('expense_list');
    if (rawData != null) {
      final List<dynamic> jsonList = jsonDecode(rawData);
      _expenses = jsonList.map((e) => Expense.fromJson(e)).toList();
    }
    notifyListeners();
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_expenses.map((e) => e.toJson()).toList());
    await prefs.setString('expense_list', encoded);
  }

  Future<void> _saveThemePref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _isDark);
  }

  Future<void> _saveBudgetPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('monthlyBudget', _monthlyBudget);
  }
}

// -----------------------------------------------------------------------------
// 3. MAIN APPLICATION & THEME SETUP
// -----------------------------------------------------------------------------
class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Expense & Budget Tracker Web',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B4F8A),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B4F8A),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: provider.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainShellScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. MAIN NAVIGATION SHELL
// -----------------------------------------------------------------------------
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    AllTransactionsScreen(),
    SettingsScreen(),
  ];

  void _openAddExpenseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddExpenseFormSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense & Budget Tracker'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Consumer<ExpenseProvider>(
              builder: (ctx, provider, _) => DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Budget Manager',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text('Total Spent: \$${provider.totalSpent.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('All Transactions'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings & Budget'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            Consumer<ExpenseProvider>(
              builder: (ctx, provider, _) => SwitchListTile(
                title: const Text('Dark Mode'),
                value: provider.isDark,
                onChanged: (val) => provider.toggleTheme(val),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return _screens[_selectedIndex];
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddExpenseSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DASHBOARD & RESPONSIVE VIEWS
// -----------------------------------------------------------------------------
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final double remaining = provider.monthlyBudget - provider.totalSpent;
    final double progress = (provider.totalSpent / provider.monthlyBudget).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;

        Widget summarySection = Card(
          margin: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Total Spent', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '\$${provider.totalSpent.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade300,
                  color: progress >= 0.9 ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Budget: \$${provider.monthlyBudget.toStringAsFixed(0)}'),
                    Text('Remaining: \$${remaining.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
        );

        Widget recentListSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: provider.expenses.isEmpty
                  ? const Center(child: Text('No expenses recorded yet!'))
                  : ListView.builder(
                      itemCount: provider.expenses.length > 5 ? 5 : provider.expenses.length,
                      itemBuilder: (ctx, index) => TransactionTile(item: provider.expenses[index]),
                    ),
            ),
          ],
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: SingleChildScrollView(child: summarySection)),
              const VerticalDivider(width: 1),
              Expanded(child: recentListSection),
            ],
          );
        }

        return Column(
          children: [
            summarySection,
            Expanded(child: recentListSection),
          ],
        );
      },
    );
  }
}

class AllTransactionsScreen extends StatelessWidget {
  const AllTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    if (provider.expenses.isEmpty) {
      return const Center(child: Text('No expenses found. Add one with the + button!'));
    }

    return ListView.builder(
      itemCount: provider.expenses.length,
      itemBuilder: (ctx, index) => TransactionTile(item: provider.expenses[index]),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final Expense item;

  const TransactionTile({super.key, required this.item});

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to remove "${item.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ExpenseProvider>().deleteExpense(item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Text(item.category[0])),
        title: Text(item.title),
        subtitle: Text('${item.category} • ${item.date.day}/${item.date.month}/${item.date.year}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${item.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}

class AddExpenseFormSheet extends StatefulWidget {
  const AddExpenseFormSheet({super.key});

  @override
  State<AddExpenseFormSheet> createState() => _AddExpenseFormSheetState();
}

class _AddExpenseFormSheetState extends State<AddExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();

  void _presentDatePicker() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      context.read<ExpenseProvider>().addExpense(
            _titleController.text.trim(),
            double.parse(_amountController.text),
            _selectedCategory,
            _selectedDate,
          );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, keyboardSpace + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add New Expense', style: Theme.of(context).textTheme.titleLarge),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Expense Title'),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a title.' : null,
            ),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (\$)'),
              validator: (val) {
                if (val == null || double.tryParse(val) == null) return 'Please enter a valid amount.';
                if (double.parse(val) <= 0) return 'Amount must be greater than zero.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: ['Food', 'Travel', 'Bills', 'Entertainment', 'Shopping']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _presentDatePicker,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitData,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
              child: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<ExpenseProvider>();
    _budgetController.text = provider.monthlyBudget.toStringAsFixed(0);
  }

  void _saveBudget() {
    final val = double.tryParse(_budgetController.text);
    if (val != null && val > 0) {
      context.read<ExpenseProvider>().setBudget(val);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly budget updated successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Budget Configuration', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Monthly Budget Cap (\$)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saveBudget,
            child: const Text('Update Budget Limit'),
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Dark Mode Appearance'),
            value: provider.isDark,
            onChanged: (val) => provider.toggleTheme(val),
          ),
        ],
      ),
    );
  }
}