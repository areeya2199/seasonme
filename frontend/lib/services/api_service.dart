import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  Future<String> hello() async {
    final response = await http.get(Uri.parse("http://10.0.2.2:8000/"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["message"];
    }

    return "Error";
  }
}
