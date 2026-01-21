import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class TranscriptionService {
  Future<String?> transcribeAudio(String audioFilePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/transcription'),
      );
      request.headers.addAll(ApiConfig.defaultHeaders);
      request.files.add(
        await http.MultipartFile.fromPath('audio', audioFilePath),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = json.decode(responseBody);
        return data['transcription'];
      } else {
        throw Exception(
          'Erreur lors de la transcription: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Erreur TranscriptionService.transcribeAudio: $e');
      return null;
    }
  }
}
