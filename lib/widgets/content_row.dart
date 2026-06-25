import 'package:flutter/material.dart';

/// Carosello orizzontale con titolo (una "riga" stile Netflix).
class ContentRow extends StatelessWidget {
  final String title;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double height;

  const ContentRow({
    super.key,
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: itemBuilder,
          ),
        ),
      ],
    );
  }
}
