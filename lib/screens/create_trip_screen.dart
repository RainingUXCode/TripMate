import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/trips_service.dart';
import '../widgets/tripmate_back_button.dart';
import '../widgets/user_avatar.dart';

String? validateTripDateRange(DateTime? startDate, DateTime? endDate) {
  if (startDate == null || endDate == null) return null;
  if (endDate.isBefore(startDate)) {
    return 'A data de término não pode ser anterior à data de início.';
  }
  return null;
}

class CreateTripScreen extends StatefulWidget {
  final TripsService? tripsService;
  final FriendsService? friendsService;
  final AuthService? authService;
  final Future<XFile?> Function()? selectCoverImage;

  const CreateTripScreen({
    super.key,
    this.tripsService,
    this.friendsService,
    this.authService,
    this.selectCoverImage,
  });

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  static const _borderColor = Color(0xFFE4E3EE);
  static const _inputColor = Color(0xFFF1F1F8);
  static const _lavender = Color(0xFFEEEBFF);
  static const _imageLimit = 8 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  late final TripsService _tripsService = widget.tripsService ?? TripsService();
  late final bool _ownsTripsService = widget.tripsService == null;
  late final FriendsService _friendsService =
      widget.friendsService ?? FriendsService();
  late final AuthService _authService = widget.authService ?? AuthService();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _startDateError;
  String? _endDateError;
  String? _submitError;
  String? _coverError;
  String? _friendsError;
  XFile? _coverImage;
  Uint8List? _coverPreviewBytes;
  List<Map<String, dynamic>> _friends = [];
  final Set<int> _selectedFriendIds = {};
  bool _loadingFriends = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    if (_ownsTripsService) _tripsService.close();
    super.dispose();
  }

  TextStyle _style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppTheme.ink,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  Future<void> _loadFriends() async {
    try {
      final user = await _authService.getSavedUser();
      final currentUserId = _toInt(user?['id']);
      if (currentUserId == null) {
        throw const TripsServiceException(
          'Não foi possível identificar sua conta para carregar os amigos.',
        );
      }

      final relationships = await _friendsService.getFriends();
      final friendsById = <int, Map<String, dynamic>>{};
      for (final relationship in relationships) {
        if (relationship['status']?.toString() != 'accepted') continue;
        final sender = _map(relationship['sender']);
        final receiver = _map(relationship['receiver']);
        final senderId = _toInt(sender['id']);
        final receiverId = _toInt(receiver['id']);
        final friend = senderId == currentUserId
            ? receiver
            : receiverId == currentUserId
            ? sender
            : null;
        final friendId = _toInt(friend?['id']);
        if (friend == null || friendId == null || friendId == currentUserId) {
          continue;
        }
        friendsById[friendId] = {
          'id': friendId,
          'name': friend['name']?.toString().trim().isNotEmpty == true
              ? friend['name'].toString().trim()
              : 'Viajante',
          'avatar_url': friend['avatar_url']?.toString(),
        };
      }

      if (!mounted) return;
      setState(() {
        _friends = friendsById.values.toList(growable: false);
        _friendsError = null;
        _loadingFriends = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friendsError = 'Não foi possível carregar os amigos agora.';
        _loadingFriends = false;
      });
    }
  }

  Future<void> _retryLoadFriends() async {
    setState(() {
      _loadingFriends = true;
      _friendsError = null;
    });
    await _loadFriends();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> _pickCoverImage() async {
    if (_saving) return;
    try {
      final selected = widget.selectCoverImage != null
          ? await widget.selectCoverImage!()
          : await _imagePicker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 8192,
              maxHeight: 8192,
            );
      if (selected == null || !mounted) return;

      final extension = selected.name.split('.').last.toLowerCase();
      if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        setState(() => _coverError = 'Escolha uma imagem JPG, PNG ou WebP.');
        return;
      }

      final imageBytes = await selected.readAsBytes();
      if (imageBytes.length > _imageLimit) {
        setState(() => _coverError = 'A foto deve ter no máximo 8 MB.');
        return;
      }

      setState(() {
        _coverImage = selected;
        _coverPreviewBytes = imageBytes;
        _coverError = null;
        _submitError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coverError = 'Não foi possível abrir essa imagem. Escolha outra foto.';
      });
    }
  }

  void _removeCoverImage() {
    setState(() {
      _coverImage = null;
      _coverPreviewBytes = null;
      _coverError = null;
    });
  }

  void _toggleFriend(int friendId) {
    if (_saving) return;
    setState(() {
      if (!_selectedFriendIds.add(friendId)) {
        _selectedFriendIds.remove(friendId);
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initialDate = isStart
        ? (_startDate ?? today)
        : (_endDate ?? _startDate ?? today);
    final firstDate = isStart ? DateTime(2000) : (_startDate ?? DateTime(2000));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      helpText: isStart
          ? 'Selecione a data de início'
          : 'Selecione a data de término',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (selectedDate == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = DateUtils.dateOnly(selectedDate);
        _startDateError = null;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDateError =
              'A data de término não pode ser anterior à data de início.';
        } else {
          _endDateError = null;
        }
      } else {
        _endDate = DateUtils.dateOnly(selectedDate);
        _endDateError = null;
      }
      _submitError = null;
    });
  }

  Future<void> _submit() async {
    if (_saving) return;
    final formIsValid = _formKey.currentState?.validate() ?? false;
    final dateError = validateTripDateRange(_startDate, _endDate);

    setState(() {
      _startDateError = _startDate == null
          ? 'Selecione a data de início.'
          : null;
      _endDateError = _endDate == null
          ? 'Selecione a data de término.'
          : dateError;
      _submitError = null;
    });

    if (!formIsValid ||
        _startDate == null ||
        _endDate == null ||
        dateError != null) {
      return;
    }

    setState(() => _saving = true);
    try {
      await _tripsService.createTrip(
        name: _nameController.text,
        destination: _destinationController.text,
        startDate: _startDate!,
        endDate: _endDate!,
        description: _descriptionController.text,
        coverImage: _coverImage,
        inviteeIds: _selectedFriendIds.toList(growable: false),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitError = error is TripsServiceException
            ? error.message
            : 'Não foi possível criar a viagem. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Selecionar data';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            const Divider(height: 1, color: _borderColor),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOVA VIAGEM EM GRUPO',
                        style: _style(
                          12,
                          weight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Informações principais',
                        style: _style(23, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Você poderá registrar os gastos depois de criar a viagem.',
                        style: _style(14, color: const Color(0xFF676874)),
                      ),
                      const SizedBox(height: 24),
                      _fieldLabel('Nome da viagem'),
                      const SizedBox(height: 8),
                      _textField(
                        key: const ValueKey('trip-name-field'),
                        controller: _nameController,
                        hint: 'Ex.: Férias em Lisboa',
                        leadingIcon: Icons.sell_outlined,
                        maxLength: 150,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Informe o nome da viagem.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Destino'),
                      const SizedBox(height: 8),
                      _textField(
                        key: const ValueKey('trip-destination-field'),
                        controller: _destinationController,
                        hint: 'Cidade, país',
                        leadingIcon: Icons.location_on_outlined,
                        maxLength: 200,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Informe o destino.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Datas da viagem'),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _dateField(
                              key: const ValueKey('trip-start-date'),
                              label: 'Início',
                              date: _startDate,
                              error: _startDateError,
                              onTap: () => _pickDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dateField(
                              key: const ValueKey('trip-end-date'),
                              label: 'Término',
                              date: _endDate,
                              error: _endDateError,
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Descrição (opcional)'),
                      const SizedBox(height: 8),
                      _textField(
                        key: const ValueKey('trip-description-field'),
                        controller: _descriptionController,
                        hint: 'Adicione detalhes para o grupo',
                        leadingIcon: Icons.notes_rounded,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 22),
                      _sectionLabel('Foto da viagem'),
                      const SizedBox(height: 8),
                      _coverPicker(),
                      const SizedBox(height: 22),
                      _sectionLabel('Participantes'),
                      const SizedBox(height: 4),
                      Text(
                        'Selecione amigos já adicionados',
                        style: _style(13, color: const Color(0xFF676874)),
                      ),
                      const SizedBox(height: 12),
                      _friendsPicker(),
                      const SizedBox(height: 14),
                      _participantsSummary(),
                      if (_submitError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _submitError!,
                            style: _style(13, color: const Color(0xFFC74D62)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _createButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('Nova viagem', style: _style(16, weight: FontWeight.w700)),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: SizedBox(
                width: 48,
                height: 48,
                child: IgnorePointer(
                  ignoring: _saving,
                  child: Center(
                    child: TripMateBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) =>
      Text(label, style: _style(15, weight: FontWeight.w700));

  Widget _sectionLabel(String label) =>
      Text(label, style: _style(16, weight: FontWeight.w700));

  Widget _textField({
    required Key key,
    required TextEditingController controller,
    required String hint,
    IconData? leadingIcon,
    String? Function(String?)? validator,
    int? maxLength,
    int maxLines = 1,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      validator: validator,
      maxLength: maxLength,
      maxLines: maxLines,
      buildCounter: maxLength == null
          ? null
          : (
              context, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => Text(
              '$currentLength/${maxLength ?? ''}',
              textAlign: TextAlign.right,
              style: _style(11, color: const Color(0xFF676874)),
            ),
      textCapitalization: TextCapitalization.sentences,
      style: _style(15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _style(14, color: const Color(0xFF676874)),
        filled: true,
        fillColor: _inputColor,
        prefixIcon: leadingIcon == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(leadingIcon, size: 19, color: AppTheme.primary),
              ),
        prefixIconConstraints: leadingIcon == null
            ? null
            : const BoxConstraints(minWidth: 48, minHeight: 48),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC74D62)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFC74D62), width: 1.5),
        ),
      ),
    );
  }

  Widget _dateField({
    required Key key,
    required String label,
    required DateTime? date,
    required String? error,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _style(13, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Material(
          color: _inputColor,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: key,
            onTap: _saving ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: error == null ? _borderColor : const Color(0xFFC74D62),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDate(date),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _style(
                        13,
                        color: date == null
                            ? const Color(0xFF676874)
                            : AppTheme.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error, style: _style(11, color: const Color(0xFFC74D62))),
        ],
      ],
    );
  }

  Widget _coverPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_coverImage == null)
          Material(
            color: _inputColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const ValueKey('select-trip-cover'),
              onTap: _saving ? null : _pickCoverImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 124,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 28,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Escolher foto',
                      style: _style(14, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'JPG, PNG ou WebP · até 8 MB',
                      style: _style(12, color: const Color(0xFF676874)),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _coverPreviewBytes!,
                    key: const ValueKey('trip-cover-preview'),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: _inputColor,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 32),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _imageAction(
                      icon: Icons.refresh_rounded,
                      label: 'Substituir',
                      onTap: _pickCoverImage,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: IconButton(
                        key: const ValueKey('remove-trip-cover'),
                        tooltip: 'Remover foto',
                        onPressed: _saving ? null : _removeCoverImage,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_coverError != null) ...[
          const SizedBox(height: 6),
          Text(_coverError!, style: _style(12, color: const Color(0xFFC74D62))),
        ],
        const SizedBox(height: 5),
        Text(
          'A imagem pode ter até 8192 × 8192 pixels.',
          style: _style(12, color: const Color(0xFF676874)),
        ),
      ],
    );
  }

  Widget _imageAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _saving ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppTheme.primary),
              const SizedBox(width: 5),
              Text(label, style: _style(12, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _friendsPicker() {
    if (_loadingFriends) {
      return const SizedBox(
        height: 92,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_friends.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _inputColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: _friendsError == null
            ? Text(
                'Você ainda não tem amigos confirmados para convidar.',
                style: _style(13, color: const Color(0xFF676874)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _friendsError!,
                    style: _style(13, color: const Color(0xFF676874)),
                  ),
                  TextButton(
                    onPressed: _retryLoadFriends,
                    child: Text(
                      'Tentar novamente',
                      style: _style(
                        13,
                        weight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
      );
    }

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _friends.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final friendId = friend['id'] as int;
          final selected = _selectedFriendIds.contains(friendId);
          final name = friend['name']?.toString() ?? 'Viajante';
          final firstName = name.trim().split(RegExp(r'\s+')).first;
          return InkWell(
            key: ValueKey('trip-friend-$friendId'),
            onTap: _saving ? null : () => _toggleFriend(friendId),
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppTheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Opacity(
                          opacity: selected ? 1 : 0.66,
                          child: UserAvatar(
                            name: name,
                            userId: friendId.toString(),
                            imageUrl: friend['avatar_url']?.toString(),
                            size: 52,
                          ),
                        ),
                      ),
                      if (selected)
                        const Positioned(
                          right: -1,
                          bottom: -1,
                          child: Icon(
                            Icons.check_circle,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _style(
                      12,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppTheme.ink : const Color(0xFF676874),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _participantsSummary() {
    final count = _selectedFriendIds.length;
    final inviteSummary = count == 0
        ? 'Nenhum amigo selecionado'
        : count == 1
        ? '1 amigo será convidado'
        : '$count amigos serão convidados';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _lavender,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.group_outlined, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inviteSummary, style: _style(14, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Você já faz parte da viagem',
                  style: _style(12, color: const Color(0xFF555168)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _createButton() {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _saving ? null : AppTheme.primaryGradient,
        color: _saving ? AppTheme.primary.withValues(alpha: 0.65) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('create-trip-submit'),
          onTap: _saving ? null : _submit,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_saving) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                _saving ? 'Salvando...' : 'Criar viagem',
                style: _style(15, weight: FontWeight.w700, color: Colors.white),
              ),
              if (!_saving) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
