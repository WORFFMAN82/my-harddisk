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
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
  final TextEditingController manualSupplyController =
      TextEditingController(); // 공급가 수동
  final TextEditingController manualSellingController =
      TextEditingController(); // 판매가 수동

  bool isVatIncluded = false;
  bool isSupplyManual = false;
  bool isSellingManual = false;
  int supplyRoundUnit = 1;
  int sellingRoundUnit = 1;

  double inputCost = 0;
  double costWithVat = 0;
  double shippingPerItem = 0;
  double totalBaseCost = 0;
  double headOfficeMarginAmount = 0;
  double supplyPrice = 0;
  double storeMarginAmount = 0;
  double sellingPrice = 0;

  void calculate() {
    inputCost = double.tryParse(costController.text) ?? 0;
    double headOfficeMarginRate =
        double.tryParse(headOfficeMarginController.text) ?? 0;
    double storeMarginRate = double.tryParse(storeMarginController.text) ?? 0;
    double totalShipping = double.tryParse(shippingController.text) ?? 0;
    double boxQty = double.tryParse(boxQuantityController.text) ?? 1;
    if (boxQty <= 0) boxQty = 1;

    setState(() {
      costWithVat = isVatIncluded ? inputCost : inputCost * 1.1;
      shippingPerItem = totalShipping / boxQty;
      totalBaseCost = costWithVat + shippingPerItem;

      // 1. 공급가 계산
      if (isSupplyManual) {
        supplyPrice = double.tryParse(manualSupplyController.text) ?? 0;
      } else {
        double rawSupply =
            costWithVat + (costWithVat * (headOfficeMarginRate / 100));
        supplyPrice = _applyRounding(rawSupply, supplyRoundUnit);
        manualSupplyController.text = supplyPrice.toStringAsFixed(0);
      }

      // 2. 판매가 계산 (공급가 기준)
      if (isSellingManual) {
        sellingPrice = double.tryParse(manualSellingController.text) ?? 0;
      } else {
        double rawSelling =
            supplyPrice + (supplyPrice * (storeMarginRate / 100));
        sellingPrice = _applyRounding(rawSelling, sellingRoundUnit);
        manualSellingController.text = sellingPrice.toStringAsFixed(0);
      }

      headOfficeMarginAmount = supplyPrice - costWithVat;
      storeMarginAmount = sellingPrice - supplyPrice;
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
      boxQuantityController.clear();
      manualSupplyController.clear();
      manualSellingController.clear();
      isVatIncluded = false;
      isSupplyManual = false;
      isSellingManual = false;
      supplyRoundUnit = 1;
      sellingRoundUnit = 1;
      inputCost = 0;
      supplyPrice = 0;
      sellingPrice = 0;
    });
  }

  Widget buildInputField(
    String label,
    TextEditingController controller, {
    String? suffix,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        if (label.isNotEmpty) const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixText: suffix,
            hintText: '0',
            filled: !enabled,
            fillColor: enabled ? null : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
          ),
          onChanged: (value) => calculate(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WORKUP',
          style: TextStyle(
            color: Colors.black,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
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
            buildInputField('원가 입력 (공급가액)', costController, suffix: '원'),
            Row(
              children: [
                Checkbox(
                  value: isVatIncluded,
                  onChanged: (v) {
                    setState(() {
                      isVatIncluded = v!;
                      calculate();
                    });
                  },
                ),
                const Text(
                  'VAT 포함 원가임',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (!isVatIncluded && inputCost > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '최종 원가(VAT 포함): ${costWithVat.toStringAsFixed(0)}원',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: buildInputField(
                    '본사 마진율',
                    headOfficeMarginController,
                    suffix: '%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: buildInputField(
                    '매장 마진율',
                    storeMarginController,
                    suffix: '%',
                  ),
                ),
              ],
            ),
            const Divider(height: 40, thickness: 1.5),

            if (inputCost > 0) ...[
              const Text(
                '단가 계산 결과 (단위 정돈 및 수동 수정 가능)',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPriceControlColumn(
                    '예상 공급가',
                    manualSupplyController,
                    isSupplyManual,
                    supplyRoundUnit,
                    (val) => isSupplyManual = val,
                    (unit) => supplyRoundUnit = unit,
                    Colors.blue[800]!,
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
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text(
                '배송비 추가 설정',
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
                    child: buildInputField(
                      '총 택배비',
                      shippingController,
                      suffix: '원',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: buildInputField(
                      '박스당 입수량',
                      boxQuantityController,
                      suffix: '개',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      '최종 마진 리포트 (배송비 포함)',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem(
                          '개당 배송비',
                          '${shippingPerItem.toStringAsFixed(0)}원',
                        ),
                        _buildSummaryItem(
                          '최종 순이익률',
                          '${sellingPrice > 0 ? ((sellingPrice - totalBaseCost) / sellingPrice * 100).toStringAsFixed(1) : 0}%',
                        ),
                        _buildSummaryItem(
                          '개당 순이익',
                          '${(sellingPrice - totalBaseCost).toStringAsFixed(0)}원',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
          buildInputField('', controller, suffix: '원', enabled: isManual),
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
                      const SizedBox(width: 2),
                      Text(
                        '수동',
                        style: TextStyle(
                          fontSize: 10,
                          color: isManual ? Colors.red : Colors.grey,
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

  Widget _buildSummaryItem(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    costController.dispose();
    headOfficeMarginController.dispose();
    storeMarginController.dispose();
    shippingController.dispose();
    boxQuantityController.dispose();
    manualSupplyController.dispose();
    manualSellingController.dispose();
    super.dispose();
  }
}
