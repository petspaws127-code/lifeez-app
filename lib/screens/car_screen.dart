import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../models/vehicle.dart';
import '../models/maintenance_item.dart';

class CarScreen extends StatelessWidget {
  static const route = '/car';
  const CarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Car')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (app.vehicles.isEmpty)
            const EmptyState(
                message:
                    'Add your vehicle to track mileage and maintenance.',
                icon: Icons.directions_car_outlined),
          ...app.vehicles.map((v) {
            final items = app.maintenanceItems
                .where((m) => m.vehicleId == v.id)
                .toList();
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: AppTheme.card3D(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CategoryIcon(
                          category: 'car', size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(v.name,
                                style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w700)),
                            Text(
                                '${v.mileage.toStringAsFixed(0)} miles',
                                style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    color: AppColors.muted)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            _updateMileage(context, v),
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    ...items.map((m) => ListTile(
                          dense: true,
                          contentPadding:
                              EdgeInsets.zero,
                          leading: Icon(
                            m.isDone
                                ? Icons.check_circle
                                : Icons.build_outlined,
                            color: m.isDone
                                ? AppColors.whatsappDark
                                : AppColors.gold,
                          ),
                          title: Text(m.title,
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  decoration: m.isDone
                                      ? TextDecoration
                                          .lineThrough
                                      : null)),
                          subtitle: m.dueDate == null
                              ? null
                              : Text(
                                  'Due ${DateFormat('MMM d, yyyy').format(m.dueDate!)}',
                                  style:
                                      GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          color:
                                              AppColors.muted)),
                          trailing: IconButton(
                            icon: const Icon(
                                Icons.check_circle_outline),
                            onPressed: () => app
                                .toggleMaintenance(m.id),
                          ),
                        )),
                  ],
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_rounded,
                        size: 18),
                    label: const Text('Add maintenance'),
                    onPressed: () =>
                        _addMaintenance(context, v.id),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          SuggestionCard(
            title: 'Car suggestions',
            suggestions: [
              if (app.vehicles.isEmpty)
                'Add your car to get oil-change and service reminders.',
              'Log mileage monthly — it keeps resale value estimates honest.',
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addVehicle(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _addVehicle(BuildContext context) {
    final name = TextEditingController();
    final miles = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add vehicle',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppTextField(
                controller: name, label: 'Name (e.g. Honda Civic)'),
            AppTextField(
                controller: miles,
                label: 'Current mileage',
                keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Save vehicle',
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final uid =
                    context.read<AppState>().profile?.id ?? '';
                await context.read<AppState>().addVehicle(
                      Vehicle(
                        id: const Uuid().v4(),
                        userId: uid,
                        name: name.text.trim(),
                        mileage:
                            double.tryParse(miles.text.trim()) ??
                                0,
                      ),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateMileage(BuildContext context, Vehicle v) {
    final miles = TextEditingController(
        text: v.mileage.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update mileage'),
        content: AppTextField(
            controller: miles,
            label: 'Current mileage',
            keyboardType: TextInputType.number),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final m = double.tryParse(miles.text.trim());
              if (m != null) {
                context
                    .read<AppState>()
                    .updateMileage(v.id, m);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addMaintenance(BuildContext context, String vehicleId) {
    final title = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add maintenance',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppTextField(
                controller: title,
                label: 'What is needed? (e.g. Oil change)'),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Save',
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                final uid =
                    context.read<AppState>().profile?.id ?? '';
                await context
                    .read<AppState>()
                    .addMaintenance(MaintenanceItem(
                      id: const Uuid().v4(),
                      userId: uid,
                      vehicleId: vehicleId,
                      title: title.text.trim(),
                    ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
