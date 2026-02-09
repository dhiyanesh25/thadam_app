import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentDetailPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String userRole;

  const StudentDetailPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.userRole,
  });

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  final Map<String, List<String>> challengeOptions = {
    'Attention And Focus (AF)': [
      'Easily Distracted',
      'Moderately Distracted',
      'Misses Instructions',
      'No Challenges'
    ],
    'Communication Support (CS)': [
      'Non Verbal',
      'Verbal',
      'Delayed Or Scattered Expression',
      'Misunderstood',
      'No Challenges'
    ],
    'Emotional Regulation (ER)': [
      'Mood Swings',
      'Frustration',
      'Shutdowns',
      'No Challenges'
    ],
    'Sensory Regulation (SR)': [
      'Over Sensitive To Noise',
      'Under Sensitive To Noise',
      'Over Sensitive To Light',
      'Under Sensitive To Light',
      'Over Sensitive To Touch',
      'Under Sensitive To Touch',
      'Over Sensitive To Smell',
      'Under Sensitive To Smell',
      'Over Sensitive To Taste',
      'Under Sensitive To Taste',
      'Regular - Noise',
      'Regular - Light',
      'Regular - Touch',
      'Regular - Smell',
      'Regular - Taste',
      'No Challenges',
      'Other'
    ],
    'Impulsivity & Hyperactivity (IH)': [
      'Interrupts Often',
      'Touches Everything',
      "Can't Sit Still",
      "Can't Stand Still",
      'Circles Around',
      'Keeps Running',
      'Bangs Objects',
      'Bangs Body Parts',
      'Bangs Others',
      'No Challenges'
    ],
    'Task Initiation & Completion (TIC)': [
      'Avoids Tasks',
      'Forgets Steps',
      'Overwhelmed',
      'No Challenges'
    ],
    'Transition Between Activities (TA)': [
      'Difficulty Shifting Focus',
      'Meltdowns',
      'Refusal',
      'No Challenges'
    ],
    'Social Interactions (SI)': [
      'Misreads Social Cues',
      'Impulsive',
      'Intense Emotions',
      'Not Interested',
      'No Challenges'
    ],
    'Collaboration With Adults (CA)': [
      'Mistrust',
      'Meltdowns During Adult Led Tasks',
      'No Challenges'
    ],
    'Strength Based Appreciation (SBA)': [
      'Fine Motor - One Hand',
      'Fine Motor - Both Hands',
      'Gross Motor - One Leg',
      'Gross Motor - Both Legs',
      'Auditory',
      'Visual',
      'Memory',
      'Organisation',
      'Comprehension',
      'Social'
    ],
  };

  String? selectedArea;
  String? selectedChallenge;

  bool get isParent => widget.userRole.toLowerCase() == 'parent';

  Color _ratingColor(int rating) {
    if (rating >= 4) return Colors.green;
    if (rating == 3) return Colors.orange;
    return Colors.red;
  }

  String _label(int v) {
    switch (v) {
      case 1:
        return 'Severe';
      case 2:
        return 'High';
      case 3:
        return 'Moderate';
      case 4:
        return 'Mild';
      case 5:
        return 'Well Managed';
      default:
        return '';
    }
  }

  // =================== ADD RECORD (PRESERVED + FIXED) ===================
  Future<void> _addRecordDialog() async {
    if (isParent) return;

    selectedArea = null;
    selectedChallenge = null;

    final formKey = GlobalKey<FormState>();
    double rating = 0;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Daily Observation"),
        content: Form(
          key: formKey,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedArea,
                      items: challengeOptions.keys
                          .map((area) =>
                          DropdownMenuItem(value: area, child: Text(area)))
                          .toList(),
                      onChanged: (val) {
                        setStateDialog(() {
                          selectedArea = val;
                          selectedChallenge = null;
                        });
                      },
                      decoration:
                      const InputDecoration(labelText: 'Area Of Support'),
                      validator: (val) =>
                      val == null ? 'Select Area' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedChallenge,
                      items: (selectedArea != null
                          ? challengeOptions[selectedArea]!
                          : [])
                          .map((c) =>
                          DropdownMenuItem<String>(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedChallenge = val),
                      decoration: const InputDecoration(
                          labelText: 'Challenge Observed'),
                      validator: (val) =>
                      val == null ? 'Select Challenge' : null,
                    ),
                    const SizedBox(height: 12),
                    const Text("Impact Level Today"),
                    RatingBar.builder(
                      initialRating: rating,
                      minRating: 0,
                      itemCount: 5,
                      allowHalfRating: false,
                      itemBuilder: (_, __) =>
                      const Icon(Icons.star, color: Colors.amber),
                      onRatingUpdate: (r) {
                        setStateDialog(() {
                          rating = r;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              if (rating == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select a rating")),
                );
                return;
              }

              final currentUser = auth.currentUser!;

              await firestore
                  .collection('students')
                  .doc(widget.studentId)
                  .collection('records')
                  .add({
                'areaOfSupport': _cap(selectedArea!),
                'challenge': _cap(selectedChallenge!),
                'rating': rating.toInt(),
                'date':
                DateFormat('yyyy-MM-dd').format(DateTime.now()),
                'timestamp': FieldValue.serverTimestamp(),

                // 🔹 REQUIRED FOR ADMIN VIEW (NEW - ADDED)
                'enteredByUid': currentUser.uid,
                'enteredByName': currentUser.email ?? 'Staff',
                'studentId': widget.studentId,
                'studentName': widget.studentName,
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // =================== UPDATE RATING (PRESERVED + FIXED) ===================
  Future<void> _updateRatingDialog(String docId, int currentRating) async {
    if (isParent) return;

    double newRating = currentRating.toDouble();
    DateTime selectedDate = DateTime.now();

    final existingDoc = await firestore
        .collection('students')
        .doc(widget.studentId)
        .collection('records')
        .doc(docId)
        .get();

    final existingData =
    existingDoc.data() as Map<String, dynamic>;
    final existingChallenge = existingData['challenge'];
    final existingArea = existingData['areaOfSupport'];

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Rating (New Entry)"),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading:
                  const Icon(Icons.calendar_today),
                  title: Text(
                    DateFormat('yyyy-MM-dd')
                        .format(selectedDate),
                  ),
                  onTap: () async {
                    final picked =
                    await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setStateDialog(
                              () => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                const Text("Select Rating"),
                RatingBar.builder(
                  initialRating: newRating,
                  minRating: 1,
                  itemCount: 5,
                  allowHalfRating: false,
                  itemBuilder: (_, __) =>
                  const Icon(Icons.star,
                      color: Colors.amber),
                  onRatingUpdate: (r) =>
                  newRating = r,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            child: const Text("Save"),
            onPressed: () async {
              final currentUser = auth.currentUser!;

              await firestore
                  .collection('students')
                  .doc(widget.studentId)
                  .collection('records')
                  .add({
                'areaOfSupport': existingArea,
                'challenge': existingChallenge,
                'rating': newRating.toInt(),
                'date': DateFormat('yyyy-MM-dd')
                    .format(selectedDate),
                'timestamp':
                FieldValue.serverTimestamp(),

                // 🔹 REQUIRED FOR ADMIN VIEW (NEW - ADDED)
                'enteredByUid': currentUser.uid,
                'enteredByName':
                currentUser.email ?? 'Staff',
                'studentId': widget.studentId,
                'studentName': widget.studentName,
              });

              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Record"),
        content: const Text(
            "Are you sure you want to delete this entry?"),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, true),
              child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      await firestore
          .collection('students')
          .doc(widget.studentId)
          .collection('records')
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        backgroundColor:
        const Color(0xFF5A9BD8),
        actions: [
          if (!isParent)
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addRecordDialog),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('students')
            .doc(widget.studentId)
            .collection('records')
            .orderBy('timestamp',
            descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text(
                    "Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(
                child:
                CircularProgressIndicator());
          }

          final allRecords =
              snapshot.data!.docs;

          Map<String, QueryDocumentSnapshot>
          latestByChallenge = {};

          for (var doc in allRecords) {
            final data =
            doc.data() as Map<String, dynamic>;
            final challenge =
            data['challenge'];

            if (!latestByChallenge
                .containsKey(challenge)) {
              latestByChallenge[challenge] =
                  doc;
            }
          }

          final records =
          latestByChallenge.values
              .toList();

          if (records.isEmpty) {
            return const Center(
                child: Text("No Records"));
          }

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (_, index) {
              final doc =
              records[index];
              final data =
              doc.data() as Map<String, dynamic>;
              final rating =
                  data['rating'] ?? 0;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChallengeProgressPage(
                            studentId:
                            widget.studentId,
                            challenge:
                            data['challenge'],
                          ),
                    ),
                  );
                },
                child: Card(
                  margin:
                  const EdgeInsets.all(10),
                  child: Padding(
                    padding:
                    const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          data['challenge'] ??
                              '',
                          style:
                          const TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                            height: 4),
                        Text(
                          data['areaOfSupport'] ??
                              '',
                          style: const TextStyle(
                              color:
                              Colors.grey),
                        ),
                        const SizedBox(
                            height: 8),
                        Row(
                          children: [
                            const Text(
                                "Rating: "),
                            Text(
                              "$rating (${_label(rating)})",
                              style: TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                                color:
                                _ratingColor(
                                    rating),
                              ),
                            ),
                            const Spacer(),
                            if (!isParent)
                              PopupMenuButton<
                                  String>(
                                onSelected:
                                    (value) {
                                  if (value ==
                                      'edit') {
                                    _updateRatingDialog(
                                        doc.id,
                                        rating);
                                  } else if (value ==
                                      'delete') {
                                    _deleteRecord(
                                        doc.id);
                                  }
                                },
                                itemBuilder:
                                    (context) =>
                                const [
                                  PopupMenuItem(
                                    value:
                                    'edit',
                                    child: Text(
                                        'Update Rating'),
                                  ),
                                  PopupMenuItem(
                                    value:
                                    'delete',
                                    child: Text(
                                        'Delete'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(
                            height: 4),
                        Text(
                            "Date: ${data['date']}"),
                        const SizedBox(
                            height: 4),
                        const Text(
                          "Tap to view full progress",
                          style: TextStyle(
                              fontSize: 12,
                              color:
                              Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ---------------- PROGRESS PAGE (UNCHANGED) ----------------
class ChallengeProgressPage extends StatefulWidget {
  final String studentId;
  final String challenge;

  const ChallengeProgressPage({
    super.key,
    required this.studentId,
    required this.challenge,
  });

  @override
  State<ChallengeProgressPage> createState() =>
      _ChallengeProgressPageState();
}

class _ChallengeProgressPageState
    extends State<ChallengeProgressPage> {
  String _label(int v) {
    switch (v) {
      case 1:
        return 'Severe';
      case 2:
        return 'High';
      case 3:
        return 'Moderate';
      case 4:
        return 'Mild';
      case 5:
        return 'Well Managed';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore =
        FirebaseFirestore.instance;

    return Scaffold(
      appBar:
      AppBar(title: Text(widget.challenge)),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('students')
            .doc(widget.studentId)
            .collection('records')
            .orderBy('date')
            .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text(
                    "Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(
                child:
                CircularProgressIndicator());
          }

          final allDocs =
              snapshot.data!.docs;
          final docs =
          allDocs.where((doc) {
            final d =
            doc.data()
            as Map<String, dynamic>;
            return d['challenge'] ==
                widget.challenge;
          }).toList();

          if (docs.isEmpty) {
            return const Center(
                child:
                Text("No Progress Data"));
          }

          return Padding(
            padding:
            const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  padding:
                  const EdgeInsets.all(10),
                  color:
                  Colors.blue.shade100,
                  child: Row(
                    children:
                    const [
                      Expanded(
                        child: Text(
                          "Date",
                          style: TextStyle(
                              fontWeight:
                              FontWeight
                                  .bold),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Rating",
                          style: TextStyle(
                              fontWeight:
                              FontWeight
                                  .bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                    height: 6),
                Expanded(
                  child:
                  ListView.builder(
                    itemCount:
                    docs.length,
                    itemBuilder:
                        (_, i) {
                      final d =
                      docs[i].data()
                      as Map<String,
                          dynamic>;

                      return Container(
                        padding:
                        const EdgeInsets
                            .all(10),
                        decoration:
                        BoxDecoration(
                          border:
                          Border(
                            bottom:
                            BorderSide(
                              color: Colors
                                  .grey
                                  .shade300,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    d['date'])),
                            Expanded(
                              child: Text(
                                "${d['rating']} (${_label(d['rating'])})",
                                style: const TextStyle(
                                    fontWeight:
                                    FontWeight
                                        .bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// -------- CAPITALIZE HELPER --------
String _cap(String text) {
  return text
      .split(' ')
      .map((e) =>
  e.isEmpty
      ? e
      : e[0].toUpperCase() +
      e.substring(1)
          .toLowerCase())
      .join(' ');
}
