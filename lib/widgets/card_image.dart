import 'package:flutter/material.dart';

import '../models/card_item.dart';

/// Shows a card's picture from its image_ref, or a suit-symbol placeholder
/// when the reference is null, blank, malformed, or fails to load.
/// It never throws and never changes the database.
class CardImage extends StatelessWidget {
  const CardImage({
    super.key,
    required this.imageRef,
    required this.suit,
    this.size = 48,
  });

  final String? imageRef;
  final String suit;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ref = imageRef?.trim() ?? '';
    if (ref.isEmpty) {
      return _placeholder();
    }

    final uri = Uri.tryParse(ref);
    final isWebUrl = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (isWebUrl) {
      return Image.network(
        ref,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    if (ref.startsWith('assets/')) {
      return Image.asset(
        ref,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholder(),
      );
    }

    // Anything else is a malformed reference.
    return _placeholder();
  }

  Widget _placeholder() {
    final isRed = suit == 'hearts' || suit == 'diamonds';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: Text(
        CardItem.symbolFor(suit),
        style: TextStyle(
          fontSize: size * 0.5,
          color: isRed ? Colors.red : Colors.black,
        ),
      ),
    );
  }
}
