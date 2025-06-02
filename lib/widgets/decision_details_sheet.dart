import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DecisionDetailsSheet extends StatelessWidget {
  final Map<dynamic, dynamic> decision;
  final String decisionId;

  const DecisionDetailsSheet({
    Key? key,
    required this.decision,
    required this.decisionId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            decision['title'] ?? 'No Title',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMMM d, yyyy').format(
              DateTime.parse(decision['date'] ?? DateTime.now().toString()),
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          _buildDetailSection('Reason', decision['reason']),
          const SizedBox(height: 20),
          _buildDetailSection('Expected Outcome', decision['expectedOutcome']),
          const SizedBox(height: 20),
          _buildDetailSection(
            'Final Outcome',
            decision['finalOutcome']?.isNotEmpty == true
                ? decision['finalOutcome']
                : 'Not recorded yet',
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child:
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String? content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            content ?? 'Not available',
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ],
    );
  }
}