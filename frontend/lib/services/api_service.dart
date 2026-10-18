import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'analysis_input.dart';
import 'auth_service.dart';

class ApiService {
  final http.Client? _client;
  final Future<String?> Function()? _idTokenProvider;

  ApiService({http.Client? client, Future<String?> Function()? idTokenProvider})
    : _client = client,
      _idTokenProvider = idTokenProvider;

  final String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  Future<String> hello() async {
    final response = await http.get(Uri.parse("$baseUrl/"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["message"];
    }

    return "Error";
  }

  Future<Map<String, dynamic>?> analyzeImage(
    String imagePath,
    Map<int, String?> answers,
  ) {
    return _analyzeImage(
      imagePath,
      Map<int, String?>.from(answers),
    ).timeout(const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>?> _analyzeImage(
    String imagePath,
    Map<int, String?> answers,
  ) async {
    AnalysisInput.validateAnswers(answers);
    final imageBytes = await AnalysisInput.validatePhoto(imagePath);

    // Firebase refreshes an expired cached ID token automatically.
    final String? idToken;
    if (_idTokenProvider != null) {
      idToken = await _idTokenProvider();
    } else {
      final user = AuthService.currentUser;
      if (user == null) {
        throw StateError('Sign in before requesting an analysis');
      }
      idToken = await user.getIdToken();
    }
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Unable to obtain a Firebase ID token');
    }

    final url = "$baseUrl/analyze";

    var request = http.MultipartRequest("POST", Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $idToken';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: File(imagePath).uri.pathSegments.last,
      ),
    );

    request.fields["answers"] = jsonEncode(
      answers.map((key, value) => MapEntry(key.toString(), value)),
    );

    final response = await (_client?.send(request) ?? request.send());

    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();

      return jsonDecode(body);
    } else if (response.statusCode == 422) {
      await response.stream.drain<void>();
      throw const AnalysisInputException(
        'Your answers could not be accepted. Please check question 4 and try again.',
      );
    } else {
      await response.stream.drain<void>();
      return null;
    }
  }
}
