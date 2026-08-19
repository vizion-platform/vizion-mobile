import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient(String server, String clientId, int port) {
  final client = MqttServerClient('wss:///ws', clientId);
  client.port = port;
  client.useWebSocket = true;
  return client;
}
