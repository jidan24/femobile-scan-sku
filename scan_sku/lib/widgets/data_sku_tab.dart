import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class DataSkuTab extends StatefulWidget {
  const DataSkuTab({super.key});

  @override
  State<DataSkuTab> createState() => _DataSkuTabState();
}

class _DataSkuTabState extends State<DataSkuTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  
  List<dynamic> _data = [];
  bool _isLoading = false;
  
  int _limit = 10;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalData = 0;

  final ScrollController _horizontalScrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final response = await ApiService.fetchSkus(
        search: _searchController.text,
        limit: _limit,
        page: _currentPage,
      );
      
      if (response['success']) {
        setState(() {
          _data = response['data'];
          _totalPages = response['pagination']['totalPages'];
          _totalData = response['totalData'] ?? response['pagination']['total'] ?? 0;
          // Ensure total pages is at least 1 to avoid pagination issues
          if (_totalPages < 1) _totalPages = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearch() {
    setState(() {
      _currentPage = 1;
    });
    _fetchData();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _onSearch();
    });
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      return isoString;
    }
  }

  List<Widget> _buildPaginationControls() {
    List<Widget> controls = [];
    
    // Previous Button
    controls.add(
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: _currentPage > 1 ? () {
          setState(() => _currentPage--);
          _fetchData();
        } : null,
      )
    );

    // Build page numbers 1 2 3 ... 11 logic
    Set<int> pageNumbers = {};
    pageNumbers.add(1);
    pageNumbers.add(_totalPages);
    
    for (int i = _currentPage - 2; i <= _currentPage + 2; i++) {
      if (i > 1 && i < _totalPages) {
        pageNumbers.add(i);
      }
    }

    List<int> sortedPages = pageNumbers.toList()..sort();
    
    int? prevPage;
    for (int page in sortedPages) {
      if (prevPage != null && page - prevPage > 1) {
        controls.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('...'),
        ));
      }
      
      controls.add(
        InkWell(
          onTap: () {
            if (_currentPage != page) {
              setState(() => _currentPage = page);
              _fetchData();
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _currentPage == page ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentPage == page ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              '$page',
              style: TextStyle(
                color: _currentPage == page ? AppColors.primaryForeground : AppColors.foreground,
                fontWeight: _currentPage == page ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
      prevPage = page;
    }

    // Next Button
    controls.add(
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: _currentPage < _totalPages ? () {
          setState(() => _currentPage++);
          _fetchData();
        } : null,
      )
    );

    return controls;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Toolbar
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      hintText: 'Search SKU...',
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.mutedForeground),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.mutedForeground),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch();
                        },
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isDense: true,
                    value: _limit,
                    items: [10, 20, 50, 100].map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value / page'),
                      );
                    }).toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null && newValue != _limit) {
                        setState(() {
                          _limit = newValue;
                          _currentPage = 1;
                        });
                        _fetchData();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primaryForeground, size: 20),
                  onPressed: () => _fetchData(showLoading: true),
                  tooltip: 'Refresh Data',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Showing ${_data.length} of $_totalData items',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Table
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : Card(
                    margin: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: AppColors.border),
                                child: DataTable(
                                columnSpacing: 32,
                                horizontalMargin: 24,
                                headingTextStyle: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.mutedForeground, fontSize: 12, letterSpacing: 0.5),
                                dataTextStyle: const TextStyle(fontSize: 14, color: AppColors.foreground),
                                headingRowColor: WidgetStateProperty.resolveWith(
                                  (states) => AppColors.muted,
                                ),
                                columns: const [
                          DataColumn(label: Expanded(child: Text('SKU Code', textAlign: TextAlign.center))),
                          DataColumn(label: Expanded(child: Text('Color', textAlign: TextAlign.center))),
                          DataColumn(label: Expanded(child: Text('Operator Name', textAlign: TextAlign.center))),
                          DataColumn(label: Expanded(child: Text('Created At', textAlign: TextAlign.center))),
                          DataColumn(label: Expanded(child: Text('Updated At', textAlign: TextAlign.center))),
                        ],
                        rows: _data.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Align(alignment: Alignment.center, child: Text(item['skuCode'] ?? '-'))),
                              DataCell(Align(alignment: Alignment.center, child: Text(item['color'] ?? '-'))),
                              DataCell(Align(alignment: Alignment.center, child: Text(item['operatorName'] ?? '-'))),
                              DataCell(Align(alignment: Alignment.center, child: Text(_formatDate(item['createdAt'] ?? '')))),
                              DataCell(Align(alignment: Alignment.center, child: Text(_formatDate(item['updatedAt'] ?? '')))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),
          ),
          
          const SizedBox(height: 16),
          
          // Pagination
          if (!_isLoading && _totalPages > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildPaginationControls(),
            ),
        ],
      ),
    );
  }
}
