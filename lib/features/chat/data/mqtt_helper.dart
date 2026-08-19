import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_helper_io.dart'
    if (dart.library.js_interop) 'mqtt_helper_web.dart'
    if (dart.library.html) 'mqtt_helper_web.dart' as helper;

MqttClient createMqttClient(String server, String clientId, int port) =>
    helper.createMqttClient(server, clientId, port);
