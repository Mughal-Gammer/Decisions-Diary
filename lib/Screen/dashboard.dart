import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../widgets/Model class new.dart';
import '../widgets/ThemeProvider.dart';
import 'Add Decisions.dart';
import 'ReportCard.dart';
import 'login page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late Stream<DatabaseEvent> _decisionsStream;
  String _selectedFilter = 'All';




  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((user) {
      _initDecisionsStream();
      if (mounted) setState(() {});
    });
    _initDecisionsStream();
  }

  void _initDecisionsStream() {
    final user = _auth.currentUser;
    if (user != null) {
      _decisionsStream = _dbRef
          .child('users/${user.uid}/decisions')
          .orderByChild('date')
          .onValue;

    } else {
      _decisionsStream = const Stream<DatabaseEvent>.empty();
    }
  }

  void _navigateToAddDecision(BuildContext context, [Decision? decision]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddDecisionScreen(decision: decision),
      ),
    ).then((_) => setState(() {}));
  }

  void _showDecisionDetails(Decision decision) {
    final TextEditingController _finalOutcomeController = TextEditingController(
        text: decision.finalOutcome ?? '');
    bool _isEditing = false;
    bool _isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            decision.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                Navigator.pop(context);
                                _navigateToAddDecision(context, decision);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                final shouldDelete = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Decision'),
                                    content: const Text('Are you sure you want to delete this decision?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (shouldDelete == true) {
                                  final user = _auth.currentUser;
                                  if (user != null) {
                                    await _dbRef.child('users/${user.uid}/decisions/${decision.id}').remove();
                                    if (mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Decision deleted successfully')),
                                      );
                                      setState(() {});
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMMM d, yyyy').format(decision.date),

                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection('Reason', decision.reason ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                        'Expected Outcome',
                        decision.expectedOutcome ?? 'Not specified'

                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Final Outcome',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,

                              ),
                            ),
                            if (!_isEditing)
                              TextButton(
                                onPressed: () => setModalState(() => _isEditing = true),
                                child: const Text('Edit',style: TextStyle(color: Colors.orange),),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isEditing)
                          Column(
                            children: [
                              TextFormField(
                                controller: _finalOutcomeController,
                                maxLines: 3,
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shadowColor:  Colors.red,
                                        elevation: 5
                                      ),
                                      onPressed: () => setModalState(() => _isEditing = false),
                                      child: const Text('Cancel',style: TextStyle(color:Colors.red),),)
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shadowColor:  Colors.green,
                                        elevation: 5
                                      ),
                                      onPressed: () async {
                                        setModalState(() => _isSaving = true);
                                        final user = _auth.currentUser;
                                        if (user != null) {
                                          await _dbRef.child('users/${user.uid}/decisions/${decision.id}')
                                              .update({
                                            'finalOutcome': _finalOutcomeController.text.trim()
                                          });
                                          if (mounted) {
                                            setModalState(() {
                                              _isEditing = false;
                                              _isSaving = false;
                                              Navigator.pop(context);
                                            });
                                            decision.finalOutcome = _finalOutcomeController.text.trim();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Updated successfully')),
                                            );
                                          }
                                        }
                                      },
                                      child: _isSaving
                                          ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.orange,
                                        ),
                                      )
                                          : const Text('Save',style: TextStyle(color: Colors.green),),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              decision.finalOutcome?.isNotEmpty == true
                                  ? decision.finalOutcome!
                                  : 'Not recorded yet',
                                  style: TextStyle(color: Colors.black),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shadowColor:  Colors.white,
                          elevation: 5,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailSection(String title, String content,) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,


          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(content,style: TextStyle(color: Colors.black),),
        ),
      ],
    );
  }

  Widget _buildDecisionCard(Decision decision) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDecisionDetails(decision),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      decision.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (decision.finalOutcome?.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.1),
                        ),
                      ),
                      child: Text(
                        'Completed',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13
                        ),
                      ),
                    ),
                    // Container(
                    //   padding: const EdgeInsets.symmetric(
                    //     horizontal: 8,
                    //     vertical: 4,
                    //   ),
                    //   decoration: BoxDecoration(
                    //     color: Colors.green.shade50,
                    //     borderRadius: BorderRadius.circular(20),
                    //     border: Border.all(color: Colors.green.shade100),
                    //   ),
                    //   child: Text(
                    //     'Completed',
                    //     style: TextStyle(
                    //       fontSize: 12,
                    //       color: Colors.green.shade800,
                    //     ),
                    //   ),
                    // ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                decision.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, yyyy').format(decision.date),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (decision.finalOutcome?.isEmpty == true)
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: Colors.orange.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Expected',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade400,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No Decisions Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start by adding your first important decision',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _navigateToAddDecision(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Add First Decision'),
          ),
        ],
      ),
    );
  }

  _alertDailogBox(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("LogOut",style: TextStyle(fontWeight: FontWeight.bold),),
          content: const Text("Are you want to sure Logout?"),
          actions: [
            TextButton(
              onPressed: () {
                _auth.signOut();
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage())
                );
              },
              child: const Text("Yes"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child:
          Consumer<ThemeProvider>(
            builder: (context, themeNotifier, child) {
              return Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: CircleAvatar(

                  backgroundColor: Colors.transparent,
                  child: ClipOval(
                    child: Image.asset(
                      themeNotifier.isDarkMode
                          ? 'assets/images/logo1.png'
                          : 'assets/images/logo.png',
                      fit: BoxFit.cover,

                    ),
                  ),
                ),
              );
            },
          ),

        ),
        title: const Text('My Decisions'),
        centerTitle: false,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reports') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportsScreen()),
                );
              } else if (value == 'theme') {
                Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
              } else if (value == 'filter') {
                showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setModalState) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Filter Decisions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...['All', 'Completed', 'Expected'].map((filter) {
                                return RadioListTile<String>(
                                  title: Text(filter),
                                  value: filter,
                                  groupValue: _selectedFilter,
                                  onChanged: (value) {
                                    setModalState(() => _selectedFilter = value!);
                                    setState(() => _selectedFilter = value!);
                                    Navigator.pop(context);
                                  },
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reports',
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('View Reports'),
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Consumer<ThemeProvider>(
                  builder: (context, themeNotifier, child) {
                    // Safe context check
                    if (!context.mounted) {
                      return const SizedBox.shrink();
                    }

                    return ListTile(
                      leading: Icon(
                        themeNotifier.isDarkMode
                            ? Icons.light_mode
                            : Icons.dark_mode,
                      ),
                      title: Text(
                        themeNotifier.isDarkMode
                            ? 'Light Mode'
                            : 'Dark Mode',
                      ),
                    );
                  },
                ),
              ),
              const PopupMenuItem(
                value: 'filter',
                child: ListTile(
                  leading: Icon(Icons.filter_list),
                  title: Text('Filter Decisions'),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _alertDailogBox(context),
            icon: const Icon(Icons.logout_sharp),
          ),
        ],

      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _decisionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData ||
              snapshot.data!.snapshot.value == null ||
              (snapshot.data!.snapshot.value as Map).isEmpty) {
            return _buildEmptyState();
          }

          final decisionsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          // Inside your StreamBuilder builder function:
          final decisions = decisionsMap.entries.map((entry) {
            return Decision.fromMap(
              Map<String, dynamic>.from(entry.value),
              entry.key,
            );
          }).toList();

          decisions.sort((a, b) => b.date.compareTo(a.date));


          List<Decision> filteredDecisions = decisions.where((decision) {
            if (_selectedFilter == 'Completed') {
              return decision.finalOutcome?.isNotEmpty == true;
            } else if (_selectedFilter == 'Expected') {
              return decision.finalOutcome?.isEmpty == true;
            }
            return true;
          }).toList();





          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredDecisions.length,
              itemBuilder: (context, index) {
                final decision = filteredDecisions[index];
                return _buildDecisionCard(decision);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        onPressed: () => _navigateToAddDecision(context),
        child: const Icon(Icons.add,color: Colors.white,),
      ),
    );
  }
}