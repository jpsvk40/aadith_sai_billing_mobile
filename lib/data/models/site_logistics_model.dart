// Project Site-Logistics models — site survey + delivery-to-site (photo proof).

double _d(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class SitePhoto {
  final String? key;
  final String? url;
  final String? caption;

  const SitePhoto({this.key, this.url, this.caption});

  factory SitePhoto.fromJson(Map<String, dynamic> j) =>
      SitePhoto(key: j['key']?.toString(), url: j['url']?.toString(), caption: j['caption']?.toString());

  Map<String, dynamic> toJson() => {
        if (key != null) 'key': key,
        if (url != null) 'url': url,
        if (caption != null) 'caption': caption,
      };
}

List<SitePhoto> _photos(dynamic v) =>
    v is List ? v.map((e) => SitePhoto.fromJson(Map<String, dynamic>.from(e as Map))).toList() : <SitePhoto>[];

class SiteSurveyItem {
  final String? openingRef;
  final String description;
  final double width;
  final double height;
  final double quantity;
  final String unit;

  const SiteSurveyItem({
    this.openingRef,
    required this.description,
    this.width = 0,
    this.height = 0,
    this.quantity = 1,
    this.unit = 'nos',
  });

  factory SiteSurveyItem.fromJson(Map<String, dynamic> j) => SiteSurveyItem(
        openingRef: j['openingRef']?.toString(),
        description: j['description']?.toString() ?? '',
        width: _d(j['width']),
        height: _d(j['height']),
        quantity: j['quantity'] != null ? _d(j['quantity']) : 1,
        unit: j['unit']?.toString() ?? 'nos',
      );

  Map<String, dynamic> toJson() => {
        if (openingRef != null) 'openingRef': openingRef,
        'description': description,
        'width': width,
        'height': height,
        'quantity': quantity,
        'unit': unit,
      };
}

class SiteSurvey {
  final String id;
  final int projectId;
  final String surveyNumber;
  final DateTime? surveyDate;
  final String? location;
  final String? surveyedBy;
  final String status;
  final List<SiteSurveyItem> items;
  final List<SitePhoto> photos;

  const SiteSurvey({
    required this.id,
    required this.projectId,
    required this.surveyNumber,
    this.surveyDate,
    this.location,
    this.surveyedBy,
    required this.status,
    this.items = const [],
    this.photos = const [],
  });

  factory SiteSurvey.fromJson(Map<String, dynamic> j) => SiteSurvey(
        id: j['id']?.toString() ?? '',
        projectId: int.tryParse(j['projectId']?.toString() ?? '0') ?? 0,
        surveyNumber: j['surveyNumber']?.toString() ?? '',
        surveyDate: _dt(j['surveyDate']),
        location: j['location']?.toString(),
        surveyedBy: j['surveyedBy']?.toString(),
        status: j['status']?.toString() ?? 'DRAFT',
        items: j['items'] is List
            ? (j['items'] as List).map((e) => SiteSurveyItem.fromJson(Map<String, dynamic>.from(e as Map))).toList()
            : const [],
        photos: _photos(j['photos']),
      );
}

class SiteDeliveryItem {
  final String description;
  final double quantity;
  final String unit;

  const SiteDeliveryItem({required this.description, this.quantity = 0, this.unit = 'nos'});

  factory SiteDeliveryItem.fromJson(Map<String, dynamic> j) => SiteDeliveryItem(
        description: j['description']?.toString() ?? '',
        quantity: _d(j['quantity']),
        unit: j['unit']?.toString() ?? 'nos',
      );

  Map<String, dynamic> toJson() => {'description': description, 'quantity': quantity, 'unit': unit};
}

class SiteDelivery {
  final String id;
  final int projectId;
  final String deliveryNumber;
  final DateTime? deliveryDate;
  final String? vehicleNo;
  final String? driverName;
  final String? receivedBy;
  final String status;
  final List<SiteDeliveryItem> items;
  final List<SitePhoto> photos;

  const SiteDelivery({
    required this.id,
    required this.projectId,
    required this.deliveryNumber,
    this.deliveryDate,
    this.vehicleNo,
    this.driverName,
    this.receivedBy,
    required this.status,
    this.items = const [],
    this.photos = const [],
  });

  factory SiteDelivery.fromJson(Map<String, dynamic> j) => SiteDelivery(
        id: j['id']?.toString() ?? '',
        projectId: int.tryParse(j['projectId']?.toString() ?? '0') ?? 0,
        deliveryNumber: j['deliveryNumber']?.toString() ?? '',
        deliveryDate: _dt(j['deliveryDate']),
        vehicleNo: j['vehicleNo']?.toString(),
        driverName: j['driverName']?.toString(),
        receivedBy: j['receivedBy']?.toString(),
        status: j['status']?.toString() ?? 'DISPATCHED',
        items: j['items'] is List
            ? (j['items'] as List).map((e) => SiteDeliveryItem.fromJson(Map<String, dynamic>.from(e as Map))).toList()
            : const [],
        photos: _photos(j['photos']),
      );
}

class ProjectLite {
  final int id;
  final String code;
  final String name;
  const ProjectLite({required this.id, required this.code, required this.name});

  factory ProjectLite.fromJson(Map<String, dynamic> j) => ProjectLite(
        id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
        code: j['projectCode']?.toString() ?? '',
        name: j['projectName']?.toString() ?? '',
      );
}
