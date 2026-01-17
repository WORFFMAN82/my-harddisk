import 'package:flutter/material.dart';

void main() => runApp(const MarginCalculatorApp());

class MarginCalculatorApp extends StatelessWidget {
  const MarginCalculatorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '올인원계산기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: true),
      home: const MarginCalculatorScreen(),
    );
  }
}

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
  bool isSupplyManual = false;
  bool isSellingManual = false;
  int supplyRoundUnit = 1;
  int sellingRoundUnit = 1;
  List<String> history = [];

  void calculate({String? trigger}) {
    double inputCost = double.tryParse(costController.text) ?? 0;
    double headRate = double.tryParse(headOfficeMarginController.text) ?? 0;
    double storeRate = double.tryParse(storeMarginController.text) ?? 0;
    double totalShip = double.tryParse(shippingController.text) ?? 0;
    double boxQty = double.tryParse(boxQuantityController.text) ?? 1;
    if (boxQty <= 0) boxQty = 1;

    setState(() {
      double costWithVat = isVatIncluded ? inputCost : inputCost * 1.1;

      if (trigger == "supply" && isSupplyManual) {
        double sPrice = double.tryParse(manualSupplyController.text) ?? 0;
        if (costWithVat > 0) {
          headOfficeMarginController.text = ((sPrice / costWithVat - 1) * 100)
              .toStringAsFixed(1);
        }
        double fPrice = double.tryParse(manualSellingController.text) ?? 0;
        if (sPrice > 0) {
          storeMarginController.text = ((fPrice / sPrice - 1) * 100)
              .toStringAsFixed(1);
        }
      } else if (trigger == "selling" && isSellingManual) {
        double fPrice = double.tryParse(manualSellingController.text) ?? 0;
        double sPrice = double.tryParse(manualSupplyController.text) ?? 0;
        if (sPrice > 0) {
          storeMarginController.text = ((fPrice / sPrice - 1) * 100)
              .toStringAsFixed(1);
        }
      }

      if (!isSupplyManual && trigger != "supply") {
        double rawSupply = costWithVat * (1 + headRate / 100);
        manualSupplyController.text = _applyRounding(
          rawSupply,
          supplyRoundUnit,
        ).toStringAsFixed(0);
      }

      if (!isSellingManual && trigger != "selling") {
        double currentSupply =
            double.tryParse(manualSupplyController.text) ?? 0;
        double rawSelling = currentSupply * (1 + storeRate / 100);
        manualSellingController.text = _applyRounding(
          rawSelling,
          sellingRoundUnit,
        ).toStringAsFixed(0);
      }
    });
  }

  double _applyRounding(double value, int unit) {
    if (unit == 10) return (value / 10).round() * 10.0;
    if (unit == 100) return (value / 100).round() * 100.0;
    return value;
  }

  void reset() {
    setState(() {
      costController.clear();
      headOfficeMarginController.clear();
      storeMarginController.clear();
      shippingController.clear();
      boxQuantityController.text = "1";
      manualSupplyController.clear();
      manualSellingController.clear();
      isVatIncluded = false;
      isSupplyManual = false;
      isSellingManual = false;
      supplyRoundUnit = 1;
      sellingRoundUnit = 1;
      history.clear();
    });
  }

  void addHistory() {
    if (manualSellingController.text.isEmpty) return;
    setState(() {
      history.insert(
        0,
        "원가:${costController.text} | 공급:${manualSupplyController.text} | 판매:${manualSellingController.text} | 이익:${storeMarginController.text}%",
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    double sellP = double.tryParse(manualSellingController.text) ?? 0;
    double baseC =
        (isVatIncluded
            ? (double.tryParse(costController.text) ?? 0)
            : (double.tryParse(costController.text) ?? 0) * 1.1) +
        ((double.tryParse(shippingController.text) ?? 0) /
            (double.tryParse(boxQuantityController.text) ?? 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '올인원계산기',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.orange,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: reset),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildField('원가 입력 (공급가액)', costController),
            Row(
              children: [
                Checkbox(
                  value: isVatIncluded,
                  activeColor: Colors.orange,
                  onChanged: (v) {
                    setState(() {
                      isVatIncluded = v!;
                      calculate();
                    });
                  },
                ),
                const Text(
                  'VAT 포함 원가임',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    '본사 마진율',
                    headOfficeMarginController,
                    suffix: '%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    '매장 마진율',
                    storeMarginController,
                    suffix: '%',
                  ),
                ),
              ],
            ),
            const Divider(height: 30, thickness: 1),
            Row(
              children: [
                _buildPriceControl(
                  '공급가',
                  manualSupplyController,
                  isSupplyManual,
                  supplyRoundUnit,
                  (v) => isSupplyManual = v,
                  (u) => supplyRoundUnit = u,
                  Colors.blue[800]!,
                  "supply",
                ),
                const SizedBox(width: 12),
                _buildPriceControl(
                  '최종 판매가',
                  manualSellingController,
                  isSellingManual,
                  sellingRoundUnit,
                  (v) => isSellingManual = v,
                  (u) => sellingRoundUnit = u,
                  Colors.green[800]!,
                  "selling",
                ),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(child: _buildField('총 택배비', shippingController)),
                const SizedBox(width: 12),
                Expanded(child: _buildField('박스당 수량', boxQuantityController)),
              ],
            ),
            const SizedBox(height: 20),
            _buildReport(sellP, baseC),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: addHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "계산 기록 저장",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                "--- 계산 히스토리 ---",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              ...history.map(
                (h) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(
                      h,
                      style: const TextStyle(
                        fontSize: 12,
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

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            suffixText: suffix,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
          onChanged: (v) => calculate(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPriceControl(
    String label,
    TextEditingController ctrl,
    bool isMan,
    int unit,
    Function(bool) toggle,
    Function(int) setUnit,
    Color col,
    String type,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: col,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            enabled: isMan,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              fillColor: isMan ? Colors.white : Colors.grey[100],
              filled: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
            onChanged: (v) => calculate(trigger: type),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _roundChip('10', 10, unit, setUnit),
                  const SizedBox(width: 4),
                  _roundChip('100', 100, unit, setUnit),
                ],
              ),
              IconButton(
                icon: Icon(
                  isMan ? Icons.edit : Icons.edit_off,
                  size: 20,
                  color: isMan ? Colors.red : Colors.grey,
                ),
                onPressed:
                    () => setState(() {
                      toggle(!isMan);
                      calculate();
                    }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundChip(String lab, int u, int curr, Function(int) onS) {
    bool isSelected = (curr == u);
    return InkWell(
      onTap:
          () => setState(() {
            onS(isSelected ? 1 : u);
            calculate();
          }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          lab,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildReport(double sell, double cost) {
    double profit = sell - cost;
    double rate = sell > 0 ? (profit / sell * 100) : 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text(
            '최종 결과 보고 (배송비 포함)',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _repItem("최종매장이익률(개당)", "${rate.toStringAsFixed(1)}%"),
              _repItem("최종매장이익금(개당)", "${profit.toStringAsFixed(0)}원"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _repItem(String t, String v) => Column(
    children: [
      Text(t, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      const SizedBox(height: 4),
      Text(
        v,
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}
