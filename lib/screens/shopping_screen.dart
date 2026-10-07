import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_input_bar.dart';
import '../widgets/category_icon.dart';
import '../widgets/suggestion_card.dart';
import '../widgets/ui_kit.dart';
import '../services/app_state.dart';
import '../services/assistant_engine.dart';
import '../models/shopping_item.dart';

class ShoppingScreen extends StatelessWidget {
  static const route = '/shopping';
  const ShoppingScreen({super.key});

  Future<void> _aiAdd(BuildContext context, String text) async {
    final reply =
        await AssistantEngine(context.read<AppState>()).handleText(text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(reply)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final toBuy = app.shoppingToBuy;
    final bought =
        app.shoppingItems.where((s) => s.isBought).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping List')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          AiInputBar(
            hint: '"add eggs and bread to my shopping list"',
            onSubmit: (t) => _aiAdd(context, t),
          ),
          const SizedBox(height: 12),
          const SectionHeader(title: 'To buy'),
          if (toBuy.isEmpty)
            const EmptyState(
                message: 'List is empty. Add items by voice or text.',
                icon: Icons.shopping_cart_outlined)
          else
            ...toBuy.map((s) => _row(context, s)),
          if (bought.isNotEmpty) ...[
            const SectionHeader(title: 'Bought'),
            ...bought.map((s) => _row(context, s)),
          ],
          const SizedBox(height: 8),
          SuggestionCard(
            title: 'Shopping suggestions',
            suggestions: [
              if (toBuy.length >= 5)
                'You have ${toBuy.length} items — group them by store section to shop faster.',
              'Say "add milk, eggs and bread to my shopping list" to add several at once.',
              if (toBuy.isEmpty)
                'Your list is clear. Nice and light.',
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _row(BuildContext context, ShoppingItem s) {
    final app = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.card3D(radius: 18),
      child: ListTile(
        leading:
            const CategoryIcon(category: 'grocery', size: 42),
        title: Text(s.name,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              decoration:
                  s.isBought ? TextDecoration.lineThrough : null,
            )),
        trailing: Checkbox(
          value: s.isBought,
          activeColor: AppColors.deepGreen,
          onChanged: (_) => app.toggleShoppingItem(s.id),
        ),
        onLongPress: () => app.deleteShoppingItem(s.id),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final name = TextEditingController();
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
            Text('Add item',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            AppTextField(controller: name, label: 'Item name'),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Add to list',
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final uid =
                    context.read<AppState>().profile?.id ?? '';
                await context.read<AppState>().addShoppingItem(
                      ShoppingItem(
                          id: const Uuid().v4(),
                          userId: uid,
                          name: name.text.trim()),
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
