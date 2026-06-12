import 'dart:convert';
import 'api_client.dart';

class AuthService {
  static Future<bool> login(String email, String password) async {
    try {
      final response = await VizionAPIClient.instance.post('/auth/login', {
        'email': email.trim(),
        'senha': password,
      });

      if (response.statusCode == 200) {
        print('Login Response Body: ${response.body}');
        final data = jsonDecode(response.body);
        
        // Store tokens and tenantId in the API Client
        // Ensure field names match the API (checking both 'token' and 'accessToken')
        VizionAPIClient.instance.setTokens(
          data['token'] ?? data['accessToken'],
          data['refreshToken'],
          data['tenant_id'],
        );
        
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  static Future<bool> deleteCurrentAccount() async {
    try {
      final response = await VizionAPIClient.instance.post('/auth/delete-account', {}); // Assuming endpoint exists based on standard practices, or handle accordingly if endpoint is different
      if (response.statusCode == 200) {
        signOut();
        return true;
      }
      return false;
    } catch (e) {
      print('Delete account error: $e');
      return false;
    }
  }

  static void signOut() {
    // In a real app, clear tokens from storage and reset client
    VizionAPIClient.instance.setTokens('', '', 0);
  }
}