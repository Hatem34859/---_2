
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DebtApp());
}

class Debt {
  String name;
  double amount;
  double paid;

  Debt({
    required this.name,
    required this.amount,
    this.paid = 0,
  });

  double get remaining => amount - paid;

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
    'paid': paid,
  };

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    name: json['name'],
    amount: (json['amount'] as num).toDouble(),
    paid: (json['paid'] as num).toDouble(),
  );
}

class DebtApp extends StatelessWidget {
  const DebtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دفتر الديون',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF087F6A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      ),
      home: const DebtHome(),
    );
  }
}

class DebtHome extends StatefulWidget {
  const DebtHome({super.key});

  @override
  State<DebtHome> createState() => _DebtHomeState();
}

class _DebtHomeState extends State<DebtHome> {
  final List<Debt> debts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDebts();
  }

  Future<void> loadDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('debts');
    if (data != null) {
      final list = jsonDecode(data) as List;
      debts.addAll(list.map(
        (e) => Debt.fromJson(Map<String, dynamic>.from(e)),
      ));
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveDebts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'debts',
      jsonEncode(debts.map((e) => e.toJson()).toList()),
    );
  }

  double get totalDebt =>
      debts.fold(0, (sum, d) => sum + d.amount);

  double get totalPaid =>
      debts.fold(0, (sum, d) => sum + d.paid);

  String money(double value) =>
      '${value.toStringAsFixed(0)} د.ع';

  Future<void> addDebt() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    final result = await showDialog<Debt>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة دين جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'اسم الشخص',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'مبلغ الدين بالدينار',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = double.tryParse(amountController.text);
              if (name.isEmpty || amount == null || amount <= 0) {
                return;
              }
              Navigator.pop(
                dialogContext,
                Debt(name: name, amount: amount),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    nameController.dispose();
    amountController.dispose();

    if (result != null) {
      setState(() => debts.add(result));
      await saveDebts();
    }
  }

  Future<void> addPayment(Debt debt) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('دفعة من ${debt.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
          ),
          decoration: const InputDecoration(
            labelText: 'المبلغ المستلم',
            suffixText: 'د.ع',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0 &&
                  value <= debt.remaining) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('تسجيل الدفعة'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (amount != null) {
      setState(() => debt.paid += amount);
      await saveDebts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'دفتر الديون',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF087F6A),
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: addDebt,
          backgroundColor: const Color(0xFF087F6A),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('إضافة دين'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _summary(
                            'إجمالي الديون',
                            totalDebt,
                            Colors.teal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summary(
                            'المتبقي',
                            totalDebt - totalPaid,
                            Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الأشخاص (${debts.length})',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: debts.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد ديون حتى الآن\nاضغط «إضافة دين» للبدء',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: debts.length,
                            itemBuilder: (context, index) {
                              final debt = debts[index];
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.teal.shade50,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.teal,
                                    ),
                                  ),
                                  title: Text(
                                    debt.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'الدين: ${money(debt.amount)}\n'
                                    'المتبقي: ${money(debt.remaining)}',
                                  ),
                                  isThreeLine: true,
                                  trailing: debt.remaining > 0
                                      ? IconButton(
                                          tooltip: 'تسجيل دفعة',
                                          icon: const Icon(
                                            Icons.payments_outlined,
                                            color: Colors.teal,
                                          ),
                                          onPressed: () => addPayment(debt),
                                        )
                                      : const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'إجمالي المستلم: ${money(totalPaid)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summary(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            money(amount),
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}