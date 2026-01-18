import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const AnyPriceApp());
}

class AnyPriceApp extends StatelessWidget {
  const AnyPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다계산해줄지니어스',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const AnyPriceScreen(),
    );
  }
}

class Product {
  final String code;
  final String barcode;
  final String name;
  final double purchasePrice;
  final double supplyPrice;
  final double sellingPrice;
  final int stock;

  Product({
    required this.code,
    required this.barcode,
    required this.name,
    required this.purchasePrice,
    required this.supplyPrice,
    required this.sellingPrice,
    required this.stock,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'barcode': barcode,
    'name': name,
    'purchasePrice': purchasePrice,
    'supplyPrice': supplyPrice,
    'sellingPrice': sellingPrice,
    'stock': stock,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    code: json['code'] ?? '',
    barcode: json['barcode'] ?? '',
    name: json['name'] ?? '',
    purchasePrice: (json['purchasePrice'] ?? 0.0).toDouble(),
    supplyPrice: (json['supplyPrice'] ?? 0.0).toDouble(),
    sellingPrice: (json['sellingPrice'] ?? 0.0).toDouble(),
    stock: json['stock'] ?? 0,
  );
}

class CalculationHistory {
  final String id;
  final DateTime timestamp;
  final double proposal;
  final bool isVatIncluded;
  final double headRate;
  final double supply;
  final double storeRate;
  final double selling;
  final double shipping;
  final double qty;
  final String memo;

  CalculationHistory({
    required this.id,
    required this.timestamp,
    required this.proposal,
    required this.isVatIncluded,
    required this.headRate,
    required this.supply,
    required this.storeRate,
    required this.selling,
    required this.shipping,
    required this.qty,
    this.memo = '',
  });

  double get vatIncludedProposal => isVatIncluded ? proposal : proposal * 1.1;
  double get shipPerItem => qty > 0 ? shipping / qty : 0;
  double get finalProfit => selling - supply - shipPerItem;
  double get finalRate => (selling > 0) ? (finalProfit / selling * 100) : 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'proposal': proposal,
    'isVatIncluded': isVatIncluded,
    'headRate': headRate,
    'supply': supply,
    'storeRate': storeRate,
    'selling': selling,
    'shipping': shipping,
    'qty': qty,
    'memo': memo,
  };

  factory CalculationHistory.fromJson(Map<String, dynamic> json) {
    return CalculationHistory(
      id: json['id'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      proposal: (json['proposal'] ?? 0.0).toDouble(),
      isVatIncluded: json['isVatIncluded'] ?? false,
      headRate: (json['headRate'] ?? 0.0).toDouble(),
      supply: (json['supply'] ?? 0.0).toDouble(),
      storeRate: (json['storeRate'] ?? 0.0).toDouble(),
      selling: (json['selling'] ?? 0.0).toDouble(),
      shipping: (json['shipping'] ?? 0.0).toDouble(),
      qty: (json['qty'] ?? 1.0).toDouble(),
      memo: json['memo'] ?? '',
    );
  }
}

class AnyPriceScreen extends StatefulWidget {
  const AnyPriceScreen({super.key});

  @override
  State<AnyPriceScreen> createState() => _AnyPriceScreenState();
}

class _AnyPriceScreenState extends State<AnyPriceScreen> {
  final TextEditingController proposalController = TextEditingController();
  final TextEditingController headMarginRateController =
      TextEditingController();
  final TextEditingController supplyPriceController = TextEditingController();
  final TextEditingController storeMarginRateController =
      TextEditingController();
  final TextEditingController sellingPriceController = TextEditingController();
  final TextEditingController shippingController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');

  bool isVatIncluded = false;
  bool isRoundTo100 = false;

  List<Product> productList = [];
  bool isProductsLoaded = false;
  String loadStatus = '제품 데이터 로딩 중...';

  List<CalculationHistory> historyList = [];

  final numFormatter = FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'));

  @override
  void initState() {
    super.initState();
    loadHistory();
    loadProductsFromAssets();
  }

  @override
  void dispose() {
    proposalController.dispose();
    headMarginRateController.dispose();
    supplyPriceController.dispose();
    storeMarginRateController.dispose();
    sellingPriceController.dispose();
    shippingController.dispose();
    qtyController.dispose();
    super.dispose();
  }

  Future<void> loadProductsFromAssets() async {
    try {
      setState(() {
        loadStatus = '제품 데이터 로딩 중...';
      });

      final String csvString = await rootBundle.loadString(
        'assets/products.csv',
      );

      List<List<dynamic>> csvData = const CsvToListConverter().convert(
        csvString,
      );

      if (csvData.isEmpty) {
        setState(() {
          loadStatus = 'CSV 파일이 비어있습니다';
          isProductsLoaded = false;
        });
        return;
      }

      List<Product> newProducts = [];
      for (int i = 1; i < csvData.length; i++) {
        try {
          final row = csvData[i];
          if (row.length < 11) continue;

          double parsePrice(dynamic value) {
            if (value == null) return 0.0;
            String strValue = value.toString().replaceAll(',', '').trim();
            return double.tryParse(strValue) ?? 0.0;
          }

          int parseInt(dynamic value) {
            if (value == null) return 0;
            String strValue = value.toString().replaceAll(',', '').trim();
            return int.tryParse(strValue) ?? 0;
          }

          newProducts.add(
            Product(
              code: row[0]?.toString() ?? '',
              barcode: row[1]?.toString() ?? '',
              name: row[7]?.toString() ?? '',
              purchasePrice: parsePrice(row[8]),
              supplyPrice: parsePrice(row[9]),
              sellingPrice: parsePrice(row[10]),
              stock: parseInt(row[12]),
            ),
          );
        } catch (e) {
          continue;
        }
      }

      setState(() {
        productList = newProducts;
        isProductsLoaded = true;
        loadStatus = '${newProducts.length}개의 제품 데이터 로드 완료';
      });
    } catch (e) {
      setState(() {
        isProductsLoaded = false;
        loadStatus = 'CSV 로드 실패: $e';
      });
    }
  }

  void showProductSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => ProductSearchSheet(
            products: productList,
            isProductsLoaded: isProductsLoaded,
            loadStatus: loadStatus,
            onProductSelected: (product) {
              applyProduct(product);
              Navigator.pop(context);
            },
          ),
    );
  }

  void applyProduct(Product product) {
    setState(() {
      proposalController.text = product.purchasePrice.toStringAsFixed(0);
      supplyPriceController.text = product.supplyPrice.toStringAsFixed(0);
      sellingPriceController.text = product.sellingPrice.toStringAsFixed(0);
      isVatIncluded = true;

      if (product.supplyPrice > 0 && product.purchasePrice > 0) {
        double headRate =
            ((product.supplyPrice - product.purchasePrice) /
                product.supplyPrice *
                100);
        headMarginRateController.text = headRate.toStringAsFixed(1);
      }

      if (product.sellingPrice > 0 && product.supplyPrice > 0) {
        double storeRate =
            ((product.sellingPrice - product.supplyPrice) /
                product.sellingPrice *
                100);
        storeMarginRateController.text = storeRate.toStringAsFixed(1);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} 제품을 불러왔습니다.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void calculate({required String trigger}) {
    setState(() {
      double proposal = double.tryParse(proposalController.text) ?? 0;
      double cost = isVatIncluded ? proposal : proposal * 1.1;

      double headRate = double.tryParse(headMarginRateController.text) ?? 0;
      double storeRate = double.tryParse(storeMarginRateController.text) ?? 0;
      double supply = double.tryParse(supplyPriceController.text) ?? 0;
      double selling = double.tryParse(sellingPriceController.text) ?? 0;
      double shipTotal = double.tryParse(shippingController.text) ?? 0;
      double qty = double.tryParse(qtyController.text) ?? 1;
      if (qty <= 0) qty = 1;
      double shipPerItem = shipTotal / qty;

      if (trigger == 'supply') {
        if (supply > 0 && cost > 0) {
          headRate = (supply - cost) / supply * 100;
          headMarginRateController.text = headRate.toStringAsFixed(1);
        }
      } else if (trigger == 'selling') {
        if (selling > 0 && supply > 0) {
          double profit = selling - supply - shipPerItem;
          storeRate = (profit / selling) * 100;
          storeMarginRateController.text = storeRate.toStringAsFixed(1);
        }
      } else if (trigger == 'headRate') {
        if (cost > 0 && headRate >= 0 && headRate < 100) {
          supply = cost / (1 - headRate / 100);
          if (isRoundTo100) supply = (supply / 100).round() * 100;
          supplyPriceController.text = supply.toStringAsFixed(0);
        }
      } else if (trigger == 'storeRate') {
        if (supply > 0 && storeRate >= 0 && storeRate < 100) {
          selling = (supply + shipPerItem) / (1 - storeRate / 100);
          if (isRoundTo100) selling = (selling / 100).round() * 100;
          sellingPriceController.text = selling.toStringAsFixed(0);
        }
      } else {
        if (selling > 0 && supply > 0) {
          double profit = selling - supply - shipPerItem;
          storeRate = (profit / selling) * 100;
          storeMarginRateController.text = storeRate.toStringAsFixed(1);
        }
      }
    });
  }

  Future<void> saveToHistory() async {
    double proposal = double.tryParse(proposalController.text) ?? 0;
    double headRate = double.tryParse(headMarginRateController.text) ?? 0;
    double supply = double.tryParse(supplyPriceController.text) ?? 0;
    double storeRate = double.tryParse(storeMarginRateController.text) ?? 0;
    double selling = double.tryParse(sellingPriceController.text) ?? 0;
    double shipping = double.tryParse(shippingController.text) ?? 0;
    double qty = double.tryParse(qtyController.text) ?? 1;

    if (proposal == 0 || supply == 0 || selling == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제안단가, 공급가, 판매가를 입력해주세요.')));
      return;
    }

    String memo = '';
    await showDialog(
      context: context,
      builder: (context) {
        TextEditingController memoController = TextEditingController();
        return AlertDialog(
          title: const Text('메모 입력'),
          content: TextField(
            controller: memoController,
            decoration: const InputDecoration(hintText: '메모를 입력하세요 (선택)'),
            maxLength: 30,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                memo = memoController.text;
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    final history = CalculationHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      proposal: proposal,
      isVatIncluded: isVatIncluded,
      headRate: headRate,
      supply: supply,
      storeRate: storeRate,
      selling: selling,
      shipping: shipping,
      qty: qty,
      memo: memo,
    );

    setState(() {
      historyList.insert(0, history);
    });

    final prefs = await SharedPreferences.getInstance();
    final jsonList = historyList.map((h) => json.encode(h.toJson())).toList();
    await prefs.setStringList('calculation_history', jsonList);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('히스토리에 저장되었습니다.')));
    }
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('calculation_history') ?? [];
    setState(() {
      historyList =
          jsonList
              .map((str) => CalculationHistory.fromJson(json.decode(str)))
              .toList();
    });
  }

  void loadFromHistory(CalculationHistory history) {
    setState(() {
      proposalController.text = history.proposal.toStringAsFixed(0);
      headMarginRateController.text = history.headRate.toStringAsFixed(1);
      supplyPriceController.text = history.supply.toStringAsFixed(0);
      storeMarginRateController.text = history.storeRate.toStringAsFixed(1);
      sellingPriceController.text = history.selling.toStringAsFixed(0);
      shippingController.text = history.shipping.toStringAsFixed(0);
      qtyController.text = history.qty.toStringAsFixed(0);
      isVatIncluded = history.isVatIncluded;
    });
    if (history.memo.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('메모: ${history.memo}')));
    }
  }

  Future<void> deleteHistory(CalculationHistory history) async {
    setState(() {
      historyList.remove(history);
    });
    final prefs = await SharedPreferences.getInstance();
    final jsonList = historyList.map((h) => json.encode(h.toJson())).toList();
    await prefs.setStringList('calculation_history', jsonList);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
    }
  }

  void showHistoryList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '히스토리 (${historyList.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child:
                        historyList.isEmpty
                            ? const Center(child: Text('저장된 히스토리가 없습니다.'))
                            : ListView.builder(
                              controller: scrollController,
                              itemCount: historyList.length,
                              itemBuilder: (context, index) {
                                final history = historyList[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  child: ListTile(
                                    title: Row(
                                      children: [
                                        Text(
                                          '${history.vatIncludedProposal.toStringAsFixed(0)}원 → ${history.supply.toStringAsFixed(0)}원 → ${history.selling.toStringAsFixed(0)}원',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (history.memo.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              history.memo,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '매장 마진: ${history.storeRate.toStringAsFixed(1)}% | 이익금: ${history.finalProfit.toStringAsFixed(0)}원',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        Text(
                                          '최종 이익률: ${history.finalRate.toStringAsFixed(1)}% | ${_formatDateTime(history.timestamp)}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            deleteHistory(history);
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      loadFromHistory(history);
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              );
            },
          ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    double proposal = double.tryParse(proposalController.text) ?? 0;
    double vatIncludedProposal = isVatIncluded ? proposal : proposal * 1.1;

    double headRate = double.tryParse(headMarginRateController.text) ?? 0;
    double storeRate = double.tryParse(storeMarginRateController.text) ?? 0;
    double supply = double.tryParse(supplyPriceController.text) ?? 0;
    double selling = double.tryParse(sellingPriceController.text) ?? 0;
    double shipTotal = double.tryParse(shippingController.text) ?? 0;
    double qty = double.tryParse(qtyController.text) ?? 1;
    if (qty <= 0) qty = 1;
    double shipPerItem = shipTotal / qty;
    double finalProfit = selling - supply - shipPerItem;
    double finalRate = (selling > 0) ? (finalProfit / selling * 100) : 0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          '다계산해줄지니어스',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 19,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: showProductSearch,
            tooltip: '제품 검색',
          ),
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.history),
                if (historyList.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${historyList.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: showHistoryList,
            tooltip: '히스토리',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 계산 결과 카드
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade50, Colors.pink.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate, color: Colors.pink, size: 24),
                      SizedBox(width: 8),
                      Text(
                        '계산결과',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildResultRow(
                    '제안단가',
                    vatIncludedProposal > 0
                        ? '${vatIncludedProposal.toStringAsFixed(0)}원 (VAT포함)'
                        : '-',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultRow(
                          '지점공급가',
                          supply > 0 ? '${supply.toStringAsFixed(0)}원' : '-',
                          isSmall: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildResultRow(
                          '본사이익률',
                          headRate > 0
                              ? '${headRate.toStringAsFixed(1)}%'
                              : '-',
                          isSmall: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultRow(
                          '매장판매가',
                          selling > 0 ? '${selling.toStringAsFixed(0)}원' : '-',
                          isSmall: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildResultRow(
                          '매장이익률',
                          storeRate > 0
                              ? '${storeRate.toStringAsFixed(1)}%'
                              : '-',
                          isSmall: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultRow(
                          '택배비',
                          shipTotal > 0
                              ? '${shipTotal.toStringAsFixed(0)}원'
                              : '-',
                          isSmall: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildResultRow(
                          '입수량',
                          qty > 0 ? '${qty.toStringAsFixed(0)}개' : '-',
                          isSmall: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildResultRow(
                          '개당택배',
                          shipPerItem > 0
                              ? '${shipPerItem.toStringAsFixed(0)}원'
                              : '-',
                          isSmall: true,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildResultRow(
                          '매장 이익금',
                          (selling > 0 && supply > 0)
                              ? '${finalProfit.toStringAsFixed(0)}원'
                              : '-',
                          isBold: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildResultRow(
                          '최종매장 이익률',
                          (selling > 0 && supply > 0)
                              ? '${finalRate.toStringAsFixed(1)}%'
                              : '-',
                          isBold: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 입력 카드
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputField(
                    '제안단가',
                    proposalController,
                    () => calculate(trigger: 'proposal'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isVatIncluded,
                        onChanged: (v) {
                          setState(() => isVatIncluded = v ?? false);
                          calculate(trigger: 'proposal');
                        },
                      ),
                      const Text('VAT 포함', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 16),
                      Checkbox(
                        value: isRoundTo100,
                        onChanged: (v) {
                          setState(() => isRoundTo100 = v ?? false);
                        },
                      ),
                      const Text('100원 단위 정리', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInputField(
                    '본사이익률(%)',
                    headMarginRateController,
                    () => calculate(trigger: 'headRate'),
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    '지점공급가',
                    supplyPriceController,
                    () => calculate(trigger: 'supply'),
                  ),
                  const Divider(height: 24),
                  _buildInputField(
                    '매장이익률(%)',
                    storeMarginRateController,
                    () => calculate(trigger: 'storeRate'),
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    '최종판매가',
                    sellingPriceController,
                    () => calculate(trigger: 'selling'),
                  ),
                  const Divider(height: 24),
                  _buildInputField(
                    '총 택배비',
                    shippingController,
                    () => calculate(trigger: 'ship'),
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    '입수량',
                    qtyController,
                    () => calculate(trigger: 'qty'),
                  ),
                ],
              ),
            ),

            // 저장 버튼
            Container(
              margin: const EdgeInsets.all(16),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saveToHistory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '히스토리에 저장',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(
    String label,
    String value, {
    bool isSmall = false,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 11 : 13,
            color: Colors.grey.shade700,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmall ? 13 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? Colors.pink : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    VoidCallback onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [numFormatter],
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}

// 🔥 개선된 검색 시트: 한 칸 입력 + 실시간 결과 표시
class ProductSearchSheet extends StatefulWidget {
  final List<Product> products;
  final bool isProductsLoaded;
  final String loadStatus;
  final Function(Product) onProductSelected;

  const ProductSearchSheet({
    super.key,
    required this.products,
    required this.isProductsLoaded,
    required this.loadStatus,
    required this.onProductSelected,
  });

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final TextEditingController searchController = TextEditingController();
  List<Product> searchResults = [];
  bool hasSearched = false;

  void searchProduct() {
    if (!widget.isProductsLoaded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.loadStatus)));
      return;
    }

    String query = searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제품명, 바코드, 또는 POS코드를 입력해주세요.')),
      );
      return;
    }

    setState(() {
      searchResults =
          widget.products.where((p) {
            return p.name.toLowerCase().contains(query.toLowerCase()) ||
                p.barcode.contains(query) ||
                p.code.contains(query);
          }).toList();
      hasSearched = true;
    });

    // 검색 결과 확인 메시지
    if (searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('검색 결과가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '제품 검색',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 로드 상태 표시
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      widget.isProductsLoaded
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        widget.isProductsLoaded
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isProductsLoaded ? Icons.check_circle : Icons.info,
                      size: 16,
                      color:
                          widget.isProductsLoaded
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.loadStatus,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              widget.isProductsLoaded
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 통합 검색 입력 필드
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: '제품명, 바코드, 또는 POS코드',
                  hintText: '예: 매드독, 8820250923178, WP17462',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      searchController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                searchResults = [];
                                hasSearched = false;
                              });
                            },
                          )
                          : null,
                ),
                onSubmitted: (_) => searchProduct(),
              ),
              const SizedBox(height: 16),

              // 검색 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: searchProduct,
                  icon: const Icon(Icons.search),
                  label: const Text('검색'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 검색 결과 헤더
              if (hasSearched) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '검색 결과',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${searchResults.length}개',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.pink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
              ],

              // 검색 결과 리스트
              Expanded(
                child:
                    !hasSearched
                        ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                '제품명, 바코드 또는 POS코드를\n입력 후 검색 버튼을 눌러주세요',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                        : searchResults.isEmpty
                        ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '검색 결과가 없습니다',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: searchResults.length,
                          itemBuilder: (context, index) {
                            final product = searchResults[index];
                            double headRate =
                                (product.supplyPrice > 0)
                                    ? ((product.supplyPrice -
                                            product.purchasePrice) /
                                        product.supplyPrice *
                                        100)
                                    : 0.0;
                            double storeRate =
                                (product.sellingPrice > 0)
                                    ? ((product.sellingPrice -
                                            product.supplyPrice) /
                                        product.sellingPrice *
                                        100)
                                    : 0.0;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 2,
                              child: ListTile(
                                title: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '매입: ${product.purchasePrice.toStringAsFixed(0)}원 | 공급: ${product.supplyPrice.toStringAsFixed(0)}원 | 판매: ${product.sellingPrice.toStringAsFixed(0)}원',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      '본사: ${headRate.toStringAsFixed(1)}% | 매장: ${storeRate.toStringAsFixed(1)}% | 재고: ${product.stock}개',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.pink,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (product.code.isNotEmpty)
                                      Text(
                                        '코드: ${product.code} | 바코드: ${product.barcode}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () => widget.onProductSelected(product),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
