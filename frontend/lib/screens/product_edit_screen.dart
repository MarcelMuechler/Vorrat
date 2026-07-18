import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../widgets/category_field.dart';
import '../widgets/quantity_unit_field.dart';

class ProductEditScreen extends StatefulWidget {
  final Product product;

  const ProductEditScreen({super.key, required this.product});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  late final TextEditingController _nameController;
  final _categoryFieldKey = GlobalKey<CategoryFieldState>();
  int? _categoryId;
  String? _categoryName;
  late String _quantityUnit;
  late final TextEditingController _bestBeforeDaysController;
  late final TextEditingController _openShelfLifeDaysController;
  late final TextEditingController _lowStockThresholdController;
  late final TextEditingController _targetStockLevelController;
  List<Location> _locations = [];
  int? _selectedLocationId;
  String? _imageUrl;
  bool _loadingLocations = true;
  bool _saving = false;
  bool _refreshingFromOff = false;
  bool _uploadingImage = false;
  late String? _barcode;
  bool _generatingQrLabel = false;
  late List<String> _extraBarcodes;
  late final TextEditingController _newBarcodeController;
  bool _barcodeBusy = false;

  /// A synthetic `VORRAT-<id>` label (#105) has no manufacturer entry on
  /// Open Food Facts to refresh from -- only offer that action for a real
  /// scanned barcode.
  bool get _hasRealBarcode => _barcode != null && !_barcode!.startsWith('VORRAT-');

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p.name);
    _categoryId = p.categoryId;
    _categoryName = p.categoryName;
    _quantityUnit = p.quantityUnit;
    _barcode = p.barcode;
    _bestBeforeDaysController = TextEditingController(
      text: p.defaultBestBeforeDays == null ? '' : '${p.defaultBestBeforeDays}',
    );
    _openShelfLifeDaysController = TextEditingController(
      text: p.defaultOpenShelfLifeDays == null ? '' : '${p.defaultOpenShelfLifeDays}',
    );
    _lowStockThresholdController = TextEditingController(
      text: p.lowStockThreshold == null ? '' : '${p.lowStockThreshold}',
    );
    _targetStockLevelController = TextEditingController(
      text: p.targetStockLevel == null ? '' : '${p.targetStockLevel}',
    );
    _selectedLocationId = p.defaultLocationId;
    _imageUrl = p.imageUrl;
    _extraBarcodes = List<String>.from(p.extraBarcodes);
    _newBarcodeController = TextEditingController();
    _loadLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bestBeforeDaysController.dispose();
    _openShelfLifeDaysController.dispose();
    _lowStockThresholdController.dispose();
    _targetStockLevelController.dispose();
    _newBarcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    final locations = await context.read<ApiClient>().listLocations();
    if (!mounted) return;
    setState(() {
      _locations = locations;
      _loadingLocations = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Force-resolve whatever's currently typed first -- tapping Save right
    // after typing a brand-new category would otherwise race the field's
    // own async create-category call.
    await _categoryFieldKey.currentState?.resolve();
    if (!mounted) return;
    final api = context.read<ApiClient>();
    try {
      await api.updateProduct(widget.product.id, {
        'name': _nameController.text,
        'category_id': _categoryId,
        'quantity_unit': _quantityUnit.isEmpty ? 'pcs' : _quantityUnit,
        'default_location_id': _selectedLocationId,
        'default_best_before_days': int.tryParse(_bestBeforeDaysController.text),
        'default_open_shelf_life_days': int.tryParse(_openShelfLifeDaysController.text),
        'low_stock_threshold': double.tryParse(_lowStockThresholdController.text),
        'target_stock_level': double.tryParse(_targetStockLevelController.text),
        'image_url': _imageUrl,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotSave('$e'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refreshFromOff() async {
    setState(() => _refreshingFromOff = true);
    final api = context.read<ApiClient>();
    try {
      final data = await api.refreshProductFromOff(widget.product.id);
      if (!mounted) return;
      final offCategory = data['category'] as String?;
      if (offCategory != null) {
        // Matches/creates the category the same way typing it in and
        // blurring would (#72/#73); updates _categoryId/_categoryName via
        // the field's own onChanged callback.
        _categoryFieldKey.currentState?.setText(offCategory);
        await _categoryFieldKey.currentState?.resolve();
        if (!mounted) return;
      }
      setState(() {
        _nameController.text = data['name'] as String? ?? _nameController.text;
        _imageUrl = data['image_url'] as String? ?? _imageUrl;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.fetchedFromOff)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotRefresh('$e'))));
      }
    } finally {
      if (mounted) setState(() => _refreshingFromOff = false);
    }
  }

  /// Uploads a camera/gallery photo (#210) as this product's image -- the
  /// only way to give a manually-added, barcode-less product a picture,
  /// since until now image_url was only ever set by pasting a URL or by the
  /// Open Food Facts lookup. Uploads immediately (unlike the other fields on
  /// this screen, which wait for Save) so the preview updates right away and
  /// a picked-but-never-saved photo isn't silently lost.
  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploadingImage = true);
    final api = context.read<ApiClient>();
    try {
      final bytes = await picked.readAsBytes();
      final updated = await api.uploadProductImage(
        widget.product.id,
        bytes: bytes,
        filename: picked.name,
      );
      if (!mounted) return;
      setState(() => _imageUrl = updated.imageUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotUploadImage('$e'))));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  /// Barcode-less products (bulk items, homemade jars) get a synthetic
  /// `VORRAT-<id>` code written to the normal barcode field via the
  /// existing PATCH endpoint (#105) -- id-derived, so it can never collide
  /// with another product's barcode, and every existing scan flow
  /// (add/open/consume/discard) picks it up unchanged since it's just
  /// another value in that column.
  Future<void> _generateQrLabel() async {
    setState(() => _generatingQrLabel = true);
    final api = context.read<ApiClient>();
    try {
      final updated = await api.updateProduct(widget.product.id, {
        'barcode': 'VORRAT-${widget.product.id}',
      });
      if (!mounted) return;
      setState(() => _barcode = updated.barcode);
      await _showQrLabelDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotSave('$e'))));
      }
    } finally {
      if (mounted) setState(() => _generatingQrLabel = false);
    }
  }

  Future<void> _showQrLabelDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final barcode = _barcode;
    if (barcode == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // White background regardless of theme -- a QR rendered in the
            // app's dark-mode colors would otherwise have too little
            // contrast for a camera to reliably scan it off a screen.
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: barcode, size: 240, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(widget.product.name, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.closeButton)),
        ],
      ),
    );
  }

  /// Adds whatever's currently typed in [_newBarcodeController] as an
  /// alternate/extra scannable code for this product (#208) -- e.g. a
  /// different pack size or a regional/reprinted barcode -- so scanning it
  /// later resolves to this product instead of offering to create a
  /// duplicate.
  Future<void> _addExtraBarcode() async {
    final code = _newBarcodeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _barcodeBusy = true);
    final api = context.read<ApiClient>();
    try {
      final updated = await api.addProductBarcode(widget.product.id, code);
      if (!mounted) return;
      setState(() {
        _extraBarcodes = updated.extraBarcodes;
        _newBarcodeController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotSave('$e'))));
      }
    } finally {
      if (mounted) setState(() => _barcodeBusy = false);
    }
  }

  Future<void> _removeExtraBarcode(String code) async {
    setState(() => _barcodeBusy = true);
    final api = context.read<ApiClient>();
    try {
      final updated = await api.removeProductBarcode(widget.product.id, code);
      if (!mounted) return;
      setState(() => _extraBarcodes = updated.extraBarcodes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.couldNotSave('$e'))));
      }
    } finally {
      if (mounted) setState(() => _barcodeBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProductTitle),
        actions: [
          IconButton(
            icon: _generatingQrLabel
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.qr_code),
            tooltip: _barcode == null ? l10n.generateQrLabelTooltip : l10n.showQrLabelTooltip,
            onPressed: _generatingQrLabel
                ? null
                : (_barcode == null ? _generateQrLabel : _showQrLabelDialog),
          ),
          if (_hasRealBarcode)
            IconButton(
              icon: _refreshingFromOff
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              tooltip: l10n.refreshFromOffTooltip,
              onPressed: _refreshingFromOff ? null : _refreshFromOff,
            ),
        ],
      ),
      body: _loadingLocations
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_imageUrl != null) ...[
                  Center(
                    child: Image.network(
                      context.read<ApiClient>().resolveImageUrl(_imageUrl!),
                      height: 120,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: _uploadingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_camera),
                        tooltip: l10n.takePhotoTooltip,
                        onPressed: _uploadingImage ? null : () => _pickImage(ImageSource.camera),
                      ),
                      IconButton(
                        icon: const Icon(Icons.photo_library),
                        tooltip: l10n.choosePhotoTooltip,
                        onPressed: _uploadingImage ? null : () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_barcode != null) ...[
                  Text(l10n.barcodeLabel(_barcode!)),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: l10n.nameLabel),
                ),
                const SizedBox(height: 12),
                Text(l10n.extraBarcodesLabel, style: Theme.of(context).textTheme.labelLarge),
                Text(l10n.extraBarcodesHint, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                if (_extraBarcodes.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final code in _extraBarcodes)
                        Chip(
                          label: Text(code),
                          onDeleted: _barcodeBusy ? null : () => _removeExtraBarcode(code),
                          deleteButtonTooltipMessage: l10n.removeBarcodeTooltip,
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newBarcodeController,
                        decoration: InputDecoration(labelText: l10n.addBarcodeTooltip),
                        onSubmitted: (_) {
                          if (!_barcodeBusy) _addExtraBarcode();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: l10n.addBarcodeTooltip,
                      onPressed: _barcodeBusy ? null : _addExtraBarcode,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CategoryField(
                  key: _categoryFieldKey,
                  categoryId: _categoryId,
                  categoryName: _categoryName,
                  label: l10n.categoryLabel,
                  onChanged: (category) => setState(() {
                    _categoryId = category?.id;
                    _categoryName = category?.name;
                  }),
                ),
                const SizedBox(height: 12),
                QuantityUnitField(
                  value: _quantityUnit,
                  label: l10n.quantityUnitLabel,
                  onChanged: (value) => setState(() => _quantityUnit = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _selectedLocationId,
                  decoration: InputDecoration(
                    labelText: l10n.defaultLocationLabel,
                  ),
                  items: [
                    DropdownMenuItem<int>(value: null, child: Text(l10n.noneLabel)),
                    for (final l in _locations) DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (value) => setState(() => _selectedLocationId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bestBeforeDaysController,
                  decoration: InputDecoration(
                    labelText: l10n.defaultBestBeforeDaysLabel,
                    hintText: l10n.defaultBestBeforeDaysHint,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _openShelfLifeDaysController,
                  decoration: InputDecoration(
                    labelText: l10n.openShelfLifeLabel,
                    hintText: l10n.openShelfLifeHint,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lowStockThresholdController,
                  decoration: InputDecoration(
                    labelText: l10n.lowStockThresholdLabel,
                    hintText: l10n.lowStockThresholdHint,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _targetStockLevelController,
                  decoration: InputDecoration(
                    labelText: l10n.targetStockLevelLabel,
                    hintText: l10n.targetStockLevelHint,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.saveButton),
                ),
              ],
            ),
    );
  }
}
