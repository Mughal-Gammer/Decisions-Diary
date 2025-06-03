// import 'package:intl/intl.dart';
//
// class Decision {
//    String? id;
//    String title;
//    String reason;
//    String? expectedOutcome;
//    late String? finalOutcome;
//    DateTime date;
//    final DateTime createdAt;
//
//   Decision({
//     this.id,
//     required this.title,
//     required this.reason,
//     this.expectedOutcome,
//     this.finalOutcome,
//     required this.date,
//     required this.createdAt,
//   });
//
//   Map<String, dynamic> toMap() {
//     return {
//       'title': title,
//       'reason': reason,
//       'expectedOutcome': expectedOutcome,
//       'finalOutcome': finalOutcome,
//       'date': DateFormat('dd-MM-yyyy').format(date),
//     };
//   }
//
//   factory Decision.fromMap(Map<String, dynamic> map, String id) {
//     return Decision(
//       id: id,
//       title: map['title'] ?? '',
//       reason: map['reason'] ?? '',
//       expectedOutcome: map['expectedOutcome'],
//       finalOutcome: map['finalOutcome'],
//       date: map['date'] != null
//           ? DateFormat('dd-MM-yyyy').parse(map['date'])
//           : DateTime.now(),
//       createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
//     );
//   }
// }
//


import 'package:intl/intl.dart';

class Decision {
  String? id;
  String title;
  String reason;
  String? expectedOutcome;
  late String? finalOutcome;
  DateTime date;
  final DateTime createdAt;

  Decision({
    this.id,
    required this.title,
    required this.reason,
    this.expectedOutcome,
    this.finalOutcome,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'reason': reason,
      'expectedOutcome': expectedOutcome,
      'finalOutcome': finalOutcome,
      'date': date.toIso8601String(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Decision.fromMap(Map<String, dynamic> map, String id) {
    return Decision(
      id: id,
      title: map['title'] ?? '',
      reason: map['reason'] ?? '',
      expectedOutcome: map['expectedOutcome'],
      finalOutcome: map['finalOutcome'],
      date: map['date'] != null
          ? DateTime.parse(map['date']) : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }
}