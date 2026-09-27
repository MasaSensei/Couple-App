import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/memory_form_data.dart';
import '../../data/models/memory_model.dart';
import '../../providers/memory_providers.dart';
import '../../providers/memory_state.dart';

class MemoryFormScreen extends ConsumerStatefulWidget {
  const MemoryFormScreen({this.memory, super.key});

  final MemoryModel? memory;

  bool get isEditing => memory != null;

  @override
  ConsumerState<MemoryFormScreen> createState() => _MemoryFormScreenState();
}

class _MemoryFormScreenState extends ConsumerState<MemoryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationNameController;
  late final TextEditingController _locationAddressController;

  late DateTime _memoryDate;

  @override
  void initState() {
    super.initState();

    final memory = widget.memory;

    _titleController = TextEditingController(text: memory?.title ?? '');

    _descriptionController = TextEditingController(
      text: memory?.description ?? '',
    );

    _locationNameController = TextEditingController(
      text: memory?.locationName ?? '',
    );

    _locationAddressController = TextEditingController(
      text: memory?.locationAddress ?? '',
    );

    _memoryDate = memory?.memoryDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _locationAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memoryNotifierProvider);
    final isLoading = state.status == MemoryStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Memory' : 'New Memory'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _buildIntro(),
              const SizedBox(height: AppSpacing.xl),

              AppTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'Give this memory a name',
                validator: _validateTitle,
              ),

              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Tell the story behind this memory...',
                maxLines: 5,
                validator: _validateDescription,
              ),

              const SizedBox(height: AppSpacing.lg),

              _buildDateField(),

              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _locationNameController,
                label: 'Location',
                hint: 'Where did this happen?',
              ),

              const SizedBox(height: AppSpacing.lg),

              AppTextField(
                controller: _locationAddressController,
                label: 'Address',
                hint: 'Optional address',
                maxLines: 2,
              ),

              const SizedBox(height: AppSpacing.xl),

              if (state.status == MemoryStatus.error &&
                  state.errorMessage != null) ...[
                _buildError(state.errorMessage!),
                const SizedBox(height: AppSpacing.md),
              ],

              AppButton(
                label: widget.isEditing ? 'Save Changes' : 'Save Memory',
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isEditing
              ? 'Keep this memory up to date.'
              : 'Save a little moment you want to remember.',
          style: AppTextStyles.subtitle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Memory date',
          suffixIcon: const Icon(Icons.calendar_today_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(_formatDate(_memoryDate), style: AppTextStyles.body),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  String? _validateTitle(String? value) {
    final title = value?.trim() ?? '';

    if (title.isEmpty) {
      return 'Title is required.';
    }

    if (title.length > 150) {
      return 'Title must not exceed 150 characters.';
    }

    return null;
  }

  String? _validateDescription(String? value) {
    final description = value?.trim() ?? '';

    if (description.length > 5000) {
      return 'Description must not exceed 5000 characters.';
    }

    return null;
  }

  Future<void> _pickDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _memoryDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _memoryDate = selectedDate;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final data = MemoryFormData(
      title: _titleController.text.trim(),
      description: _nullableText(_descriptionController.text),
      memoryDate: _memoryDate,
      locationName: _nullableText(_locationNameController.text),
      locationAddress: _nullableText(_locationAddressController.text),
      latitude: widget.memory?.latitude,
      longitude: widget.memory?.longitude,
      dateId: widget.memory?.dateId,
    );

    final notifier = ref.read(memoryNotifierProvider.notifier);

    final MemoryModel? result;

    if (widget.isEditing) {
      result = await notifier.updateMemory(widget.memory!.id, data);
    } else {
      result = await notifier.createMemory(data);
    }

    if (!mounted) {
      return;
    }

    if (result != null) {
      Navigator.of(context).pop(result);
    }
  }

  String? _nullableText(String value) {
    final text = value.trim();

    return text.isEmpty ? null : text;
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
