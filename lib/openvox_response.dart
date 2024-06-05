// To parse this JSON data, do
//
// final openvoxResponse = openvoxResponseFromJson(jsonString);

import 'dart:convert';

OpenvoxResponse openvoxResponseFromJson(String str) =>
    OpenvoxResponse.fromJson(json.decode(str));

String openvoxResponseToJson(OpenvoxResponse data) =>
    json.encode(data.toJson());

class OpenvoxResponse {
  String message;
  List<Report> report;

  OpenvoxResponse({
    required this.message,
    required this.report,
  });

  factory OpenvoxResponse.fromJson(Map<String, dynamic> json) =>
      OpenvoxResponse(
        message: json["message"],
        report:
            List<Report>.from(json["report"].map((x) => Report.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "report": List<dynamic>.from(report.map((x) => x.toJson())),
      };
}

class Report {
  List<Detail> detail;

  Report({
    required this.detail,
  });

  factory Report.fromJson(Map<String, dynamic> json) => Report(
        detail: List<Detail>.from(json["1"].map((x) => Detail.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "1": List<dynamic>.from(detail.map((x) => x.toJson())),
      };
}

class Detail {
  String port;
  String phonenumber;
  DateTime time;
  String id;
  String result;

  Detail({
    required this.port,
    required this.phonenumber,
    required this.time,
    required this.id,
    required this.result,
  });

  factory Detail.fromJson(Map<String, dynamic> json) => Detail(
        port: json["port"],
        phonenumber: json["phonenumber"],
        time: DateTime.parse(json["time"]),
        id: json["id"],
        result: json["result"],
      );

  Map<String, dynamic> toJson() => {
        "port": port,
        "phonenumber": phonenumber,
        "time": time.toIso8601String(),
        "id": id,
        "result": result,
      };
}
