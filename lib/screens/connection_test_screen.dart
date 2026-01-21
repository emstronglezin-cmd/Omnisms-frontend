import 'package:flutter/material.dart';
import '../services/connection_test_service.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  final ConnectionTestService _testService = ConnectionTestService();
  List<ConnectionTestResult> _results = [];
  bool _isTesting = false;

  Future<void> _runAllTests() async {
    setState(() {
      _isTesting = true;
      _results.clear();
    });

    final results = await _testService.testAllEndpoints();

    setState(() {
      _results = results;
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Connexion Backend'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuration Backend',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('URL: http://51.15.89.72'),
                    Text('WebSocket: ws://51.15.89.72/ws'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isTesting ? null : _runAllTests,
              child: _isTesting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Test en cours...'),
                      ],
                    )
                  : const Text('Tester la Connexion'),
            ),
            const SizedBox(height: 16),
            if (_results.isNotEmpty) ...[
              Text(
                'Résultats des Tests',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return Card(
                      color: result.isConnected
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      child: ListTile(
                        leading: Icon(
                          result.isConnected ? Icons.check_circle : Icons.error,
                          color: result.isConnected ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          result.isConnected ? 'Succès' : 'Échec',
                          style: TextStyle(
                            color: result.isConnected
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(result.message),
                            if (result.statusCode != null)
                              Text('Code: ${result.statusCode}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
