import 'package:flutter/material.dart';

void main() => runApp(const AnyPriceApp());

class AnyPriceApp extends StatelessWidget {
  const AnyPriceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다계산해줄지니',
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
  final storeMarginRateController = TextEditingController(); // 최종 매장 이익률 입력용
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
    double shipTotal = double.tryParse(shippingController.text) ?? 0;
    double qty = double.tryParse(boxQtyController.text) ?? 1;
    double shipPerItem = shipTotal / qty;

    setState(() {
      // 1. 지점공급가 수정 시 -> 본사 마진율 역계산
      if (trigger == "supply") {
        if (cost > 0)
          headMarginRateController.text = ((supply / cost - 1) * 100)
              .toStringAsFixed(1);
      }
      // 2. 최종 판매가 수정 시 -> 매장 이익률(판매가 기준) 역계산 (배송비 고려)
      else if (trigger == "selling") {
        if (selling > 0) {
          double profit = selling - supply - shipPerItem;
          storeMarginRateController.text = (profit / selling * 100)
              .toStringAsFixed(1);
        }
      }
      // 3. 본사 마진율 수정 시 -> 공급가 계산
      else if (trigger == "headRate") {
        supply = cost * (1 + headRate / 100);
        supplyPriceController.text = supply.toStringAsFixed(0);
      }
      // 4. 매장 이익률 직접 입력 시 -> 최종 판매가 역산 (형님의 핵심 요청)
      // 공식: 판매가 = (공급가 + 개당배송비) / (1 - 희망이익률/100)
      else if (trigger == "storeRate") {
        if (storeRate < 100) {
          selling = (supply + shipPerItem) / (1 - storeRate / 100);
          sellingPriceController.text = selling.toStringAsFixed(0);
        }
      }
      // 5. 원가/배송비 등 기본 변경 시 -> 현재 설정된 이익률 기준으로 판매가 갱신
      else {
        supply = cost * (1 + headRate / 100);
        supplyPriceController.text = supply.toStringAsFixed(0);
        if (storeRate < 100) {
          selling = (supply + shipPerItem) / (1 - storeRate / 100);
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

    double headProfit = s - cost;
    double finalNetProfit = f - s - shipPerItem;
    double finalRate = f > 0 ? (finalNetProfit / f * 100) : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              '다계산해줄지니',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
            Text(
              '(멋진 거래를 위하여)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
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
                  "VAT 포함 제안임 (최종매입가: ${cost.toStringAsFixed(0)}원)",
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
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                '본사 이익: ${headProfit.toStringAsFixed(0)}원',
                style: TextStyle(
                  color: Colors.blue[900],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 40, thickness: 1.5),
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    "4. 매장 이익률 직접입력(%)",
                    storeMarginRateController,
                    (v) => calculate(trigger: "storeRate"),
                    color: Colors.orange[50],
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
            const SizedBox(height: 20),
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
            const SizedBox(height: 30),
            _buildReport(finalRate, finalNetProfit),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  () => setState(
                    () => history.insert(
                      0,
                      "공급:${s.toStringAsFixed(0)}→판매:${f.toStringAsFixed(0)} (이익:${finalRate.toStringAsFixed(1)}%)",
                    ),
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "계산 기록 저장",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 20),
              ...history.map(
                (h) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
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
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChg,
          decoration: InputDecoration(
            filled: true,
            fillColor: color ?? Colors.white,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReport(double rate, double profit) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
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

  Widget _repItem(String t, String v) => Column(
    children: [
      Text(t, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 8),
      Text(
        v,
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}
