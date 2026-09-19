import 'package:flutter/material.dart';

/// Keeps recognized foods visible without assigning unrelated nutrition values.
class UnmatchedFoodsCard extends StatelessWidget {
  const UnmatchedFoodsCard({super.key, required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Belum ada kecocokan di database',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final name in names) Text('• $name'),
            const SizedBox(height: 8),
            const Text(
              'Nama ini adalah perkiraan model. Nutrisi belum dihitung untuk '
              'makanan di atas karena belum ada kecocokan yang pasti di katalog. '
              'Jangan pilih makanan pengganti yang berbeda.',
            ),
          ],
        ),
      ),
    );
  }
}
