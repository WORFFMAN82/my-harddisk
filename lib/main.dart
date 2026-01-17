import 'package:flutter/material.dart';

void main() => runApp(const MarginApp());

class MarginApp extends StatelessWidget {
  const MarginApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MarginCalculator(),
    );
  }
}

class MarginCalculator extends StatefulWidget {
  const MarginCalculator({super.key});
  @override
  State<MarginCalculator> createState() => _MarginCalculatorState();
}

class _MarginCalculatorState extends State<MarginCalculator> {
  final TextEditingController _costController = TextEditingController(); // 원가
  final TextEditingController _marginController =
      TextEditingController(); // 마진율
  final TextEditingController _shippingController =
      TextEditingController(); // 택배비
  final TextEditingController _qtyController = TextEditingController(
    text: "1",
  ); // 박스당 수량
  final TextEditingController _priceController =
      TextEditingController(); // 판매가(직접 입력용)

  double _finalPrice = 0; // 최종 판매가
  double _profit = 0; // 순이익

  @override
  void initState() {
    super.initState();
    // 입력할 때마다 실시간 계산
    _costController.addListener(_calculateByMargin);
    _marginController.addListener(_calculateByMargin);
    _shippingController.addListener(_calculateByMargin);
    _qtyController.addListener(_calculateByMargin);
  }

  // 1. 원가/마진율 기준으로 판매가 계산
  void _calculateByMargin() {
    double cost = double.tryParse(_costController.text) ?? 0;
    double marginPercent = double.tryParse(_marginController.text) ?? 0;
    double shipping = double.tryParse(_shippingController.text) ?? 0;
    double qty = double.tryParse(_qtyController.text) ?? 1;
    if (qty <= 0) qty = 1;

    double shippingPerItem = shipping / qty;

    setState(() {
      _finalPrice = cost * (1 + marginPercent / 100) + shippingPerItem;
      _profit = _finalPrice - cost - shippingPerItem;
      // 판매가 칸에 실시간 반영 (포커스가 없을 때만)
      if (!_priceFocusNode.hasFocus) {
        _priceController.text = _finalPrice.toStringAsFixed(0);
      }
    });
  }

  // 2. 판매가 직접 입력 시 마진율 역계산
  void _calculateByPrice(String value) {
    double inputPrice = double.tryParse(value) ?? 0;
    double cost = double.tryParse(_costController.text) ?? 0;
    double shipping = double.tryParse(_shippingController.text) ?? 0;
    double qty = double.tryParse(_qtyController.text) ?? 1;
    if (qty <= 0) qty = 1;

    double shippingPerItem = shipping / qty;

    if (cost > 0) {
      double reverseMargin = ((inputPrice - shippingPerItem) / cost - 1) * 100;
      setState(() {
        _marginController.text = reverseMargin.toStringAsFixed(1);
        _finalPrice = inputPrice;
        _profit = _finalPrice - cost - shippingPerItem;
      });
    }
  }

  final FocusNode _priceFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마진율 역산 계산기')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildInput("원가 (₩)", _costController),
              _buildInput("마진율 (%)", _marginController),
              _buildInput("택배비 (₩)", _shippingController),
              _buildInput("박스당 수량", _qtyController),
              const Divider(height: 30),
              _buildInput(
                "판매가 직접 설정 (₩)",
                _priceController,
                onChanged: _calculateByPrice,
                focusNode: _priceFocusNode,
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.blue[50],
                child: Column(
                  children: [
                    Text(
                      "최종 판매가: ${_finalPrice.toStringAsFixed(0)}원",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "개당 순이익: ${_profit.toStringAsFixed(0)}원",
                      style: const TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller, {
    Function(String)? onChanged,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}
