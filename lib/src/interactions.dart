class Cassette {
  Cassette({
    this.name,
    List<InteractionPair>? interactions,
  })  : interactions = interactions ?? const <InteractionPair>[],
        interactionsByRequestUrl = {
          for (final interaction in interactions ?? const <InteractionPair>[])
            interaction.request!.url!: interaction,
        };

  final String? name;
  final List<InteractionPair> interactions;
  final Map<String, InteractionPair> interactionsByRequestUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'interactions': interactions,
    };
  }

  static Cassette fromJson(dynamic json) {
    return Cassette(
      name: json['name'] as String?,
      interactions: (json['interactions'] as List?)
          ?.map((e) => InteractionPair.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InteractionPair {
  InteractionPair({this.request, this.response});

  RequestInteraction? request;
  ResponseInteraction? response;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'request': request,
      'response': response,
    };
  }

  static InteractionPair fromJson(dynamic json) {
    return InteractionPair(
      request: json['request'] == null
          ? null
          : RequestInteraction.fromJson(
              json['request'] as Map<String, dynamic>),
      response: json['response'] == null
          ? null
          : ResponseInteraction.fromJson(
              json['response'] as Map<String, dynamic>),
    );
  }
}

class RequestInteraction {
  RequestInteraction({
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
  });

  final String? method;
  final String? url;
  final Map<String, String>? headers;
  final InteractionBody? body;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'method': method,
      'uri': url,
      'headers': headers,
      'body': body,
    };
  }

  static RequestInteraction fromJson(dynamic json) {
    return RequestInteraction(
      method: json['method'] as String?,
      url: json['uri'] as String?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      body: json['body'] == null
          ? null
          : InteractionBody.fromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

class ResponseInteraction {
  ResponseInteraction({
    required this.status,
    this.headers = const {},
    this.body,
  });
  final int? status;
  final Map<String, String>? headers;
  final InteractionBody? body;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status,
      'headers': headers,
      'body': body,
    };
  }

  static ResponseInteraction fromJson(dynamic json) {
    return ResponseInteraction(
      status: json['status'] as int?,
      headers: (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
      body: json['body'] == null
          ? null
          : InteractionBody.fromJson(json['body'] as Map<String, dynamic>),
    );
  }
}

class InteractionBody {
  InteractionBody({
    required this.string,
    this.encoding = 'utf-8',
  });
  final String? encoding;
  final String? string;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'encoding': encoding,
      'string': string,
    };
  }

  static InteractionBody fromJson(dynamic json) {
    return InteractionBody(
      encoding: json['encoding'] as String?,
      string: json['string'] as String?,
    );
  }
}
