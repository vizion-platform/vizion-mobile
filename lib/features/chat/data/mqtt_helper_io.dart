import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient(String server, String clientId, int port) {
  // On native platforms MqttServerClient expects the complete WebSocket URI.
  // The previous `wss:///ws` URI had no host, so the connection always failed
  // and the chat fell back to HTTP polling.
  final client = MqttServerClient('wss://$server/ws', clientId);
  client.port = port;
  client.useWebSocket = true;
  return client;
}
