import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MarginCalculatorApp());
}

class MarginCalculatorApp extends StatelessWidget {
  const MarginCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '마진율 계산기',
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
  final TextEditingController costController = TextEditingController();
  final TextEditingController headOfficeMarginController =
      TextEditingController();
  final TextEditingController storeMarginController = TextEditingController();
  final TextEditingController shippingController = TextEditingController();
  final TextEditingController boxQuantityController = TextEditingController();
  final TextEditingController manualSupplyController = TextEditingController();
  final TextEditingController manualSellingController = TextEditingController();

  bool isVatIncluded = false;
  bool isSupplyManual = false;
  bool isSellingManual = false;
  int supplyRoundUnit = 1;
  int sellingRoundUnit = 1;

  double costWithVat = 0;
  double shippingPerItem = 0;
  double totalBaseCost = 0;
  double supplyPrice = 0;
  double sellingPrice = 0;

  void calculate() {
    double inputCost = double.tryParse(costController.text) ?? 0;
    double headOfficeRate =
        double.tryParse(headOfficeMarginController.text) ?? 0;
    double storeRate = double.tryParse(storeMarginController.text) ?? 0;
    double totalShipping = double.tryParse(shippingController.text) ?? 0;
    double boxQty = double.tryParse(boxQuantityController.text) ?? 1;
    if (boxQty <= 0) boxQty = 1;

    setState(() {
      costWithVat = isVatIncluded ? inputCost : inputCost * 1.1;
      shippingPerItem = totalShipping / boxQty;
      totalBaseCost = costWithVat + shippingPerItem;

      if (!isSupplyManual) {
        double rawSupply = costWithVat + (costWithVat * (headOfficeRate / 100));
        supplyPrice = _applyRounding(rawSupply, supplyRoundUnit);
        manualSupplyController.text = supplyPrice.toStringAsFixed(0);
      } else {
        supplyPrice = double.tryParse(manualSupplyController.text) ?? 0;
      }

      if (!isSellingManual) {
        double rawSelling = supplyPrice + (supplyPrice * (storeRate / 100));
        sellingPrice = _applyRounding(rawSelling, sellingRoundUnit);
        manualSellingController.text = sellingPrice.toStringAsFixed(0);
      } else {
        sellingPrice = double.tryParse(manualSellingController.text) ?? 0;
      }
    });
  }

  void reverseCalculateSupply(String value) {
    if (!isSupplyManual) return;
    double inputSupply = double.tryParse(value) ?? 0;
    double cost =
        isVatIncluded
            ? (double.tryParse(costController.text) ?? 0)
            : (double.tryParse(costController.text) ?? 0) * 1.1;

    if (cost > 0) {
      double calculatedMargin = ((inputSupply / cost) - 1) * 100;
      headOfficeMarginController.text = calculatedMargin.toStringAsFixed(1);
    }
    calculate();
  }

  void reverseCalculateSelling(String value) {
    if (!isSellingManual) return;
    double inputSelling = double.tryParse(value) ?? 0;
    double sPrice = double.tryParse(manualSupplyController.text) ?? 0;

    if (sPrice > 0) {
      double calculatedMargin = ((inputSelling / sPrice) - 1) * 100;
      storeMarginController.text = calculatedMargin.toStringAsFixed(1);
    }
    calculate();
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
      boxQuantityController.text = "1"; // 에러 원인 수정: clear 대신 text 직접 지정
      manualSupplyController.clear();
      manualSellingController.clear();
      isVatIncluded = false;
      isSupplyManual = false;
      isSellingManual = false;
      supplyRoundUnit = 1;
      sellingRoundUnit = 1;
      costWithVat = 0;
      supplyPrice = 0;
      sellingPrice = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'WORKUP',
          style: TextStyle(
            color: Colors.black,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.orange,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: reset,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInput('원가 (공급가액)', costController, suffix: '원'),
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
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    '본사 마진율',
                    headOfficeMarginController,
                    suffix: '%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInput(
                    '매장 마진율',
                    storeMarginController,
                    suffix: '%',
                  ),
                ),
              ],
            ),
            const Divider(height: 40, thickness: 2, color: Colors.black12),
            const Text(
              '단가 조율 (수동 버튼 클릭 시 수정 및 마진 역산)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPriceControlColumn(
                  '공급가',
                  manualSupplyController,
                  isSupplyManual,
                  supplyRoundUnit,
                  (val) => isSupplyManual = val,
                  (unit) => supplyRoundUnit = unit,
                  Colors.blue[800]!,
                  reverseCalculateSupply,
                ),
                const SizedBox(width: 12),
                _buildPriceControlColumn(
                  '최종 판매가',
                  manualSellingController,
                  isSellingManual,
                  sellingRoundUnit,
                  (val) => isSellingManual = val,
                  (unit) => sellingRoundUnit = unit,
                  Colors.green[800]!,
                  reverseCalculateSelling,
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              '배송비 설정',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildInput('총 택배비', shippingController, suffix: '원'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInput(
                    '박스당 수량',
                    boxQuantityController,
                    suffix: '개',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _buildReportCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller, {
    String? suffix,
    bool enabled = true,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixText: suffix,
            filled: !enabled,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
          onChanged: onChanged ?? (value) => calculate(),
        ),
      ],
    );
  }

  Widget _buildPriceControlColumn(
    String label,
    TextEditingController controller,
    bool isManual,
    int currentUnit,
    Function(bool) onManualToggle,
    Function(int) onUnitSelect,
    Color color,
    Function(String) onReverse,
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
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          _buildInput(
            '',
            controller,
            suffix: '원',
            enabled: isManual,
            onChanged: onReverse,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _roundChip('10', 10, currentUnit, onUnitSelect),
              _roundChip('100', 100, currentUnit, onUnitSelect),
              GestureDetector(
                onTap: () {
                  setState(() {
                    onManualToggle(!isManual);
                    calculate();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isManual ? Colors.red[50] : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isManual ? Icons.edit : Icons.edit_off,
                        size: 12,
                        color: isManual ? Colors.red : Colors.grey,
                      ),
                      const Text(
                        '수동',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundChip(
    String label,
    int unit,
    int currentUnit,
    Function(int) onSelect,
  ) {
    bool isSelected = currentUnit == unit;
    return InkWell(
      onTap: () {
        setState(() {
          onSelect(isSelected ? 1 : unit);
          calculate();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard() {
    double netProfit = sellingPrice - totalBaseCost;
    double profitRate = sellingPrice > 0 ? (netProfit / sellingPrice * 100) : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text('최종 마진 리포트', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                '개당 배송비',
                '${shippingPerItem.toStringAsFixed(0)}원',
              ),
              _buildSummaryItem('순이익률', '${profitRate.toStringAsFixed(1)}%'),
              _buildSummaryItem('개당 순이익', '${netProfit.toStringAsFixed(0)}원'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
