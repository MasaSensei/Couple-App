import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../data/models/date_model.dart';
import '../providers/date_providers.dart';

class DateFormScreen extends ConsumerStatefulWidget {
  const DateFormScreen({super.key, this.date});

  final DateModel? date;

  bool get isEditing => date != null;

  @override
  ConsumerState<DateFormScreen> createState() => _DateFormScreenState();
}

class _DateFormScreenState extends ConsumerState<DateFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  DateTime? _scheduledAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final date = widget.date;

    _titleController = TextEditingController(text: date?.title ?? '');

    _descriptionController = TextEditingController(
      text: date?.description ?? '',
    );

    _locationController = TextEditingController(text: date?.location ?? '');

    _scheduledAt = date?.scheduledAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();

    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final initialDate = _scheduledAt ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledAt != null
          ? TimeOfDay.fromDateTime(_scheduledAt!)
          : TimeOfDay.now(),
    );

    if (pickedTime == null) {
      return;
    }

    setState(() {
      _scheduledAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    if (title.isEmpty) {
      _showMessage('Please enter a title.');
      return;
    }

    if (_scheduledAt == null) {
      _showMessage('Please choose a date and time.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final notifier = ref.read(dateNotifierProvider.notifier);

    final result = widget.isEditing
        ? await notifier.updateDate(
            dateId: widget.date!.id,
            title: title,
            description: description.isEmpty ? null : description,
            location: location.isEmpty ? null : location,
            scheduledAt: _scheduledAt!,
          )
        : await notifier.createDate(
            title: title,
            description: description.isEmpty ? null : description,
            location: location.isEmpty ? null : location,
            scheduledAt: _scheduledAt!,
          );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (result != null) {
      Navigator.of(context).pop(result);
      return;
    }

    final error = ref.read(dateNotifierProvider).errorMessage;

    _showMessage(error ?? 'Unable to save date.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppScaffold(
      title: widget.isEditing ? 'Edit date' : 'Plan a date',
      padded: false,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          children: [
            Text(
              widget.isEditing ? 'Update your plan' : 'Plan something special',
              style: t.handwriting,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _titleController,
              label: 'Title',
              hint: 'Dinner, movie, a weekend away',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildDateTimePicker(),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _locationController,
              label: 'Place (optional)',
              hint: 'Where will you go?',
              prefixIcon: Icons.place_outlined,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _descriptionController,
              label: 'Notes (optional)',
              hint: 'Anything to remember or bring',
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: widget.isEditing ? 'Save changes' : 'Plan this date',
              onPressed: _isSaving ? null : _save,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    final t = context.tokens;
    final at = _scheduledAt;
    return JournalCard(
      onTap: _isSaving ? null : _pickDateTime,
      semanticLabel: at == null
          ? 'Choose date and time'
          : 'Date and time: ${AppFormatters.full(at)}. Tap to change.',
      child: Row(
        children: [
          if (at != null)
            DateBadge(date: at)
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: t.surfaceMuted,
                borderRadius: BorderRadius.circular(t.cardRadius * 0.6),
              ),
              child: Icon(Icons.event_outlined, color: t.primary),
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('When', style: t.caption),
                const SizedBox(height: 2),
                Text(
                  at == null ? 'Choose date and time' : AppFormatters.full(at),
                  style: t.heading.copyWith(
                    color: at == null ? t.primary : null,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.textSecondary),
        ],
      ),
    );
  }
}
