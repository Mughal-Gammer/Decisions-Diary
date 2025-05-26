import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ShowDecisions extends StatefulWidget {
  final List<Map<String, dynamic>> showdecisionslist;
  const ShowDecisions({super.key, required this.showdecisionslist});

  @override
  State<ShowDecisions> createState() => _ShowDecisionsState();
}

class _ShowDecisionsState extends State<ShowDecisions> {

  final _ref = FirebaseDatabase.instance.ref().child('users');


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('data'),
        ],
      ),
    );
  }
}
