import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AnyPriceApp());

class AnyPriceApp extends StatelessWidget {
  const AnyPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다계산해줄지니어스',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      ),
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

  // 트렌디 컬러 10개 (라이트 모드 기반)
  final List<Color> themeColors = const [
    Color(0xFFFF6F61), // 코랄
    Color(0xFFFF9AA2), // 살몬 핑크
    Color(0xFF7FDBDA), // 민트
    Color(0xFF5DADEC), // 소프트 블루
    Color(0xFF273469), // 네이비
    Color(0xFF6B8E23), // 올리브
    Color(0xFFF4B41A), // 머스타드
    Color(0xFF8D909B), // 워밍 그레이
    Color(0xFF36454F), // 차콜
    Color(0xFF4B0082), // 다크 퍼플
  ];

  Color themeColor = const Color(0xFFFF6F61); // 기본 코랄

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
        if (supply > 0 && cost > 0) {
          headMarginRateController.text = ((supply - cost) / supply * 100)
              .toStringAsFixed(1);
        }
      } else if (trigger == "selling") {
        // 5. 최종 판매가 직접 입력 → 매장 이익률 계산
        if (selling > 0 && supply > 0) {
          double profit = selling - supply - shipPerItem;
          storeMarginRateController.text = (profit / selling * 100)
              .toStringAsFixed(1);
        }
      } else if (trigger == "headRate") {
        // 2. 본사 마진율 입력 → 지점공급가 계산
        if (headRate < 100 && cost > 0) {
          supply = cost / (1 - headRate / 100);
          if (isRoundTo100) {
            supply = (supply / 100).round() * 100.0;
          }
          supplyPriceController.text = supply.toStringAsFixed(0);
        }
      } else if (trigger == "storeRate") {
        // 4. 매장 이익률 입력 → 최종 판매가 계산
        if (storeRate < 100 && supply > 0) {
          selling = (supply + shipPerItem) / (1 - storeRate / 100);
          if (isRoundTo100) {
            selling = (selling / 100).round() * 100.0;
          }
          sellingPriceController.text = selling.toStringAsFixed(0);
        }
      } else {
        // 택배비 / 입수량 변경 시: 판매가 고정, 이익률만 재계산
        if (selling > 0 && supply > 0) {
          double profit = selling - supply - shipPerItem;
          storeMarginRateController.text = (profit / selling * 100)
              .toStringAsFixed(1);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double proposal = double.tryParse(proposalController.text) ?? 0;
    double headRate = double.tryParse(headMarginRateController.text) ?? 0;
    double storeRate = double.tryParse(storeMarginRateController.text) ?? 0;
    double supply = double.tryParse(supplyPriceController.text) ?? 0;
    double selling = double.tryParse(sellingPriceController.text) ?? 0;
    double shipTotal = double.tryParse(shippingController.text) ?? 0;
    double qty = double.tryParse(boxQtyController.text) ?? 1;
    if (qty <= 0) qty = 1;
    double shipPerItem = shipTotal / qty;

    double finalProfit = selling - supply - shipPerItem; // 실질 이익금
    double finalRate =
        selling > 0 ? (finalProfit / selling * 100) : 0; // 실질 이익률
    double diff = selling - supply; // 판매가 - 공급가 차액

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '다계산해줄지니어스',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildThemeSelector(),
            const SizedBox(height: 16),
            _buildInfoCard(
              proposal,
              headRate,
              supply,
              storeRate,
              selling,
              finalProfit,
              diff,
            ),
            const SizedBox(height: 20),
            _buildInputCard(),
          ],
        ),
      ),
    );
  }

  // 상단 색상 선택 (작고 간결하게)
  Widget _buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "테마 색상",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                themeColors.map((c) {
                  final bool selected = (themeColor == c);
                  return GestureDetector(
                    onTap: () => setState(() => themeColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: selected ? 30 : 24,
                      height: selected ? 30 : 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black : Colors.grey.shade300,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  // 정보 표시 카드 (입력과 완전히 분리)
  Widget _buildInfoCard(
    double proposal,
    double headRate,
    double supply,
    double storeRate,
    double selling,
    double profit,
    double diff,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor.withOpacity(0.9), themeColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withOpacity(0.9),
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                "계산 결과",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white54, height: 20),

          _buildInfoRow(
            "제안단가",
            proposal > 0
                ? "${proposal.toStringAsFixed(0)}원 ${isVatIncluded ? '(VAT포함)' : '(VAT별도)'}"
                : "-",
          ),
          const SizedBox(height: 8),

          _buildInfoRow(
            "본사 마진율",
            headRate > 0 ? "${headRate.toStringAsFixed(1)}%" : "-",
          ),
          const SizedBox(height: 8),

          _buildInfoRow(
            "지점공급가",
            supply > 0 ? "${supply.toStringAsFixed(0)}원" : "-",
          ),
          const SizedBox(height: 8),

          _buildInfoRow(
            "매장 이익률",
            storeRate > 0 ? "${storeRate.toStringAsFixed(1)}%" : "-",
          ),
          const SizedBox(height: 8),

          _buildInfoRow(
            "최종 판매가",
            selling > 0 ? "${selling.toStringAsFixed(0)}원" : "-",
          ),

          const Divider(color: Colors.white54, height: 20),

          _buildInfoRow(
            "실질 이익금 (택배비 반영)",
            selling > 0 && supply > 0 ? "${profit.toStringAsFixed(0)}원" : "-",
            isBold: true,
          ),
          const SizedBox(height: 8),

          _buildInfoRow(
            "판매가 - 공급가 차액",
            selling > 0 && supply > 0 ? "${diff.toStringAsFixed(0)}원" : "-",
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.95),
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // 입력 카드 (본체)
  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: themeColor, size: 20),
              const SizedBox(width: 6),
              const Text(
                "입력 영역",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            "기본 정보",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // 1. 제안 단가
          _buildInput(
            "1. 제안 단가",
            proposalController,
            (v) => calculate(),
            inputFormatters: [intFormatter],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCheck("VAT 포함", isVatIncluded, (v) {
                setState(() {
                  isVatIncluded = v ?? false;
                  calculate();
                });
              }),
              _buildCheck("100원 단위 정리", isRoundTo100, (v) {
                setState(() {
                  isRoundTo100 = v ?? false;
                  calculate();
                });
              }),
            ],
          ),

          const SizedBox(height: 18),
          const Text(
            "본사 · 지점 조건",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

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

          const SizedBox(height: 18),
          const Text(
            "매장 판매 조건",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

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

          const SizedBox(height: 18),
          const Text(
            "물류 조건",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),

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
        ],
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
