import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Banner "in evidenza" in cima allo Sfoglia: poster grande con gradiente verso
/// il nero, titolo e azioni (Riproduci + La mia lista). Tap → dettaglio.
class FeaturedHero extends StatelessWidget {
  final String imageUrl;
  final String title;
  final VoidCallback onPlay;
  final VoidCallback onTap;
  final Widget myListButton;

  const FeaturedHero({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.onPlay,
    required this.onTap,
    required this.myListButton,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 460,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, _) => Container(color: Colors.white10),
                errorWidget: (_, _, _) => Container(color: Colors.white10),
              )
            else
              Container(color: Colors.white10),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87, Colors.black],
                  stops: [0.35, 0.85, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Riproduci'),
                      ),
                      const SizedBox(width: 12),
                      myListButton,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
