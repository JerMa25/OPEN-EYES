import 'package:flutter/material.dart';
import '../../model/destination.dart';
import '../../services/destination_service.dart';
import 'destination_card.dart';

class DestinationListWidget extends StatefulWidget {
  const DestinationListWidget({super.key});

  @override
  State<DestinationListWidget> createState() => _DestinationListWidgetState();
}

class _DestinationListWidgetState extends State<DestinationListWidget> {
  late Future<List<Destination>> _destinationsFuture;
  final PositionService service = PositionService();

  @override
  void initState() {
    super.initState();
    _destinationsFuture = service.fetchLieuxFrequents(canneId: 1);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Destination>>(
      future: _destinationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aucune destination trouvée.'));
        }

        final destinations = snapshot.data!;
        return ListView.builder(
          itemCount: destinations.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
              child: DestinationCard(destination: destinations[index]),
            );
          },
        );
      },
    );
  }
}
