import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Default Supabase URL (kept in source because it's not secret). You may
// replace this with an env var too if you need multiple environments.
const _defaultSupabaseUrl = 'https://qjwnudofsiznvfcgzwuv.supabase.co';

// Prefer compile-time overrides via --dart-define but fall back to a local
// .env file (loaded by flutter_dotenv) so developers can set a private
// .env during development. This keeps secrets out of the repo.
const _supabaseUrlFromDefine = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);
const _supabaseKeyFromDefine = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env if present. This is optional — if you prefer not to use a
  // local .env file, simply provide the key with --dart-define instead.
  await dotenv.load();

  final supabaseUrl = _supabaseUrlFromDefine.isNotEmpty
      ? _supabaseUrlFromDefine
      : (dotenv.env['SUPABASE_URL'] ?? _defaultSupabaseUrl);

  final supabaseKey = _supabaseKeyFromDefine.isNotEmpty
      ? _supabaseKeyFromDefine
      : (dotenv.env['SUPABASE_KEY'] ?? '');

  if (supabaseKey.isEmpty) {
    // Fail early so the developer knows to provide the key.
    throw Exception(
      'SUPABASE_KEY is not defined. Provide it using one of the following:\n'
      '  - flutter run --dart-define=SUPABASE_KEY="your_anon_key_here"\n'
      '  - set SUPABASE_KEY in your environment and use the VS Code launch config (see README)\n'
      '  - create a local .env file with SUPABASE_KEY and optionally SUPABASE_URL (see .env.example)',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  // Helpful debug-only log to confirm initialization at runtime.
  // Runs only in debug mode and avoids printing secrets.
  // Example output (debug only): "Supabase initialized at https://...supabase.co"
  assert(() {
    debugPrint('Supabase initialized at $supabaseUrl');
    return true;
  }());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
