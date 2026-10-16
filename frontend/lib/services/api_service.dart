import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {

  final String baseUrl = "http://10.0.2.2:8000";
  //final String baseUrl = "http://172.27.228.243:8000";

   Future<String> hello() async {

    final response = await http.get(
      Uri.parse("$baseUrl/")
    );

    if(response.statusCode == 200){
      final data = jsonDecode(response.body);
      return data["message"];
    }

    return "Error";
  }


  Future<Map<String, dynamic>?> analyzeImage(
    String imagePath,
    Map<int, String?> answers,
  ) {
    return _analyzeImage(imagePath, answers).timeout(
      const Duration(seconds: 30),
    );
  }

  Future<Map<String, dynamic>?> _analyzeImage(String imagePath, Map<int, String?> answers,) async {

      final user = AuthService.currentUser;
      if (user == null) {
        throw StateError('Sign in before requesting an analysis');
      }

      // Firebase refreshes an expired cached ID token automatically.
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Unable to obtain a Firebase ID token');
      }

      final url = "$baseUrl/analyze";

  var request = http.MultipartRequest(
    "POST",
    Uri.parse(url),
  );
    request.headers['Authorization'] = 'Bearer $idToken';


    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        imagePath,
      ),
    );

    request.fields["answers"] = jsonEncode(
      answers.map((key, value) => MapEntry(key.toString(), value)),
    );

    final response = await request.send();


    if(response.statusCode == 200){

      final body = await response.stream.bytesToString();

      return jsonDecode(body);

    } else {

      return null;
    }
  }
}
