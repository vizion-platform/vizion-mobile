import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// [server] é o host do broker; a conexão usa WebSocket seguro (wss) no caminho /ws.
MqttClient createMqttClient(String server, String clientId, int port) {
  final client = MqttServerClient.withPort('wss://$server/ws', clientId, port);
  client.useWebSocket = true;
  return client;
}
