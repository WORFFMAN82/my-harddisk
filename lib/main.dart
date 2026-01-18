import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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
    purchasePrice: (json['purchasePrice'] ?? 0).toDouble(),
    supplyPrice: (json['supplyPrice'] ?? 0).toDouble(),
    sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
    stock: (json['stock'] ?? 0).toInt(),
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
  String memo;

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
  double get finalRate => selling > 0 ? (finalProfit / selling * 100) : 0;
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

  bool isVatIncluded = true;
  bool isRoundTo100 = false;

  List<CalculationHistory> historyList = [];
  List<Product> productList = [];
  bool isLoadingProducts = false;

  final List<Color> themeColors = const [
    Color(0xFFFF6F61),
    Color(0xFFFF9AA2),
    Color(0xFF7FDBDA),
    Color(0xFF5DADEC),
    Color(0xFF273469),
    Color(0xFF6B8E23),
    Color(0xFFF4B41A),
    Color(0xFF8D909B),
    Color(0xFF36454F),
    Color(0xFF4B0082),
  ];

  Color themeColor = const Color(0xFFFF6F61);

  final TextInputFormatter intFormatter =
      FilteringTextInputFormatter.digitsOnly;
  final TextInputFormatter decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9.]'),
  );

  @override
  void initState() {
    super.initState();
    loadProducts();
  }

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

  Future<void> loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? productsJson = prefs.getString('products');
    if (productsJson != null) {
      final List<dynamic> decoded = jsonDecode(productsJson);
      setState(() {
        productList = decoded.map((item) => Product.fromJson(item)).toList();
      });
    }
  }

  Future<void> saveProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      productList.map((p) => p.toJson()).toList(),
    );
    await prefs.setString('products', encoded);
  }

  Future<void> uploadCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result != null) {
        setState(() => isLoadingProducts = true);

        final bytes = result.files.first.bytes;
        if (bytes == null) throw Exception('파일을 읽을 수 없습니다.');

        String csvString;
        try {
          csvString = utf8.decode(bytes);
        } catch (e) {
          csvString = latin1.decode(bytes);
        }

        List<List<dynamic>> csvData = const CsvToListConverter().convert(
          csvString,
        );

        if (csvData.isEmpty) throw Exception('CSV 파일이 비어있습니다.');

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
          isLoadingProducts = false;
        });

        await saveProducts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${newProducts.length}개의 제품을 불러왔습니다.')),
          );
        }
      }
    } catch (e) {
      setState(() => isLoadingProducts = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('파일 업로드 실패: $e')));
      }
    }
  }

  void showProductSearch() {
    if (productList.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 제품 데이터를 업로드해주세요.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => ProductSearchSheet(
            products: productList,
            themeColor: themeColor,
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

      if (product.supplyPrice > 0) {
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${product.name} 제품을 불러왔습니다.')));
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
        if (supply > 0 && cost > 0) {
          headMarginRateController.text = ((supply - cost) / supply * 100)
              .toStringAsFixed(1);
        }
      } else if (trigger == "selling") {
        if (selling > 0 && supply > 0) {
          double profit = selling - supply - shipPerItem;
          storeMarginRateController.text = (profit / selling * 100)
              .toStringAsFixed(1);
        }
      } else if (trigger == "headRate") {
        if (headRate < 100 && cost > 0) {
          supply = cost / (1 - headRate / 100);
          if (isRoundTo100) {
            supply = (supply / 100).round() * 100.0;
          }
          supplyPriceController.text = supply.toStringAsFixed(0);
        }
      } else if (trigger == "storeRate") {
        if (storeRate < 100 && supply > 0) {
          selling = (supply + shipPerItem) / (1 - storeRate / 100);
          if (isRoundTo100) {
            selling = (selling / 100).round() * 100.0;
          }
          sellingPriceController.text = selling.toStringAsFixed(0);
        }
      } else {
        if (selling > 0 && supply > 0) {
          double profit = selling - supply - shipPerItem;
          storeMarginRateController.text = (profit / selling * 100)
              .toStringAsFixed(1);
        }
      }
    });
  }

  void saveToHistory() {
    double proposal = double.tryParse(proposalController.text) ?? 0;
    double headRate = double.tryParse(headMarginRateController.text) ?? 0;
    double storeRate = double.tryParse(storeMarginRateController.text) ?? 0;
    double supply = double.tryParse(supplyPriceController.text) ?? 0;
    double selling = double.tryParse(sellingPriceController.text) ?? 0;
    double shipping = double.tryParse(shippingController.text) ?? 0;
    double qty = double.tryParse(boxQtyController.text) ?? 1;

    if (proposal <= 0 || supply <= 0 || selling <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('계산 결과가 없습니다. 값을 입력해주세요.')));
      return;
    }

    TextEditingController memoController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('히스토리 저장'),
            content: TextField(
              controller: memoController,
              decoration: const InputDecoration(
                labelText: '메모 (선택사항)',
                hintText: '예: A업체 견적',
              ),
              maxLength: 30,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    historyList.add(
                      CalculationHistory(
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
                        memo: memoController.text.trim(),
                      ),
                    );
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('히스토리에 저장되었습니다.')),
                  );
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

  void loadFromHistory(CalculationHistory history) {
    setState(() {
      proposalController.text = history.proposal.toStringAsFixed(0);
      isVatIncluded = history.isVatIncluded;
      headMarginRateController.text = history.headRate.toStringAsFixed(1);
      supplyPriceController.text = history.supply.toStringAsFixed(0);
      storeMarginRateController.text = history.storeRate.toStringAsFixed(1);
      sellingPriceController.text = history.selling.toStringAsFixed(0);
      shippingController.text = history.shipping.toStringAsFixed(0);
      boxQtyController.text = history.qty.toStringAsFixed(0);
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${history.memo.isNotEmpty ? history.memo : "저장된 데이터"}를 불러왔습니다.',
        ),
      ),
    );
  }

  void deleteHistory(CalculationHistory history) {
    setState(() {
      historyList.remove(history);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
  }

  void showHistoryList() {
    if (historyList.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장된 히스토리가 없습니다.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder:
                (context, scrollController) => Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '저장된 히스토리',
                            style: TextStyle(
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
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: historyList.length,
                        itemBuilder: (context, index) {
                          final history =
                              historyList[historyList.length - 1 - index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              title: Text(
                                history.memo.isNotEmpty
                                    ? history.memo
                                    : '견적 ${historyList.length - index}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    '제안: ${history.proposal.toStringAsFixed(0)}원 | '
                                    '공급: ${history.supply.toStringAsFixed(0)}원 | '
                                    '판매: ${history.selling.toStringAsFixed(0)}원',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '매장이익률: ${history.finalRate.toStringAsFixed(1)}% | '
                                    '이익금: ${history.finalProfit.toStringAsFixed(0)}원',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    '저장: ${_formatDateTime(history.timestamp)}',
                                    style: TextStyle(
                                      fontSize: 11,
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
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      deleteHistory(history);
                                      if (historyList.isEmpty) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  ),
                                  const Icon(Icons.chevron_right),
                                ],
                              ),
                              onTap: () => loadFromHistory(history),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
    double qty = double.tryParse(boxQtyController.text) ?? 1;
    if (qty <= 0) qty = 1;
    double shipPerItem = shipTotal / qty;

    double finalProfit = selling - supply - shipPerItem;
    double finalRate = selling > 0 ? (finalProfit / selling * 100) : 0;

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
            icon: const Icon(Icons.upload_file),
            onPressed: uploadCSV,
            tooltip: 'CSV 업로드',
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
      body:
          isLoadingProducts
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (productList.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${productList.length}개의 제품 데이터가 로드되었습니다',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (productList.isNotEmpty) const SizedBox(height: 10),
                    buildThemeSelector(),
                    const SizedBox(height: 10),
                    buildInfoCard(
                      vatIncludedProposal,
                      headRate,
                      supply,
                      storeRate,
                      selling,
                      shipTotal,
                      qty,
                      shipPerItem,
                      finalProfit,
                      finalRate,
                    ),
                    const SizedBox(height: 12),
                    buildInputCard(),
                    const SizedBox(height: 12),
                    buildSaveButton(),
                  ],
                ),
              ),
    );
  }

  Widget buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "테마 색상",
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children:
                themeColors.map((c) {
                  final bool selected = (themeColor == c);
                  return GestureDetector(
                    onTap: () => setState(() => themeColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: selected ? 28 : 22,
                      height: selected ? 28 : 22,
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

  Widget buildInfoCard(
    double vatIncludedProposal,
    double headRate,
    double supply,
    double storeRate,
    double selling,
    double shipTotal,
    double qty,
    double shipPerItem,
    double profit,
    double finalRate,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [themeColor.withOpacity(0.9), themeColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.2),
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
              Icon(
                Icons.calculate_outlined,
                color: Colors.white.withOpacity(0.9),
                size: 18,
              ),
              const SizedBox(width: 5),
              const Text(
                "계산 결과",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white54, height: 16),
          buildInfoTitle("제안단가"),
          buildInfoValue(
            vatIncludedProposal > 0
                ? "${vatIncludedProposal.toStringAsFixed(0)}원 (VAT포함)"
                : "-",
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoTitle("지점공급가"),
                    buildInfoValue(
                      supply > 0 ? "${supply.toStringAsFixed(0)}원" : "-",
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoTitle("본사이익률"),
                    buildInfoValue(
                      headRate > 0 ? "${headRate.toStringAsFixed(1)}%" : "-",
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoTitle("매장판매가"),
                    buildInfoValue(
                      selling > 0 ? "${selling.toStringAsFixed(0)}원" : "-",
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoTitle("매장이익률"),
                    buildInfoValue(
                      storeRate > 0 ? "${storeRate.toStringAsFixed(1)}%" : "-",
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoTitle("택배비"),
                    buildInfoValue(
                      shipTotal > 0 ? "${shipTotal.toStringAsFixed(0)}원" : "-",
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoTitle("입수량"),
                    buildInfoValue(
                      qty > 0 ? "${qty.toStringAsFixed(0)}개" : "-",
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoTitle("개당택배"),
                    buildInfoValue(
                      shipPerItem > 0
                          ? "${shipPerItem.toStringAsFixed(0)}원"
                          : "-",
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white54, height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoTitle("매장 이익금", isBold: true),
                    buildInfoValue(
                      selling > 0 && supply > 0
                          ? "${profit.toStringAsFixed(0)}원"
                          : "-",
                      isBold: true,
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildInfoTitle("최종매장 이익률", isBold: true),
                    buildInfoValue(
                      selling > 0 && supply > 0
                          ? "${finalRate.toStringAsFixed(1)}%"
                          : "-",
                      isBold: true,
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildInfoTitle(String text, {bool isBold = false}) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.85),
        fontSize: 10,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget buildInfoValue(String text, {bool isBold = false, double? fontSize}) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize ?? 13,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
      ),
    );
  }

  Widget buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: themeColor, size: 18),
              const SizedBox(width: 5),
              const Text(
                "입력 영역",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "기본 정보",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          buildInput(
            "1. 제안 단가",
            proposalController,
            (v) => calculate(),
            inputFormatters: [intFormatter],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              buildCheck("VAT 포함", isVatIncluded, (v) {
                setState(() {
                  isVatIncluded = v ?? false;
                  calculate();
                });
              }),
              buildCheck("100원 단위 정리", isRoundTo100, (v) {
                setState(() {
                  isRoundTo100 = v ?? false;
                  calculate();
                });
              }),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "본사 · 지점 조건",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: buildInput(
                  "2. 본사 마진율(%)",
                  headMarginRateController,
                  (v) => calculate(trigger: "headRate"),
                  inputFormatters: [decimalFormatter],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildInput(
                  "3. 지점공급가",
                  supplyPriceController,
                  (v) => calculate(trigger: "supply"),
                  color: themeColor.withOpacity(0.05),
                  inputFormatters: [intFormatter],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "매장 판매 조건",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: buildInput(
                  "4. 매장 이익률(%)",
                  storeMarginRateController,
                  (v) => calculate(trigger: "storeRate"),
                  inputFormatters: [decimalFormatter],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildInput(
                  "5. 최종 판매가",
                  sellingPriceController,
                  (v) => calculate(trigger: "selling"),
                  color: Colors.green[50],
                  inputFormatters: [intFormatter],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "물류 조건",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: buildInput(
                  "총 택배비",
                  shippingController,
                  (v) => calculate(),
                  inputFormatters: [intFormatter],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildInput(
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

  Widget buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: saveToHistory,
      icon: const Icon(Icons.bookmark_add),
      label: const Text('이 계산 결과를 히스토리에 저장'),
      style: ElevatedButton.styleFrom(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget buildCheck(String label, bool val, Function(bool?) onChg) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: val,
            activeColor: themeColor,
            onChanged: onChg,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget buildInput(
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChg,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: color ?? Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class ProductSearchSheet extends StatefulWidget {
  final List<Product> products;
  final Color themeColor;
  final Function(Product) onProductSelected;

  const ProductSearchSheet({
    super.key,
    required this.products,
    required this.themeColor,
    required this.onProductSelected,
  });

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final TextEditingController searchController = TextEditingController();
  List<Product> filteredProducts = [];

  @override
  void initState() {
    super.initState();
    filteredProducts = widget.products;
  }

  void filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = widget.products;
      } else {
        filteredProducts =
            widget.products.where((product) {
              return product.name.toLowerCase().contains(query.toLowerCase()) ||
                  product.code.contains(query) ||
                  product.barcode.contains(query);
            }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder:
          (context, scrollController) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '제품 검색',
                          style: TextStyle(
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: filterProducts,
                      decoration: InputDecoration(
                        hintText: '제품명, 상품코드, 바코드로 검색',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon:
                            searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    filterProducts('');
                                  },
                                )
                                : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${filteredProducts.length}개의 제품',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child:
                    filteredProducts.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '검색 결과가 없습니다',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            final headRate =
                                product.supplyPrice > 0
                                    ? ((product.supplyPrice -
                                            product.purchasePrice) /
                                        product.supplyPrice *
                                        100)
                                    : 0.0;
                            final storeRate =
                                product.sellingPrice > 0
                                    ? ((product.sellingPrice -
                                            product.supplyPrice) /
                                        product.sellingPrice *
                                        100)
                                    : 0.0;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                title: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: widget.themeColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (product.code.isNotEmpty)
                                      Text(
                                        '코드: ${product.code}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => widget.onProductSelected(product),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
