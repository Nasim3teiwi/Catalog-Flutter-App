import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/order_provider.dart';
import '../models/order.dart';
import 'order_detail_screen.dart';

enum _OrdersFilter { today, previous }

class OrdersHistoryScreen extends StatefulWidget {
  final Widget? drawer;
  const OrdersHistoryScreen({super.key, this.drawer});

  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  _OrdersFilter _selectedFilter = _OrdersFilter.today;
  final Set<int> _selectedOrderIds = <int>{};

  bool get _isSelectionMode => _selectedOrderIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
  }

  Future<OrderListSummary> _summaryForOrder(int orderId) {
    return context.read<OrderProvider>().getOrderListSummary(orderId);
  }

  void _toggleSelection(int orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
    });
  }

  void _clearSelection() {
    if (_selectedOrderIds.isEmpty) return;
    setState(() => _selectedOrderIds.clear());
  }

  void _selectAll(List<Order> orders) {
    final ids = orders.map((order) => order.id!).toSet();
    setState(() {
      if (_selectedOrderIds.length == ids.length) {
        _selectedOrderIds.clear();
      } else {
        _selectedOrderIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  Future<void> _moveSelectedToPrevious() async {
    final ids = _selectedOrderIds.toList(growable: false);
    if (ids.isEmpty) return;

    await context.read<OrderProvider>().moveOrdersToPrevious(ids);
    if (!mounted) return;
    setState(() => _selectedOrderIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'إلغاء التحديد',
                onPressed: _clearSelection,
              )
            : null,
        title: Text(
          _isSelectionMode
              ? '${_selectedOrderIds.length} محدد'
              : 'سجل الطلبات',
        ),
        centerTitle: true,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'تحديد الكل',
                  onPressed: () {
                    final orderProvider = context.read<OrderProvider>();
                    final now = DateTime.now();
                    final todayOrders = orderProvider.orders.where((order) {
                      return DateUtils.isSameDay(order.date, now);
                    }).toList();
                    _selectAll(todayOrders);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  tooltip: 'نقل للطلبات السابقة',
                  onPressed: _moveSelectedToPrevious,
                ),
              ]
            : null,
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          if (orderProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    orderProvider.errorMessage!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      orderProvider.loadOrders();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          if (orderProvider.orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 80,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد طلبات بعد',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الطلبات المحفوظة ستظهر هنا',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final now = DateTime.now();
          final todayOrders = orderProvider.orders.where((order) {
            return DateUtils.isSameDay(order.date, now);
          }).toList();
          final previousOrders = orderProvider.orders.where((order) {
            return !DateUtils.isSameDay(order.date, now);
          }).toList();
          final selectedOrders = _selectedFilter == _OrdersFilter.today
              ? todayOrders
              : previousOrders;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: SegmentedButton<_OrdersFilter>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment<_OrdersFilter>(
                      value: _OrdersFilter.today,
                      label: Text('طلبات اليوم (${todayOrders.length})'),
                    ),
                    ButtonSegment<_OrdersFilter>(
                      value: _OrdersFilter.previous,
                      label: Text('الطلبات السابقة (${previousOrders.length})'),
                    ),
                  ],
                  selected: {_selectedFilter},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedFilter = selection.first;
                      _selectedOrderIds.clear();
                    });
                  },
                ),
              ),
              Expanded(
                child: selectedOrders.isEmpty
                    ? Center(
                        child: Text(
                          _selectedFilter == _OrdersFilter.today
                              ? 'لا توجد طلبات اليوم'
                              : 'لا توجد طلبات سابقة',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: selectedOrders.length,
                        itemBuilder: (context, index) {
                          final order = selectedOrders[index];
                          final isTodayOrder = DateUtils.isSameDay(order.date, now);
                          final isSelected = _selectedOrderIds.contains(order.id);

                          return _OrderCard(
                            order: order,
                            summaryFuture: _summaryForOrder(order.id!),
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            onLongPress: isTodayOrder
                                ? () => _toggleSelection(order.id!)
                                : null,
                            onTap: () async {
                              if (_isSelectionMode) {
                                if (isTodayOrder) {
                                  _toggleSelection(order.id!);
                                }
                                return;
                              }

                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OrderDetailScreen(order: order),
                                ),
                              );
                              if (context.mounted) {
                                context.read<OrderProvider>().loadOrders();
                              }
                            },
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
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final Future<OrderListSummary> summaryFuture;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _OrderCard({
    required this.order,
    required this.summaryFuture,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: onLongPress == null ? null : (_) => onTap(),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.store,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FutureBuilder<OrderListSummary>(
                  future: summaryFuture,
                  builder: (context, snapshot) {
                    final summary = snapshot.data;
                    final count = summary?.itemCount ?? 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.shopName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(status: order.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(order.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$count عنصر',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (summary != null)
                          Text(
                            summary.isTotalAvailable
                                ? 'المجموع: ${summary.total!.toStringAsFixed(2)} ₪'
                                : 'يوجد منتجات غير مسعّرة',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: summary.isTotalAvailable
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (order.notes != null && order.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            order.notes!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (snapshot.hasError)
                          Text(
                            'المجموع غير متوفر',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDelivered = status == Order.deliveredStatus;
    const pendingBg = Color(0xFFFEF3C7);
    const pendingText = Color(0xFFB45309);
    const deliveredBg = Color(0xFFDCFCE7);
    const deliveredText = Color(0xFF166534);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDelivered ? deliveredBg : pendingBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isDelivered ? 'تم التسليم' : 'قيد التنفيذ',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDelivered ? deliveredText : pendingText,
        ),
      ),
    );
  }
}
