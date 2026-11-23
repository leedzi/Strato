import Foundation
import CoreLocation

public struct Airport: Identifiable, Codable, Hashable, Sendable {
    public var id: String { iata }
    public let iata: String
    public let icao: String
    public let name: String
    public let city: String
    public let country: String
    public let latitude: Double
    public let longitude: Double

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        iata: String,
        icao: String,
        name: String,
        city: String,
        country: String,
        latitude: Double,
        longitude: Double
    ) {
        self.iata = iata
        self.icao = icao
        self.name = name
        self.city = city
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum GreatCircle {
    private static let earthRadiusKM: Double = 6371.0088
    private static let kmPerNM: Double = 1.852

    public static func distanceKM(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return earthRadiusKM * c
    }

    public static func distanceNM(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        distanceKM(from: from, to: to) / kmPerNM
    }

    public static func bearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Smallest absolute angle difference (0...180) between two headings in degrees.
    public static func angleDifference(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        return diff > 180 ? 360 - diff : diff
    }

    /// Interpolates a point along the great-circle path between two coordinates (`fraction` in 0...1).
    public static func interpolate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        fraction: Double
    ) -> CLLocationCoordinate2D {
        let t = min(max(fraction, 0), 1)
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let x1 = cos(lat1) * cos(lon1)
        let y1 = cos(lat1) * sin(lon1)
        let z1 = sin(lat1)

        let x2 = cos(lat2) * cos(lon2)
        let y2 = cos(lat2) * sin(lon2)
        let z2 = sin(lat2)

        let dot = min(max(x1 * x2 + y1 * y2 + z1 * z2, -1), 1)
        let omega = acos(dot)
        if omega < 1e-6 {
            return from
        }

        let sinOmega = sin(omega)
        let a = sin((1 - t) * omega) / sinOmega
        let b = sin(t * omega) / sinOmega

        let x = a * x1 + b * x2
        let y = a * y1 + b * y2
        let z = a * z1 + b * z2

        let lat = atan2(z, sqrt(x * x + y * y)) * 180 / .pi
        let lon = atan2(y, x) * 180 / .pi
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    public static func arcCoordinates(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        segments: Int = 48
    ) -> [CLLocationCoordinate2D] {
        guard segments > 1 else { return [from, to] }
        return (0...segments).map { step in
            interpolate(from: from, to: to, fraction: Double(step) / Double(segments))
        }
    }

    /// Advances a coordinate forward along a heading by distance in nautical miles.
    public static func destination(
        from: CLLocationCoordinate2D,
        bearingDegrees: Double,
        distanceNM: Double
    ) -> CLLocationCoordinate2D {
        let angularDistance = (distanceNM * kmPerNM) / earthRadiusKM
        let bearing = bearingDegrees * .pi / 180
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180

        let lat2 = asin(
            sin(lat1) * cos(angularDistance)
            + cos(lat1) * sin(angularDistance) * cos(bearing)
        )
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: ((lon2 * 180 / .pi + 540).truncatingRemainder(dividingBy: 360)) - 180
        )
    }
}

public enum AirportDatabase {
    public static let all: [Airport] = [
        // Mainland China & HK/MO/TW
        Airport(iata: "PEK", icao: "ZBAA", name: "Capital International", city: "北京首都", country: "CN", latitude: 40.0799, longitude: 116.6031),
        Airport(iata: "PKX", icao: "ZBAD", name: "Daxing International", city: "北京大兴", country: "CN", latitude: 39.5098, longitude: 116.4105),
        Airport(iata: "PVG", icao: "ZSPD", name: "Pudong International", city: "上海浦东", country: "CN", latitude: 31.1443, longitude: 121.8083),
        Airport(iata: "SHA", icao: "ZSSS", name: "Hongqiao International", city: "上海虹桥", country: "CN", latitude: 31.1979, longitude: 121.3363),
        Airport(iata: "CAN", icao: "ZGGG", name: "Baiyun International", city: "广州白云", country: "CN", latitude: 23.3924, longitude: 113.2988),
        Airport(iata: "SZX", icao: "ZGSZ", name: "Bao'an International", city: "深圳宝安", country: "CN", latitude: 22.6393, longitude: 113.8107),
        Airport(iata: "CTU", icao: "ZUUU", name: "Shuangliu International", city: "成都双流", country: "CN", latitude: 30.5785, longitude: 103.9471),
        Airport(iata: "TFU", icao: "ZUTF", name: "Tianfu International", city: "成都天府", country: "CN", latitude: 30.3125, longitude: 104.4414),
        Airport(iata: "CKG", icao: "ZUCK", name: "Jiangbei International", city: "重庆江北", country: "CN", latitude: 29.7192, longitude: 106.6417),
        Airport(iata: "HGH", icao: "ZSHC", name: "Xiaoshan International", city: "杭州萧山", country: "CN", latitude: 30.2295, longitude: 120.4344),
        Airport(iata: "XIY", icao: "ZLXY", name: "Xianyang International", city: "西安咸阳", country: "CN", latitude: 34.4471, longitude: 108.7516),
        Airport(iata: "WUH", icao: "ZHHH", name: "Tianhe International", city: "武汉天河", country: "CN", latitude: 30.7838, longitude: 114.2081),
        Airport(iata: "KMG", icao: "ZPPP", name: "Changshui International", city: "昆明长水", country: "CN", latitude: 25.1019, longitude: 102.9292),
        Airport(iata: "NKG", icao: "ZSNJ", name: "Lukou International", city: "南京禄口", country: "CN", latitude: 31.7420, longitude: 118.8620),
        Airport(iata: "XMN", icao: "ZSAM", name: "Gaoqi International", city: "厦门高崎", country: "CN", latitude: 24.5440, longitude: 118.1277),
        Airport(iata: "CSX", icao: "ZGHA", name: "Huanghua International", city: "长沙黄花", country: "CN", latitude: 28.1892, longitude: 113.2196),
        Airport(iata: "TAO", icao: "ZSQD", name: "Jiaodong International", city: "青岛胶东", country: "CN", latitude: 36.3611, longitude: 120.0961),
        Airport(iata: "CGO", icao: "ZHCC", name: "Xinzheng International", city: "郑州新郑", country: "CN", latitude: 34.5197, longitude: 113.8409),
        Airport(iata: "TSN", icao: "ZBTJ", name: "Binhai International", city: "天津滨海", country: "CN", latitude: 39.1244, longitude: 117.3462),
        Airport(iata: "SHE", icao: "ZYTX", name: "Taoxian International", city: "沈阳桃仙", country: "CN", latitude: 41.6398, longitude: 123.4834),
        Airport(iata: "DLC", icao: "ZYTL", name: "Zhoushuizi International", city: "大连周水子", country: "CN", latitude: 38.9657, longitude: 121.5386),
        Airport(iata: "HRB", icao: "ZYHB", name: "Taiping International", city: "哈尔滨太平", country: "CN", latitude: 45.6234, longitude: 126.2500),
        Airport(iata: "URC", icao: "ZWWW", name: "Diwopu International", city: "乌鲁木齐", country: "CN", latitude: 43.9071, longitude: 87.4742),
        Airport(iata: "SYX", icao: "ZJSY", name: "Phoenix International", city: "三亚凤凰", country: "CN", latitude: 18.3029, longitude: 109.4120),
        Airport(iata: "HAK", icao: "ZJHK", name: "Meilan International", city: "海口美兰", country: "CN", latitude: 19.9349, longitude: 110.4590),
        Airport(iata: "FOC", icao: "ZSFZ", name: "Changle International", city: "福州长乐", country: "CN", latitude: 25.9351, longitude: 119.6633),
        Airport(iata: "NNG", icao: "ZGNN", name: "Wuxu International", city: "南宁吴圩", country: "CN", latitude: 22.6083, longitude: 108.1720),
        Airport(iata: "KWE", icao: "ZUGY", name: "Longdongbao International", city: "贵阳龙洞堡", country: "CN", latitude: 26.5385, longitude: 106.8007),
        Airport(iata: "HKG", icao: "VHHH", name: "Hong Kong International", city: "香港", country: "HK", latitude: 22.3080, longitude: 113.9185),
        Airport(iata: "MFM", icao: "VMMC", name: "Macau International", city: "澳门", country: "MO", latitude: 22.1496, longitude: 113.5920),
        Airport(iata: "TPE", icao: "RCTP", name: "Taoyuan International", city: "台北桃园", country: "TW", latitude: 25.0777, longitude: 121.2328),
        Airport(iata: "TSA", icao: "RCSS", name: "Songshan Airport", city: "台北松山", country: "TW", latitude: 25.0694, longitude: 121.5525),
        Airport(iata: "KHH", icao: "RCKH", name: "Kaohsiung International", city: "高雄", country: "TW", latitude: 22.5771, longitude: 120.3500),

        // Japan & Korea
        Airport(iata: "HND", icao: "RJTT", name: "Haneda Airport", city: "东京羽田", country: "JP", latitude: 35.5494, longitude: 139.7798),
        Airport(iata: "NRT", icao: "RJAA", name: "Narita International", city: "东京成田", country: "JP", latitude: 35.7720, longitude: 140.3929),
        Airport(iata: "KIX", icao: "RJBB", name: "Kansai International", city: "大阪关西", country: "JP", latitude: 34.4347, longitude: 135.2441),
        Airport(iata: "ITM", icao: "RJOO", name: "Itami Airport", city: "大阪伊丹", country: "JP", latitude: 34.7855, longitude: 135.4380),
        Airport(iata: "NGO", icao: "RJGG", name: "Chubu Centrair", city: "名古屋", country: "JP", latitude: 34.8584, longitude: 136.8054),
        Airport(iata: "FUK", icao: "RJFF", name: "Fukuoka Airport", city: "福冈", country: "JP", latitude: 33.5859, longitude: 130.4510),
        Airport(iata: "CTS", icao: "RJCC", name: "New Chitose", city: "札幌新千岁", country: "JP", latitude: 42.7752, longitude: 141.6923),
        Airport(iata: "OKA", icao: "ROAH", name: "Naha Airport", city: "冲绳那霸", country: "JP", latitude: 26.1958, longitude: 127.6460),
        Airport(iata: "ICN", icao: "RKSI", name: "Incheon International", city: "首尔仁川", country: "KR", latitude: 37.4602, longitude: 126.4407),
        Airport(iata: "GMP", icao: "RKSS", name: "Gimpo International", city: "首尔金浦", country: "KR", latitude: 37.5583, longitude: 126.7906),
        Airport(iata: "PUS", icao: "RKPK", name: "Gimhae International", city: "釜山", country: "KR", latitude: 35.1795, longitude: 128.9382),
        Airport(iata: "CJU", icao: "RKPC", name: "Jeju International", city: "济州岛", country: "KR", latitude: 33.5113, longitude: 126.4930),

        // Southeast & South Asia
        Airport(iata: "SIN", icao: "WSSS", name: "Changi Airport", city: "新加坡", country: "SG", latitude: 1.3644, longitude: 103.9915),
        Airport(iata: "BKK", icao: "VTBS", name: "Suvarnabhumi", city: "曼谷素万那普", country: "TH", latitude: 13.6900, longitude: 100.7501),
        Airport(iata: "DMK", icao: "VTBD", name: "Don Mueang", city: "曼谷廊曼", country: "TH", latitude: 13.9126, longitude: 100.6068),
        Airport(iata: "HKT", icao: "VTSP", name: "Phuket International", city: "普吉岛", country: "TH", latitude: 8.1132, longitude: 98.3169),
        Airport(iata: "KUL", icao: "WMKK", name: "Kuala Lumpur Intl", city: "吉隆坡", country: "MY", latitude: 2.7456, longitude: 101.7099),
        Airport(iata: "CGK", icao: "WIII", name: "Soekarno-Hatta", city: "雅加达", country: "ID", latitude: -6.1256, longitude: 106.6559),
        Airport(iata: "DPS", icao: "WADD", name: "Ngurah Rai", city: "巴厘岛", country: "ID", latitude: -8.7482, longitude: 115.1672),
        Airport(iata: "MNL", icao: "RPLL", name: "Ninoy Aquino", city: "马尼拉", country: "PH", latitude: 14.5086, longitude: 121.0194),
        Airport(iata: "SGN", icao: "VVTS", name: "Tan Son Nhat", city: "胡志明市", country: "VN", latitude: 10.8188, longitude: 106.6519),
        Airport(iata: "HAN", icao: "VVNB", name: "Noi Bai International", city: "河内", country: "VN", latitude: 21.2212, longitude: 105.8072),
        Airport(iata: "DEL", icao: "VIDP", name: "Indira Gandhi Intl", city: "新德里", country: "IN", latitude: 28.5562, longitude: 77.1000),
        Airport(iata: "BOM", icao: "VABB", name: "Chhatrapati Shivaji", city: "孟买", country: "IN", latitude: 19.0896, longitude: 72.8656),

        // Europe & Middle East
        Airport(iata: "LHR", icao: "EGLL", name: "Heathrow", city: "伦敦希思罗", country: "GB", latitude: 51.4700, longitude: -0.4543),
        Airport(iata: "LGW", icao: "EGKK", name: "Gatwick", city: "伦敦盖特威克", country: "GB", latitude: 51.1537, longitude: -0.1821),
        Airport(iata: "MAN", icao: "EGCC", name: "Manchester Airport", city: "曼彻斯特", country: "GB", latitude: 53.3537, longitude: -2.2750),
        Airport(iata: "CDG", icao: "LFPG", name: "Charles de Gaulle", city: "巴黎戴高乐", country: "FR", latitude: 49.0097, longitude: 2.5479),
        Airport(iata: "ORY", icao: "LFPO", name: "Orly Airport", city: "巴黎奥利", country: "FR", latitude: 48.7262, longitude: 2.3652),
        Airport(iata: "FRA", icao: "EDDF", name: "Frankfurt Airport", city: "法兰克福", country: "DE", latitude: 50.0379, longitude: 8.5622),
        Airport(iata: "MUC", icao: "EDDM", name: "Munich Airport", city: "慕尼黑", country: "DE", latitude: 48.3537, longitude: 11.7750),
        Airport(iata: "BER", icao: "EDDB", name: "Berlin Brandenburg", city: "柏林", country: "DE", latitude: 52.3667, longitude: 13.5033),
        Airport(iata: "AMS", icao: "EHAM", name: "Schiphol", city: "阿姆斯特丹", country: "NL", latitude: 52.3105, longitude: 4.7683),
        Airport(iata: "ZRH", icao: "LSZH", name: "Zurich Airport", city: "苏黎世", country: "CH", latitude: 47.4647, longitude: 8.5492),
        Airport(iata: "VIE", icao: "LOWW", name: "Vienna International", city: "维也纳", country: "AT", latitude: 48.1103, longitude: 16.5697),
        Airport(iata: "MAD", icao: "LEMD", name: "Barajas", city: "马德里", country: "ES", latitude: 40.4983, longitude: -3.5676),
        Airport(iata: "BCN", icao: "LEBL", name: "El Prat", city: "巴塞罗那", country: "ES", latitude: 41.2974, longitude: 2.0833),
        Airport(iata: "FCO", icao: "LIRF", name: "Fiumicino", city: "罗马", country: "IT", latitude: 41.8003, longitude: 12.2389),
        Airport(iata: "MXP", icao: "LIMC", name: "Malpensa", city: "米兰", country: "IT", latitude: 45.6301, longitude: 8.7231),
        Airport(iata: "CPH", icao: "EKCH", name: "Kastrup", city: "哥本哈根", country: "DK", latitude: 55.6180, longitude: 12.6508),
        Airport(iata: "ARN", icao: "ESSA", name: "Arlanda", city: "斯德哥尔摩", country: "SE", latitude: 59.6498, longitude: 17.9238),
        Airport(iata: "HEL", icao: "EFHK", name: "Helsinki-Vantaa", city: "赫尔辛基", country: "FI", latitude: 60.3172, longitude: 24.9633),
        Airport(iata: "IST", icao: "LTFM", name: "Istanbul Airport", city: "伊斯坦布尔", country: "TR", latitude: 41.2753, longitude: 28.7519),
        Airport(iata: "DXB", icao: "OMDB", name: "Dubai International", city: "迪拜", country: "AE", latitude: 25.2532, longitude: 55.3657),
        Airport(iata: "AUH", icao: "OMAA", name: "Zayed International", city: "阿布扎比", country: "AE", latitude: 24.4330, longitude: 54.6511),
        Airport(iata: "DOH", icao: "OTHH", name: "Hamad International", city: "多哈", country: "QA", latitude: 25.2731, longitude: 51.6081),
        Airport(iata: "KEF", icao: "BIKF", name: "Keflavik", city: "雷克雅未克", country: "IS", latitude: 63.9850, longitude: -22.6056),

        // North America & Oceania
        Airport(iata: "JFK", icao: "KJFK", name: "John F. Kennedy", city: "纽约肯尼迪", country: "US", latitude: 40.6413, longitude: -73.7781),
        Airport(iata: "EWR", icao: "KEWR", name: "Newark Liberty", city: "纽约纽瓦克", country: "US", latitude: 40.6895, longitude: -74.1745),
        Airport(iata: "BOS", icao: "KBOS", name: "Logan International", city: "波士顿", country: "US", latitude: 42.3656, longitude: -71.0096),
        Airport(iata: "IAD", icao: "KIAD", name: "Dulles International", city: "华盛顿杜勒斯", country: "US", latitude: 38.9531, longitude: -77.4565),
        Airport(iata: "LAX", icao: "KLAX", name: "Los Angeles Intl", city: "洛杉矶", country: "US", latitude: 33.9416, longitude: -118.4085),
        Airport(iata: "SFO", icao: "KSFO", name: "San Francisco Intl", city: "旧金山", country: "US", latitude: 37.6213, longitude: -122.3790),
        Airport(iata: "SEA", icao: "KSEA", name: "Seattle-Tacoma", city: "西雅图", country: "US", latitude: 47.4502, longitude: -122.3088),
        Airport(iata: "ORD", icao: "KORD", name: "O'Hare International", city: "芝加哥", country: "US", latitude: 41.9742, longitude: -87.9073),
        Airport(iata: "ATL", icao: "KATL", name: "Hartsfield-Jackson", city: "亚特兰大", country: "US", latitude: 33.6407, longitude: -84.4277),
        Airport(iata: "DFW", icao: "KDFW", name: "Dallas/Fort Worth", city: "达拉斯", country: "US", latitude: 32.8998, longitude: -97.0403),
        Airport(iata: "DEN", icao: "KDEN", name: "Denver International", city: "丹佛", country: "US", latitude: 39.8561, longitude: -104.6737),
        Airport(iata: "LAS", icao: "KLAS", name: "Harry Reid Intl", city: "拉斯维加斯", country: "US", latitude: 36.0840, longitude: -115.1537),
        Airport(iata: "MIA", icao: "KMIA", name: "Miami International", city: "迈阿密", country: "US", latitude: 25.7959, longitude: -80.2870),
        Airport(iata: "HNL", icao: "PHNL", name: "Daniel K. Inouye", city: "檀香山", country: "US", latitude: 21.3187, longitude: -157.9224),
        Airport(iata: "YVR", icao: "CYVR", name: "Vancouver Intl", city: "温哥华", country: "CA", latitude: 49.1967, longitude: -123.1815),
        Airport(iata: "YYZ", icao: "CYYZ", name: "Toronto Pearson", city: "多伦多", country: "CA", latitude: 43.6777, longitude: -79.6248),
        Airport(iata: "SYD", icao: "YSSY", name: "Kingsford Smith", city: "悉尼", country: "AU", latitude: -33.9399, longitude: 151.1753),
        Airport(iata: "MEL", icao: "YMML", name: "Melbourne Airport", city: "墨尔本", country: "AU", latitude: -37.6690, longitude: 144.8410),
        Airport(iata: "AKL", icao: "NZAA", name: "Auckland Airport", city: "奥克兰", country: "NZ", latitude: -37.0082, longitude: 174.7850)
    ]

    private static let byIATA: [String: Airport] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.iata, $0) }
    )

    private static let byICAO: [String: Airport] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.icao, $0) }
    )

    public static func find(code: String) -> Airport? {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return byIATA[normalized] ?? byICAO[normalized]
    }

    public static func nearest(to coordinate: CLLocationCoordinate2D) -> Airport {
        all.min {
            GreatCircle.distanceKM(from: coordinate, to: $0.coordinate)
            < GreatCircle.distanceKM(from: coordinate, to: $1.coordinate)
        } ?? all[0]
    }

    /// Geometrically infers a realistic origin and destination airport when an aircraft's schedule is unlisted.
    /// Uses current aircraft position, true track heading, altitude, and vertical rate to pick the airport behind
    /// and the airport ahead along the flight corridor.
    public static func inferRoute(
        coordinate: CLLocationCoordinate2D,
        trackDegrees: Double,
        altitudeFeet: Int,
        verticalRateFpm: Int
    ) -> (origin: Airport, destination: Airport) {
        let reciprocalHeading = (trackDegrees + 180).truncatingRemainder(dividingBy: 360)

        // Expected remaining distance based on phase/altitude
        let expectedForwardKM: Double = {
            if altitudeFeet < 12_000 && verticalRateFpm < -250 { return 140 }
            if altitudeFeet < 18_000 { return 420 }
            return 1350
        }()

        // Find best destination ahead within a forward heading cone
        let bestDestination = all
            .map { airport -> (Airport, Double) in
                let dist = GreatCircle.distanceKM(from: coordinate, to: airport.coordinate)
                let bearing = GreatCircle.bearingDegrees(from: coordinate, to: airport.coordinate)
                let angleErr = GreatCircle.angleDifference(trackDegrees, bearing)
                // Penalize wide angles and unrealistic distances
                let distPenalty = abs(dist - expectedForwardKM) * 0.35
                let score = (angleErr * 18.0) + distPenalty + (dist < 45 ? 5000 : 0)
                return (airport, score)
            }
            .min { $0.1 < $1.1 }?.0 ?? nearest(to: coordinate)

        // Find best origin behind along the reciprocal track
        let bestOrigin = all
            .filter { $0.iata != bestDestination.iata }
            .map { airport -> (Airport, Double) in
                let dist = GreatCircle.distanceKM(from: coordinate, to: airport.coordinate)
                let bearing = GreatCircle.bearingDegrees(from: coordinate, to: airport.coordinate)
                let angleErr = GreatCircle.angleDifference(reciprocalHeading, bearing)
                let score = (angleErr * 16.0) + (dist * 0.25) + (dist < 30 ? 3500 : 0)
                return (airport, score)
            }
            .min { $0.1 < $1.1 }?.0 ?? nearest(to: coordinate)

        return (bestOrigin, bestDestination)
    }
}
