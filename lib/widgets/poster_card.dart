import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Locandina 2:3 in stile Netflix, con caricamento fluido (cache su disco) e
/// fallback (icona + titolo) quando manca l'immagine.
class PosterCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final VoidCallback onTap;
  final double width;
  final IconData fallback;

  const PosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.width = 120,
    this.fallback = Icons.movie,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 3 / 2;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: width,
          height: height,
          child: imageUrl.isEmpty
              ? _fallback()
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: Colors.white10),
                  errorWidget: (_, _, _) => _fallback(),
                ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: Colors.white10,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(fallback, color: Colors.white54),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      );
}
