import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '탄소 챌린지',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// 로그인 페이지
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final hakbunController = TextEditingController();
  final nameController = TextEditingController();

  void _login() async {
    final hakbun = hakbunController.text.trim();
    final name = nameController.text.trim();
    if (hakbun.isEmpty || name.isEmpty) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('hakbun', hakbun);
    await prefs.setString('name', name);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ChallengeSelectionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: hakbunController, decoration: const InputDecoration(labelText: '학번')),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '이름')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text('시작하기')),
          ],
        ),
      ),
    );
  }
}

// 챌린지 선택 페이지
class ChallengeSelectionPage extends StatefulWidget {
  const ChallengeSelectionPage({super.key});
  @override
  State<ChallengeSelectionPage> createState() => _ChallengeSelectionPageState();
}

class _ChallengeSelectionPageState extends State<ChallengeSelectionPage> {
  final challenges = [
    '일회용 컵 대신 텀블러 사용하기',
    '대중교통 이용하기',
    '불필요한 조명 끄기',
    '채식 식사 한 끼 하기',
    '비닐봉투 대신 장바구니 사용하기',
    '난방/에어컨 적정온도 유지',
    '음식 남기지 않기',
  ];
  final carbonValues = [0.2, 0.6, 0.1, 0.4, 0.2, 0.35, 0.3];
  final selected = <int>{};

  @override
  void initState() {
    super.initState();
    _loadSelectedChallenges();
  }

  Future<void> _loadSelectedChallenges() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? saved = prefs.getStringList('selectedChallengeIndexes');
    if (saved != null) {
      setState(() {
        selected.addAll(saved.map(int.parse));
      });
    }
  }

  Future<void> _saveSelectedChallenges() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selectedChallengeIndexes', selected.map((e) => e.toString()).toList());
  }

  void _startChallenge() {
    final selectedChallenges = selected.map((i) => challenges[i]).toList();
    final selectedCarbon = selected.map((i) => carbonValues[i]).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklyChallengePage(
          challenges: selectedChallenges,
          carbonValues: selectedCarbon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('챌린지 선택')),
      body: ListView.builder(
        itemCount: challenges.length,
        itemBuilder: (_, i) => CheckboxListTile(
          title: Text(challenges[i]),
          value: selected.contains(i),
          onChanged: (v) async {
            setState(() {
              if (v!) {
                selected.add(i);
              } else {
                selected.remove(i);
              }
            });
            await _saveSelectedChallenges();
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: selected.isEmpty ? null : _startChallenge,
        label: const Text('시작하기'),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }
}

// 주간 챌린지 체크 페이지
class WeeklyChallengePage extends StatefulWidget {
  final List<String> challenges;
  final List<double> carbonValues;

  const WeeklyChallengePage({
    super.key,
    required this.challenges,
    required this.carbonValues,
  });

  @override
  State<WeeklyChallengePage> createState() => _WeeklyChallengePageState();
}

class _WeeklyChallengePageState extends State<WeeklyChallengePage> {
  late List<List<bool>> checks;
  double totalCarbon = 0;
  final int today = (DateTime.now().weekday + 6) % 7; // 월:0 ~ 일:6

  static const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    checks = List.generate(widget.challenges.length, (_) => List.filled(7, false));
  }

  void _toggleCheck(int i, int day, bool? value) async {
    setState(() {
      checks[i][day] = value ?? false;
    });

    final date = DateTime.now().toIso8601String().split('T').first;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> records = [];

    String? recordJson = prefs.getString('history');
    if (recordJson != null) {
      records = List<Map<String, dynamic>>.from(json.decode(recordJson));
      records.removeWhere((r) =>
          r['date'] == date && r['challenge'] == widget.challenges[i]);
    }

    if (value == true) {
      records.add({
        'date': date,
        'challenge': widget.challenges[i],
        'carbon': widget.carbonValues[i],
        'completed': true,
      });
    }

    await prefs.setString('history', json.encode(records));
    _recalculateTotal(records);
  }

  void _recalculateTotal(List<Map<String, dynamic>> records) {
    double sum = 0;
    for (var r in records) {
      if (r['completed'] == true) sum += r['carbon'];
    }
    setState(() {
      totalCarbon = sum;
    });
  }

  void _goToHistory() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()));
  }

  void _goToLeaderboard() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이번 주 챌린지')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text('총 절감 탄소량: ${totalCarbon.toStringAsFixed(2)}kg',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: Center(child: Text(weekdays[i], style: const TextStyle(fontWeight: FontWeight.bold))),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: widget.challenges.length,
              itemBuilder: (_, i) => Card(
                color: Colors.green[50],
                child: ListTile(
                  title: Text(widget.challenges[i]),
                  subtitle: Row(
                    children: List.generate(7, (day) {
                      return Expanded(
                        child: Checkbox(
                          value: checks[i][day],
                          onChanged: day == today ? (v) => _toggleCheck(i, day, v) : null,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        height: 60,
        color: Colors.green[100],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _goToHistory,
              icon: const Icon(Icons.history),
              label: const Text('지난 기록 보기'),
            ),
            ElevatedButton.icon(
              onPressed: _goToLeaderboard,
              icon: const Icon(Icons.leaderboard),
              label: const Text('리더보드'),
            ),
          ],
        ),
      ),
    );
  }
}

// 기록 보기 페이지
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? recordJson = prefs.getString('history');
    if (recordJson == null) return [];
    return List<Map<String, dynamic>>.from(json.decode(recordJson));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기록 보기')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadHistory(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final records = snapshot.data!;
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (_, i) {
              final r = records[i];
              return ListTile(
                title: Text('${r['date']} - ${r['challenge']}'),
                trailing: Text('${r['completed'] == true ? '+' : '-'} ${r['carbon']}kg'),
              );
            },
          );
        },
      ),
    );
  }
}

// 리더보드 페이지
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  Future<List<Map<String, dynamic>>> _loadLeaderboard() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('history');
    String? name = prefs.getString('name');
    String? hakbun = prefs.getString('hakbun');

    if (historyJson == null || name == null || hakbun == null) return [];

    List<dynamic> raw = json.decode(historyJson);
    double totalCarbon = 0;
    for (var record in raw) {
      if (record['completed'] == true) {
        totalCarbon += record['carbon'];
      }
    }

    return [
      {
        'name': name,
        'hakbun': hakbun,
        'carbon': totalCarbon.toStringAsFixed(2),
      }
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리더보드')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadLeaderboard(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text('${user['name']} (${user['hakbun']})'),
                trailing: Text('${user['carbon']}kg'),
              );
            },
          );
        },
      ),
    );
  }
}
