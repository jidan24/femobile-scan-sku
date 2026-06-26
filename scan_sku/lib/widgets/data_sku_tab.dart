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

class _DataSkuTabState extends State<DataSkuTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<dynamic> _data = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  static const int _limit = 10;
  int _currentPage = 1;
  int _totalData = 0;

  @override
  void initState() {
    super.initState();
    _fetchData(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  // Jika konten tidak memenuhi layar setelah load, langsung muat lebih
  void _checkIfNeedLoadMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent == 0 &&
          _hasMore &&
          !_isLoadingMore) {
        _loadMore();
      }
    });
  }

  Future<void> _fetchData({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (refresh) {
        _data = [];
        _currentPage = 1;
        _hasMore = true;
      }
    });

    try {
      final response = await ApiService.fetchSkus(
        search: _searchController.text,
        limit: _limit,
        page: 1,
      );

      if (mounted && response['success'] == true) {
        final newData = response['data'] as List<dynamic>;
        final totalPages = (response['pagination']['totalPages'] as num).toInt();
        setState(() {
          _data = newData;
          _currentPage = 1;
          _totalData = (response['totalData'] ?? response['pagination']['total'] ?? 0) is num
              ? (response['totalData'] ?? response['pagination']['total'] ?? 0)
              : 0;
          _hasMore = _currentPage < totalPages;
        });
        _checkIfNeedLoadMore();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.fetchSkus(
        search: _searchController.text,
        limit: _limit,
        page: nextPage,
      );

      if (mounted && response['success'] == true) {
        final newData = response['data'] as List<dynamic>;
        final totalPages = (response['pagination']['totalPages'] as num).toInt();
        setState(() {
          _data.addAll(newData);
          _currentPage = nextPage;
          _hasMore = _currentPage < totalPages;
        });
        _checkIfNeedLoadMore();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchData(refresh: true);
    });
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _fetchData(refresh: true),
            decoration: InputDecoration(
              hintText: 'Search SKU, color, or operator...',
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.mutedForeground,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 18,
                        color: AppColors.mutedForeground,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _fetchData(refresh: true);
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.card,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ),

        // Total count badge
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha((255 * 0.1).toInt()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_data.length} dari $_totalData item',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

        // List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _data.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => _fetchData(refresh: true),
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _data.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _data.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          return _buildSkuCard(_data[index], index);
                        },
                      ),
                    ),
        ),

        // No more data indicator
        if (!_isLoading && !_hasMore && _data.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 1,
                  width: 40,
                  color: AppColors.border,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Semua data sudah dimuat',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 1,
                  width: 40,
                  color: AppColors.border,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSkuCard(Map<String, dynamic> item, int index) {
    final skuCode = item['skuCode'] ?? '-';
    final color = item['color'] ?? '-';
    final operatorName = item['operatorName'] ?? '-';
    final quantity = item['quantity'];
    final createdAt = item['createdAt'] != null
        ? _formatDate(item['createdAt'])
        : '-';
    final updatedAt = item['updatedAt'] != null
        ? _formatDate(item['updatedAt'])
        : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: SKU Code + index badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha((255 * 0.1).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    skuCode,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.foreground,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (quantity != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withAlpha((255 * 0.12).toInt()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Qty: $quantity',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),

            // Info rows
            _buildInfoRow(Icons.color_lens_outlined, 'Color', color),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person_outline, 'Operator', operatorName),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'Created',
              createdAt,
            ),
            if (updatedAt != createdAt) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.update_outlined,
                'Updated',
                updatedAt,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.mutedForeground),
        const SizedBox(width: 8),
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const Text(
          ':  ',
          style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchData(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: AppColors.mutedForeground.withAlpha(128),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tidak ada data',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tarik ke bawah untuk refresh',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
