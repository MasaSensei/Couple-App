import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Date' : 'Plan a Date'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEditing
                    ? 'Update your plan ♡'
                    : 'Plan something special ♡',
                style: AppTextStyles.title,
              ),

              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'Dinner, movie, trip...',
              ),

              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Add some details...',
              ),

              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _locationController,
                label: 'Location',
                hint: 'Where will you go?',
              ),

              const SizedBox(height: AppSpacing.lg),

              _buildDateTimePicker(),

              const SizedBox(height: AppSpacing.xl),

              AppButton(
                label: widget.isEditing ? 'Save changes' : 'Create date',
                onPressed: _isSaving ? null : _save,
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date & Time', style: AppTextStyles.subtitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _scheduledAt == null
                        ? 'Not selected'
                        : _formatDateTime(_scheduledAt!),
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ),

            TextButton(
              onPressed: _isSaving ? null : _pickDateTime,
              child: const Text('Choose'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');

    final month = localDate.month.toString().padLeft(2, '0');

    final year = localDate.year;

    final hour = localDate.hour.toString().padLeft(2, '0');

    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }
}
