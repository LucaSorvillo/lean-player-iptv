import 'package:flutter/material.dart';

import '../services/settings_store.dart';

/// Mostra i Termini d'uso al primo avvio; una volta accettati mostra [child].
class EulaGate extends StatefulWidget {
  final Widget child;
  const EulaGate({super.key, required this.child});

  @override
  State<EulaGate> createState() => _EulaGateState();
}

class _EulaGateState extends State<EulaGate> {
  late bool _accepted = SettingsStore.instance.eulaAccepted;

  Future<void> _accept() async {
    await SettingsStore.instance.acceptEula();
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted) return widget.child;
    return Scaffold(
      appBar: AppBar(title: const Text('Termini d\'uso')),
      body: Column(
        children: [
          const Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Text(
                'LeanPlayerIPTV è un lettore multimediale. NON fornisce, ospita '
                'né include alcun contenuto, canale o playlist.\n\n'
                'Tutti i contenuti riprodotti provengono esclusivamente dai '
                'server, dalle credenziali o dalle playlist che inserisci tu. '
                'Utilizzando l\'app dichiari di avere il diritto o un abbonamento '
                'legittimo per accedere ai contenuti che riproduci, e ti assumi '
                'ogni responsabilità sul loro uso.\n\n'
                'L\'app non è affiliata ad alcun fornitore di contenuti o '
                'servizio di streaming. Usala nel rispetto delle leggi sul '
                'diritto d\'autore vigenti nel tuo Paese.',
                style: TextStyle(height: 1.5),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _accept,
                  child: const Text('Accetto e continuo'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
