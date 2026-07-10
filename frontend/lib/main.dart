import 'package:flutter/material.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  String message = "Loading...";

  @override
  void initState() {
    super.initState();

    ApiService().hello().then((value) {
      setState(() {
        message = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("SeasonMe"),
      ),
      body: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }
}