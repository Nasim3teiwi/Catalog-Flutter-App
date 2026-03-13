import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/order.dart';
import '../models/order_item.dart';
import '../providers/order_provider.dart';
import '../providers/catalog_provider.dart';
import '../services/pdf_style.dart';
import '../widgets/product_image.dart';
import '../widgets/quantity_selector.dart';

class OrderDetailScreen extends StatefulWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  bool _isProcessing = false;
  bool _isExportingPdf = false;
  bool _isLoadingDetails = true;
  String? _loadError;
  List<OrderItem> _items = const [];
  bool _isTotalAvailable = false;
  final ValueNotifier<double?> _totalNotifier = ValueNotifier<double?>(null);
  final Map<int, _OrderItemQuantityState> _quantityStates = {};

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadDetails();
  }

  @override
  void dispose() {
    _totalNotifier.dispose();
    for (final state in _quantityStates.values) {
      state.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoadingDetails = true;
      _loadError = null;
    });

    try {
      final data = await context
          .read<OrderProvider>()
          .getOrderDetailsViewData(_order.id!);
      if (!mounted) return;

      for (final state in _quantityStates.values) {
        state.dispose();
      }
      _quantityStates.clear();

      for (final item in data.items) {
        if (item.id != null) {
          _quantityStates[item.id!] = _OrderItemQuantityState(item.quantity);
        }
      }

      setState(() {
        _items = data.items;
        _isTotalAvailable = data.isTotalAvailable;
        _totalNotifier.value = data.total;
        _isLoadingDetails = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'فشل في تحميل عناصر الطلب';
        _isLoadingDetails = false;
      });
    }
  }

  Future<void> _confirmDeleteOrder() async {
    final theme = Theme.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الطلب؟'),
        content: const Text('لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;
    await context.read<OrderProvider>().deleteOrder(_order.id!);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _confirmMarkDelivered() async {
    final shouldDeliver = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد التسليم'),
        content: const Text(
          'عند تأكيد التسليم سيصبح الطلب غير قابل للتعديل.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد التسليم'),
          ),
        ],
      ),
    );

    if (shouldDeliver != true || !mounted) return;

    setState(() => _isProcessing = true);
    final updatedOrder = await context.read<OrderProvider>().markOrderAsDelivered(
          _order,
        );
    if (!mounted) return;
    setState(() {
      _order = updatedOrder;
      _isProcessing = false;
    });
  }

  Future<void> _updateItemQuantity(OrderItem item, int quantity) async {
    final orderItemId = item.id;
    if (orderItemId == null) return;

    final quantityState = _quantityStates[orderItemId];
    if (quantityState == null) return;

    final previousQuantity = quantityState.quantity;
    if (previousQuantity == quantity) return;

    quantityState.setQuantity(quantity);

    final unitPrice = item.productPrice;
    if (_isTotalAvailable && unitPrice != null && _totalNotifier.value != null) {
      _totalNotifier.value =
          _totalNotifier.value! + (quantity - previousQuantity) * unitPrice;
    }

    try {
      await context.read<OrderProvider>().updatePendingOrderItemQuantity(
            order: _order,
            orderItemId: orderItemId,
            quantity: quantity,
          );
    } catch (_) {
      quantityState.setQuantity(previousQuantity);
      if (_isTotalAvailable && unitPrice != null && _totalNotifier.value != null) {
        _totalNotifier.value =
            _totalNotifier.value! + (previousQuantity - quantity) * unitPrice;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديث الكمية، حاول مرة أخرى'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeItem(OrderItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة العنصر؟'),
        content: const Text('هل أنت متأكد من إزالة هذا العنصر من الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<OrderProvider>().removePendingOrderItem(
          order: _order,
          orderItemId: item.id!,
        );
    if (!mounted) return;

    final removedQuantity = _quantityStates[item.id!]?.quantity ?? item.quantity;
    _quantityStates.remove(item.id!)?.dispose();

    if (_isTotalAvailable && item.productPrice != null && _totalNotifier.value != null) {
      _totalNotifier.value =
          _totalNotifier.value! - (removedQuantity * item.productPrice!);
    }

    setState(() {
      _items = _items.where((orderItem) => orderItem.id != item.id).toList();
    });
  }

  int _effectiveQuantity(OrderItem item) {
    final id = item.id;
    if (id == null) return item.quantity;
    return _quantityStates[id]?.quantity ?? item.quantity;
  }

  String _statusLabel(String status) {
    return status == Order.deliveredStatus ? 'تم التسليم' : 'قيد التنفيذ';
  }

  String _formatMoneyEn(double value) => cleanPdfText('${value.toStringAsFixed(2)} ₪');

  String _formatDateEn(DateTime value) {
    final enFormatter = DateFormat('MMM dd, yyyy - hh:mm a', 'en_US');
    return cleanPdfText(enFormatter.format(value));
  }

  Future<Uint8List> _buildOrderPdf() async {
    final doc = pw.Document();
    final pdfStyles = await loadPdfStyleBundle();

    double runningTotal = 0;
    var hasFullTotal = true;

    for (final item in _items) {
      final price = item.productPrice;
      if (price == null) {
        hasFullTotal = false;
        continue;
      }
      runningTotal += price * _effectiveQuantity(item);
    }

    final totalText = hasFullTotal ? _formatMoneyEn(runningTotal) : 'N/A';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: pdfStyles.cairoFont,
          bold: pdfStyles.cairoFont,
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  cleanPdfText('تفاصيل الطلب'),
                  textAlign: pw.TextAlign.right,
                  style: pdfStyles.arabicHeaderStyle,
                ),
                pw.SizedBox(height: 14),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(cleanPdfText('اسم المحل'),
                              textAlign: pw.TextAlign.right,
                              style: pdfStyles.arabicLabelStyle),
                          pw.Text(cleanPdfText(_order.shopName),
                              textAlign: pw.TextAlign.left,
                              style: pdfStyles.arabicStyle),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(cleanPdfText('تاريخ الطلب'),
                              textAlign: pw.TextAlign.right,
                              style: pdfStyles.arabicLabelStyle),
                          pw.Text(
                            _formatDateEn(_order.date),
                            textAlign: pw.TextAlign.left,
                            textDirection: pw.TextDirection.ltr,
                            style: pdfStyles.arabicStyle,
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(cleanPdfText('الحالة'),
                              textAlign: pw.TextAlign.right,
                              style: pdfStyles.arabicLabelStyle),
                          pw.Text(cleanPdfText(_statusLabel(_order.status)),
                              textAlign: pw.TextAlign.left,
                              style: pdfStyles.arabicStyle),
                        ],
                      ),
                      if (_order.isDelivered && _order.deliveredAt != null) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(cleanPdfText('تاريخ التسليم'),
                                textAlign: pw.TextAlign.right,
                                style: pdfStyles.arabicLabelStyle),
                            pw.Text(
                              _formatDateEn(_order.deliveredAt!),
                              textAlign: pw.TextAlign.left,
                              textDirection: pw.TextDirection.ltr,
                              style: pdfStyles.arabicStyle,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  cleanPdfText('العناصر'),
                  textAlign: pw.TextAlign.right,
                  style: pdfStyles.arabicLabelStyle.copyWith(fontSize: 14),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4),
                    1: const pw.FlexColumnWidth(1.4),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(cleanPdfText('المنتج'),
                              textAlign: pw.TextAlign.right,
                              style: pdfStyles.arabicLabelStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(cleanPdfText('الكمية'),
                              textAlign: pw.TextAlign.center,
                              style: pdfStyles.arabicLabelStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(cleanPdfText('سعر الوحدة'),
                              textAlign: pw.TextAlign.center,
                              style: pdfStyles.arabicLabelStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(cleanPdfText('الإجمالي'),
                              textAlign: pw.TextAlign.center,
                              style: pdfStyles.arabicLabelStyle),
                        ),
                      ],
                    ),
                    ..._items.map((item) {
                      final qty = _effectiveQuantity(item);
                      final unitPrice = item.productPrice;
                      final lineTotal = unitPrice != null ? unitPrice * qty : null;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              cleanPdfText(
                                  item.productName ?? 'Product #${item.productId}'),
                              textAlign: pw.TextAlign.right,
                              style: pdfStyles.arabicStyle,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              cleanPdfText('$qty'),
                              textAlign: pw.TextAlign.center,
                              textDirection: pw.TextDirection.ltr,
                              style: pdfStyles.arabicStyle,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              unitPrice != null ? _formatMoneyEn(unitPrice) : 'N/A',
                              textAlign: pw.TextAlign.center,
                              textDirection: pw.TextDirection.ltr,
                              style: pdfStyles.arabicStyle,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              lineTotal != null ? _formatMoneyEn(lineTotal) : 'N/A',
                              textAlign: pw.TextAlign.center,
                              textDirection: pw.TextDirection.ltr,
                              style: pdfStyles.arabicStyle,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 14),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      totalText,
                      textAlign: pw.TextAlign.left,
                      textDirection: pw.TextDirection.ltr,
                      style: pdfStyles.arabicLabelStyle,
                    ),
                    pw.Text(
                      cleanPdfText('المجموع الكلي'),
                      textAlign: pw.TextAlign.right,
                      style: pdfStyles.arabicLabelStyle,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<String> _savePdfLocally(Uint8List bytes, String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(p.join(appDir.path, 'order_exports'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final outputPath = p.join(exportDir.path, fileName);
    final file = File(outputPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _openPdfActions(Uint8List bytes, String fileName) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('مشاركة PDF'),
              onTap: () async {
                Navigator.pop(ctx);
                await Printing.sharePdf(bytes: bytes, filename: fileName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: const Text('طباعة / حفظ كـ PDF'),
              onTap: () async {
                Navigator.pop(ctx);
                await Printing.layoutPdf(
                  name: fileName,
                  onLayout: (_) async => bytes,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('حفظ داخل التطبيق'),
              onTap: () async {
                Navigator.pop(ctx);
                final savedPath = await _savePdfLocally(bytes, fileName);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حفظ الملف في: $savedPath'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_isExportingPdf || _isLoadingDetails) return;

    setState(() => _isExportingPdf = true);
    try {
      final bytes = await _buildOrderPdf();
      final fileName =
          'order_${_order.id}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      if (!mounted) return;
      await _openPdfActions(bytes, fileName);
    } catch (e, st) {
      debugPrint('PDF generation failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إنشاء ملف PDF'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMMM dd, yyyy • hh:mm a');
    final deliveredDateFormat = DateFormat('yyyy/MM/dd • hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        centerTitle: true,
        actions: [
          if (!_order.isDelivered)
            IconButton(
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.local_shipping_outlined),
              tooltip: 'تأكيد التسليم',
              onPressed: _isProcessing ? null : _confirmMarkDelivered,
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'حذف الطلب',
            onPressed: _confirmDeleteOrder,
          ),
        ],
      ),
      body: _isLoadingDetails
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Text(
                    _loadError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                )
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _order.shopName,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dateFormat.format(_order.date),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _OrderStatusBadge(status: _order.status),
                          ],
                        ),
                        if (_order.isDelivered && _order.deliveredAt != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'تاريخ التسليم: ${deliveredDateFormat.format(_order.deliveredAt!)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (_order.notes != null && _order.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.notes,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _order.notes!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_order.isDelivered) ...[
                          const SizedBox(height: 12),
                          Text(
                            'هذا الطلب تم تسليمه ولا يمكن تعديله.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'العناصر',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  const Center(child: Text('لا توجد عناصر في هذا الطلب'))
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final catalog = context.read<CatalogProvider>();
                      final product = catalog.getProductById(item.productId);
                      final itemName = item.productName ?? 'منتج #${item.productId}';
                        final quantityState = item.id != null
                          ? _quantityStates[item.id!]
                          : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: product != null
                                          ? ProductImage(
                                              imagePath: product.image,
                                              fit: BoxFit.contain,
                                              errorWidget: Icon(
                                                Icons.image_outlined,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            )
                                          : Icon(
                                              Icons.image_outlined,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemName,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.productPrice != null
                                              ? '${item.productPrice!.toStringAsFixed(2)} ₪ للوحدة'
                                              : 'السعر غير متوفر',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_order.isDelivered)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '×${item.quantity}',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (!_order.isDelivered) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    quantityState == null
                                        ? QuantitySelector(
                                            quantity: item.quantity,
                                            size: 34,
                                            onChanged: (value) =>
                                                _updateItemQuantity(item, value),
                                          )
                                        : ChangeNotifierProvider.value(
                                            value: quantityState,
                                            child: Selector<_OrderItemQuantityState, int>(
                                              selector: (_, state) => state.quantity,
                                              builder: (context, quantity, _) {
                                                return QuantitySelector(
                                                  quantity: quantity,
                                                  size: 34,
                                                  onChanged: (value) =>
                                                      _updateItemQuantity(item, value),
                                                );
                                              },
                                            ),
                                          ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () => _removeItem(item),
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: theme.colorScheme.error,
                                      ),
                                      label: Text(
                                        'إزالة',
                                        style: TextStyle(color: theme.colorScheme.error),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الإجمالي',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isTotalAvailable)
                          ValueListenableBuilder<double?>(
                            valueListenable: _totalNotifier,
                            builder: (context, total, _) {
                              return Text(
                                total != null
                                    ? '${total.toStringAsFixed(2)} ₪'
                                    : 'المجموع غير متوفر',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          )
                        else
                          Text(
                            'المجموع غير متوفر',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isExportingPdf ? null : _exportPdf,
                    icon: _isExportingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(_isExportingPdf ? 'جار التصدير...' : 'تصدير PDF'),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _OrderItemQuantityState extends ChangeNotifier {
  int _quantity;

  _OrderItemQuantityState(this._quantity);

  int get quantity => _quantity;

  void setQuantity(int value) {
    if (_quantity == value) return;
    _quantity = value;
    notifyListeners();
  }
}

class _OrderStatusBadge extends StatelessWidget {
  final String status;

  const _OrderStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDelivered = status == Order.deliveredStatus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDelivered
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isDelivered ? 'تم التسليم' : 'قيد التنفيذ',
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDelivered
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
