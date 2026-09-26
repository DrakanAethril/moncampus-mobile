import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/equipment.dart';
import '../services/auth_service.dart';
import '../services/equipment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/sheet_picker.dart';

/// « Matériel » - recording an inventory movement with the piece in hand (moncampus Gestion >
/// Matériel).
///
/// Two ways in, as on the web: the code on a piece's label, typed as it reads (`ca 142 0` finds
/// `CA-0142-0`), or a type picked from the list - the only way for cables and other things counted
/// in quantity, and the way to record a delivery.
///
/// Orders, the annual report, the count and the settings stay on the web: the phone is for what
/// happens in a corridor.
class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key, this.service});

  /// Injected by tests; a fresh client otherwise.
  final EquipmentService? service;

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  late final EquipmentService _service = widget.service ?? EquipmentService();
  final _codeController = TextEditingController();

  EquipmentLookup? _lookup;
  String? _lookupError;
  bool _searching = false;

  List<EquipmentType>? _types;
  String? _typesError;
  List<EquipmentRoom>? _rooms;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthService>().token;

  Future<void> _loadTypes() async {
    final token = _token;
    if (token == null) return;

    try {
      final types = await _service.types(token);
      if (!mounted) return;
      setState(() {
        _types = types;
        _typesError = null;
      });
    } on EquipmentException catch (e) {
      if (!mounted) return;
      setState(() => _typesError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _typesError = 'Impossible de charger le matériel.');
    }
  }

  Future<void> _search() async {
    final token = _token;
    final code = _codeController.text.trim();
    if (token == null || code.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _lookupError = null;
    });

    try {
      final lookup = await _service.lookup(token, code);
      if (!mounted) return;
      setState(() => _lookup = lookup);
    } on EquipmentException catch (e) {
      if (!mounted) return;
      setState(() => _lookupError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _lookupError = 'Impossible de chercher ce code.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<List<EquipmentRoom>> _loadRooms() async {
    final cached = _rooms;
    if (cached != null) return cached;

    final token = _token;
    if (token == null) return const [];

    try {
      final rooms = await _service.rooms(token);
      _rooms = rooms;
      return rooms;
    } catch (_) {
      // The room is optional: without the list, the gesture is simply recorded without one.
      return const [];
    }
  }

  Future<void> _onItemAction(EquipmentItem item, String action) async {
    final movement = await _askMovement(action: action, title: '${item.code} · ${EquipmentAction.label(action)}');
    final token = _token;
    if (movement == null || token == null) return;

    try {
      final updated = await _service.moveItem(token, item.id, movement);
      if (!mounted) return;
      _replaceItem(updated);
      _toast('${updated.code} : ${updated.statusLabel}.');
      _loadTypes();
    } on EquipmentException catch (e) {
      _toast(e.message, error: true);
    } catch (_) {
      _toast('Le mouvement n’a pas pu être enregistré.', error: true);
    }
  }

  Future<void> _onType(EquipmentType type) async {
    final actions = type.actions;
    final action = actions.length == 1
        ? actions.first
        : await showSheetPicker(context, labels: actions.map(EquipmentAction.label).toList(), selectedIndex: -1)
            .then((index) => index == null ? null : actions[index]);
    if (action == null || !mounted) return;

    final movement = await _askMovement(action: action, title: '${type.name} · ${EquipmentAction.label(action)}', forType: true);
    final token = _token;
    if (movement == null || token == null) return;

    try {
      final result = await _service.moveType(token, type.id, movement);
      if (!mounted) return;
      setState(() {
        _types = [for (final t in _types ?? const <EquipmentType>[]) t.id == result.type.id ? result.type : t];
      });

      if (result.createdCodes.isNotEmpty) {
        await _showCreatedCodes(result.createdCodes);
      } else {
        _toast('${result.type.name} : ${result.type.available} disponible(s), ${result.type.inUse} utilisé(s).');
      }
    } on EquipmentException catch (e) {
      _toast(e.message, error: true);
    } catch (_) {
      _toast('Le mouvement n’a pas pu être enregistré.', error: true);
    }
  }

  void _replaceItem(EquipmentItem updated) {
    final lookup = _lookup;
    if (lookup == null) return;

    setState(() {
      _lookup = EquipmentLookup(
        items: [for (final i in lookup.items) i.id == updated.id ? updated : i],
        suggestions: [for (final i in lookup.suggestions) i.id == updated.id ? updated : i],
        wrongCheckDigit: lookup.wrongCheckDigit,
      );
    });
  }

  Future<EquipmentMovement?> _askMovement({required String action, required String title, bool forType = false}) async {
    final rooms = EquipmentAction.takesRoom(action) ? await _loadRooms() : const <EquipmentRoom>[];
    if (!mounted) return null;

    // A piece put back in the reserve, found or repaired needs nothing more than the tap itself.
    final needsForm = forType || EquipmentAction.takesRoom(action);
    if (!needsForm) return EquipmentMovement(action: action);

    return showModalBottomSheet<EquipmentMovement>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (_) => _MovementSheet(title: title, action: action, forType: forType, rooms: rooms),
    );
  }

  Future<void> _showCreatedCodes(List<String> codes) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('À étiqueter', style: AppFont.spectral(size: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Les codes à taper sur l’étiqueteuse, dans l’ordre :',
                style: AppFont.sans(size: 13, color: AppColors.muted)),
            const SizedBox(height: 10),
            for (final code in codes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(code,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer'))],
      ),
    );
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.lateInk : AppColors.navy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            AppHeader(
              user: context.watch<AuthService>().currentUser,
              child: AppHeaderTitleRow(title: 'Matériel', onBack: () => Navigator.of(context).pop()),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadTypes,
                color: AppColors.brand,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle('Un exemplaire étiqueté'),
                    _codeCard(),
                    ..._lookupResults(),
                    const SizedBox(height: 22),
                    _sectionTitle('Tout le matériel'),
                    ..._typeRows(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label.toUpperCase(),
            style: AppFont.sans(size: 11.5, weight: FontWeight.w700, color: AppColors.muted, letterSpacing: .6)),
      );

  Widget _codeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('equipment-code'),
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 17, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'CA-0142-0',
                labelText: 'Code de l’étiquette',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            key: const Key('equipment-search'),
            onPressed: _searching ? null : _search,
            child: _searching
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Chercher'),
          ),
        ],
      ),
    );
  }

  List<Widget> _lookupResults() {
    final error = _lookupError;
    if (error != null) return [_notice(error, error: true)];

    final lookup = _lookup;
    if (lookup == null) return const [];

    return [
      // A wrong check digit is said, never corrected: the piece it nearly names is only offered.
      if (lookup.wrongCheckDigit)
        _notice('Le dernier chiffre ne correspond pas au code : l’étiquette ou la saisie contient une faute. '
            'Vérifiez l’étiquette avant de choisir l’exemplaire proposé.'),
      if (lookup.items.isEmpty && lookup.suggestions.isEmpty) _notice('Aucun exemplaire ne porte ce code.'),
      for (final item in [...lookup.items, ...lookup.suggestions])
        _ItemCard(
          item: item,
          suggestion: lookup.suggestions.contains(item),
          onAction: (action) => _onItemAction(item, action),
        ),
    ];
  }

  List<Widget> _typeRows() {
    final error = _typesError;
    if (error != null) return [_notice(error, error: true)];

    final types = _types;
    if (types == null) return const [Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))];
    if (types.isEmpty) return [_notice('Aucun matériel pour l’instant.')];

    return [for (final type in types) _TypeRow(type: type, onTap: () => _onType(type))];
  }

  Widget _notice(String message, {bool error = false}) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error ? AppColors.lateBg : AppColors.goldSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: error ? AppColors.lateBorder : AppColors.chipGoldBg),
        ),
        child: Text(message, style: AppFont.sans(size: 13, color: error ? AppColors.lateInk : AppColors.goldInk)),
      );
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    );

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.suggestion, required this.onAction});

  final EquipmentItem item;
  final bool suggestion;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.code,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              _StatusChip(status: item.status, label: item.statusLabel),
              if (suggestion) ...[
                const SizedBox(width: 6),
                const _Chip(label: 'Suggestion', background: AppColors.chipGoldBg, ink: AppColors.chipGoldInk),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [item.typeName, if (item.room != null) item.room!].join(' · '),
            style: AppFont.sans(size: 13, color: AppColors.muted),
          ),
          if (item.actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in item.actions)
                  OutlinedButton(
                    key: Key('equipment-action-$action'),
                    onPressed: () => onAction(action),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EquipmentAction.isIncident(action) ? AppColors.lateInk : AppColors.brandStrong,
                    ),
                    child: Text(EquipmentAction.label(action)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.type, required this.onTap});

  final EquipmentType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, ink) = switch (type.level) {
      'red' => (AppColors.redBg, AppColors.redTx),
      'gold' => (AppColors.goldBg, AppColors.goldTx),
      _ => (AppColors.greenBg, AppColors.greenTx),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: _cardDecoration(),
      child: ListTile(
        onTap: onTap,
        title: Text(type.name, style: AppFont.sans(size: 14.5, weight: FontWeight.w600)),
        subtitle: Text(
          [
            if (type.category != null) type.category!,
            type.unitTracked ? 'à l’unité' : 'en quantité',
            '${type.inUse} utilisé(s)',
          ].join(' · '),
          style: AppFont.sans(size: 12.5, color: AppColors.muted),
        ),
        trailing: _Chip(label: '${type.available}', background: background, ink: ink),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (background, ink) = switch (status) {
      'available' => (AppColors.greenBg, AppColors.greenTx),
      'in_use' => (AppColors.blueBg, AppColors.blueTx),
      'missing' => (AppColors.redBg, AppColors.redTx),
      'out_of_order' => (AppColors.goldBg, AppColors.goldTx),
      _ => (AppColors.neutralBg, AppColors.muted),
    };

    return _Chip(label: label, background: background, ink: ink);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.background, required this.ink});

  final String label;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppFont.sans(size: 11.5, weight: FontWeight.w700, color: ink)),
    );
  }
}

/// What a gesture needs besides its name: how many (on a type), where the lost or broken pieces
/// were taken from (on a quantity type), why (on an incident), the room (optional, always) and a
/// note. Returns null when dismissed.
class _MovementSheet extends StatefulWidget {
  const _MovementSheet({required this.title, required this.action, required this.forType, required this.rooms});

  final String title;
  final String action;
  final bool forType;
  final List<EquipmentRoom> rooms;

  @override
  State<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends State<_MovementSheet> {
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  String _origin = 'in_use';
  String? _cause;
  int? _roomId;
  String? _error;

  bool get _isIncident => EquipmentAction.isIncident(widget.action);

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = widget.forType ? int.tryParse(_quantity.text.trim()) : null;

    if (widget.forType && (quantity == null || quantity < 1)) {
      setState(() => _error = 'Indiquez une quantité.');
      return;
    }

    if (_isIncident && _cause == null) {
      setState(() => _error = 'Choisissez une cause.');
      return;
    }

    Navigator.of(context).pop(EquipmentMovement(
      action: widget.action,
      quantity: quantity,
      origin: widget.forType && _isIncident ? _origin : null,
      cause: _cause,
      roomId: _roomId,
      note: _note.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: EdgeInsets.fromLTRB(18, 14, 18, 16 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: AppFont.spectral(size: 18)),
              const SizedBox(height: 14),
              if (widget.forType) ...[
                TextField(
                  key: const Key('equipment-quantity'),
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantité', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
              ],
              if (widget.forType && _isIncident) ...[
                Text('Pris sur', style: AppFont.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'in_use', label: Text('En service')),
                    ButtonSegment(value: 'available', label: Text('La réserve')),
                  ],
                  selected: {_origin},
                  onSelectionChanged: (value) => setState(() => _origin = value.first),
                ),
                const SizedBox(height: 12),
              ],
              if (_isIncident) ...[
                Text('Cause', style: AppFont.sans(size: 12.5, weight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in EquipmentCause.values.entries)
                      ChoiceChip(
                        key: Key('equipment-cause-${entry.key}'),
                        label: Text(entry.value),
                        selected: _cause == entry.key,
                        onSelected: (_) => setState(() => _cause = entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (EquipmentAction.takesRoom(widget.action) && widget.rooms.isNotEmpty) ...[
                DropdownButtonFormField<int?>(
                  value: _roomId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Salle', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Aucune salle précisée')),
                    for (final room in widget.rooms) DropdownMenuItem<int?>(value: room.id, child: Text(room.name)),
                  ],
                  onChanged: (value) => setState(() => _roomId = value),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (facultative)', border: OutlineInputBorder(), isDense: true),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: AppFont.sans(size: 13, color: AppColors.lateInk)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('equipment-submit'),
                  onPressed: _submit,
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
