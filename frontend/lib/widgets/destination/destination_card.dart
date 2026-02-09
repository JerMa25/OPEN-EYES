// lib/widgets/destination/destination_card.dart

import 'package:flutter/material.dart';
import '../../model/destination.dart';
import '../../ui/destination_style.dart';

/// Carte affichant une destination
class DestinationCard extends StatelessWidget {
  final Destination destination;
  final VoidCallback? onTap;

  const DestinationCard({
    super.key,
    required this.destination,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withAlpha(25),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône dynamique avec couleur de fond
                _buildIcon(),
                const SizedBox(width: 16),

                // Informations du lieu
                Expanded(child: _buildInfo()),

                // Flèche et étoiles
                _buildTrailing(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: destination.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        destination.icon,
        color: destination.iconColor,
        size: 24,
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nom du lieu
        Text(
          destination.lieu,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        
        // Badges
        Row(
          children: [
            // Badge de fréquence
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: destination.iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                destination.frequenceLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: destination.iconColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            
            // Nombre de visites
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  destination.visiteBadge,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrailing() {
    return Column(
      children: [
        // Étoiles de popularité
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return Icon(
              index < destination.popularityStars
                  ? Icons.star
                  : Icons.star_border,
              size: 14,
              color: index < destination.popularityStars
                  ? Colors.amber
                  : Colors.grey[300],
            );
          }),
        ),
        const SizedBox(height: 8),
        Icon(
          Icons.chevron_right,
          color: Colors.grey[400],
          size: 24,
        ),
      ],
    );
  }
}
