import 'package:mysql_client/mysql_client.dart';
import 'package:server_nano/server_nano.dart';

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

    String parsedToken = Uri.encodeFull(req.query['token']!);

    //md5->eztexttoken = 18ff0affd537aaee9384823a4a472411
    if (parsedToken != '18ff0affd537aaee9384823a4a472411') {
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

    res.status(201).send('ok! lastId->${stmtResult.lastInsertID}');
    // res.status(201).send('ok! ${mobilenumber.length}');
  });

  server.get('/sms_openvox', (req, res) {
    res.send('Test sms_openvox');
  });

  server.listen(port: 3000, serverMode: ServerMode.compatibility);
}
