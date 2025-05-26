import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'decision_details_sheet.dart';

class DecisionSearchDelegate extends SearchDelegate {
  final Stream<DatabaseEvent> decisionsStream;

  DecisionSearchDelegate(this.decisionsStream);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return StreamBuilder<DatabaseEvent>(
      stream: decisionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: Text('No decisions found'));
        }

        final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
        final filteredDecisions = data.entries.where((entry) {
          try {
            final decision = Map<String, dynamic>.from(entry.value);
            if (query.isEmpty) return true;
            return (decision['title']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false) ||
                (decision['reason']?.toString().toLowerCase().contains(query.toLowerCase()) ?? false);
          } catch (e) {
            return false;
          }
        }).toList();

        if (filteredDecisions.isEmpty) {
          return const Center(child: Text('No matching decisions'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDecisions.length,
          itemBuilder: (context, index) {
            final entry = filteredDecisions[index];
            final decision = Map<String, dynamic>.from(entry.value);

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(decision['title'] ?? 'Untitled Decision'),
                subtitle: Text(decision['reason'] ?? 'No reason provided'),
                onTap: () {
                  close(context, null);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => DecisionDetailsSheet(
                      decision: decision,
                      decisionId: entry.key,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
