import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Screen Time',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedPeriod = 'Today';
  List<Map<String, dynamic>> appUsageData = [];
  bool isLoading = true;
  double totalScreenTime = 0;

  static const platform = MethodChannel('app_usage_stats');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    setState(() {
      isLoading = true;
    });

    try {
      final List<dynamic> result = await platform.invokeMethod('getUsageStats');

      final List<Map<String, dynamic>> usageStats = result.map((item) {
        final timeInMillis = (item['timeInMillis'] as int).toDouble();
        final hours = (timeInMillis / (1000 * 60 * 60)).floor();
        final minutes = ((timeInMillis / (1000 * 60)) % 60).floor();

        return {
          'name': item['appName'] ?? item['packageName'].toString().split('.').last,
          'packageName': item['packageName'],
          'timeInMillis': timeInMillis,
          'time': '${hours}h ${minutes}m',
          'percentage': timeInMillis / (24 * 60 * 60 * 1000), // Percentage of day
          'color': Colors.primaries[result.indexOf(item) % Colors.primaries.length],
          'icon': Icons.android,
        };
      }).toList();

      // Sort by usage time (highest to lowest)
      usageStats.sort((a, b) => (b['timeInMillis'] as double).compareTo(a['timeInMillis'] as double));

      // Calculate total screen time
      totalScreenTime = usageStats.fold<double>(
          0, (sum, item) => sum + (item['timeInMillis'] as double)
      );

      setState(() {
        appUsageData = usageStats;
        isLoading = false;
      });
    } on PlatformException catch (e) {
      print("Failed to get usage stats: ${e.message}");
      if (e.message?.contains('PERMISSION_DENIED') ?? false) {
        // Show permission error UI
        setState(() {
          isLoading = false;
          appUsageData = [];
        });
      }
    }
  }

  String _formatTotalTime() {
    final hours = (totalScreenTime / (1000 * 60 * 60)).floor();
    final minutes = ((totalScreenTime / (1000 * 60)) % 60).floor();
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Time'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Apps'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildAppsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appUsageData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Permission Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please grant usage access permission',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsageStats,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsageStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildPeriodSelector(),
            _buildTotalTimeCard(),
            _buildUsageSummary(),
            _buildTopAppsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'Today', label: Text('Today')),
          ButtonSegment(value: 'Week', label: Text('Week')),
          ButtonSegment(value: 'Month', label: Text('Month')),
        ],
        selected: {selectedPeriod},
        onSelectionChanged: (Set<String> newSelection) {
          setState(() {
            selectedPeriod = newSelection.first;
          });
        },
      ),
    );
  }

  Widget _buildTotalTimeCard() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _formatTotalTime(),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Total Screen Time ($selectedPeriod)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: totalScreenTime / (24 * 60 * 60 * 1000),
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageSummary() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Apps Used', appUsageData.length.toString(), Icons.apps),
                _buildSummaryItem('Most Used',
                    appUsageData.isNotEmpty ? appUsageData.first['name'].toString().split('.').last : 'N/A',
                    Icons.star),
                _buildSummaryItem('Average Time',
                    _formatAverageTime(),
                    Icons.access_time),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAverageTime() {
    if (appUsageData.isEmpty) return '0h 0m';
    final averageMillis = totalScreenTime / appUsageData.length;
    final hours = (averageMillis / (1000 * 60 * 60)).floor();
    final minutes = ((averageMillis / (1000 * 60)) % 60).floor();
    return '${hours}h ${minutes}m';
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(label),
      ],
    );
  }

  Widget _buildTopAppsSection() {
    if (appUsageData.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Most Used Apps',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...appUsageData.take(3).map((app) => ListTile(
              leading: CircleAvatar(
                backgroundColor: app['color'],
                child: const Icon(Icons.android, color: Colors.white),
              ),
              title: Text(app['name'].toString().split('.').last),
              subtitle: LinearProgressIndicator(
                value: app['percentage'],
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(app['color']),
              ),
              trailing: Text(
                app['time'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAppsTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (appUsageData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'No Usage Data Available',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please grant usage access permission',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsageStats,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsageStats,
      child: ListView.builder(
        itemCount: appUsageData.length,
        padding: const EdgeInsets.all(8.0),
        itemBuilder: (context, index) {
          final app = appUsageData[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: app['color'],
                child: const Icon(Icons.android, color: Colors.white),
              ),
              title: Text(app['name'].toString().split('.').last),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app['packageName']),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: app['percentage'],
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(app['color']),
                  ),
                ],
              ),
              trailing: Text(
                app['time'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}