import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/speech.dart';

/// Menu d'un appui long sur un mot anglais : écouter ou copier.
Future<void> afficherMenuMot(BuildContext context, String mot) {
  final services = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(mot, style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.volume_up_rounded),
            title: const Text('Écouter'),
            onTap: () async {
              Navigator.of(ctx).pop();
              final ok = await speech.speak(mot, accent: services.user.accent);
              if (!ok) {
                messenger.showSnackBar(const SnackBar(
                  content: Text('Aucune voix anglaise n\'est installée sur cet appareil.'),
                ));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copier'),
            onTap: () async {
              Navigator.of(ctx).pop();
              await Clipboard.setData(ClipboardData(text: mot));
              messenger.showSnackBar(const SnackBar(content: Text('Copié.')));
            },
          ),
        ],
      ),
    ),
  );
}
