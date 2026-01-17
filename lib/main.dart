import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AnyPriceApp());

class AnyPriceApp extends StatelessWidget {
  const AnyPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다계산해줄지니',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const AnyPriceScreen(),
    );
  }
}

class AnyPriceScreen extends StatefulWidget {
  const AnyPriceScreen({super.key});

  @override
  State<AnyPriceScreen> createState() => _AnyPriceScreenState();
}

class _AnyPriceScreenState extends State<AnyPriceScreen> {
  final proposalController = TextEditingController();
  final headMarginRateController = TextEditingController();
  final storeMarginRateController = TextEditingController();
  final supplyPriceController = TextEditingController();
  final sellingPriceController = TextEditingController();
  final shippingController = TextEditingController();
  final boxQtyController = TextEditingController(text: "1");

  bool isVatIncluded = false;
  bool isRoundTo100 = false;

  // 테마 옵션 한 군데로 정리
  final List<Map<String, dynamic>> themeOptions = const [
    {'name': '오렌지', 'color': Color(0xFFFF9800)},
    {'name': '블루', 'color': Color(0xFF2196F3)},
    {'name': '그린', 'color': Color(0xFF4CAF50)},
    {'name': '레드', 'color': Color(0xFFF44336)},
    {'name': '다크', 'color': Color(0xFF607D8B)},
  ];

  Color themeColor = const Color(0xFFFF9800);

  // 숫자 입력 포맷터
  final TextInputFormatter intFormatter =
      FilteringTextInputFormatter.digitsOnly;
  final TextInputFormatter decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9.]'),
  );

  @override
  void dispose() {
    proposalController.dispose();
    headMarginRateController.dispose();
    storeMarginRateController.dispose();
    supplyPriceController.dispose();
    sellingPriceController.dispose();
    shippingController.dispose();
    boxQtyController.dispose();
    super.dispose();
  }

  void calculate({String? trigger}) {
    double proposal = double.tryParse(proposalController.text) ?? 0;
    double cost = isVatIncluded ? proposal : proposal * 1.1;
    double headRate = double.tryParse(headMarginRateController.text) ?? 0;
    double storeRate = double.tryParse(storeMarginRateController.text) ?? 0;
    double supply = double.tryParse(supplyPriceController.text) ?? 0;
    double selling = double.tryParse(sellingPriceController.text) ?? 0;
    double shipTotal = double.tryParse(shippingController.text) ?? 0;
    double qty = double.tryParse(boxQtyController.text) ?? 1;
    if (qty <= 0) qty = 1;
    double shipPerItem = shipTotal / qty;

    setState(() {
      if (trigger == "supply") {
        // 3. 지점공급가 직접 입력 → 본사 마진율 계산
        if (supply > 0) {
          headMarginRateController.text = ((supply - cost) / supply * 100)
              .toStringAsFixed(1);
        }
      } else if (trigger == "selling") {
        // 5. 최종 판매가 직접 입력 → 매장 이익률 계산
        if (selling > 0) {
          double profit = selling - supply - shipPerItem;
          storeMarginRateController.text = (profit / selling * 100)
              .toStringAsFixed(1);
        }
      } else if (trigger == "headRate") {
        // 2. 본사 마진율 입력 → 지점공급가 계산
        if (headRate < 100) {
          supply = cost / (1 - headRate / 100);
          if (isRoundTo100) {
            supply = (supply / 100).round() * 100.0;
          }
          supplyPriceController.text = supply.toStringAsFixed(0);
        }
      } else if (trigger == "storeRate") {
        // 4. 매장 이익률 입력 → 최종 판매가 계산
        if (storeRate < 100) {
          selling = (supply + shipPerItem) / (1 - storeRate / 100);
          if (isRoundTo100) {
            selling = (selling / 100).round() * 100.0;
          }
          sellingPriceController.text = selling.toStringAsFixed(0);
        }
      } else {
        // 택배비 / 입수량 변경 시: 판매가 고정, 이익률만 재계산
        if (selling > 0) {
          double profit = selling - supply - shipPerItem;
          storeMarginRateController.text = (profit / selling * 100)
              .toStringAsFixed(1);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double s = double.tryParse(supplyPriceController.text) ?? 0;
    double f = double.tryParse(sellingPriceController.text) ?? 0;
    double shipTotal = double.tryParse(shippingController.text) ?? 0;
    double qty = double.tryParse(boxQtyController.text) ?? 1;
    if (qty <= 0) qty = 1;
    double shipPerItem = shipTotal / qty;

    double finalProfit = f - s - shipPerItem;
    double finalRate = f > 0 ? (finalProfit / f * 100) : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '다계산해줄지니',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "테마 색상 선택",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(themeOptions.length, (index) {
                  final opt = themeOptions[index];
                  final Color c = opt['color'] as Color;
                  final String name = opt['name'] as String;

                  return GestureDetector(
                    onTap: () => setState(() => themeColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: themeColor == c ? themeColor : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: themeColor == c ? Colors.white : Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Divider(height: 30),

            // 1. 제안 단가
            _buildInput(
              "1. 제안 단가",
              proposalController,
              (v) => calculate(),
              inputFormatters: [intFormatter],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCheck(
                  "VAT 포함",
                  isVatIncluded,
                  (v) => setState(() {
                    isVatIncluded = v ?? false;
                    // VAT 방식 바꿀 때는 값만 다시 계산
                    calculate();
                  }),
                ),
                _buildCheck(
                  "100원 단위 정리",
                  isRoundTo100,
                  (v) => setState(() {
                    isRoundTo100 = v ?? false;
                    calculate();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 2, 3
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "2. 본사 마진율(%)",
                    headMarginRateController,
                    (v) => calculate(trigger: "headRate"),
                    inputFormatters: [decimalFormatter],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    "3. 지점공급가",
                    supplyPriceController,
                    (v) => calculate(trigger: "supply"),
                    color: themeColor.withOpacity(0.05),
                    inputFormatters: [intFormatter],
                  ),
                ),
              ],
            ),
            const Divider(height: 40),

            // 4, 5
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "4. 매장 이익률(%)",
                    storeMarginRateController,
                    (v) => calculate(trigger: "storeRate"),
                    inputFormatters: [decimalFormatter],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    "5. 최종 판매가",
                    sellingPriceController,
                    (v) => calculate(trigger: "selling"),
                    color: Colors.green[50],
                    inputFormatters: [intFormatter],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // 택배비, 입수량
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "총 택배비",
                    shippingController,
                    (v) => calculate(),
                    inputFormatters: [intFormatter],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    "입수량",
                    boxQtyController,
                    (v) => calculate(),
                    inputFormatters: [intFormatter],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            _buildReport(finalRate, finalProfit),
          ],
        ),
      ),
    );
  }

  Widget _buildCheck(String label, bool val, Function(bool?) onChg) {
    return Row(
      children: [
        Checkbox(value: val, activeColor: themeColor, onChanged: onChg),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController ctrl,
    Function(String) onChg, {
    Color? color,
    List<TextInputFormatter>? inputFormatters,
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
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            filled: true,
            fillColor: color ?? Colors.white,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
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
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _repItem("최종 매장 이익률", "${rate.toStringAsFixed(1)}%"),
          _repItem("최종 매장 이익금", "${profit.toStringAsFixed(0)}원"),
        ],
      ),
    );
  }

  Widget _repItem(String t, String v) {
    return Column(
      children: [
        Text(t, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 5),
        Text(
          v,
          style: TextStyle(
            color: themeColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
