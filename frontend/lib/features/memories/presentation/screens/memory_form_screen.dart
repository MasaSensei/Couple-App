import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_widgets.dart';
import '../../data/models/memory_form_data.dart';
import '../../data/models/memory_model.dart';
import '../../providers/memory_providers.dart';
import '../../providers/memory_state.dart';

class MemoryFormScreen extends ConsumerStatefulWidget {
  const MemoryFormScreen({this.memory, this.initialData, super.key});

  final MemoryModel? memory;
  final MemoryFormData? initialData;

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
    final initialData = widget.initialData;

    _titleController = TextEditingController(
      text: memory?.title ?? initialData?.title ?? '',
    );

    _descriptionController = TextEditingController(
      text: memory?.description ?? initialData?.description ?? '',
    );

    _locationNameController = TextEditingController(
      text: memory?.locationName ?? initialData?.locationName ?? '',
    );

    _locationAddressController = TextEditingController(
      text: memory?.locationAddress ?? initialData?.locationAddress ?? '',
    );

    _memoryDate =
        memory?.memoryDate ?? initialData?.memoryDate ?? DateTime.now();
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

    return AppScaffold(
      title: widget.isEditing ? 'Edit memory' : 'New memory',
      padded: false,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              AppSpacing.xl,
            ),
            children: [
              Text(
                widget.isEditing
                    ? 'Keep this memory up to date'
                    : 'Save a little moment',
                style: context.tokens.handwriting,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'Give this memory a name',
                validator: _validateTitle,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDateField(),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descriptionController,
                label: 'The story (optional)',
                hint: 'What happened, what you felt',
                maxLines: 5,
                validator: _validateDescription,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _locationNameController,
                label: 'Place (optional)',
                hint: 'Where did this happen?',
                prefixIcon: Icons.place_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _locationAddressController,
                label: 'Address (optional)',
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'You can add photos after saving. They are encrypted on your phone before upload.',
                style: context.tokens.caption,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.status == MemoryStatus.error &&
                  state.errorMessage != null) ...[
                NoticeBanner(
                  tone: StatusTone.error,
                  message: state.errorMessage!,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                label: widget.isEditing ? 'Save changes' : 'Save memory',
                isLoading: isLoading,
                onPressed: isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Semantics(
      button: true,
      label:
          'Memory date, ${AppFormatters.dayMonthYear(_memoryDate)}. Tap to change.',
      excludeSemantics: true,
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(context.tokens.buttonRadius),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'When',
            prefixIcon: Icon(Icons.event_outlined),
            suffixIcon: Icon(Icons.chevron_right_rounded),
          ),
          child: Text(
            AppFormatters.dayMonthYear(_memoryDate),
            style: context.tokens.body,
          ),
        ),
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
      latitude: widget.memory?.latitude ?? widget.initialData?.latitude,
      longitude: widget.memory?.longitude ?? widget.initialData?.longitude,
      dateId: widget.memory?.dateId ?? widget.initialData?.dateId,
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
}
