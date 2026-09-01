import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient(String server, String clientId, int port) {
  final client = MqttBrowserClient('wss://$server/ws', clientId);
  client.port = port;
  return client;
}
