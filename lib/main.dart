import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(
  const MaterialApp(
    home: MarginCalculatorScreen(),
    debugShowCheckedModeBanner: false,
  ),
);

class MarginCalculatorScreen extends StatefulWidget {
  const MarginCalculatorScreen({super.key});
  @override
  State<MarginCalculatorScreen> createState() => _MarginCalculatorScreenState();
}

class _MarginCalculatorScreenState extends State<MarginCalculatorScreen> {
  final costController = TextEditingController();
  final headOfficeMarginController = TextEditingController();
  final storeMarginController = TextEditingController();
  final shippingController = TextEditingController();
  final boxQuantityController = TextEditingController(text: "1");
  final manualSupplyController = TextEditingController();
  final manualSellingController = TextEditingController();

  bool isVatIncluded = false;
  List<String> history = [];

  void _updateValues({
    bool fromSupply = false,
    bool fromSelling = false,
    bool fromMargin = false,
  }) {
    double cost = double.tryParse(costController.text) ?? 0;
    double vatCost = isVatIncluded ? cost : cost * 1.1;
    double ship =
        (double.tryParse(shippingController.text) ?? 0) /
        (double.tryParse(boxQuantityController.text) ?? 1);

    setState(() {
      if (fromMargin) {
        double hRate = double.tryParse(headOfficeMarginController.text) ?? 0;
        double sRate = double.tryParse(storeMarginController.text) ?? 0;
        double sPrice = vatCost * (1 + hRate / 100);
        double fPrice = sPrice * (1 + sRate / 100);
        manualSupplyController.text = sPrice.toStringAsFixed(0);
        manualSellingController.text = fPrice.toStringAsFixed(0);
      } else if (fromSupply) {
        double sPrice = double.tryParse(manualSupplyController.text) ?? 0;
        if (vatCost > 0)
          headOfficeMarginController.text = ((sPrice / vatCost - 1) * 100)
              .toStringAsFixed(1);
        _updateValues(fromMargin: true);
      } else if (fromSelling) {
        double fPrice = double.tryParse(manualSellingController.text) ?? 0;
        double sPrice = double.tryParse(manualSupplyController.text) ?? 0;
        if (sPrice > 0)
          storeMarginController.text = ((fPrice / sPrice - 1) * 100)
              .toStringAsFixed(1);
      }
    });
  }

  void _addHistory() {
    if (manualSellingController.text.isEmpty ||
        manualSellingController.text == "0")
      return;
    setState(() {
      history.insert(
        0,
        "원가:${costController.text}원 → 판매가:${manualSellingController.text}원 (마진:${storeMarginController.text}%)",
      );
    });
  }

  void _reset() {
    setState(() {
      costController.clear();
      headOfficeMarginController.clear();
      storeMarginController.clear();
      shippingController.clear();
      boxQuantityController.text = "1";
      manualSupplyController.clear();
      manualSellingController.clear();
      isVatIncluded = false;
      history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFD700),
      appBar: AppBar(
        title: const Text(
          'WORKUP PRO',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFFFFD700),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _reset,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInput(
              "원가",
              costController,
              onChanged: (v) => _updateValues(fromMargin: true),
            ),
            Row(
              children: [
                Checkbox(
                  value: isVatIncluded,
                  onChanged: (v) {
                    setState(() {
                      isVatIncluded = v!;
                      _updateValues(fromMargin: true);
                    });
                  },
                ),
                const Text(
                  "VAT 포함",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "본사 마진%",
                    headOfficeMarginController,
                    onChanged: (v) => _updateValues(fromMargin: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    "공급가 수정",
                    manualSupplyController,
                    onChanged: (v) => _updateValues(fromSupply: true),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "매장 마진%",
                    storeMarginController,
                    onChanged: (v) => _updateValues(fromMargin: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    "판매가 수정",
                    manualSellingController,
                    onChanged: (v) => _updateValues(fromSelling: true),
                  ),
                ),
              ],
            ),
            _buildInput(
              "택배비",
              shippingController,
              onChanged: (v) => _updateValues(fromMargin: true),
            ),
            _buildInput(
              "박스입수량",
              boxQuantityController,
              onChanged: (v) => _updateValues(fromMargin: true),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                "계산 기록 저장",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            if (history.isNotEmpty) ...[
              const Text(
                "--- 계산 히스토리 ---",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...history.map(
                (h) => Card(
                  child: ListTile(
                    title: Text(
                      h,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController ctrl, {
    required Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
