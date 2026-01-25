import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';

void main() {
  runApp(const AnyPriceApp());
}

class AnyPriceApp extends StatelessWidget {
  const AnyPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '다계산해줄지니어스',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: CardTheme(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF3498DB), width: 2),
          ),
        ),
      ),
      home: const AnyPriceScreen(),
      debugShowCheckedModeBanner: false,
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
}

class CalculationHistory {
  final DateTime timestamp;
  final double proposal;
  final double supply;
  final double selling;
  final double headRate;
  final double storeRate;
  final bool isVatIncluded;
  final double shippingCost;
  final int quantity;

  CalculationHistory({
    required this.timestamp,
    required this.proposal,
    required this.supply,
    required this.selling,
    required this.headRate,
    required this.storeRate,
    required this.isVatIncluded,
    this.shippingCost = 0,
    this.quantity = 1,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'proposal': proposal,
        'supply': supply,
        'selling': selling,
        'headRate': headRate,
        'storeRate': storeRate,
        'isVatIncluded': isVatIncluded,
        'shippingCost': shippingCost,
        'quantity': quantity,
      };

  factory CalculationHistory.fromJson(Map<String, dynamic> json) {
    return CalculationHistory(
      timestamp: DateTime.parse(json['timestamp']),
      proposal: json['proposal'],
      supply: json['supply'],
      selling: json['selling'],
      headRate: json['headRate'],
      storeRate: json['storeRate'],
      isVatIncluded: json['isVatIncluded'] ?? false,
      shippingCost: json['shippingCost'] ?? 0,
      quantity: json['quantity'] ?? 1,
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
  final TextEditingController supplyController = TextEditingController();
  final TextEditingController sellingController = TextEditingController();
  final TextEditingController headRateController = TextEditingController();
  final TextEditingController storeRateController = TextEditingController();
  final TextEditingController shipController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );

  bool isVatIncluded = false;
  bool isRoundTo100 = true;
  bool isProposalFixed = false;
  bool isSellingFixed = false;

  double vatIncludedProposal = 0;
  double calculatedSupply = 0;
  double calculatedSelling = 0;
  double calculatedHeadRate = 0;
  double calculatedStoreRate = 0;
  double shippingCostPerUnit = 0;
  double storeProfit = 0;
  double finalStoreProfit = 0;
  double finalStoreProfitRate = 0;
  double priceDifference = 0;
  int quantity = 1;
  double totalShippingCost = 0;

  Product? selectedProduct;

  List<Product> productList = [];
  bool isProductsLoaded = false;
  String loadStatus = '제품 데이터 로딩 시도 중...';
  String? loadError;

  List<CalculationHistory> historyList = [];

  final numFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^[0-9]*\.?[0-9]*'),
  );

  @override
  void initState() {
    super.initState();
    loadHistory();
    loadProductsFromAssets();
  }

  @override
  void dispose() {
    proposalController.dispose();
    supplyController.dispose();
    sellingController.dispose();
    headRateController.dispose();
    storeRateController.dispose();
    shipController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  double parsePrice(dynamic value) {
    if (value == null) return 0.0;
    String str = value.toString().trim().replaceAll(',', '');
    return double.tryParse(str) ?? 0.0;
  }

  int parseInt(dynamic value) {
    if (value == null) return 0;
    String str = value.toString().trim().replaceAll(',', '');
    return int.tryParse(str) ?? 0;
  }

  Future<void> loadProductsFromAssets() async {
    try {
      setState(() {
        loadStatus = '제품 데이터 로딩 중...';
        loadError = null;
      });

      String csvString = '';
      try {
        csvString = await rootBundle.loadString('assets/products.csv');
      } catch (e) {
        try {
          csvString = await rootBundle.loadString('assets/assets/products.csv');
        } catch (e2) {
          throw Exception('CSV 파일을 찾을 수 없습니다: $e');
        }
      }

      if (csvString.isEmpty) {
        setState(() {
          loadStatus = '제품 데이터가 비어있습니다';
          loadError = 'CSV 파일이 비어있습니다';
          isProductsLoaded = true;
        });
        return;
      }

      List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n',
        fieldDelimiter: ',',
      ).convert(csvString);

      if (csvTable.isEmpty) {
        setState(() {
          loadStatus = '제품 데이터가 없습니다';
          isProductsLoaded = true;
        });
        return;
      }

      List<Product> newProducts = [];
      int successCount = 0;
      int failCount = 0;

      for (int i = 1; i < csvTable.length; i++) {
        List<dynamic> row = csvTable[i];

        if (row.length < 7) {
          failCount++;
          continue;
        }

        try {
          String code = row[0]?.toString().trim() ?? '';
          String barcode = row[1]?.toString().trim() ?? '';
          String name = row[2]?.toString().trim() ?? '';

          if (name.isEmpty) {
            failCount++;
            continue;
          }

          double purchasePrice = parsePrice(row[3]);
          double supplyPrice = parsePrice(row[4]);
          double sellingPrice = parsePrice(row[5]);
          int stock = parseInt(row[6]);

          newProducts.add(
            Product(
              code: code,
              barcode: barcode,
              name: name,
              purchasePrice: purchasePrice,
              supplyPrice: supplyPrice,
              sellingPrice: sellingPrice,
              stock: stock,
            ),
          );

          successCount++;
        } catch (e) {
          failCount++;
        }
      }

      setState(() {
        productList = newProducts;
        isProductsLoaded = true;
        loadStatus =
            '$successCount개의 제품 로드 완료${failCount > 0 ? ' ($failCount개 실패)' : ''}';
      });
    } catch (e) {
      setState(() {
        loadStatus = '제품 데이터 로드 실패';
        loadError = e.toString();
        isProductsLoaded = true;
      });
    }
  }

  Future<void> loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('calculation_history');
    if (historyJson != null) {
      List<dynamic> decoded = json.decode(historyJson);
      setState(() {
        historyList =
            decoded.map((e) => CalculationHistory.fromJson(e)).toList();
      });
    }
  }

  Future<void> saveHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String encoded = json.encode(historyList.map((e) => e.toJson()).toList());
    await prefs.setString('calculation_history', encoded);
  }

  void addToHistory() {
    if (vatIncludedProposal > 0) {
      CalculationHistory newEntry = CalculationHistory(
        timestamp: DateTime.now(),
        proposal: vatIncludedProposal,
        supply: calculatedSupply,
        selling: calculatedSelling,
        headRate: calculatedHeadRate,
        storeRate: calculatedStoreRate,
        isVatIncluded: isVatIncluded,
        shippingCost: totalShippingCost,
        quantity: quantity,
      );
      setState(() {
        historyList.insert(0, newEntry);
        if (historyList.length > 50) {
          historyList = historyList.sublist(0, 50);
        }
      });
      saveHistory();
    }
  }

  double roundTo100(double value) {
    if (isRoundTo100) {
      return (value / 100).round() * 100.0;
    }
    return value;
  }

  void calculate(String trigger) {
    double proposal = double.tryParse(proposalController.text) ?? 0;
    double supply = double.tryParse(supplyController.text) ?? 0;
    double selling = double.tryParse(sellingController.text) ?? 0;
    double headRate = double.tryParse(headRateController.text) ?? 0;
    double storeRate = double.tryParse(storeRateController.text) ?? 0;
    double shippingCost = double.tryParse(shipController.text) ?? 0;
    int qty = int.tryParse(quantityController.text) ?? 1;
    if (qty == 0) qty = 1;

    setState(() {
      quantity = qty;
      totalShippingCost = shippingCost;
      vatIncludedProposal = isVatIncluded ? proposal : proposal * 1.1;

      shippingCostPerUnit = shippingCost / qty;

      if (isProposalFixed && isSellingFixed) {
        if (trigger == 'supply') {
          calculatedSupply = supply;

          if (vatIncludedProposal > 0) {
            calculatedHeadRate =
                ((calculatedSupply - vatIncludedProposal) / calculatedSupply) *
                    100;
            headRateController.text = calculatedHeadRate.toStringAsFixed(1);
          }

          calculatedSelling = selling;
          if (calculatedSupply > 0) {
            calculatedStoreRate =
                ((calculatedSelling - calculatedSupply) / calculatedSelling) *
                    100;
            storeRateController.text = calculatedStoreRate.toStringAsFixed(1);
          }
        } else if (trigger == 'headRate') {
          if (vatIncludedProposal > 0 && headRate > 0) {
            calculatedSupply = roundTo100(
              vatIncludedProposal / (1 - headRate / 100),
            );
            supplyController.text = calculatedSupply.toStringAsFixed(0);
            calculatedHeadRate = headRate;

            calculatedSelling = selling;
            if (calculatedSupply > 0 && calculatedSelling > 0) {
              calculatedStoreRate =
                  ((calculatedSelling - calculatedSupply) / calculatedSelling) *
                      100;
              storeRateController.text = calculatedStoreRate.toStringAsFixed(1);
            }
          }
        } else if (trigger == 'storeRate') {
          calculatedSelling = selling;
          if (calculatedSelling > 0 && storeRate > 0) {
            calculatedSupply = roundTo100(
              calculatedSelling * (1 - storeRate / 100),
            );
            supplyController.text = calculatedSupply.toStringAsFixed(0);
            calculatedStoreRate = storeRate;

            if (vatIncludedProposal > 0 && calculatedSupply > 0) {
              calculatedHeadRate = ((calculatedSupply - vatIncludedProposal) /
                      calculatedSupply) *
                  100;
              headRateController.text = calculatedHeadRate.toStringAsFixed(1);
            }
          }
        }
      } else {
        if (trigger == 'proposal') {
          if (vatIncludedProposal > 0 && headRate > 0) {
            calculatedSupply = roundTo100(
              vatIncludedProposal / (1 - headRate / 100),
            );
            supplyController.text = calculatedSupply.toStringAsFixed(0);

            if (storeRate > 0 && !isSellingFixed) {
              calculatedSelling = roundTo100(
                calculatedSupply / (1 - storeRate / 100),
              );
              sellingController.text = calculatedSelling.toStringAsFixed(0);
            } else if (isSellingFixed) {
              calculatedSelling = selling;
            }
          }

          if (calculatedSupply > 0 && vatIncludedProposal > 0) {
            calculatedHeadRate =
                ((calculatedSupply - vatIncludedProposal) / calculatedSupply) *
                    100;
            headRateController.text = calculatedHeadRate.toStringAsFixed(1);
          }
        } else if (trigger == 'headRate') {
          if (vatIncludedProposal > 0 && headRate > 0) {
            calculatedSupply = roundTo100(
              vatIncludedProposal / (1 - headRate / 100),
            );
            supplyController.text = calculatedSupply.toStringAsFixed(0);
            calculatedHeadRate = headRate;

            if (storeRate > 0 && !isSellingFixed) {
              calculatedSelling = roundTo100(
                calculatedSupply / (1 - storeRate / 100),
              );
              sellingController.text = calculatedSelling.toStringAsFixed(0);
            } else if (isSellingFixed) {
              calculatedSelling = selling;
              if (calculatedSupply > 0) {
                calculatedStoreRate = ((calculatedSelling - calculatedSupply) /
                        calculatedSelling) *
                    100;
                storeRateController.text = calculatedStoreRate.toStringAsFixed(
                  1,
                );
              }
            }
          }
        } else if (trigger == 'supply') {
          calculatedSupply = supply;

          if (vatIncludedProposal > 0 && !isProposalFixed) {
            calculatedHeadRate =
                ((calculatedSupply - vatIncludedProposal) / calculatedSupply) *
                    100;
            headRateController.text = calculatedHeadRate.toStringAsFixed(1);
          }

          if (storeRate > 0 && !isSellingFixed) {
            calculatedSelling = roundTo100(
              calculatedSupply / (1 - storeRate / 100),
            );
            sellingController.text = calculatedSelling.toStringAsFixed(0);
          } else if (isSellingFixed) {
            calculatedSelling = selling;
            if (calculatedSupply > 0) {
              calculatedStoreRate =
                  ((calculatedSelling - calculatedSupply) / calculatedSelling) *
                      100;
              storeRateController.text = calculatedStoreRate.toStringAsFixed(1);
            }
          }
        } else if (trigger == 'storeRate') {
          if (calculatedSupply > 0 && storeRate > 0 && !isSellingFixed) {
            calculatedSelling = roundTo100(
              calculatedSupply / (1 - storeRate / 100),
            );
            sellingController.text = calculatedSelling.toStringAsFixed(0);
            calculatedStoreRate = storeRate;
          } else if (isSellingFixed) {
            calculatedSelling = selling;
          }
        } else if (trigger == 'selling') {
          calculatedSelling = selling;

          if (calculatedSupply > 0) {
            calculatedStoreRate =
                ((calculatedSelling - calculatedSupply) / calculatedSelling) *
                    100;
            storeRateController.text = calculatedStoreRate.toStringAsFixed(1);
          }
        }
      }

      if (calculatedSupply > 0 && vatIncludedProposal > 0) {
        calculatedHeadRate =
            ((calculatedSupply - vatIncludedProposal) / calculatedSupply) * 100;
      }

      if (calculatedSelling > 0 && calculatedSupply > 0) {
        calculatedStoreRate =
            ((calculatedSelling - calculatedSupply) / calculatedSelling) * 100;
      }

      if (calculatedSelling > 0 && calculatedSupply > 0) {
        storeProfit = calculatedSelling - calculatedSupply;
      } else {
        storeProfit = 0;
      }

      if (calculatedSelling > 0 && calculatedSupply > 0) {
        finalStoreProfit =
            calculatedSelling - calculatedSupply - shippingCostPerUnit;
      } else {
        finalStoreProfit = 0;
      }

      if (calculatedSelling > 0) {
        finalStoreProfitRate = (finalStoreProfit / calculatedSelling) * 100;
      } else {
        finalStoreProfitRate = 0;
      }

      if (selling > 0) {
        priceDifference = calculatedSelling - selling;
      } else {
        priceDifference = 0;
      }
    });

    addToHistory();
  }

  Future<void> resetCalculation() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('초기화'),
        content: const Text(
          '모든 입력 값과 계산 결과를 초기화하시겠습니까?\n\n'
          '히스토리는 유지됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE74C3C),
            ),
            child: const Text('초기화'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        proposalController.clear();
        supplyController.clear();
        sellingController.clear();
        headRateController.clear();
        storeRateController.clear();
        shipController.clear();
        quantityController.text = '1';

        vatIncludedProposal = 0;
        calculatedSupply = 0;
        calculatedSelling = 0;
        calculatedHeadRate = 0;
        calculatedStoreRate = 0;
        shippingCostPerUnit = 0;
        storeProfit = 0;
        finalStoreProfit = 0;
        finalStoreProfitRate = 0;
        priceDifference = 0;
        quantity = 1;
        totalShippingCost = 0;

        selectedProduct = null;

        isVatIncluded = false;
        isRoundTo100 = true;
        isProposalFixed = false;
        isSellingFixed = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('초기화 완료'),
            backgroundColor: Color(0xFF27AE60),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> exportToExcel() async {
    if (historyList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('내보낼 데이터가 없습니다'),
          backgroundColor: Color(0xFFE67E22),
        ),
      );
      return;
    }

    try {
      List<List<dynamic>> rows = [
        [
          '날짜',
          '시간',
          '제안단가(VAT포함)',
          '공급가',
          '판매가',
          '본사이익률(%)',
          '매장이익률(%)',
          '매장이익금',
          '택배비',
          '수량',
          '개당택배비',
          '최종매장이익금(개당)',
          '최종매장이익률(%)',
        ],
      ];

      for (var history in historyList) {
        final double storeProfit = history.selling - history.supply;
        final double shippingPerUnit =
            history.quantity > 0 ? history.shippingCost / history.quantity : 0;

        final double finalProfit =
            history.selling - history.supply - shippingPerUnit;
        final double finalProfitRate =
            history.selling > 0 ? (finalProfit / history.selling) * 100 : 0;

        rows.add([
          '${history.timestamp.year}-${history.timestamp.month.toString().padLeft(2, '0')}-${history.timestamp.day.toString().padLeft(2, '0')}',
          '${history.timestamp.hour.toString().padLeft(2, '0')}:${history.timestamp.minute.toString().padLeft(2, '0')}',
          history.proposal.toStringAsFixed(0),
          history.supply.toStringAsFixed(0),
          history.selling.toStringAsFixed(0),
          history.headRate.toStringAsFixed(1),
          history.storeRate.toStringAsFixed(1),
          storeProfit.toStringAsFixed(0),
          history.shippingCost.toStringAsFixed(0),
          history.quantity,
          shippingPerUnit.toStringAsFixed(0),
          finalProfit.toStringAsFixed(0),
          finalProfitRate.toStringAsFixed(1),
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];

      final now = DateTime.now();
      final fileName =
          '다계산해줄지니어스_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '계산 히스토리',
        text: '다계산해줄지니어스 계산 히스토리입니다.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('엑셀 파일이 생성되었습니다'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('내보내기 실패: $e'),
            backgroundColor: const Color(0xFFE74C3C),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 0,
        title: const Text(
          '다계산해줄지니어스',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
            onPressed: resetCalculation,
            tooltip: '초기화',
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white, size: 22),
            onPressed: exportToExcel,
            tooltip: '엑셀 내보내기',
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 22),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => ProductSearchSheet(
                  products: productList,
                  isLoaded: isProductsLoaded,
                  loadStatus: loadStatus,
                  onProductSelected: (product) {
                    setState(() {
                      selectedProduct = product;
                      proposalController.text =
                          product.purchasePrice.toStringAsFixed(0);
                      supplyController.text =
                          product.supplyPrice.toStringAsFixed(0);
                      sellingController.text =
                          product.sellingPrice.toStringAsFixed(0);
                    });
                    calculate('supply');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} 선택됨'),
                        backgroundColor: const Color(0xFF27AE60),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white, size: 22),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              '계산 히스토리',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ),
                          Expanded(
                            child: historyList.isEmpty
                                ? const Center(
                                    child: Text(
                                      '히스토리가 없습니다',
                                      style: TextStyle(
                                        color: Color(0xFF95A5A6),
                                        fontSize: 14,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    itemCount: historyList.length,
                                    itemBuilder: (context, index) {
                                      CalculationHistory history =
                                          historyList[index];
                                      return Card(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          title: Text(
                                            '제안: ${history.proposal.toStringAsFixed(0)}원',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF2C3E50),
                                            ),
                                          ),
                                          subtitle: Text(
                                            '공급: ${history.supply.toStringAsFixed(0)}원 | 판매: ${history.selling.toStringAsFixed(0)}원\n'
                                            '본사: ${history.headRate.toStringAsFixed(1)}% | 매장: ${history.storeRate.toStringAsFixed(1)}%',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF7F8C8D),
                                            ),
                                          ),
                                          trailing: Text(
                                            '${history.timestamp.month}/${history.timestamp.day}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF95A5A6),
                                            ),
                                          ),
                                          onTap: () {
                                            setState(() {
                                              proposalController.text = history
                                                  .proposal
                                                  .toStringAsFixed(0);
                                              isVatIncluded =
                                                  history.isVatIncluded;
                                            });
                                            Navigator.pop(context);
                                            calculate('proposal');
                                          },
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLiveDisplayCard(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: _buildInputCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDisplayCard() {
    double? baseHeadRate;
    double? baseStoreRate;

    if (selectedProduct != null) {
      baseHeadRate = selectedProduct!.supplyPrice > 0
          ? ((selectedProduct!.supplyPrice - selectedProduct!.purchasePrice) /
                  selectedProduct!.supplyPrice) *
              100
          : 0;
      baseStoreRate = selectedProduct!.sellingPrice > 0
          ? ((selectedProduct!.sellingPrice - selectedProduct!.supplyPrice) /
                  selectedProduct!.sellingPrice) *
              100
          : 0;
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF2C3E50),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (selectedProduct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF34495E),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF445566), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedProduct!.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFECF0F1),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF95A5A6),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        selectedProduct = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: selectedProduct != null
                ? _buildComparisonDisplay(baseHeadRate!, baseStoreRate!)
                : _buildNormalDisplay(),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalDisplay() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                flex: 5,
                child: Center(
                  child: Text(
                    '금액',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFECF0F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    '이익률',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF95A5A6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildSingleRow(
          '매입가',
          vatIncludedProposal,
          null,
        ),
        const SizedBox(height: 6),
        _buildSingleRow(
          '공급가',
          calculatedSupply,
          calculatedHeadRate,
        ),
        const SizedBox(height: 6),
        _buildSingleRow(
          '판매가',
          calculatedSelling,
          calculatedStoreRate,
          highlight: true,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '택배비',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBDC3C7),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${totalShippingCost.toStringAsFixed(0)}원',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFECF0F1),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Text(
                      ' (${shippingCostPerUnit.toStringAsFixed(0)}원)',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF95A5A6),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '${quantity}EA',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFECF0F1),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: const Color(0xFF445566)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDisplayItem(
                '매장이익금',
                '${finalStoreProfit.toStringAsFixed(0)}원',
                const Color(0xFF27AE60),
                small: false,
                bold: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDisplayItem(
                '매장이익률',
                '${finalStoreProfitRate.toStringAsFixed(1)}%',
                const Color(0xFFF39C12),
                small: false,
                bold: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleRow(
    String label,
    double value,
    double? rate, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: highlight
                    ? const Color(0xFFF39C12)
                    : const Color(0xFFBDC3C7),
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 12,
                      color: highlight
                          ? const Color(0xFFF39C12)
                          : const Color(0xFFECF0F1),
                      fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Text(
                  '원',
                  style: TextStyle(
                    fontSize: 12,
                    color: highlight
                        ? const Color(0xFFF39C12)
                        : const Color(0xFFECF0F1),
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              rate != null ? '${rate.toStringAsFixed(1)}%' : '',
              style: TextStyle(
                fontSize: 12,
                color: highlight
                    ? const Color(0xFFF39C12)
                    : const Color(0xFFBDC3C7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonDisplay(double baseHeadRate, double baseStoreRate) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                flex: 4,
                child: Center(
                  child: Text(
                    '변경전',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF95A5A6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    '차액',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF95A5A6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Center(
                  child: Text(
                    '변경후',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFECF0F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildComparisonRow(
          '매입가',
          selectedProduct!.purchasePrice,
          vatIncludedProposal,
        ),
        const SizedBox(height: 6),
        _buildComparisonRow(
          '공급가',
          selectedProduct!.supplyPrice,
          calculatedSupply,
          rate1: baseHeadRate,
          rate2: calculatedHeadRate,
        ),
        const SizedBox(height: 6),
        _buildComparisonRow(
          '판매가',
          selectedProduct!.sellingPrice,
          calculatedSelling,
          rate1: baseStoreRate,
          rate2: calculatedStoreRate,
          highlight: true,
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '택배비',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFBDC3C7),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '${totalShippingCost.toStringAsFixed(0)}원 (${shippingCostPerUnit.toStringAsFixed(0)}원)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFECF0F1),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    '수량',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFBDC3C7),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '${quantity}EA',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFECF0F1),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: const Color(0xFF445566)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDisplayItem(
                '매장이익금',
                '${finalStoreProfit.toStringAsFixed(0)}원',
                const Color(0xFF27AE60),
                small: false,
                bold: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDisplayItem(
                '매장이익률',
                '${finalStoreProfitRate.toStringAsFixed(1)}%',
                const Color(0xFFF39C12),
                small: false,
                bold: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonRow(
    String label,
    double baseValue,
    double currentValue, {
    double? rate1,
    double? rate2,
    bool highlight = false,
  }) {
    final diff = currentValue - baseValue;
    final diffColor =
        diff >= 0 ? const Color(0xFFE74C3C) : const Color(0xFF3498DB);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: highlight
                    ? const Color(0xFFF39C12)
                    : const Color(0xFFBDC3C7),
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    baseValue.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF95A5A6),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const Text(
                  '원',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF95A5A6),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    rate1 != null ? ' (${rate1.toStringAsFixed(1)}%)' : '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF7F8C8D),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  diff >= 0
                      ? '+${diff.toStringAsFixed(0)}'
                      : diff.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 11,
                    color: diffColor,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '원',
                  style: TextStyle(
                    fontSize: 11,
                    color: diffColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    currentValue.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 12,
                      color: highlight
                          ? const Color(0xFFF39C12)
                          : const Color(0xFFECF0F1),
                      fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Text(
                  '원',
                  style: TextStyle(
                    fontSize: 12,
                    color: highlight
                        ? const Color(0xFFF39C12)
                        : const Color(0xFFECF0F1),
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    rate2 != null ? ' (${rate2.toStringAsFixed(1)}%)' : '',
                    style: TextStyle(
                      fontSize: 10,
                      color: highlight
                          ? const Color(0xFFF39C12)
                          : const Color(0xFFBDC3C7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayItem(
    String label,
    String value,
    Color color, {
    bool bold = false,
    bool small = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF34495E),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: bold ? color : const Color(0xFF445566),
          width: bold ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 11 : 12,
              color: const Color(0xFF95A5A6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: small ? 13 : 15,
              color: color,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompactSwitch('VAT포함', isVatIncluded, (val) {
                  setState(() => isVatIncluded = val);
                  calculate('proposal');
                }),
                _buildCompactSwitch('100원단위', isRoundTo100, (val) {
                  setState(() => isRoundTo100 = val);
                  calculate('proposal');
                }),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCompactCheckbox('매입가 고정', isProposalFixed, (val) {
                  setState(() => isProposalFixed = val);
                }),
                _buildCompactCheckbox('판매가 고정', isSellingFixed, (val) {
                  setState(() => isSellingFixed = val);
                }),
              ],
            ),
            const Divider(height: 16, thickness: 1, color: Color(0xFFECF0F1)),
            _buildCompactTextField(
              '제안단가',
              proposalController,
              () => calculate('proposal'),
              enabled: !isProposalFixed,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildCompactTextField(
                    '공급가',
                    supplyController,
                    () => calculate('supply'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactTextField(
                    '본사이익률(%)',
                    headRateController,
                    () => calculate('headRate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildCompactTextField(
                    '판매가',
                    sellingController,
                    () => calculate('selling'),
                    enabled: !isSellingFixed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactTextField(
                    '매장이익률(%)',
                    storeRateController,
                    () => calculate('storeRate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildCompactTextField(
                    '택배비',
                    shipController,
                    () => calculate('ship'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCompactTextField(
                    '수량',
                    quantityController,
                    () => calculate('quantity'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSwitch(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3498DB),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCheckbox(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: Checkbox(
            value: value,
            onChanged: (val) => onChanged(val ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            activeColor: const Color(0xFF3498DB),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
        ),
      ],
    );
  }

  Widget _buildCompactTextField(
    String label,
    TextEditingController controller,
    VoidCallback onChanged, {
    bool enabled = true,
  }) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [numFormatter],
        textInputAction: TextInputAction.done,
        enabled: enabled,
        style: TextStyle(
          fontSize: 13,
          color: enabled ? const Color(0xFF2C3E50) : const Color(0xFF95A5A6),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF7F8C8D)),
          suffixIcon: !enabled
              ? const Icon(Icons.lock, size: 14, color: Color(0xFF95A5A6))
              : null,
        ),
        onChanged: (value) => onChanged(),
        onSubmitted: (value) {
          FocusScope.of(context).unfocus();
          onChanged();
        },
        onTapOutside: (event) {
          FocusScope.of(context).unfocus();
        },
      ),
    );
  }
}

class ProductSearchSheet extends StatefulWidget {
  final List<Product> products;
  final bool isLoaded;
  final String loadStatus;
  final Function(Product) onProductSelected;

  const ProductSearchSheet({
    super.key,
    required this.products,
    required this.isLoaded,
    required this.loadStatus,
    required this.onProductSelected,
  });

  @override
  State<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<ProductSearchSheet> {
  final TextEditingController searchController = TextEditingController();
  List<Product> filteredProducts = [];
  final FocusNode _focusNode = FocusNode();
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    filteredProducts = widget.products;
  }

  @override
  void dispose() {
    searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void searchProducts(String query) {
    if (_lastQuery == query) return;
    _lastQuery = query;

    setState(() {
      if (query.isEmpty) {
        filteredProducts = widget.products;
      } else {
        filteredProducts = widget.products.where((product) {
          return product.name.toLowerCase().contains(query.toLowerCase()) ||
              product.code.contains(query) ||
              product.barcode.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    children: [
                      Text(
                        widget.loadStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: widget.isLoaded
                              ? const Color(0xFF27AE60)
                              : const Color(0xFFE67E22),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: '제품명, 바코드, POS 코드 검색',
                          hintStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF95A5A6),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 18,
                            color: Color(0xFF7F8C8D),
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                        textInputAction: TextInputAction.search,
                        onChanged: searchProducts,
                        onSubmitted: (value) {
                          _focusNode.unfocus();
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            '검색 결과가 없습니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF95A5A6),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            Product product = filteredProducts[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                title: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                                subtitle: Text(
                                  '코드: ${product.code} | 바코드: ${product.barcode}\n'
                                  '매입: ${product.purchasePrice.toStringAsFixed(0)}원 | '
                                  '공급: ${product.supplyPrice.toStringAsFixed(0)}원 | '
                                  '판매: ${product.sellingPrice.toStringAsFixed(0)}원',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF7F8C8D),
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '입수',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Color(0xFF95A5A6),
                                      ),
                                    ),
                                    Text(
                                      '${product.stock}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF3498DB),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  _focusNode.unfocus();
                                  widget.onProductSelected(product);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
