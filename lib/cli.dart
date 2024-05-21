import 'package:mysql_client/mysql_client.dart';
import 'package:server_nano/server_nano.dart';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final server = Server();

  final conn = await MySQLConnection.createConnection(
    host: '192.168.221.21', //localhost
    port: 3306,
    userName: 'janrey.dumaog',
    password: 'janr3yD', //iTan0ng
    secure: true,
    databaseName: 'dev', // optional
  );

  //connect to database
  await conn.connect();

  server.get('/', (req, res) {
    res.send('MYSQL connected: ${conn.connected}');
  });

  server.get('/sms_eztext', (req, res) async {
    //add delay para dile ma ddos
    await Future.delayed(Duration(milliseconds: 100));

    //check parameters
    if (!req.query.containsKey('mobilenumber') ||
        !req.query.containsKey('message') ||
        !req.query.containsKey('messagefrom') ||
        !req.query.containsKey('priority') ||
        !req.query.containsKey('sendretry') ||
        !req.query.containsKey('token')) {
      res.status(400).send('Bad request, missing parameters');
      return;
    }

    String token = req.query['token']!;

    //md5->eztexttoken = 18ff0affd537aaee9384823a4a472411
    if (token != '18ff0affd537aaee9384823a4a472411') {
      res.status(401).send('Unauthorized');
      return;
    }

    String mobilenumber = req.query['mobilenumber']!;
    String decodePlussign = Uri.decodeComponent('%2B');
    bool is63 = mobilenumber.startsWith(' 63');
    bool is09 = mobilenumber.startsWith('09');

    if ((mobilenumber.length != 13 && is63)) {
      res.status(400).send('Bad request, mobilenumber length +63');
      return;
    } else if (mobilenumber.length != 11 && is09) {
      res.status(400).send('Bad request, mobilenumber length 09');
      return;
    }

    if (!is63 && !is09) {
      res.status(400).send('Bad request, mobilenumber format');
      return;
    }

    String finalMobilenumber =
        is63 ? mobilenumber.replaceRange(0, 1, decodePlussign) : mobilenumber;
    String message = req.query['message']!;
    String messagefrom = req.query['messagefrom']!;
    String priority = req.query['priority']!;
    String sendretry = req.query['sendretry']!;

    try {
      final stmt = await conn.prepare(
        "INSERT INTO outboxsms (mobilenumber, message, messagefrom, messagecreated, messagesendon, priority, sendretry) VALUES (?, ?, ?, ?, ?, ?, ?)",
      );

      final stmtResult = await stmt.execute([
        finalMobilenumber,
        message,
        messagefrom,
        DateTime.now(),
        DateTime.now(),
        priority,
        sendretry
      ]);

      res.status(200).send('${stmtResult.lastInsertID}');
    } catch (e) {
      res.status(200).send(e.toString());
    }
  });

  server.get('/sms_openvox', (req, res) async {
    await Future.delayed(Duration(milliseconds: 100));

    //check parameters
    if (!req.query.containsKey('username') ||
        !req.query.containsKey('password') ||
        !req.query.containsKey('phonenumber') ||
        !req.query.containsKey('message') ||
        !req.query.containsKey('port') ||
        !req.query.containsKey('token')) {
      res.status(400).send('Bad request, missing parameters');
      return;
    }

    String token = req.query['token']!;

    //md5->openvoxtoken = 9c22aa3ab771c997d421b81f63c56360
    if (token != '9c22aa3ab771c997d421b81f63c56360') {
      res.status(401).send('Unauthorized');
      return;
    }

    String phonenumber = req.query['phonenumber']!;
    String decodePlussign = Uri.decodeComponent('%2B');
    bool is63 = phonenumber.startsWith(' 63');
    bool is09 = phonenumber.startsWith('09');

    if ((phonenumber.length != 13 && is63)) {
      res.status(400).send('Bad request, mobilenumber length +63');
      return;
    } else if (phonenumber.length != 11 && is09) {
      res.status(400).send('Bad request, mobilenumber length 09');
      return;
    }

    if (!is63 && !is09) {
      res.status(400).send('Bad request, mobilenumber format');
      return;
    }

    String username = req.query['username']!; //ovsms
    String password = req.query['password']!; //ovSMS@2020
    String finalPhonenumber = is63
        ? phonenumber.replaceRange(0, 1, decodePlussign)
        : phonenumber; //09670266317
    String message = req.query['message']!; //Hello janrey
    String port = req.query['port']!; //1

    final queryParameters = {
      'username': username,
      'password': password,
      'phonenumber': finalPhonenumber,
      'message': message,
      'port': port
    };

    try {
      final uri = Uri.http('172.21.3.18:80', '/sendsms', queryParameters);

      final response = await http.get(uri);

      res.status(200).send(response.body);
    } catch (e) {
      res.status(200).send(e.toString());
    }
  });

  server.listen(port: 3000, serverMode: ServerMode.compatibility);
}
