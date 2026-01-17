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

      // 1. 공급가 직접 입력 시 모드 자동 전환 및 역산
      if (trigger == "supply") {
        isSupplyManual = true;
        double sPrice = double.tryParse(manualSupplyController.text) ?? 0;
        if (costWithVat > 0) {
          headOfficeMarginController.text = ((sPrice / costWithVat - 1) * 100)
              .toStringAsFixed(1);
        }
      }
      // 2. 판매가 직접 입력 시 모드 자동 전환 및 역산
      else if (trigger == "selling") {
        isSellingManual = true;
        double fPrice = double.tryParse(manualSellingController.text) ?? 0;
        double sPrice = double.tryParse(manualSupplyController.text) ?? 0;
        if (sPrice > 0) {
          storeMarginController.text = ((fPrice / sPrice - 1) * 100)
              .toStringAsFixed(1);
        }
      }

      // 3. 마진율 수정 시 수동 모드 해제 및 자동 계산
      if (trigger == "headMargin") isSupplyManual = false;
      if (trigger == "storeMargin") isSellingManual = false;

      if (!isSupplyManual) {
        double rawSupply = costWithVat * (1 + headRate / 100);
        manualSupplyController.text = rawSupply.toStringAsFixed(0);
      }

      if (!isSellingManual) {
        double currentSupply =
            double.tryParse(manualSupplyController.text) ?? 0;
        double rawSelling = currentSupply * (1 + storeRate / 100);
        manualSellingController.text = rawSelling.toStringAsFixed(0);
      }
    });
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
      history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    double inputC = double.tryParse(costController.text) ?? 0;
    double vatAmt = isVatIncluded ? inputC / 1.1 * 0.1 : inputC * 0.1;
    double costWithVat = isVatIncluded ? inputC : inputC * 1.1;

    double shipTotal = double.tryParse(shippingController.text) ?? 0;
    double bQty = double.tryParse(boxQuantityController.text) ?? 1;
    double shipPerItem = shipTotal / bQty;

    double sPrice = double.tryParse(manualSupplyController.text) ?? 0;
    double fPrice = double.tryParse(manualSellingController.text) ?? 0;

    double headProfit = sPrice - costWithVat;
    double storeProfit = fPrice - sPrice;
    double totalBaseCost = costWithVat + shipPerItem;
    double finalNetProfit = fPrice - totalBaseCost;
    double finalRate = fPrice > 0 ? (finalNetProfit / fPrice * 100) : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '올인원계산기',
          style: TextStyle(fontWeight: FontWeight.w900),
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
            _buildField('원가(공급가액)', costController, (v) => calculate()),
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
                Text(
                  'VAT 포함 (자동계산: ${vatAmt.toStringAsFixed(0)}원)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    '본사 마진%',
                    headOfficeMarginController,
                    (v) => calculate(trigger: "headMargin"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    '매장 마진%',
                    storeMarginController,
                    (v) => calculate(trigger: "storeMargin"),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    '공급가 직접입력',
                    manualSupplyController,
                    (v) => calculate(trigger: "supply"),
                    color: Colors.blue[50],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    '판매가 직접입력',
                    manualSellingController,
                    (v) => calculate(trigger: "selling"),
                    color: Colors.green[50],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '본사익: ${headProfit.toStringAsFixed(0)}원',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '매장익: ${storeProfit.toStringAsFixed(0)}원',
                    style: TextStyle(
                      color: Colors.green[900],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    '총 택배비',
                    shippingController,
                    (v) => calculate(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildField(
                    '박스 수량',
                    boxQuantityController,
                    (v) => calculate(),
                  ),
                ),
              ],
            ),
            Text(
              '개당 배송비: ${shipPerItem.toStringAsFixed(0)}원',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildReport(finalRate, finalNetProfit),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed:
                  () => setState(
                    () => history.insert(
                      0,
                      "공급:${sPrice.toStringAsFixed(0)} | 판매:${fPrice.toStringAsFixed(0)} | 이익률:${finalRate.toStringAsFixed(1)}%",
                    ),
                  ),
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
            if (history.isNotEmpty) ...[
              const SizedBox(height: 20),
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
    TextEditingController ctrl,
    Function(String) onChg, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChg,
          decoration: InputDecoration(
            filled: true,
            fillColor: color ?? Colors.white,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReport(double rate, double profit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _repItem("최종매장이익률(개당)", "${rate.toStringAsFixed(1)}%"),
          _repItem("최종매장이익금(개당)", "${profit.toStringAsFixed(0)}원"),
        ],
      ),
    );
  }

  Widget _repItem(String t, String v) => Column(
    children: [
      Text(t, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      const SizedBox(height: 5),
      Text(
        v,
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}
