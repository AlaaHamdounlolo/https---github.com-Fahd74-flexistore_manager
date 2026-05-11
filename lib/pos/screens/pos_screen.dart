import 'package:flutter/material.dart';

import '../widgets/product_search_widget.dart';
import '../widgets/cart_widget.dart';

/// Main POS screen — desktop split layout.
///
/// ┌────────────────────────┬──────────────┐
/// │  Product Search (65%)  │  Cart (35%)  │
/// └────────────────────────┴──────────────┘
class PosScreen extends StatelessWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        // ── Left: Products ────────────────────────────────────────────────
        Expanded(
          flex: 65,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: ProductSearchWidget(),
          ),
        ),

        // ── Right: Cart ───────────────────────────────────────────────────
        Expanded(
          flex: 35,
          child: CartWidget(),
        ),
      ],
    );
  }
}
