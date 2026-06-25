import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Locandina 2:3 in stile Netflix, con caricamento fluido (cache su disco) e
/// fallback (icona + titolo) quando manca l'immagine. Se [progress] è valorizzato
/// mostra una barra di avanzamento in basso (per "Continua a guardare").
class PosterCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final VoidCallback onTap;
  final double width;
  final IconData fallback;
  final double? progress;

  const PosterCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onTap,
    this.width = 120,
    this.fallback = Icons.movie,
    this.progress,
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isEmpty)
                _fallback()
              else
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: Colors.white10),
                  errorWidget: (_, _, _) => _fallback(),
                ),
              if (progress != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.black54,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
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
