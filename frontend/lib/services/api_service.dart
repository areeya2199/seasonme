import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  //final String baseUrl = "http://192.168.1.162:8000";
  final String baseUrl = "http://172.27.228.186:8000";

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
      answers,
    ).timeout(const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>?> _analyzeImage(
    String imagePath,
    Map<int, String?> answers,
  ) async {
    final url = "$baseUrl/analyze";

    print("Sending image to: $url");

    var request = http.MultipartRequest("POST", Uri.parse(url));

    request.files.add(await http.MultipartFile.fromPath("file", imagePath));

    request.fields["answers"] = jsonEncode(
      answers.map((key, value) => MapEntry(key.toString(), value)),
    );

    final response = await request.send();

    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();

      return jsonDecode(body);
    } else {
      print("API Error: ${response.statusCode}");

      return null;
    }
  }
}
