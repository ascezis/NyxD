import 'package:flutter/material.dart';
import 'package:nyxd/app/theme/theme_controller.dart';

class ThemeSettingsDialog extends StatefulWidget {
  const ThemeSettingsDialog({super.key, required this.controller});

  final ThemeController controller;

  @override
  State<ThemeSettingsDialog> createState() => _ThemeSettingsDialogState();
}

class _ThemeSettingsDialogState extends State<ThemeSettingsDialog> {
  String _formatMinutes(BuildContext context, int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);
  }

  Future<void> _pickTime({required bool darkFrom}) async {
    final controller = widget.controller;
    final current = darkFrom
        ? controller.darkFromMinutes
        : controller.lightFromMinutes;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (selected == null) return;
    final minutes = selected.hour * 60 + selected.minute;
    await controller.setSchedule(
      darkFrom: darkFrom ? minutes : controller.darkFromMinutes,
      lightFrom: darkFrom ? controller.lightFromMinutes : minutes,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AlertDialog(
      title: const Text('Настройки'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Оформление', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<ThemePreference>(
              segments: const [
                ButtonSegment(
                  value: ThemePreference.light,
                  label: Text('Светлая'),
                ),
                ButtonSegment(
                  value: ThemePreference.dark,
                  label: Text('Тёмная'),
                ),
                ButtonSegment(
                  value: ThemePreference.scheduled,
                  label: Text('Авто'),
                ),
              ],
              selected: {controller.preference},
              onSelectionChanged: (selection) {
                controller.setPreference(selection.first);
                setState(() {});
              },
            ),
            if (controller.preference == ThemePreference.scheduled) ...[
              const SizedBox(height: 20),
              const Text('Тёмная тема включается по расписанию:'),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Включить тёмную'),
                trailing: Text(
                  _formatMinutes(context, controller.darkFromMinutes),
                ),
                onTap: () => _pickTime(darkFrom: true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Вернуть светлую'),
                trailing: Text(
                  _formatMinutes(context, controller.lightFromMinutes),
                ),
                onTap: () => _pickTime(darkFrom: false),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Безопасность',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Блокировать без активности через: '
              '${controller.inactivityTimeoutSeconds >= 60 ? '${controller.inactivityTimeoutSeconds ~/ 60} мин. ${controller.inactivityTimeoutSeconds % 60 > 0 ? '${controller.inactivityTimeoutSeconds % 60} сек.' : ''}'.trim() : '${controller.inactivityTimeoutSeconds} сек.'}',
            ),
            Slider(
              value: controller.inactivityTimeoutSeconds.toDouble(),
              min: 30,
              max: 900,
              divisions: 29,
              label: controller.inactivityTimeoutSeconds >= 60
                  ? '${controller.inactivityTimeoutSeconds ~/ 60} мин.'
                  : '${controller.inactivityTimeoutSeconds} сек.',
              onChanged: (value) {
                controller.setInactivityTimeout(value.round());
                setState(() {});
              },
            ),
            const Text('Диапазон: от 30 секунд до 15 минут.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}
