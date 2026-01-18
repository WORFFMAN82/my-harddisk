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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
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

  CalculationHistory({
    required this.timestamp,
    required this.proposal,
    required this.supply,
    required this.selling,
    required this.headRate,
    required this.storeRate,
    required this.isVatIncluded,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'proposal': proposal,
    'supply': supply,
    'selling': selling,
    'headRate': headRate,
    'storeRate': storeRate,
    'isVatIncluded': isVatIncluded,
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

  bool isVatIncluded = false;
  bool isRoundTo100 = true;

  double vatIncludedProposal = 0;
  double calculatedSupply = 0;
  double calculatedSelling = 0;
  double calculatedHeadRate = 0;
  double calculatedStoreRate = 0;
  double finalStoreProfit = 0; // 변경: 최종매장이익금
  double finalStoreProfitRate = 0; // 변경: 최종매장이익률
  double priceDifference = 0;

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
    super.dispose();
  }

  // 헬퍼 함수들
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

      debugPrint('CSV 로드 완료: ${csvTable.length}줄');

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
          debugPrint('행 $i: 열 개수 부족 (${row.length}개)');
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

          if (i <= 3) {
            debugPrint(
              '행 $i: 코드=$code, 바코드=$barcode, 이름=$name, 매입=$purchasePrice, 공급=$supplyPrice, 판매=$sellingPrice, 재고=$stock',
            );
          }
        } catch (e) {
          failCount++;
          debugPrint('행 $i 파싱 실패: $e');
        }
      }

      setState(() {
        productList = newProducts;
        isProductsLoaded = true;
        loadStatus =
            '$successCount개의 제품 로드 완료${failCount > 0 ? ' ($failCount개 실패)' : ''}';
      });

      debugPrint('✅ 최종 로드 완료: $successCount개 성공, $failCount개 실패');
    } catch (e) {
      setState(() {
        loadStatus = '제품 데이터 로드 실패';
        loadError = e.toString();
        isProductsLoaded = true;
      });
      debugPrint('❌ CSV 로드 에러: $e');
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

    setState(() {
      // 1. VAT 포함 제안단가 계산
      vatIncludedProposal = isVatIncluded ? proposal : proposal * 1.1;

      // 2. 시나리오별 계산
      if (trigger == 'proposal' && headRate > 0 && vatIncludedProposal > 0) {
        // 시나리오 1: 제안단가 + 본사마진율 입력 → 공급가 계산
        calculatedSupply = roundTo100(
          vatIncludedProposal * (1 + headRate / 100),
        );

        if (storeRate > 0) {
          // 매장마진율도 있으면 판매가 계산
          calculatedSelling = roundTo100(
            calculatedSupply * (1 + storeRate / 100),
          );
        }
      } else if (trigger == 'headRate' &&
          vatIncludedProposal > 0 &&
          headRate > 0) {
        // 본사마진율 변경 → 공급가 재계산
        calculatedSupply = roundTo100(
          vatIncludedProposal * (1 + headRate / 100),
        );

        if (storeRate > 0) {
          calculatedSelling = roundTo100(
            calculatedSupply * (1 + storeRate / 100),
          );
        }
      } else if (trigger == 'supply' && supply > 0) {
        // 시나리오 2: 공급가 직접 입력 → 본사마진율 역산
        calculatedSupply = supply;

        if (vatIncludedProposal > 0) {
          calculatedHeadRate =
              ((calculatedSupply - vatIncludedProposal) / vatIncludedProposal) *
              100;
        }

        if (storeRate > 0) {
          calculatedSelling = roundTo100(
            calculatedSupply * (1 + storeRate / 100),
          );
        }
      } else if (trigger == 'storeRate' &&
          calculatedSupply > 0 &&
          storeRate > 0) {
        // 매장마진율 입력/변경 → 판매가 계산
        calculatedSelling = roundTo100(
          calculatedSupply * (1 + storeRate / 100),
        );
      } else if (trigger == 'selling' && selling > 0) {
        // 시나리오 3: 판매가 직접 입력 → 역산
        calculatedSelling = selling;

        if (calculatedSupply > 0) {
          // 공급가가 있으면 매장마진율 계산
          calculatedStoreRate =
              ((calculatedSelling - calculatedSupply) / calculatedSupply) * 100;
        } else if (supply > 0) {
          // 입력된 공급가로 계산
          calculatedSupply = supply;
          calculatedStoreRate =
              ((calculatedSelling - calculatedSupply) / calculatedSupply) * 100;

          if (vatIncludedProposal > 0) {
            calculatedHeadRate =
                ((calculatedSupply - vatIncludedProposal) /
                    vatIncludedProposal) *
                100;
          }
        } else if (storeRate > 0) {
          // 매장마진율로 공급가 역산
          calculatedSupply = roundTo100(
            calculatedSelling / (1 + storeRate / 100),
          );

          if (vatIncludedProposal > 0) {
            calculatedHeadRate =
                ((calculatedSupply - vatIncludedProposal) /
                    vatIncludedProposal) *
                100;
          }
        }
      }

      // 3. 항상 재계산되어야 하는 값들

      // 본사마진율 계산 (공급가와 제안단가가 모두 있을 때)
      if (calculatedSupply > 0 && vatIncludedProposal > 0) {
        calculatedHeadRate =
            ((calculatedSupply - vatIncludedProposal) / vatIncludedProposal) *
            100;
      }

      // 매장마진율 계산 (판매가와 공급가가 모두 있을 때)
      if (calculatedSelling > 0 && calculatedSupply > 0) {
        calculatedStoreRate =
            ((calculatedSelling - calculatedSupply) / calculatedSupply) * 100;
      }

      // 4. 최종매장이익금 = 판매가 - 공급가 (핵심 수정!)
      if (calculatedSelling > 0 && calculatedSupply > 0) {
        finalStoreProfit = calculatedSelling - calculatedSupply;
      } else {
        finalStoreProfit = 0;
      }

      // 5. 최종매장이익률 = (판매가 - 공급가) / 판매가 * 100 (판매가 기준)
      if (calculatedSelling > 0 && finalStoreProfit > 0) {
        finalStoreProfitRate = (finalStoreProfit / calculatedSelling) * 100;
      } else {
        finalStoreProfitRate = 0;
      }

      // 6. 차액 (입력된 판매가와 계산된 판매가의 차이)
      if (selling > 0) {
        priceDifference = calculatedSelling - selling;
      } else {
        priceDifference = 0;
      }
    });

    addToHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink[100],
        title: const Text(
          '다계산해줄지니어스',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder:
                    (context) => ProductSearchSheet(
                      products: productList,
                      isLoaded: isProductsLoaded,
                      loadStatus: loadStatus,
                      onProductSelected: (product) {
                        setState(() {
                          proposalController.text = product.purchasePrice
                              .toStringAsFixed(0);
                          supplyController.text = product.supplyPrice
                              .toStringAsFixed(0);
                          sellingController.text = product.sellingPrice
                              .toStringAsFixed(0);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} 선택됨'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder:
                    (context) => DraggableScrollableSheet(
                      initialChildSize: 0.7,
                      minChildSize: 0.5,
                      maxChildSize: 0.95,
                      builder: (context, scrollController) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
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
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child:
                                    historyList.isEmpty
                                        ? const Center(
                                          child: Text('히스토리가 없습니다'),
                                        )
                                        : ListView.builder(
                                          controller: scrollController,
                                          itemCount: historyList.length,
                                          itemBuilder: (context, index) {
                                            CalculationHistory history =
                                                historyList[index];
                                            return Card(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              child: ListTile(
                                                title: Text(
                                                  '제안: ${history.proposal.toStringAsFixed(0)}원',
                                                ),
                                                subtitle: Text(
                                                  '공급: ${history.supply.toStringAsFixed(0)}원 | 판매: ${history.selling.toStringAsFixed(0)}원\n'
                                                  '본사: ${history.headRate.toStringAsFixed(1)}% | 매장: ${history.storeRate.toStringAsFixed(1)}%',
                                                ),
                                                trailing: Text(
                                                  '${history.timestamp.month}/${history.timestamp.day}',
                                                ),
                                                onTap: () {
                                                  setState(() {
                                                    proposalController
                                                        .text = history.proposal
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            _buildInputCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.pink[50],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💰 계산 정보',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 2),
            _infoRow(
              '제안단가 (VAT포함)',
              '${vatIncludedProposal.toStringAsFixed(0)}원',
            ),
            _infoRow('본사마진율', '${calculatedHeadRate.toStringAsFixed(1)}%'),
            _infoRow('공급가', '${calculatedSupply.toStringAsFixed(0)}원'),
            _infoRow('매장마진율', '${calculatedStoreRate.toStringAsFixed(1)}%'),
            _infoRow(
              '최종판매가',
              '${calculatedSelling.toStringAsFixed(0)}원',
              highlight: true,
            ),
            const Divider(thickness: 2),
            _infoRow('최종매장이익금', '${finalStoreProfit.toStringAsFixed(0)}원'),
            _infoRow('최종매장이익률', '${finalStoreProfitRate.toStringAsFixed(1)}%'),
            _infoRow('차액', '${priceDifference.toStringAsFixed(0)}원'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.pink[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              '📝 입력 정보',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 2),
            Row(
              children: [
                const Text('VAT 포함 여부: '),
                Switch(
                  value: isVatIncluded,
                  onChanged: (value) {
                    setState(() {
                      isVatIncluded = value;
                    });
                    calculate('proposal');
                  },
                ),
                const Spacer(),
                const Text('100원 단위 정리: '),
                Switch(
                  value: isRoundTo100,
                  onChanged: (value) {
                    setState(() {
                      isRoundTo100 = value;
                    });
                    calculate('proposal');
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildTextField(
              '제안단가',
              proposalController,
              () => calculate('proposal'),
            ),
            _buildTextField(
              '본사 마진율 (%)',
              headRateController,
              () => calculate('headRate'),
            ),
            _buildTextField('공급가', supplyController, () => calculate('supply')),
            _buildTextField(
              '매장 마진율 (%)',
              storeRateController,
              () => calculate('storeRate'),
            ),
            _buildTextField(
              '최종 판매가',
              sellingController,
              () => calculate('selling'),
            ),
            _buildTextField('배송비', shipController, () => calculate('ship')),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    VoidCallback onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [numFormatter],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (value) => onChanged(),
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

  @override
  void initState() {
    super.initState();
    filteredProducts = widget.products;
  }

  void searchProducts(String query) {
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
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      widget.loadStatus,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.isLoaded ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: '제품명, 바코드, POS 코드 검색',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: searchProducts,
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    filteredProducts.isEmpty
                        ? const Center(child: Text('검색 결과가 없습니다'))
                        : ListView.builder(
                          controller: scrollController,
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            Product product = filteredProducts[index];
                            return ListTile(
                              title: Text(product.name),
                              subtitle: Text(
                                '코드: ${product.code} | 바코드: ${product.barcode}\n'
                                '매입: ${product.purchasePrice.toStringAsFixed(0)}원 | '
                                '공급: ${product.supplyPrice.toStringAsFixed(0)}원 | '
                                '판매: ${product.sellingPrice.toStringAsFixed(0)}원',
                              ),
                              trailing: Text('재고: ${product.stock}'),
                              onTap: () {
                                widget.onProductSelected(product);
                                Navigator.pop(context);
                              },
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
}
