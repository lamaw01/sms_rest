import 'package:mysql_client/mysql_client.dart';
import 'package:server_nano/server_nano.dart';
import 'package:http/http.dart' as http;

// phonenumber -> required
// message -> required
// token -> required
// servicetype -> optional, default null. 0=eztext, 1=openvox
// messagefrom -> optional, only for eztext
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

  server.get('/sendsms', (req, res) async {
    //insert result
    void insertApiLog(String apiResponse) async {
      try {
        final clientInfo = req.input.connectionInfo;
        String cilentIp = clientInfo?.remoteAddress.address ?? '';

        //make insert query
        final stmt = await conn
            .prepare("INSERT INTO api_log (reply, sender) VALUES (?, ?)");

        await stmt.execute([apiResponse, cilentIp]);
      } catch (e) {
        print(e.toString());
      }
    }

    //add delay
    await Future.delayed(Duration(milliseconds: 100));

    //check parameters
    if (!req.query.containsKey('phonenumber') ||
        !req.query.containsKey('message') ||
        !req.query.containsKey('token')) {
      res.status(400).send('Missing parameters');
      return;
    }

    //md5->smsapitoken = 7ca04a3af82999d90c60f06cf3780d99
    String token = req.query['token']!;

    //check token
    if (token != '7ca04a3af82999d90c60f06cf3780d99') {
      res.status(401).send('Unauthorized');
      return;
    }

    String phonenumber = req.query['phonenumber']!;
    String message = req.query['message']!;

    bool is63 = phonenumber.startsWith(' 63');
    bool is09 = phonenumber.startsWith('09');
    String decodePlussign = Uri.decodeComponent('%2B');
    String finalPhonenumber =
        is63 ? phonenumber.replaceRange(0, 1, decodePlussign) : phonenumber;

    //check phone number if proper format
    if ((phonenumber.length != 13 && is63)) {
      res.status(400).send('Invalid phonenumber format(+63)');
      return;
    } else if (phonenumber.length != 11 && is09) {
      res.status(400).send('Invalid phonenumber format(09)');
      return;
    }

    if (!is63 && !is09) {
      res.status(400).send('Invalid phonenumber format');
      return;
    }

    String? servicetype = req.query['servicetype'];
    String apiResponse = '';

    //0 = eztext or null
    if (servicetype == null || servicetype == '0') {
      try {
        String messagefrom = req.query['messagefrom'] ?? '';
        int priority = 99;
        int sendretry = 20;

        final stmt = await conn.prepare(
          "INSERT INTO outboxsms (mobilenumber, message, messagefrom, messagecreated, messagesendon, priority, sendretry) VALUES (?, ?, ?, ?, ?, ?, ?)",
        );

        final stmtResult = await stmt.execute([
          finalPhonenumber,
          message,
          messagefrom,
          DateTime.now(),
          DateTime.now(),
          priority,
          sendretry
        ]);

        apiResponse = '${stmtResult.lastInsertID}';
        res.status(200).send('${stmtResult.lastInsertID}');
      } catch (e) {
        apiResponse = e.toString();
        res.status(200).send(e.toString());
      } finally {
        insertApiLog(apiResponse);
      }
    }
    //1 = openvox
    else if (servicetype == '1') {
      try {
        final queryParameters = {
          'username': 'ovsms',
          'password': 'ovSMS@2020',
          'phonenumber': finalPhonenumber,
          'message': message,
          'port': '1'
        };

        final uri = Uri.http('172.21.3.18', '/sendsms', queryParameters);

        final response = await http.get(uri);

        apiResponse = response.body;
        res.status(200).send(response.body);
      } catch (e) {
        apiResponse = e.toString();
        res.status(200).send(e.toString());
      } finally {
        insertApiLog(apiResponse);
      }
    } else {
      res.status(400).send('Invalid servicetype');
    }
  });

  server.listen(port: 3000, serverMode: ServerMode.compatibility);
}
