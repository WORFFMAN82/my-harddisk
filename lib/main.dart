import 'package:flutter/material.dart';

void main() => runApp(const AnyPriceApp());

class AnyPriceApp extends StatelessWidget {
  const AnyPriceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '아무단가나그냥너어',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: true),
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
  List<String> history = [];

  void calculate({String? trigger}) {
    double proposal = double.tryParse(proposalController.text) ?? 0;
    double cost = isVatIncluded ? proposal : proposal * 1.1; // 최종 매입원가

    double headRate = double.tryParse(headMarginRateController.text) ?? 0;
    double storeRate = double.tryParse(storeMarginRateController.text) ?? 0;
    double supply = double.tryParse(supplyPriceController.text) ?? 0;
    double selling = double.tryParse(sellingPriceController.text) ?? 0;

    setState(() {
      // 1. 공급가 수정 -> 원가 대비 마크업 역산
      if (trigger == "supply") {
        if (cost > 0)
          headMarginRateController.text = ((supply / cost - 1) * 100)
              .toStringAsFixed(1);
      }
      // 2. 판매가 수정 -> 판매가 기준 이익률(형님 방식) 역산
      else if (trigger == "selling") {
        if (selling > 0)
          storeMarginRateController.text = ((selling - supply) / selling * 100)
              .toStringAsFixed(1);
      }
      // 3. 본사 마진율 수정 -> 공급가 계산
      else if (trigger == "headRate") {
        supply = cost * (1 + headRate / 100);
        supplyPriceController.text = supply.toStringAsFixed(0);
      }
      // 4. 매장 마진율 수정 -> 판매가 기준(형님 방식)으로 가격 결정
      else if (trigger == "storeRate") {
        // 공식: 판매가 = 공급가 / (1 - 이익률)
        if (storeRate < 100) {
          selling = supply / (1 - storeRate / 100);
          sellingPriceController.text = selling.toStringAsFixed(0);
        }
      }
      // 5. 기본 연동
      else {
        supply = cost * (1 + headRate / 100);
        supplyPriceController.text = supply.toStringAsFixed(0);
        if (storeRate < 100) {
          selling = supply / (1 - storeRate / 100);
          sellingPriceController.text = selling.toStringAsFixed(0);
        }
      }
    });
  }

  void reset() {
    setState(() {
      proposalController.clear();
      headMarginRateController.clear();
      storeMarginRateController.clear();
      supplyPriceController.clear();
      sellingPriceController.clear();
      shippingController.clear();
      boxQtyController.text = "1";
      isVatIncluded = false;
      history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    double p = double.tryParse(proposalController.text) ?? 0;
    double cost = isVatIncluded ? p : p * 1.1;
    double s = double.tryParse(supplyPriceController.text) ?? 0;
    double f = double.tryParse(sellingPriceController.text) ?? 0;
    double shipTotal = double.tryParse(shippingController.text) ?? 0;
    double qty = double.tryParse(boxQtyController.text) ?? 1;
    double shipPerItem = shipTotal / qty;

    // 최종 매장 이익금 = 판매가 - 공급가 - 개당 배송비
    double finalNetProfit = f - s - shipPerItem;
    // 최종 매장 이익률 = (판매가 - 공급가 - 개당 배송비) / 판매가 (형님 방식 적용)
    double finalRate = f > 0 ? (finalNetProfit / f * 100) : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '아무단가나그냥너어',
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
            _buildInput("1. 제안 단가 입력", proposalController, (v) => calculate()),
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
                  "VAT 포함 제안 (최종매입가: ${cost.toStringAsFixed(0)}원)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "2. 본사 마진율(%)",
                    headMarginRateController,
                    (v) => calculate(trigger: "headRate"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    "3. 지점공급가",
                    supplyPriceController,
                    (v) => calculate(trigger: "supply"),
                    color: Colors.blue[50],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "4. 매장 이익률(판매가 기준 %)",
                    storeMarginRateController,
                    (v) => calculate(trigger: "storeRate"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    "5. 최종 판매가",
                    sellingPriceController,
                    (v) => calculate(trigger: "selling"),
                    color: Colors.green[50],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "총 택배비",
                    shippingController,
                    (v) => calculate(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput(
                    "박스입수량",
                    boxQtyController,
                    (v) => calculate(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _buildReport(finalRate, finalNetProfit),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed:
                  () => setState(
                    () => history.insert(
                      0,
                      "공급:${s.toStringAsFixed(0)}→판매:${f.toStringAsFixed(0)} (이익률:${finalRate.toStringAsFixed(1)}%)",
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

  Widget _buildInput(
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
              vertical: 10,
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
