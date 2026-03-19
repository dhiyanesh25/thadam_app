import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────
//  DESIGN TOKENS  (matches record_page.dart)
// ─────────────────────────────────────────────────────────────
class _T {
  static const navy      = Color(0xFF0D1B2A);
  static const navyLight = Color(0xFF1B2E42);
  static const teal      = Color(0xFF0A9396);
  static const tealLight = Color(0xFFD9F0F1);
  static const accent    = Color(0xFF94D2BD);
  static const surface   = Color(0xFFF8FAFB);
  static const card      = Color(0xFFFFFFFF);
  static const border    = Color(0xFFE4EAF0);
  static const textPri   = Color(0xFF0D1B2A);
  static const textSub   = Color(0xFF6B7A8D);
  static const red       = Color(0xFFE63946);
  static const orange    = Color(0xFFF4A261);
  static const green     = Color(0xFF2DC653);
  static const amber     = Color(0xFFFFC300);

  static InputDecoration inputDec(String label,
      {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: textSub)
            : null,
        labelStyle: const TextStyle(color: textSub, fontSize: 14),
        hintStyle: TextStyle(color: textSub.withOpacity(0.6), fontSize: 14),
        filled: true,
        fillColor: surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border, width: 1.2)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border, width: 1.2)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: teal, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: red, width: 1.2)),
      );
}

// ─────────────────────────────────────────────────────────────
//  SECTION LABEL
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 6),
    child: Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: _T.textSub)),
  );
}

// ─────────────────────────────────────────────────────────────
//  SHARED CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────
Future<bool?> _confirmDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  bool danger = false,
}) =>
    showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _T.red.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: _T.red, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _T.textPri))),
              ]),
              const SizedBox(height: 16),
              Text(body,
                  style: const TextStyle(
                      fontSize: 14, color: _T.textSub, height: 1.6)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _T.textSub,
                          side: const BorderSide(color: _T.border, width: 1.2),
                          padding:
                          const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: const Text('Cancel',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    )),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                          danger ? _T.red : _T.teal,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                          const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      child: Text(confirmLabel,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    )),
              ]),
            ],
          ),
        ),
      ),
    );

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

  // =================== LOCAL AI NOTE GENERATION ===================
  String generateAiNote({
    required String domain,
    required String goal,
    required int rating,
  }) {
    final Map<int, Map<String, String>> ratingDescriptors = {
      1: {
        'performance': 'struggled significantly',
        'support': 'requires intensive one-on-one support',
        'trend': 'below baseline performance observed',
      },
      2: {
        'performance': 'performed at baseline level',
        'support': 'requires consistent adult prompting',
        'trend': 'baseline engagement noted',
      },
      3: {
        'performance': 'showed early signs of understanding',
        'support': 'required frequent prompts to begin',
        'trend': 'beginning to engage with the task',
      },
      4: {
        'performance': 'demonstrated gradual improvement',
        'support': 'needed occasional reminders',
        'trend': 'progressing steadily toward the goal',
      },
      5: {
        'performance': 'performed with minimal support',
        'support': 'required only light prompting',
        'trend': 'nearly achieved the target independently',
      },
      6: {
        'performance': 'successfully achieved the goal',
        'support': 'worked independently without prompts',
        'trend': 'goal fully achieved today',
      },
      7: {
        'performance': 'consistently retained the skill',
        'support': 'demonstrated mastery with no support needed',
        'trend': 'skill is retained and generalized',
      },
    };

    final Map<String, String> domainActions = {
      'Attention And Focus (AF)': 'maintaining attention during',
      'Communication Support (CS)': 'communicating effectively during',
      'Emotional Regulation (ER)': 'managing emotions throughout',
      'Sensory Regulation (SR)': 'regulating sensory responses in',
      'Impulsivity & Hyperactivity (IH)': 'managing impulse control during',
      'Task Initiation & Completion (TIC)': 'initiating and completing',
      'Transition Between Activities (TA)': 'transitioning smoothly through',
      'Social Interactions (SI)': 'engaging socially during',
      'Collaboration With Adults (CA)': 'collaborating with adults in',
      'Strength Based Appreciation (SBA)': 'demonstrating strengths in',
      'literacy': 'applying literacy skills during',
      'reading': 'demonstrating reading skills in',
      'writing': 'practising writing during',
      'adl': 'performing daily living tasks in',
      'therapy': 'engaging in therapeutic activities for',
      'math': 'applying numeracy skills in',
      'communication': 'communicating effectively during',
      'motor': 'performing motor activities in',
      'social': 'participating socially in',
    };

    final desc = ratingDescriptors[rating] ?? ratingDescriptors[4]!;

    String domainPhrase = 'working on';
    final domainLower = domain.toLowerCase();
    for (final key in domainActions.keys) {
      if (domainLower.contains(key.toLowerCase()) ||
          key.toLowerCase().contains(domainLower)) {
        domainPhrase = domainActions[key]!;
        break;
      }
    }

    final cleanGoal = goal.isNotEmpty
        ? goal[0].toLowerCase() + goal.substring(1)
        : 'assigned activity';

    if (rating <= 2) {
      return "Student ${desc['performance']} ${domainPhrase} $cleanGoal and ${desc['support']}.";
    } else if (rating <= 4) {
      return "Student ${desc['performance']} — ${desc['trend']} while ${domainPhrase} $cleanGoal.";
    } else if (rating <= 5) {
      return "Student ${desc['performance']} — ${desc['trend']} in $cleanGoal with ${desc['support']}.";
    } else {
      return "Student ${desc['performance']} in $cleanGoal — ${desc['trend']}.";
    }
  }

  @override
  void initState() {
    super.initState();
    loadSuggestions();
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  List<String> domainSuggestions = [];
  List<String> goalSuggestions = [];

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
  String? entryType;

  final TextEditingController domainController = TextEditingController();
  final TextEditingController goalController = TextEditingController();

  bool get isParent => widget.userRole.toLowerCase() == 'parent';

  Future<void> loadSuggestions() async {
    final snapshot = await firestore.collectionGroup('records').get();
    final Set<String> domains = {};
    final Set<String> goals = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['entryType'] != "Behaviour") {
        if (data['areaOfSupport'] != null) domains.add(data['areaOfSupport']);
        if (data['challenge'] != null) goals.add(data['challenge']);
      }
    }

    setState(() {
      domainSuggestions = domains.toList();
      goalSuggestions = goals.toList();
    });
  }

  Color _ratingColor(int rating) {
    if (rating >= 6) return _T.green;
    if (rating == 4) return _T.orange;
    return _T.red;
  }

  String _label(int v) {
    switch (v) {
      case 1: return 'Below Baseline';
      case 2: return 'Baseline';
      case 3: return '25% - Beginning';
      case 4: return '50% - Improving';
      case 5: return '75% - Nearly Achieved';
      case 6: return 'Achieved';
      case 7: return 'Retained';
      default: return '';
    }
  }

  // =================== ADD RECORD ===================
  Future<void> _addRecordDialog() async {
    if (isParent) return;

    selectedArea = null;
    selectedChallenge = null;
    entryType = null;
    domainController.clear();
    goalController.clear();

    final formKey = GlobalKey<FormState>();
    double rating = 0;
    final TextEditingController noteController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
                    decoration: const BoxDecoration(
                        color: _T.navy,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20))),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_rounded,
                            color: _T.accent, size: 26),
                        const SizedBox(width: 12),
                        const Text('Add Daily Observation',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close,
                                color: Colors.white54, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints()),
                      ],
                    ),
                  ),

                  // ── Body ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // STEP 1: ENTRY TYPE
                            if (entryType == null) ...[
                              const _SectionLabel('ENTRY TYPE'),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: ["Behaviour", "Literacy", "ADL", "Therapy"]
                                    .map((e) => ElevatedButton(
                                  onPressed: () => setStateDialog(() => entryType = e),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _T.teal,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8)),
                                  ),
                                  child: Text(e, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                ))
                                    .toList(),
                              ),
                              const SizedBox(height: 24),
                            ]
                            // STEP 2: BEHAVIOUR
                            else if (entryType == "Behaviour") ...[
                              const _SectionLabel('AREA OF SUPPORT'),
                              DropdownButtonFormField<String>(
                                value: selectedArea,
                                items: challengeOptions.keys
                                    .map((area) => DropdownMenuItem(
                                    value: area, child: Text(area, style: const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (val) => setStateDialog(() {
                                  selectedArea = val;
                                  selectedChallenge = null;
                                }),
                                decoration: _T.inputDec('Area Of Support'),
                                validator: (val) =>
                                val == null ? 'Select Area' : null,
                              ),
                              const SizedBox(height: 16),
                              const _SectionLabel('CHALLENGE OBSERVED'),
                              DropdownButtonFormField<String>(
                                value: selectedChallenge,
                                items: (selectedArea != null
                                    ? challengeOptions[selectedArea]!
                                    : [])
                                    .map((c) => DropdownMenuItem<String>(
                                    value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                                    .toList(),
                                onChanged: (val) =>
                                    setStateDialog(() => selectedChallenge = val),
                                decoration: _T.inputDec('Challenge Observed'),
                                validator: (val) =>
                                val == null ? 'Select Challenge' : null,
                              ),
                            ]
                            // STEP 3: LITERACY / ADL / THERAPY
                            else ...[
                                const _SectionLabel('DOMAIN'),
                                Autocomplete<String>(
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.length < 3)
                                      return const Iterable<String>.empty();
                                    return domainSuggestions.where((option) =>
                                        option.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase()));
                                  },
                                  onSelected: (selection) =>
                                  domainController.text = selection,
                                  fieldViewBuilder:
                                      (context, controller, focusNode, onEditingComplete) {
                                    controller.text = domainController.text;
                                    controller.addListener(() =>
                                    domainController.text = controller.text);
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration:
                                      _T.inputDec("Domain"),
                                      validator: (v) =>
                                      v!.isEmpty ? "Enter Domain" : null,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                const _SectionLabel('GOAL'),
                                Autocomplete<String>(
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text.length < 3)
                                      return const Iterable<String>.empty();
                                    return goalSuggestions.where((option) =>
                                        option.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase()));
                                  },
                                  onSelected: (selection) =>
                                  goalController.text = selection,
                                  fieldViewBuilder:
                                      (context, controller, focusNode, onEditingComplete) {
                                    controller.text = goalController.text;
                                    controller.addListener(() =>
                                    goalController.text = controller.text);
                                    return TextFormField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: _T.inputDec("Goal"),
                                      validator: (v) =>
                                      v!.isEmpty ? "Enter Goal" : null,
                                    );
                                  },
                                ),
                              ],

                            const SizedBox(height: 24),
                            const _SectionLabel('IMPACT LEVEL TODAY'),
                            RatingBar.builder(
                              initialRating: rating,
                              minRating: 1,
                              itemCount: 7,
                              allowHalfRating: false,
                              itemBuilder: (_, __) =>
                              const Icon(Icons.star, color: _T.amber),
                              onRatingUpdate: (r) => setStateDialog(() => rating = r),
                            ),
                            const SizedBox(height: 24),

                            const _SectionLabel('TEACHER OBSERVATION'),
                            TextFormField(
                              controller: noteController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: "Add Note (Optional)",
                                hintText:
                                "Describe behavior, progress, or concerns...",
                                filled: true,
                                fillColor: _T.surface,
                                labelStyle: const TextStyle(fontSize: 14, color: _T.textSub),
                                hintStyle: const TextStyle(fontSize: 14, color: _T.textSub),
                                border: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    borderSide:
                                    const BorderSide(color: _T.border, width: 1.2)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    borderSide:
                                    const BorderSide(color: _T.border, width: 1.2)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: _T.teal, width: 2)),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Footer ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    decoration: BoxDecoration(
                        color: _T.surface,
                        border: const Border(
                            top: BorderSide(color: _T.border, width: 1.2)),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20))),
                    child: Row(
                      children: [
                        Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: _T.textSub,
                                  side: const BorderSide(color: _T.border, width: 1.2),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10))),
                              child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            )),
                        const SizedBox(width: 12),
                        Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _T.teal,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10))),
                              onPressed: () async {
                                if (!formKey.currentState!.validate())
                                  return;
                                if (rating == 0) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Please select a rating",
                                          style: TextStyle(fontSize: 14)),
                                      behavior: SnackBarBehavior
                                          .floating,
                                      backgroundColor: _T.navy,
                                    ),
                                  );
                                  return;
                                }

                                final currentUser = auth.currentUser!;
                                String finalNote =
                                noteController.text.trim();
                                bool aiGenerated = false;

                                if (finalNote.isEmpty) {
                                  finalNote = generateAiNote(
                                    domain: (entryType ==
                                        "Behaviour")
                                        ? selectedArea ?? ""
                                        : domainController.text,
                                    goal: (entryType ==
                                        "Behaviour")
                                        ? selectedChallenge ?? ""
                                        : goalController.text,
                                    rating: rating.toInt(),
                                  );
                                  aiGenerated = true;
                                }

                                await firestore
                                    .collection('students')
                                    .doc(widget.studentId)
                                    .collection('records')
                                    .add({
                                  'entryType': entryType ?? "Behaviour",
                                  'areaOfSupport': (entryType ==
                                      "Behaviour")
                                      ? _cap(selectedArea ?? "Unknown")
                                      : domainController.text.trim(),
                                  'challenge': (entryType ==
                                      "Behaviour")
                                      ? _cap(selectedChallenge ?? "Unknown")
                                      : goalController.text.trim(),
                                  'rating': rating.toInt(),
                                  'date': DateFormat('yyyy-MM-dd')
                                      .format(DateTime.now()),
                                  'timestamp':
                                  FieldValue.serverTimestamp(),
                                  'enteredByUid': currentUser.uid,
                                  'enteredByName':
                                  currentUser.email ?? 'Staff',
                                  'studentId': widget.studentId,
                                  'studentName': widget.studentName,
                                  'teacherNote': finalNote,
                                  'aiGenerated': aiGenerated,
                                });

                                Navigator.pop(context);
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =================== UPDATE RATING (NEW ENTRY) ===================
  Future<void> _updateRatingDialog(String docId, int currentRating) async {
    if (isParent) return;

    double newRating = currentRating.toDouble();
    DateTime selectedDate = DateTime.now();
    final TextEditingController noteController = TextEditingController();

    final existingDoc = await firestore
        .collection('students')
        .doc(widget.studentId)
        .collection('records')
        .doc(docId)
        .get();

    final existingData = existingDoc.data() as Map<String, dynamic>;
    final existingChallenge = existingData['challenge'];
    final existingArea = existingData['areaOfSupport'];

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
                    decoration: const BoxDecoration(
                        color: _T.navy,
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20))),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded,
                            color: _T.accent, size: 26),
                        const SizedBox(width: 12),
                        const Text('Update Rating',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close,
                                color: Colors.white54, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints()),
                      ],
                    ),
                  ),

                  // ── Body ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel('SELECT DATE'),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                builder: (c, child) => Theme(
                                    data:
                                    ThemeData.light().copyWith(
                                        colorScheme:
                                        const ColorScheme.light(
                                            primary: _T.teal)),
                                    child: child!),
                              );
                              if (picked != null)
                                setStateDialog(() => selectedDate = picked);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                  color: _T.surface,
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  border: Border.all(color: _T.border, width: 1.2)),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined,
                                      size: 18, color: _T.teal),
                                  const SizedBox(width: 12),
                                  Text(
                                      DateFormat('dd MMM yyyy')
                                          .format(selectedDate),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  const Spacer(),
                                  const Icon(Icons.chevron_right,
                                      size: 20, color: _T.textSub),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const _SectionLabel('SELECT RATING'),
                          RatingBar.builder(
                            initialRating: newRating,
                            minRating: 1,
                            itemCount: 7,
                            allowHalfRating: false,
                            itemBuilder: (_, __) =>
                            const Icon(Icons.star, color: _T.amber),
                            onRatingUpdate: (r) =>
                                setStateDialog(() => newRating = r),
                          ),
                          const SizedBox(height: 24),
                          const _SectionLabel('TEACHER OBSERVATION'),
                          TextFormField(
                            controller: noteController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: "Add Note (Optional)",
                              filled: true,
                              fillColor: _T.surface,
                              labelStyle: const TextStyle(fontSize: 14, color: _T.textSub),
                              border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  borderSide:
                                  const BorderSide(color: _T.border, width: 1.2)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  borderSide:
                                  const BorderSide(color: _T.border, width: 1.2)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: _T.teal, width: 2)),
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Footer ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    decoration: BoxDecoration(
                        color: _T.surface,
                        border: const Border(
                            top: BorderSide(color: _T.border, width: 1.2)),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20))),
                    child: Row(
                      children: [
                        Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: _T.textSub,
                                  side: const BorderSide(color: _T.border, width: 1.2),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10))),
                              child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            )),
                        const SizedBox(width: 12),
                        Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _T.teal,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10))),
                              onPressed: () async {
                                final currentUser = auth.currentUser!;
                                String finalNote =
                                noteController.text.trim();
                                bool aiGenerated = false;

                                if (finalNote.isEmpty) {
                                  finalNote = generateAiNote(
                                    domain: existingArea ?? "",
                                    goal: existingChallenge ?? "",
                                    rating: newRating.toInt(),
                                  );
                                  aiGenerated = true;
                                }

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
                                  'entryType':
                                  existingData['entryType'] ??
                                      "Behaviour",
                                  'enteredByUid': currentUser.uid,
                                  'enteredByName':
                                  currentUser.email ?? 'Staff',
                                  'studentId': widget.studentId,
                                  'studentName': widget.studentName,
                                  'teacherNote': finalNote,
                                  'aiGenerated': aiGenerated,
                                });

                                Navigator.pop(context);
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =================== DELETE ===================
  Future<void> _deleteRecord(String docId) async {
    final confirm = await _confirmDialog(
      context: context,
      title: 'Delete Entry',
      body:
      'This will remove only this specific entry. Other progress records for this challenge will remain.',
      confirmLabel: 'Delete Entry',
      danger: true,
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
      backgroundColor: _T.surface,
      appBar: AppBar(
        title: Text(widget.studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        backgroundColor: _T.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (!isParent)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _addRecordDialog,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _T.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('students')
            .doc(widget.studentId)
            .collection('records')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(fontSize: 15)));
          if (!snapshot.hasData)
            return const Center(
                child: CircularProgressIndicator(color: _T.teal));

          final allRecords = snapshot.data!.docs;

          Map<String, QueryDocumentSnapshot> latestByChallenge = {};
          for (var doc in allRecords) {
            final data = doc.data() as Map<String, dynamic>;
            final key =
                "${data['entryType'] ?? 'Behaviour'} - ${data['challenge'] ?? 'Unknown'}";
            if (!latestByChallenge.containsKey(key)) {
              latestByChallenge[key] = doc;
            }
          }

          final records = latestByChallenge.values.toList();
          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_rounded,
                      size: 60,
                      color: _T.textSub.withOpacity(0.35)),
                  const SizedBox(height: 14),
                  const Text('No observations yet',
                      style: TextStyle(
                          color: _T.textSub, fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final doc = records[index];
              final data = doc.data() as Map<String, dynamic>;
              final rating = data['rating'] ?? 0;
              final note = data['teacherNote'] ?? "No teacher note added";
              final bool aiGenerated = data['aiGenerated'] ?? false;
              final type = data['entryType'] ?? "Behaviour";

              return Material(
                color: _T.card,
                borderRadius: BorderRadius.circular(14),
                elevation: 0,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChallengeProgressPage(
                          studentId: widget.studentId,
                          challenge: data['challenge'] ?? '',
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _T.border, width: 1.2),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header row ──
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _T.tealLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                type,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _T.teal,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (!isParent)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    size: 20, color: _T.textSub),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(10)),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _updateRatingDialog(doc.id, rating);
                                  } else if (value == 'delete') {
                                    _deleteRecord(doc.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit_rounded,
                                          size: 18, color: _T.textSub),
                                      SizedBox(width: 10),
                                      Text('Update Rating', style: TextStyle(fontSize: 14)),
                                    ]),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete_outline_rounded,
                                          size: 18, color: _T.red),
                                      SizedBox(width: 10),
                                      Text('Delete Entry',
                                          style: TextStyle(
                                              color: _T.red, fontSize: 14)),
                                    ]),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Challenge & Area ──
                        Text(
                          data['challenge'] ?? '',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data['areaOfSupport'] ?? '',
                          style: const TextStyle(
                              fontSize: 14, color: _T.textSub),
                        ),

                        const SizedBox(height: 14),

                        // ── Rating ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _ratingColor(rating)
                                .withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "$rating",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: _ratingColor(rating),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _label(rating),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: _ratingColor(rating),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Teacher Note ──
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _T.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _T.border, width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    "Teacher Note",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _T.textPri,
                                    ),
                                  ),
                                  if (aiGenerated) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _T.tealLight,
                                        borderRadius:
                                        BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "AI",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _T.teal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                note,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _T.textSub,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Date + Tap hint ──
                        Row(
                          children: [
                            Text(
                              "Date: ${data['date'] ?? ''}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: _T.textSub,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              "Tap to view all →",
                              style: TextStyle(
                                fontSize: 12,
                                color: _T.teal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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

// =================== CHALLENGE PROGRESS PAGE ===================
class ChallengeProgressPage extends StatefulWidget {
  final String studentId;
  final String challenge;

  const ChallengeProgressPage({
    super.key,
    required this.studentId,
    required this.challenge,
  });

  @override
  State<ChallengeProgressPage> createState() => _ChallengeProgressPageState();
}

class _ChallengeProgressPageState extends State<ChallengeProgressPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  String _label(int v) {
    switch (v) {
      case 1:
        return 'Below Baseline';
      case 2:
        return 'Baseline';
      case 3:
        return '25% - Beginning';
      case 4:
        return '50% - Improving';
      case 5:
        return '75% - Nearly Achieved';
      case 6:
        return 'Achieved';
      case 7:
        return 'Retained';
      default:
        return '';
    }
  }

  Color _ratingColor(int rating) {
    if (rating >= 6) return _T.green;
    if (rating >= 4) return _T.orange;
    return _T.red;
  }

  // =================== EDIT PROGRESS ENTRY (in-place update) ===================
  Future<void> _editProgressEntry({
    required String docId,
    required int currentRating,
    required String currentNote,
    required bool currentAiGenerated,
    required String existingArea,
    required String existingChallenge,
    required String existingEntryType,
  }) async {
    double editedRating = currentRating.toDouble();
    final noteController = TextEditingController(text: currentNote);

    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 16, 18),
                    decoration: const BoxDecoration(
                        color: _T.navy,
                        borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note_rounded,
                            color: _T.accent, size: 26),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Edit Entry',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close,
                                color: Colors.white54, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints()),
                      ],
                    ),
                  ),

                  // ── Body ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Context chip (read-only)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: _T.tealLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _T.teal.withOpacity(0.3),
                                  width: 1.2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.label_outline_rounded,
                                    size: 16, color: _T.teal),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    existingChallenge,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _T.teal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                          const _SectionLabel('EDIT RATING'),
                          RatingBar.builder(
                            initialRating: editedRating,
                            minRating: 1,
                            itemCount: 7,
                            allowHalfRating: false,
                            itemBuilder: (_, __) =>
                            const Icon(Icons.star, color: _T.amber),
                            onRatingUpdate: (r) =>
                                setStateDialog(() => editedRating = r),
                          ),

                          // Live rating label
                          if (editedRating > 0) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _ratingColor(editedRating.toInt())
                                    .withOpacity(0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${editedRating.toInt()}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: _ratingColor(editedRating.toInt()),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _label(editedRating.toInt()),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _ratingColor(editedRating.toInt()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Note field — with AI banner if applicable
                          Row(
                            children: [
                              const _SectionLabel('EDIT NOTE'),
                              if (currentAiGenerated) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _T.tealLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded,
                                          size: 11, color: _T.teal),
                                      SizedBox(width: 4),
                                      Text(
                                        "AI Generated — review before saving",
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: _T.teal),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          TextFormField(
                            controller: noteController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText:
                              "Describe behaviour, progress, or concerns...",
                              filled: true,
                              fillColor: currentAiGenerated
                                  ? _T.tealLight.withOpacity(0.5)
                                  : _T.surface,
                              hintStyle: const TextStyle(
                                  fontSize: 14, color: _T.textSub),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: _T.border, width: 1.2)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: currentAiGenerated
                                        ? _T.teal.withOpacity(0.4)
                                        : _T.border,
                                    width: 1.2,
                                  )),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: _T.teal, width: 2)),
                            ),
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Footer ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    decoration: BoxDecoration(
                        color: _T.surface,
                        border: const Border(
                            top: BorderSide(color: _T.border, width: 1.2)),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20))),
                    child: Row(
                      children: [
                        Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: _T.textSub,
                                  side: const BorderSide(
                                      color: _T.border, width: 1.2),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10))),
                              child: const Text('Cancel',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            )),
                        const SizedBox(width: 12),
                        Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_rounded, size: 20),
                              label: const Text('Save Changes',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: _T.teal,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius.circular(10))),
                              onPressed: () async {
                                final updatedNote =
                                noteController.text.trim();
                                // If teacher edited the note, mark aiGenerated = false
                                final bool stillAi =
                                    currentAiGenerated && updatedNote == currentNote;

                                await firestore
                                    .collection('students')
                                    .doc(widget.studentId)
                                    .collection('records')
                                    .doc(docId)
                                    .update({
                                  'rating': editedRating.toInt(),
                                  'teacherNote': updatedNote.isEmpty
                                      ? currentNote
                                      : updatedNote,
                                  'aiGenerated': stillAi,
                                  'editedAt':
                                  FieldValue.serverTimestamp(),
                                });

                                if (context.mounted) Navigator.pop(context);
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteProgressEntry(String docId) async {
    final confirm = await _confirmDialog(
      context: context,
      title: 'Delete Entry',
      body: 'Only this date entry will be removed. All other progress records remain.',
      confirmLabel: 'Delete Entry',
      danger: true,
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

  Future<void> _deleteAllProgress(List<QueryDocumentSnapshot> docs) async {
    final confirm = await _confirmDialog(
      context: context,
      title: 'Delete All Progress',
      body:
      'This will permanently delete ALL ${docs.length} progress entries for "${widget.challenge}".\n\nThis cannot be undone.',
      confirmLabel: 'Delete All',
      danger: true,
    );

    if (confirm != true) return;

    final batch = firestore.batch();
    for (final doc in docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.surface,
      appBar: AppBar(
        title: Text(widget.challenge, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        backgroundColor: _T.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('students')
            .doc(widget.studentId)
            .collection('records')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(fontSize: 15)));
          }
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _T.teal));
          }

          final allDocs = snapshot.data!.docs;

          final docs = allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return d['challenge'] == widget.challenge;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_rounded,
                      size: 60,
                      color: _T.textSub.withOpacity(0.35)),
                  const SizedBox(height: 14),
                  const Text('No progress data',
                      style: TextStyle(
                          color: _T.textSub, fontSize: 16, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Info bar ──
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _T.tealLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _T.teal.withOpacity(0.3), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_rounded,
                          color: _T.teal, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "${docs.length} ${docs.length == 1 ? 'entry' : 'entries'} • newest first",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _T.teal,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _deleteAllProgress(docs),
                        icon: const Icon(Icons.delete_forever,
                            color: _T.red, size: 18),
                        label: const Text(
                          "Delete All",
                          style: TextStyle(
                              color: _T.red, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Column headers ──
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _T.navy.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _T.border, width: 1.2),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text("Date",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _T.textPri,
                            )),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text("Rating",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _T.textPri,
                            )),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text("Teacher Note",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _T.textPri,
                            )),
                      ),
                      // Space for the two action buttons
                      SizedBox(width: 64),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Entry rows ──
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final d = doc.data() as Map<String, dynamic>;
                      final note = d['teacherNote'] ?? "No note added";
                      final bool aiGenerated = d['aiGenerated'] ?? false;
                      final int rating = d['rating'] ?? 0;
                      final bool isLatest = i == 0;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isLatest
                              ? _T.green.withOpacity(0.08)
                              : _T.card,
                          border: Border.all(
                            color: isLatest
                                ? _T.green.withOpacity(0.3)
                                : _T.border,
                            width: 1.2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Date + Latest badge ──
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['date'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _T.textPri,
                                    ),
                                  ),
                                  if (isLatest)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _T.green.withOpacity(0.15),
                                          borderRadius:
                                          BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          "Latest",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _T.green,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // ── Rating ──
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$rating",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: _ratingColor(rating),
                                    ),
                                  ),
                                  Text(
                                    _label(rating),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _ratingColor(rating),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Note + AI badge ──
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          note,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _T.textSub,
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // AI badge shown below note text
                                  if (aiGenerated)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _T.tealLight,
                                          borderRadius:
                                          BorderRadius.circular(3),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.auto_awesome_rounded,
                                                size: 9, color: _T.teal),
                                            SizedBox(width: 3),
                                            Text(
                                              "AI",
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: _T.teal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // ── Action buttons: Edit + Delete ──
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit button
                                Tooltip(
                                  message: "Edit rating & note",
                                  child: InkWell(
                                    onTap: () => _editProgressEntry(
                                      docId: doc.id,
                                      currentRating: rating,
                                      currentNote: note,
                                      currentAiGenerated: aiGenerated,
                                      existingArea:
                                      d['areaOfSupport'] ?? '',
                                      existingChallenge:
                                      d['challenge'] ?? '',
                                      existingEntryType:
                                      d['entryType'] ?? 'Behaviour',
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: _T.teal.withOpacity(0.10),
                                        borderRadius:
                                        BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: _T.teal,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Delete button
                                Tooltip(
                                  message: "Delete this entry",
                                  child: InkWell(
                                    onTap: () =>
                                        _deleteProgressEntry(doc.id),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: _T.red.withOpacity(0.10),
                                        borderRadius:
                                        BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        size: 16,
                                        color: _T.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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

// -------- CAPITALIZE HELPER --------
String _cap(String text) {
  return text
      .split(' ')
      .map((e) =>
  e.isEmpty ? e : e[0].toUpperCase() + e.substring(1).toLowerCase())
      .join(' ');
}