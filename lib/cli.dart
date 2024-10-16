import 'package:intl/intl.dart';
import 'package:mysql_client/mysql_client.dart';
import 'package:server_nano/server_nano.dart';
import 'package:http/http.dart' as http;
// import '../openvox_response.dart';

import 'dart:io';

Future<void> main() async {
  final server = Server();

  final conn = await MySQLConnection.createConnection(
    host: '192.168.221.21', // 172.21.3.22
    port: 3306,
    userName: 'janrey.dumaog', // sms-api
    password: 'janr3yD', // 5m5-AP1
    secure: true,
    databaseName: 'sms_api', // pctvsms
  );

  // mysql -h 172.21.3.22 -u sms-api -p

  // connect to database
  await conn.connect();

  // final conn = MySQLConnectionPool(
  //   host: '192.168.221.21',
  //   port: 3306,
  //   userName: 'janrey.dumaog',
  //   password: 'janr3yD',
  //   secure: true,
  //   databaseName: 'sms_api',
  //   maxConnections: 5,
  // );

  Future<void> sendsms(ContextRequest req, ContextResponse res) async {
    // add delay
    await Future.delayed(Duration(milliseconds: 100));

    // write error log
    void writeErrorLog(String errorMessage) async {
      try {
        final File file = File('file/log.txt');
        var dateformat = DateFormat('yyyy-MM-dd HH:mm:ss');
        var timestamp = dateformat.format(DateTime.now());

        await file.writeAsString('$timestamp -> $errorMessage\n',
            mode: FileMode.writeOnlyAppend);
      } catch (e) {
        print(e.toString());
      }
    }

    // show api guide
    void showGuide(String errorMessage) async {
      try {
        final File file = File('file/guide.txt');
        String guide = await file.readAsString();

        res.status(200).send('Message: $errorMessage\n$guide');
      } catch (e) {
        res.status(200).send('Message: $errorMessage\n$e');
      }
    }

    // insert result
    Future<String> insertApiLog(
        String apiResponse,
        String cilentIp,
        String phonenumber,
        String message,
        String token,
        String servicetype,
        String messagefrom) async {
      String id = '';
      try {
        //make insert query
        final stmt = await conn.prepare(
            "INSERT INTO api_log (reply, sender, phonenumber, message, token, servicetype, messagefrom) VALUES (?, ?, ?, ?, ?, ?, ?)");

        var stmtResult = await stmt.execute([
          apiResponse,
          cilentIp,
          phonenumber,
          message,
          token,
          servicetype,
          messagefrom
        ]);

        id = stmtResult.lastInsertID.toString();
      } catch (e) {
        writeErrorLog(e.toString());
      }
      return id;
    }

    // check parameters
    if (!req.query.containsKey('phonenumber') ||
        !req.query.containsKey('message') ||
        !req.query.containsKey('token')) {
      showGuide('Missing parameters.');
      return;
    }

    String phonenumber = req.query['phonenumber']!;
    String message = req.query['message']!;
    String token = req.query['token']!;
    String messagefrom = req.query['messagefrom'] ?? '';
    String servicetype = req.query['servicetype'] ?? '1';
    var clientInfo = req.input.connectionInfo;
    String cilentIp = clientInfo?.remoteAddress.address ?? '';

    // check token auth
    try {
      var result = await conn.execute(
        "SELECT * FROM token WHERE token = :token AND address = :address AND active = 1",
        {"token": token, "address": cilentIp},
      );
      if (result.numOfRows == 0) {
        showGuide('Unauthorized.');
        return;
      }
    } catch (e) {
      writeErrorLog(e.toString());
      showGuide(e.toString());
      return;
    }

    bool is63 = phonenumber.startsWith(' 63');
    bool is09 = phonenumber.startsWith('09');
    String decodePlussign = Uri.decodeComponent('%2B');
    String finalPhonenumber =
        is63 ? phonenumber.replaceRange(0, 1, decodePlussign) : phonenumber;

    // check phone number if proper format
    if ((phonenumber.length != 13 && is63)) {
      showGuide('Invalid phonenumber format(+63).');
      return;
    } else if (phonenumber.length != 11 && is09) {
      showGuide('Invalid phonenumber format(09).');
      return;
    }

    if (!is63 && !is09) {
      showGuide('Invalid phonenumber format.');
      return;
    }

    // 0 = eztext or null
    if (servicetype == '0') {
      try {
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

        // res.status(200).send('${stmtResult.lastInsertID}');

        var apiResponse = '${stmtResult.lastInsertID}';

        var apilogID = await insertApiLog(apiResponse, cilentIp, phonenumber,
            message, token, servicetype, messagefrom);

        res.status(200).send(apilogID);
      } catch (e) {
        writeErrorLog(e.toString());
        showGuide(e.toString());
      }
    }
    // 1 = openvox
    else if (servicetype == '1') {
      final queryParameters = {
        'username': 'ovsms',
        'password': 'ovSMS@2020',
        'phonenumber': finalPhonenumber,
        'message': message,
        'id': 'missmsapi',
        // 'port': '1'
      };
      try {
        final uri = Uri.http('172.21.3.18', '/sendsms', queryParameters);

        final response = await http.get(uri);

        // var openvoxResponse = openvoxResponseFromJson(response.body);

        // apiResponse = openvoxResponse.report.first.detail.first.id;

        var apiResponse = response.body;

        var apilogID = await insertApiLog(apiResponse, cilentIp, phonenumber,
            message, token, servicetype, messagefrom);

        res.status(200).send(apilogID);
      } catch (e) {
        writeErrorLog(e.toString());
        showGuide(e.toString());
      }
    } else if (servicetype == '2') {
      final String username = 'sms-api';
      final String password = '5m5-AP1';

      try {
        final queryParameters1 = {
          'USERNAME': username,
          'PASSWORD': password,
          'smsnum': finalPhonenumber,
          'Memo': message,
          'smsprovider': '1',
          'method': '2',
        };

        final uri1 =
            Uri.http('172.21.3.32', '/goip/en/dosend.php', queryParameters1);

        final response1 = await http.get(uri1);

        var apiResponse1 = response1.body;

        int messageidIndex = apiResponse1.indexOf('messageid=');
        int usernameIndex = apiResponse1.indexOf('USERNAME=');

        String messageid =
            apiResponse1.substring(messageidIndex + 10, usernameIndex - 1);

        final queryParameters2 = {
          'messageid': messageid,
          'USERNAME': username,
          'PASSWORD': password,
        };

        final uri2 =
            Uri.http('172.21.3.32', '/goip/en/resend.php', queryParameters2);

        final response2 = await http.get(uri2);

        var apiResponse2 = response2.body;

        var apilogID = await insertApiLog(apiResponse2, cilentIp, phonenumber,
            message, token, servicetype, messagefrom);

        res.status(200).send(apilogID);
      } catch (e) {
        writeErrorLog(e.toString());
        showGuide(e.toString());
      }
    } else {
      showGuide('Invalid servicetype.');
    }
  }

  server.get('/', (req, res) async {
    await sendsms(req, res);
  });

  server.get('/test', (req, res) async {
    bool status = conn.connected;
    res.status(200).send(status);
  });

  server.get('/sendsms', (req, res) async {
    await sendsms(req, res);
  });

  server.listen(port: 3000, serverMode: ServerMode.compatibility);
}
