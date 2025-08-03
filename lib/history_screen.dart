// arquivo: lib/history_screen.dart

import 'package:flutter/material.dart';
import 'package:folhas/database_helper.dart';
import 'dart:io';

import 'package:folhas/detection_model.dart';
import 'package:folhas/history_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<DetectionHistory>> _historyFuture;
  String? _activeFilter; // Guarda o nome da classe do filtro ativo

  @override
  void initState() {
    super.initState();
    _refreshHistory();
  }

  void _refreshHistory() {
    setState(() {
      _historyFuture = DatabaseHelper.instance.getFullHistory();
      _activeFilter = null; // Limpa o filtro ao recarregar
    });
  }

  // NOVO: Função para mostrar o diálogo de confirmação de exclusão
  Future<void> _showConfirmDeleteDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Apagar Histórico?'),
          content: const Text(
            'Esta ação é irreversível e apagará todas as detecções salvas. Você tem certeza?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Apagar'),
              onPressed: () async {
                await DatabaseHelper.instance.clearAllHistory();
                Navigator.of(context).pop();
                _refreshHistory(); // Atualiza a tela para mostrar que está vazia
              },
            ),
          ],
        );
      },
    );
  }

  // NOVO: Função para mostrar o diálogo de filtro
  Future<void> _showFilterDialog(List<DetectionHistory> allHistory) async {
    // 1. Encontrar todas as classes únicas
    final allResults = allHistory.expand((h) => h.results);
    final uniqueClasses = allResults.map((r) => r.className).toSet().toList();
    uniqueClasses.sort();

    // 2. Mostrar o diálogo
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filtrar por espécie'),
        children: [
          // Opção para limpar o filtro
          SimpleDialogOption(
            onPressed: () {
              setState(() => _activeFilter = null);
              Navigator.pop(context);
            },
            child: const Text('Mostrar Todas'),
          ),
          // Opções para cada classe
          ...uniqueClasses.map(
            (className) => SimpleDialogOption(
              onPressed: () {
                setState(() => _activeFilter = className);
                Navigator.pop(context);
              },
              child: Text(className),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Detecções'),
        // NOVO: Ações na AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Só mostra o filtro se houver dados carregados
              _historyFuture.then((history) {
                if (history.isNotEmpty) {
                  _showFilterDialog(history);
                }
              });
            },
            tooltip: 'Filtrar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              _historyFuture.then((history) {
                if (history.isNotEmpty) {
                  _showConfirmDeleteDialog();
                }
              });
            },
            tooltip: 'Apagar tudo',
          ),
        ],
      ),
      body: FutureBuilder<List<DetectionHistory>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80),
                  SizedBox(height: 16),
                  Text('Nenhuma detecção salva ainda.'),
                ],
              ),
            );
          }

          final allHistory = snapshot.data!;
          // NOVO: Aplica o filtro se houver um ativo
          final filteredHistory = _activeFilter == null
              ? allHistory
              : allHistory
                    .where(
                      (h) => h.results.any((r) => r.className == _activeFilter),
                    )
                    .toList();

          return Column(
            children: [
              // NOVO: Indicador de filtro ativo
              if (_activeFilter != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Chip(
                    label: Text('Filtrando por: $_activeFilter'),
                    onDeleted: () {
                      setState(() => _activeFilter = null);
                    },
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                  ),
                ),
              if (filteredHistory.isEmpty && _activeFilter != null)
                const Expanded(
                  child: Center(
                    child: Text(
                      'Nenhum resultado encontrado para este filtro.',
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final history = filteredHistory[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.file(
                              File(history.imagePath),
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            '${history.results.length} folha(s) detectada(s)',
                          ),
                          subtitle: Text(
                            '${history.detectionDate.day}/${history.detectionDate.month}/${history.detectionDate.year} - ${history.detectionDate.hour}:${history.detectionDate.minute.toString().padLeft(2, '0')}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    HistoryDetailScreen(history: history),
                              ),
                            );
                            _refreshHistory();
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
