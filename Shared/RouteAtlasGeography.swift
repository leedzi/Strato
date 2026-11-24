import Foundation

// Public-domain Natural Earth 1:110m land; simplified to 0.55 degrees for this overview.
// https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_110m_land.geojson
// Source SHA-256: 9e0729ee253ca7d7a5c4ae9395fb1902264c5377c52e224d13dd85010e2835d9
// Geographic outlines and their offline triangulation are bundled; no map tiles are fetched.
struct RouteAtlasLandPolygon: Sendable {
    let points: [GeoPoint]
    let triangles: [Int]
}

enum RouteAtlasGeography {
    static let polygons: [RouteAtlasLandPolygon] = [
        RouteAtlasLandPolygon(points: [
            GeoPoint(-79.6287, -60.6101), GeoPoint(-79.9814, -61.1390), GeoPoint(-80.3929, -61.8832), GeoPoint(-80.2949, -64.0377), GeoPoint(-80.2558, -66.2900),
            GeoPoint(-80.5497, -65.7417), GeoPoint(-80.5888, -65.7417), GeoPoint(-80.9219, -64.4881), GeoPoint(-80.8632, -62.2554), GeoPoint(-81.0003, -60.1597),
            GeoPoint(-80.5497, -59.8658), GeoPoint(-80.0402, -59.5721),
        ], triangles: [
            11, 0, 1, 11, 1, 2, 2, 3, 4, 2, 4, 5, 2, 5, 6, 2, 6, 7, 11, 2, 7, 11, 7, 8,
            11, 8, 9, 9, 10, 11,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-79.0463, -159.4824), GeoPoint(-78.6936, -160.2462), GeoPoint(-78.3802, -161.2451), GeoPoint(-78.2233, -163.1058), GeoPoint(-78.5957, -163.7129),
            GeoPoint(-78.8700, -163.0666), GeoPoint(-78.9288, -163.0274), GeoPoint(-79.2815, -162.4398), GeoPoint(-79.6342, -161.1276), GeoPoint(-79.4971, -159.2082),
        ], triangles: [
            9, 0, 1, 9, 1, 2, 9, 2, 3, 9, 3, 4, 9, 4, 5, 9, 5, 6, 9, 6, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-78.0470, -48.6606), GeoPoint(-80.6335, -54.1643), GeoPoint(-81.0254, -50.4821), GeoPoint(-80.0261, -43.3333), GeoPoint(-78.4781, -43.9208),
            GeoPoint(-78.0471, -45.1548),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-73.3246, -122.4062), GeoPoint(-73.6578, -122.6217), GeoPoint(-73.6578, -122.6217), GeoPoint(-74.0105, -121.6228), GeoPoint(-74.0888, -120.2322),
            GeoPoint(-73.8341, -119.2921), GeoPoint(-73.4814, -118.7241), GeoPoint(-73.6577, -119.9189), GeoPoint(-73.5010, -121.2115),
        ], triangles: [
            8, 0, 1, 8, 1, 2, 8, 2, 3, 8, 3, 4, 8, 4, 5, 5, 6, 7, 5, 7, 8,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-73.2462, -126.5585), GeoPoint(-73.4618, -127.2831), GeoPoint(-73.4618, -127.2831), GeoPoint(-73.7361, -125.9122), GeoPoint(-73.8341, -124.6195),
            GeoPoint(-73.8733, -124.0319), GeoPoint(-73.4814, -125.5596),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-71.8550, -100.4309), GeoPoint(-71.7178, -101.7040), GeoPoint(-71.8942, -102.3307), GeoPoint(-72.3057, -101.8019), GeoPoint(-72.5016, -100.7835),
            GeoPoint(-72.4429, -99.4320), GeoPoint(-72.4820, -98.1981), GeoPoint(-72.4429, -96.9838), GeoPoint(-72.5212, -96.2004), GeoPoint(-71.9530, -96.7879),
            GeoPoint(-72.0705, -97.8847), GeoPoint(-71.9333, -98.9815),
        ], triangles: [
            0, 1, 2, 11, 0, 2, 11, 2, 3, 11, 3, 4, 11, 4, 5, 11, 5, 6, 11, 6, 7, 11, 7, 8,
            8, 9, 10, 8, 10, 11,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-68.8787, -70.2533), GeoPoint(-69.5058, -71.7418), GeoPoint(-71.1910, -72.0747), GeoPoint(-71.6613, -75.0126), GeoPoint(-72.5038, -71.0759),
            GeoPoint(-72.1707, -68.7843), GeoPoint(-70.9558, -68.4513),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-63.5254, -57.2236), GeoPoint(-64.6423, -63.0014), GeoPoint(-67.3268, -67.7412), GeoPoint(-68.1498, -67.4278), GeoPoint(-69.7174, -68.5442),
            GeoPoint(-72.4803, -67.3691), GeoPoint(-73.8716, -74.8900), GeoPoint(-73.1270, -80.2958), GeoPoint(-73.8520, -81.4709), GeoPoint(-72.5587, -89.2270),
            GeoPoint(-73.3229, -90.0887), GeoPoint(-73.6168, -96.3366), GeoPoint(-72.6175, -103.6813), GeoPoint(-74.1067, -102.5453), GeoPoint(-74.8709, -100.1167),
            GeoPoint(-75.1845, -107.5593), GeoPoint(-74.7142, -112.2991), GeoPoint(-73.7148, -113.9443), GeoPoint(-74.5182, -121.0736), GeoPoint(-74.3027, -135.2146),
            GeoPoint(-75.3804, -146.2023), GeoPoint(-76.4778, -146.1044), GeoPoint(-77.3987, -151.3338), GeoPoint(-76.8892, -158.3651), GeoPoint(-78.0257, -158.0518),
            GeoPoint(-79.0643, -155.3294), GeoPoint(-80.3379, -146.4177), GeoPoint(-81.3373, -150.6483), GeoPoint(-81.1021, -156.8374), GeoPoint(-82.0427, -152.8615),
            GeoPoint(-83.6887, -153.5862), GeoPoint(-85.0408, -143.1077), GeoPoint(-85.3739, -158.0714), GeoPoint(-83.8846, -169.9512), GeoPoint(-84.1394, -179.0587),
            GeoPoint(-84.7134, -180.0000), GeoPoint(-90.0000, -180.0000), GeoPoint(-90.0000, 180.0000), GeoPoint(-84.7134, 180.0000), GeoPoint(-83.8259, 169.4048),
            GeoPoint(-80.9454, 159.7882), GeoPoint(-79.1622, 161.7664), GeoPoint(-78.7507, 166.9958), GeoPoint(-78.1825, 164.7435), GeoPoint(-76.2426, 163.5682),
            GeoPoint(-74.3810, 166.0948), GeoPoint(-73.6560, 169.2873), GeoPoint(-71.6965, 171.2068), GeoPoint(-70.5796, 161.5705), GeoPoint(-68.5613, 154.2846),
            GeoPoint(-68.3850, 148.8396), GeoPoint(-66.9153, 145.4904), GeoPoint(-66.9546, 137.4603), GeoPoint(-65.3086, 135.0708), GeoPoint(-66.2100, 134.7574),
            GeoPoint(-67.2681, 119.8329), GeoPoint(-65.8768, 113.6047), GeoPoint(-66.9349, 106.1816), GeoPoint(-65.5633, 102.8324), GeoPoint(-67.2485, 99.7182),
            GeoPoint(-67.3857, 95.7815), GeoPoint(-67.1505, 89.6706), GeoPoint(-66.2099, 87.9863), GeoPoint(-67.1505, 86.7524), GeoPoint(-67.2093, 82.7764),
            GeoPoint(-69.4627, 77.6449), GeoPoint(-69.8742, 73.8649), GeoPoint(-72.2648, 69.8693), GeoPoint(-71.8533, 67.9499), GeoPoint(-70.6775, 69.0663),
            GeoPoint(-70.3053, 67.8127), GeoPoint(-69.2276, 69.6735), GeoPoint(-67.9343, 68.8900), GeoPoint(-67.9539, 61.4278), GeoPoint(-65.8180, 54.5335),
            GeoPoint(-69.7762, 38.6494), GeoPoint(-68.5026, 33.8704), GeoPoint(-69.6586, 31.9902), GeoPoint(-70.4621, 27.0937), GeoPoint(-69.9722, 13.4228),
            GeoPoint(-70.8343, 10.8178), GeoPoint(-69.8938, 7.7429), GeoPoint(-71.6377, -0.2286), GeoPoint(-70.9323, -6.8682), GeoPoint(-71.6965, -7.4166),
            GeoPoint(-71.2654, -10.2958), GeoPoint(-73.1465, -15.4469), GeoPoint(-73.8716, -16.4653), GeoPoint(-74.4986, -15.7015), GeoPoint(-75.1257, -17.5230),
            GeoPoint(-78.3392, -35.7770), GeoPoint(-79.4561, -35.6399), GeoPoint(-79.2602, -29.6858), GeoPoint(-80.3379, -28.5498), GeoPoint(-82.0819, -42.8084),
            GeoPoint(-81.7292, -49.7614), GeoPoint(-83.2184, -58.2225), GeoPoint(-79.1818, -78.0238), GeoPoint(-78.3784, -77.9259), GeoPoint(-77.9081, -73.6561),
            GeoPoint(-76.7129, -77.2404), GeoPoint(-76.6345, -70.6007), GeoPoint(-73.6952, -60.8274), GeoPoint(-70.7168, -61.8067), GeoPoint(-67.9539, -65.6651),
            GeoPoint(-66.1903, -62.1201), GeoPoint(-65.4849, -62.6489), GeoPoint(-64.7991, -62.0221), GeoPoint(-64.1525, -58.6141),
        ], triangles: [
            108, 0, 1, 1, 2, 3, 1, 3, 4, 6, 7, 8, 8, 9, 10, 8, 10, 11, 11, 12, 13, 8, 11, 13,
            6, 8, 13, 6, 13, 14, 6, 14, 15, 16, 17, 18, 15, 16, 18, 15, 18, 19, 15, 19, 20, 15, 20, 21,
            15, 21, 22, 6, 15, 22, 22, 23, 24, 6, 22, 24, 6, 24, 25, 6, 25, 26, 6, 26, 27, 27, 28, 29,
            6, 27, 29, 6, 29, 30, 6, 30, 31, 32, 33, 34, 32, 34, 35, 32, 35, 36, 31, 32, 36, 31, 36, 37,
            31, 37, 38, 31, 38, 39, 31, 39, 40, 31, 40, 41, 31, 41, 42, 45, 46, 47, 45, 47, 48, 44, 45, 48,
            44, 48, 49, 43, 44, 49, 43, 49, 50, 43, 50, 51, 43, 51, 52, 52, 53, 54, 43, 52, 54, 43, 54, 55,
            42, 43, 55, 42, 55, 56, 42, 56, 57, 57, 58, 59, 42, 57, 59, 42, 59, 60, 42, 60, 61, 61, 62, 63,
            42, 61, 63, 42, 63, 64, 42, 64, 65, 42, 65, 66, 42, 66, 67, 68, 69, 70, 70, 71, 72, 70, 72, 73,
            68, 70, 73, 68, 73, 74, 68, 74, 75, 67, 68, 75, 75, 76, 77, 67, 75, 77, 67, 77, 78, 42, 67, 78,
            42, 78, 79, 42, 79, 80, 80, 81, 82, 42, 80, 82, 82, 83, 84, 42, 82, 84, 84, 85, 86, 42, 84, 86,
            42, 86, 87, 42, 87, 88, 42, 88, 89, 42, 89, 90, 90, 91, 92, 42, 90, 92, 42, 92, 93, 42, 93, 94,
            94, 95, 96, 42, 94, 96, 31, 42, 96, 31, 96, 97, 31, 97, 98, 31, 98, 99, 31, 99, 100, 6, 31, 100,
            5, 6, 100, 5, 100, 101, 5, 101, 102, 4, 5, 102, 4, 102, 103, 4, 103, 104, 1, 4, 104, 104, 105, 106,
            1, 104, 106, 1, 106, 107, 1, 107, 108,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-52.5183, -69.3457), GeoPoint(-54.0743, -71.1077), GeoPoint(-52.8375, -74.6625), GeoPoint(-55.4991, -69.2321), GeoPoint(-54.7000, -65.0500),
            GeoPoint(-53.8500, -67.7500),
        ], triangles: [
            5, 0, 1, 1, 2, 3, 5, 1, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-51.5000, -59.1500), GeoPoint(-51.2500, -60.0000), GeoPoint(-51.8500, -61.2000), GeoPoint(-52.3000, -60.7000), GeoPoint(-51.8500, -59.8500),
            GeoPoint(-52.2000, -59.4000), GeoPoint(-51.9000, -58.0500), GeoPoint(-51.5500, -57.7500), GeoPoint(-51.1000, -58.5500),
        ], triangles: [
            0, 1, 2, 2, 3, 4, 0, 2, 4, 0, 4, 5, 8, 0, 5, 8, 5, 6, 6, 7, 8,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-49.2550, 70.5600), GeoPoint(-49.0650, 70.5250), GeoPoint(-48.9400, 69.5800), GeoPoint(-48.6250, 68.9350), GeoPoint(-48.8300, 68.8675),
            GeoPoint(-49.2425, 68.7200), GeoPoint(-49.7750, 68.7450), GeoPoint(-49.7100, 70.2800),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-41.1626, 144.7181), GeoPoint(-43.5497, 146.0484), GeoPoint(-43.2115, 147.9141), GeoPoint(-40.8754, 148.2891), GeoPoint(-40.7925, 145.3980),
        ], triangles: [
            4, 0, 1, 4, 1, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-45.1109, 167.0464), GeoPoint(-46.2199, 166.6769), GeoPoint(-46.6412, 169.3323), GeoPoint(-44.2425, 171.4529), GeoPoint(-43.8533, 173.0801),
            GeoPoint(-41.3492, 174.2476), GeoPoint(-40.9191, 173.0204),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-34.5291, 172.6360), GeoPoint(-37.3811, 174.6970), GeoPoint(-39.5089, 173.8240), GeoPoint(-39.9089, 174.9002), GeoPoint(-41.6883, 175.2396),
            GeoPoint(-37.6954, 178.5171), GeoPoint(-37.8813, 176.7632), GeoPoint(-36.1564, 174.6120),
        ], triangles: [
            7, 0, 1, 1, 2, 3, 7, 1, 3, 7, 3, 4, 4, 5, 6, 4, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-21.7000, 166.6000), GeoPoint(-21.0800, 165.7800), GeoPoint(-20.8000, 165.4600), GeoPoint(-20.4600, 165.0200), GeoPoint(-20.1200, 164.4600),
            GeoPoint(-20.1056, 164.0296), GeoPoint(-20.4447, 164.1680), GeoPoint(-21.1498, 164.8298), GeoPoint(-21.6796, 165.4744), GeoPoint(-22.1297, 166.1897),
            GeoPoint(-22.4000, 166.7400), GeoPoint(-22.1600, 167.1200),
        ], triangles: [
            11, 0, 1, 1, 2, 3, 1, 3, 4, 11, 1, 4, 11, 4, 5, 11, 5, 6, 11, 6, 7, 11, 7, 8,
            11, 8, 9, 9, 10, 11,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-17.5048, 178.1256), GeoPoint(-17.3811, 177.6709), GeoPoint(-17.7247, 177.2850), GeoPoint(-18.1643, 177.3815), GeoPoint(-18.2880, 177.9327),
            GeoPoint(-18.1506, 178.5527), GeoPoint(-17.6285, 178.7181), GeoPoint(-17.3399, 178.3736),
        ], triangles: [
            0, 1, 2, 0, 2, 3, 7, 0, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-16.5552, 180.0000), GeoPoint(-16.0671, 180.0000), GeoPoint(-16.3791, 179.4135), GeoPoint(-16.4340, 179.0966), GeoPoint(-16.6392, 178.5968),
            GeoPoint(-17.0120, 178.7251), GeoPoint(-16.8014, 179.3641),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-16.0209, -179.7933), GeoPoint(-16.0671, -180.0000), GeoPoint(-16.5552, -180.0000), GeoPoint(-16.5018, -179.9174),
        ], triangles: [
            3, 0, 1, 1, 2, 3,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-15.8918, 167.2168), GeoPoint(-16.1600, 167.1800), GeoPoint(-16.5979, 167.5152), GeoPoint(-16.4663, 167.8449),
        ], triangles: [
            3, 0, 1, 1, 2, 3,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-14.6265, 166.6291), GeoPoint(-15.3927, 166.6499), GeoPoint(-15.6688, 166.7932), GeoPoint(-15.6146, 167.0012), GeoPoint(-15.7400, 167.2700),
            GeoPoint(-14.9339, 167.1077),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-12.0406, 49.1947), GeoPoint(-14.5943, 47.7051), GeoPoint(-16.2162, 44.4465), GeoPoint(-20.0724, 44.3743), GeoPoint(-22.0574, 43.2542),
            GeoPoint(-24.9883, 44.0397), GeoPoint(-25.6014, 45.4095), GeoPoint(-24.9416, 47.0958), GeoPoint(-15.7102, 49.6726), GeoPoint(-15.7061, 50.3771),
            GeoPoint(-13.5558, 50.0565),
        ], triangles: [
            10, 0, 1, 10, 1, 2, 10, 2, 3, 10, 3, 4, 10, 4, 5, 10, 5, 6, 10, 6, 7, 10, 7, 8,
            8, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-10.6682, 142.5153), GeoPoint(-16.3889, 141.2741), GeoPoint(-17.7108, 140.2152), GeoPoint(-14.9977, 135.5002), GeoPoint(-12.3520, 136.9516),
            GeoPoint(-11.8572, 136.4925), GeoPoint(-12.2486, 135.2985), GeoPoint(-11.1285, 132.3572), GeoPoint(-11.2738, 131.8247), GeoPoint(-12.1140, 132.5753),
            GeoPoint(-12.5364, 130.6178), GeoPoint(-14.9698, 129.6215), GeoPoint(-13.8180, 127.0659), GeoPoint(-14.2307, 125.6858), GeoPoint(-16.5965, 123.5032),
            GeoPoint(-17.0690, 123.8593), GeoPoint(-16.4052, 123.0126), GeoPoint(-19.6837, 120.8562), GeoPoint(-20.7017, 116.7116), GeoPoint(-22.5175, 114.2253),
            GeoPoint(-21.7559, 114.1498), GeoPoint(-24.3848, 113.3935), GeoPoint(-26.2984, 114.2329), GeoPoint(-26.1165, 113.3390), GeoPoint(-31.6124, 115.6896),
            GeoPoint(-34.1965, 115.0268), GeoPoint(-35.0647, 118.0250), GeoPoint(-33.9761, 119.8937), GeoPoint(-33.8902, 123.6597), GeoPoint(-32.2160, 126.1487),
            GeoPoint(-31.4958, 131.3263), GeoPoint(-32.6172, 134.2739), GeoPoint(-34.8901, 135.9890), GeoPoint(-32.9000, 137.8103), GeoPoint(-35.2605, 136.8294),
            GeoPoint(-34.3847, 138.2076), GeoPoint(-35.6123, 138.1207), GeoPoint(-36.1384, 139.5741), GeoPoint(-38.0193, 140.6386), GeoPoint(-38.8095, 143.6100),
            GeoPoint(-37.8962, 145.0322), GeoPoint(-39.0358, 146.3179), GeoPoint(-37.4253, 149.9973), GeoPoint(-31.6404, 152.8916), GeoPoint(-26.0712, 153.1362),
            GeoPoint(-20.3912, 148.8484), GeoPoint(-18.9583, 146.3875), GeoPoint(-14.9850, 145.3747), GeoPoint(-13.7637, 143.5618),
        ], triangles: [
            48, 0, 1, 48, 1, 2, 3, 4, 5, 3, 5, 6, 3, 6, 7, 3, 7, 8, 3, 8, 9, 3, 9, 10,
            2, 3, 10, 2, 10, 11, 11, 12, 13, 2, 11, 13, 2, 13, 14, 2, 14, 15, 15, 16, 17, 2, 15, 17,
            2, 17, 18, 2, 18, 19, 19, 20, 21, 2, 19, 21, 2, 21, 22, 22, 23, 24, 2, 22, 24, 2, 24, 25,
            2, 25, 26, 2, 26, 27, 2, 27, 28, 2, 28, 29, 2, 29, 30, 48, 2, 30, 48, 30, 31, 48, 31, 32,
            48, 32, 33, 33, 34, 35, 48, 33, 35, 48, 35, 36, 48, 36, 37, 48, 37, 38, 48, 38, 39, 48, 39, 40,
            48, 40, 41, 48, 41, 42, 48, 42, 43, 43, 44, 45, 43, 45, 46, 48, 43, 46, 46, 47, 48,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-10.4467, 161.9174), GeoPoint(-10.2048, 161.3198), GeoPoint(-10.8200, 161.7000), GeoPoint(-10.8264, 162.3986), GeoPoint(-10.4827, 162.1190),
        ], triangles: [
            0, 1, 2, 4, 0, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-9.9697, 120.7755), GeoPoint(-9.6659, 120.4258), GeoPoint(-9.3613, 119.9003), GeoPoint(-9.5580, 118.9678), GeoPoint(-10.2586, 120.2950),
            GeoPoint(-10.2396, 120.7156),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-9.6102, 160.6885), GeoPoint(-9.4003, 160.3630), GeoPoint(-9.2430, 159.7029), GeoPoint(-9.6400, 159.6400), GeoPoint(-9.7940, 159.8494),
            GeoPoint(-9.8952, 160.4626), GeoPoint(-9.8729, 160.8522),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-9.1200, 161.2800), GeoPoint(-8.3200, 160.9200), GeoPoint(-8.3200, 160.5800), GeoPoint(-8.9175, 160.7883), GeoPoint(-9.7843, 161.5294),
            GeoPoint(-9.6000, 161.6800),
        ], triangles: [
            0, 1, 2, 5, 0, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-8.3973, 127.3359), GeoPoint(-8.6569, 125.0862), GeoPoint(-10.2400, 123.4600), GeoPoint(-10.1400, 124.4360),
        ], triangles: [
            3, 0, 1, 1, 2, 3,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-8.4493, 117.6320), GeoPoint(-8.4572, 117.0837), GeoPoint(-9.0329, 116.7401), GeoPoint(-9.0409, 117.2777), GeoPoint(-8.9066, 117.9704),
            GeoPoint(-8.7058, 119.1265), GeoPoint(-8.2807, 118.8785), GeoPoint(-8.3624, 118.2606), GeoPoint(-8.0957, 117.9000),
        ], triangles: [
            0, 1, 2, 0, 2, 3, 8, 0, 3, 8, 3, 4, 4, 5, 6, 4, 6, 7, 4, 7, 8,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-8.4606, 122.0074), GeoPoint(-8.5367, 121.3417), GeoPoint(-8.2370, 120.7151), GeoPoint(-8.4449, 119.9209), GeoPoint(-8.8104, 119.9244),
            GeoPoint(-8.9337, 121.2545), GeoPoint(-8.6498, 122.7570), GeoPoint(-8.0942, 122.9035),
        ], triangles: [
            1, 2, 3, 1, 3, 4, 0, 1, 4, 0, 4, 5, 7, 0, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-8.0200, 159.6400), GeoPoint(-7.5600, 158.8200), GeoPoint(-7.3200, 158.3600), GeoPoint(-7.4219, 158.2112), GeoPoint(-7.7548, 158.5861),
            GeoPoint(-8.1142, 159.1337), GeoPoint(-8.5383, 159.9174), GeoPoint(-8.3373, 159.8750),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-7.0216, 157.1400), GeoPoint(-6.5993, 156.5428), GeoPoint(-6.7659, 156.4914), GeoPoint(-7.1769, 156.9020), GeoPoint(-7.4048, 157.3394),
            GeoPoint(-7.3478, 157.5384),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-5.8959, 106.0516), GeoPoint(-6.8514, 105.3655), GeoPoint(-8.3708, 115.7055), GeoPoint(-6.4652, 110.7596), GeoPoint(-6.7777, 108.6235),
        ], triangles: [
            4, 0, 1, 4, 1, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-5.7376, 134.7270), GeoPoint(-5.4450, 134.4996), GeoPoint(-5.7831, 134.2903), GeoPoint(-6.1425, 134.1128), GeoPoint(-6.8952, 134.2101),
            GeoPoint(-6.2144, 134.7246),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-6.5400, 156.0200), GeoPoint(-6.2007, 155.5477), GeoPoint(-5.5668, 155.0629), GeoPoint(-5.3400, 154.7600), GeoPoint(-5.0424, 154.6525),
            GeoPoint(-5.1391, 154.5141), GeoPoint(-5.9008, 154.7292), GeoPoint(-6.5359, 155.1670), GeoPoint(-6.9200, 155.6000), GeoPoint(-6.8200, 155.8800),
        ], triangles: [
            9, 0, 1, 9, 1, 2, 9, 2, 3, 3, 4, 5, 9, 3, 5, 9, 5, 6, 9, 6, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-4.3130, 152.3387), GeoPoint(-4.1678, 151.5379), GeoPoint(-5.4558, 150.8075), GeoPoint(-5.7471, 148.3189), GeoPoint(-6.3178, 150.2412),
            GeoPoint(-5.4781, 151.9828),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-3.1293, 127.0007), GeoPoint(-3.1773, 125.9890), GeoPoint(-3.6074, 126.1838), GeoPoint(-3.7910, 126.8749), GeoPoint(-3.4591, 127.2492),
        ], triangles: [
            4, 0, 1, 4, 1, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-2.8022, 129.3710), GeoPoint(-2.8436, 128.1359), GeoPoint(-3.3934, 127.8989), GeoPoint(-3.4287, 128.5907), GeoPoint(-3.3626, 129.1552),
            GeoPoint(-3.4463, 129.9905), GeoPoint(-3.8585, 130.8348), GeoPoint(-3.0938, 130.4713),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-3.9800, 153.0200), GeoPoint(-3.6600, 152.6400), GeoPoint(-3.2400, 152.2400), GeoPoint(-3.0000, 151.8200), GeoPoint(-2.7800, 151.4800),
            GeoPoint(-2.5000, 150.9400), GeoPoint(-2.7415, 150.6620), GeoPoint(-3.0354, 151.3843), GeoPoint(-3.4621, 151.9532), GeoPoint(-3.7897, 152.4060),
            GeoPoint(-4.1761, 152.6387), GeoPoint(-4.7664, 152.8273), GeoPoint(-4.5000, 153.1400),
        ], triangles: [
            12, 0, 1, 12, 1, 2, 12, 2, 3, 12, 3, 4, 4, 5, 6, 4, 6, 7, 4, 7, 8, 4, 8, 9,
            12, 4, 9, 12, 9, 10, 10, 11, 12,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-0.3695, 132.3801), GeoPoint(-0.9377, 130.5196), GeoPoint(-2.2145, 133.6962), GeoPoint(-2.8206, 131.9898), GeoPoint(-4.1130, 132.9840),
            GeoPoint(-3.5389, 133.6629), GeoPoint(-5.3934, 137.9278), GeoPoint(-7.3202, 138.6686), GeoPoint(-8.4117, 137.6145), GeoPoint(-8.0960, 139.1278),
            GeoPoint(-9.3268, 142.6284), GeoPoint(-7.6301, 144.7442), GeoPoint(-10.1304, 147.9130), GeoPoint(-10.5827, 150.6906), GeoPoint(-7.3880, 147.1919),
            GeoPoint(-6.0837, 147.6481), GeoPoint(-3.8614, 144.5840), GeoPoint(-1.7027, 138.3297), GeoPoint(-3.3678, 135.4576), GeoPoint(-2.7692, 134.4226),
            GeoPoint(-1.1519, 134.1434),
        ], triangles: [
            20, 0, 1, 20, 1, 2, 2, 3, 4, 20, 2, 4, 20, 4, 5, 7, 8, 9, 6, 7, 9, 6, 9, 10,
            6, 10, 11, 5, 6, 11, 11, 12, 13, 11, 13, 14, 5, 11, 14, 5, 14, 15, 5, 15, 16, 16, 17, 18,
            5, 16, 18, 5, 18, 19, 5, 19, 20,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(1.3092, 120.8858), GeoPoint(0.5665, 120.0357), GeoPoint(-2.8020, 118.7678), GeoPoint(-3.4944, 119.4988), GeoPoint(-5.3799, 119.3669),
            GeoPoint(-5.5282, 120.4307), GeoPoint(-2.9316, 120.3055), GeoPoint(-2.6276, 120.9724), GeoPoint(-4.5746, 121.4895), GeoPoint(-4.4642, 122.7196),
            GeoPoint(-5.2829, 122.2364), GeoPoint(-5.3406, 123.1623), GeoPoint(-1.9045, 121.5083), GeoPoint(-0.6157, 123.3406), GeoPoint(-1.4089, 120.9359),
            GeoPoint(0.2372, 120.1831), GeoPoint(0.2356, 123.6855), GeoPoint(1.4198, 125.2405),
        ], triangles: [
            17, 0, 1, 1, 2, 3, 1, 3, 4, 1, 4, 5, 1, 5, 6, 1, 6, 7, 7, 8, 9, 9, 10, 11,
            9, 11, 12, 7, 9, 12, 12, 13, 14, 7, 12, 14, 7, 14, 15, 1, 7, 15, 17, 1, 15, 15, 16, 17,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(1.5408, 128.5946), GeoPoint(1.6285, 128.0042), GeoPoint(2.1746, 127.9324), GeoPoint(1.8107, 127.6005), GeoPoint(1.0117, 127.3995),
            GeoPoint(-0.2666, 127.6965), GeoPoint(-0.9000, 128.1000), GeoPoint(-0.7800, 128.3800), GeoPoint(-0.2521, 127.9680), GeoPoint(0.3564, 128.1202),
            GeoPoint(0.2585, 128.6360), GeoPoint(1.1324, 128.6882),
        ], triangles: [
            11, 0, 1, 1, 2, 3, 11, 1, 3, 11, 3, 4, 4, 5, 6, 6, 7, 8, 4, 6, 8, 4, 8, 9,
            11, 4, 9, 9, 10, 11,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(-3.0618, 106.1086), GeoPoint(-0.7119, 103.4376), GeoPoint(0.1045, 103.8384), GeoPoint(5.2463, 97.4849), GeoPoint(5.4798, 95.2930),
            GeoPoint(-4.2203, 102.5843), GeoPoint(-5.8524, 105.8177),
        ], triangles: [
            6, 0, 1, 1, 2, 3, 6, 1, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(3.2344, 117.3132), GeoPoint(5.4078, 119.1819), GeoPoint(6.9248, 116.7251), GeoPoint(3.1024, 112.9956), GeoPoint(2.6973, 111.3701),
            GeoPoint(1.8506, 111.1689), GeoPoint(2.0065, 109.6633), GeoPoint(-0.4595, 109.0919), GeoPoint(-2.9340, 110.2238), GeoPoint(-4.0127, 116.1481),
            GeoPoint(0.7842, 117.8119), GeoPoint(0.9022, 118.9967), GeoPoint(1.8276, 117.8756),
        ], triangles: [
            0, 1, 2, 0, 2, 3, 12, 0, 3, 12, 3, 4, 12, 4, 5, 5, 6, 7, 12, 5, 7, 12, 7, 8,
            12, 8, 9, 12, 9, 10, 10, 11, 12,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(9.7603, 125.4121), GeoPoint(8.9870, 125.4714), GeoPoint(8.6930, 123.4877), GeoPoint(7.1921, 121.9199), GeoPoint(7.8335, 123.6102),
            GeoPoint(6.1614, 124.2198), GeoPoint(5.5810, 125.3965), GeoPoint(6.7865, 125.3639), GeoPoint(7.2937, 125.8314), GeoPoint(6.2743, 126.1968),
            GeoPoint(7.1894, 126.5374), GeoPoint(8.4147, 126.3768),
        ], triangles: [
            11, 0, 1, 11, 1, 2, 2, 3, 4, 11, 2, 4, 11, 4, 5, 5, 6, 7, 11, 5, 7, 11, 7, 8,
            11, 8, 9, 9, 10, 11,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(6.4818, 81.6373), GeoPoint(7.5231, 81.7880), GeoPoint(8.5642, 81.3043), GeoPoint(9.2684, 80.8388), GeoPoint(9.8241, 80.1478),
            GeoPoint(8.2008, 79.6952), GeoPoint(6.7635, 79.8725), GeoPoint(5.9684, 80.3484), GeoPoint(6.1971, 81.2180),
        ], triangles: [
            8, 0, 1, 8, 1, 2, 8, 2, 3, 8, 3, 4, 8, 4, 5, 8, 5, 6, 6, 7, 8,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(10.8550, -60.8950), GeoPoint(10.8900, -61.1050), GeoPoint(10.7600, -61.6800), GeoPoint(10.3650, -61.6600), GeoPoint(10.0900, -61.9500),
            GeoPoint(10.0000, -61.7700), GeoPoint(10.1100, -60.9350),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(11.2327, 124.0779), GeoPoint(10.2674, 123.3378), GeoPoint(10.9406, 123.4989), GeoPoint(10.8819, 122.9474), GeoPoint(10.2612, 122.8371),
            GeoPoint(9.9810, 122.5861), GeoPoint(9.7134, 122.3801), GeoPoint(9.0222, 122.9959), GeoPoint(9.3183, 123.3099), GeoPoint(9.9501, 123.6232),
            GeoPoint(10.2788, 123.9824),
        ], triangles: [
            10, 0, 1, 1, 2, 3, 1, 3, 4, 1, 4, 5, 10, 1, 5, 10, 5, 6, 6, 7, 8, 6, 8, 9,
            6, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(10.0037, 119.0295), GeoPoint(10.5543, 119.6897), GeoPoint(11.3697, 119.5115), GeoPoint(10.3763, 118.9873), GeoPoint(9.6845, 118.3869),
            GeoPoint(9.0669, 117.6645), GeoPoint(8.3675, 117.1743), GeoPoint(9.3164, 118.5046),
        ], triangles: [
            0, 1, 2, 7, 0, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(11.4158, 122.0384), GeoPoint(10.9057, 121.9674), GeoPoint(10.4410, 122.0026), GeoPoint(10.7413, 122.6377), GeoPoint(11.1659, 123.1008),
            GeoPoint(11.5837, 123.1202), GeoPoint(11.5822, 122.4838), GeoPoint(11.8918, 121.8835),
        ], triangles: [
            0, 1, 2, 0, 2, 3, 7, 0, 3, 7, 3, 4, 4, 5, 6, 4, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(12.5578, 124.2668), GeoPoint(10.1347, 124.8018), GeoPoint(11.3115, 125.0119), GeoPoint(11.0461, 125.7835), GeoPoint(12.1627, 125.5026),
        ], triangles: [
            0, 1, 2, 4, 0, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(13.4297, 121.1801), GeoPoint(13.4664, 120.3234), GeoPoint(12.7045, 120.8339), GeoPoint(12.2056, 121.2622), GeoPoint(13.0696, 121.5274),
        ], triangles: [
            4, 0, 1, 4, 1, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(16.3637, 119.8838), GeoPoint(14.9709, 120.0704), GeoPoint(14.5254, 120.9918), GeoPoint(13.8577, 120.6286), GeoPoint(12.5367, 124.0774),
            GeoPoint(13.7821, 123.9503), GeoPoint(14.3284, 121.7288), GeoPoint(17.0935, 122.5157), GeoPoint(18.4790, 122.2460), GeoPoint(18.5041, 121.3213),
        ], triangles: [
            9, 0, 1, 9, 1, 2, 2, 3, 4, 4, 5, 6, 2, 4, 6, 9, 2, 6, 9, 6, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(18.4267, -65.7713), GeoPoint(18.5148, -66.2824), GeoPoint(18.5206, -67.1007), GeoPoint(18.3745, -67.2424), GeoPoint(17.9466, -67.1842),
            GeoPoint(17.9818, -66.5999), GeoPoint(17.9759, -65.8472), GeoPoint(18.2280, -65.5910),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(17.8869, -76.1997), GeoPoint(18.1607, -76.3654), GeoPoint(18.4009, -76.8966), GeoPoint(18.4905, -77.5696), GeoPoint(18.5242, -77.7974),
            GeoPoint(18.4545, -78.2177), GeoPoint(18.2260, -78.3377), GeoPoint(17.8616, -77.7660), GeoPoint(17.7011, -77.2063), GeoPoint(17.8682, -76.9026),
        ], triangles: [
            9, 0, 1, 9, 1, 2, 9, 2, 3, 9, 3, 4, 9, 4, 5, 9, 5, 6, 9, 6, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(19.6396, -73.4150), GeoPoint(18.6684, -72.3349), GeoPoint(18.3425, -74.4580), GeoPoint(17.5986, -71.4002), GeoPoint(18.4269, -70.6693),
            GeoPoint(18.6122, -68.3179), GeoPoint(19.8715, -72.5797),
        ], triangles: [
            6, 0, 1, 1, 2, 3, 6, 1, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(19.2559, 110.5706), GeoPoint(19.6959, 111.0101), GeoPoint(20.0775, 110.7866), GeoPoint(20.1013, 110.2116), GeoPoint(19.8210, 109.1191),
            GeoPoint(19.3679, 108.6262), GeoPoint(18.5077, 108.6552), GeoPoint(18.1977, 109.4752), GeoPoint(18.6784, 110.3392),
        ], triangles: [
            0, 1, 2, 8, 0, 2, 8, 2, 3, 8, 3, 4, 8, 4, 5, 8, 5, 6, 6, 7, 8,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(19.5087, -154.8074), GeoPoint(20.2672, -155.8611), GeoPoint(19.0835, -155.5421),
        ], triangles: [
            0, 1, 2,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(20.7640, -155.9957), GeoPoint(20.9174, -156.2571), GeoPoint(21.0125, -156.6126), GeoPoint(20.9268, -156.7106), GeoPoint(20.8643, -156.7017),
            GeoPoint(20.7830, -156.5867), GeoPoint(20.5724, -156.4144), GeoPoint(20.6440, -156.0793),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(21.2196, -157.2503), GeoPoint(21.0978, -157.3252), GeoPoint(21.0687, -156.7893), GeoPoint(21.1768, -156.7582),
        ], triangles: [
            3, 0, 1, 1, 2, 3,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(21.6527, -157.9416), GeoPoint(21.7170, -158.0252), GeoPoint(21.5791, -158.2927), GeoPoint(21.5392, -158.2538), GeoPoint(21.3124, -158.1267),
            GeoPoint(21.2773, -157.7786), GeoPoint(21.2644, -157.7070), GeoPoint(21.3222, -157.6528),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(22.2149, -159.3657), GeoPoint(22.2362, -159.5962), GeoPoint(22.1382, -159.7488), GeoPoint(22.0653, -159.8005), GeoPoint(21.8830, -159.4637),
            GeoPoint(21.9820, -159.3451),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(23.1886, -82.2682), GeoPoint(21.8960, -84.9749), GeoPoint(22.6370, -81.7950), GeoPoint(21.5981, -78.7199), GeoPoint(20.4134, -77.0851),
            GeoPoint(19.8555, -77.7555), GeoPoint(20.2846, -74.1780), GeoPoint(22.7653, -79.6795),
        ], triangles: [
            0, 1, 2, 7, 0, 2, 7, 2, 3, 7, 3, 4, 4, 5, 6, 4, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(24.3400, -77.5400), GeoPoint(25.1700, -77.8900), GeoPoint(25.2103, -78.1909), GeoPoint(24.5756, -78.4085), GeoPoint(24.2861, -78.0340),
            GeoPoint(23.7100, -77.7800), GeoPoint(23.7598, -77.5347),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 2, 3, 4, 6, 2, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(24.3943, 121.7778), GeoPoint(24.9976, 121.9512), GeoPoint(25.2955, 121.4950), GeoPoint(24.5385, 120.6947), GeoPoint(23.5563, 120.1062),
            GeoPoint(22.8149, 120.2201), GeoPoint(21.9706, 120.7471), GeoPoint(22.7909, 121.1756),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(26.8400, -77.8500), GeoPoint(26.8700, -78.5100), GeoPoint(26.7900, -78.9800), GeoPoint(26.4200, -78.9100), GeoPoint(26.5800, -77.8200),
        ], triangles: [
            4, 0, 1, 4, 1, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(27.0400, -77.7900), GeoPoint(26.9252, -77.7880), GeoPoint(26.5300, -77.3400), GeoPoint(26.0073, -77.3564), GeoPoint(25.8792, -77.1726),
            GeoPoint(26.5900, -77.0000),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(34.3649, 133.9041), GeoPoint(33.9446, 133.4930), GeoPoint(34.0603, 132.9244), GeoPoint(33.4636, 132.3712), GeoPoint(32.9894, 132.3631),
            GeoPoint(32.7046, 133.0149), GeoPoint(33.2896, 133.2803), GeoPoint(33.5220, 133.7929), GeoPoint(33.2012, 134.2034), GeoPoint(33.8063, 134.7664),
            GeoPoint(34.1492, 134.6384),
        ], triangles: [
            10, 0, 1, 1, 2, 3, 10, 1, 3, 10, 3, 4, 4, 5, 6, 10, 4, 6, 10, 6, 7, 10, 7, 8,
            8, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(35.3732, 33.6672), GeoPoint(35.3867, 32.9470), GeoPoint(35.1455, 32.8025), GeoPoint(35.1400, 32.7318), GeoPoint(35.1032, 32.2567),
            GeoPoint(34.7017, 32.4903), GeoPoint(34.5719, 32.9798), GeoPoint(34.9781, 34.0049), GeoPoint(35.0585, 33.9736), GeoPoint(35.2458, 33.9008),
            GeoPoint(35.6716, 34.5765),
        ], triangles: [
            0, 1, 2, 3, 4, 5, 2, 3, 5, 0, 2, 5, 10, 0, 5, 5, 6, 7, 5, 7, 8, 5, 8, 9,
            5, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(35.2800, 23.5150), GeoPoint(35.0850, 24.7350), GeoPoint(34.9200, 24.7250), GeoPoint(35.0050, 26.1650), GeoPoint(35.3000, 26.2900),
            GeoPoint(35.1800, 25.7450), GeoPoint(35.3540, 25.7692), GeoPoint(35.4250, 25.0250), GeoPoint(35.3680, 24.2467), GeoPoint(35.7050, 23.7000),
        ], triangles: [
            1, 2, 3, 0, 1, 3, 3, 4, 5, 0, 3, 5, 0, 5, 6, 0, 6, 7, 0, 7, 8, 0, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(38.1439, 14.7612), GeoPoint(38.0350, 13.7412), GeoPoint(38.1264, 12.5709), GeoPoint(37.6129, 12.4310), GeoPoint(37.1045, 13.8267),
            GeoPoint(36.9966, 14.3352), GeoPoint(36.6200, 15.1000), GeoPoint(37.1342, 15.3099), GeoPoint(37.4440, 15.1602), GeoPoint(38.2312, 15.5204),
        ], triangles: [
            1, 2, 3, 0, 1, 3, 9, 0, 3, 9, 3, 4, 9, 4, 5, 5, 6, 7, 5, 7, 8, 5, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(40.9000, 8.7100), GeoPoint(40.9500, 8.1600), GeoPoint(40.3783, 8.3883), GeoPoint(39.1718, 8.4283), GeoPoint(38.9066, 8.8069),
            GeoPoint(39.2405, 9.2148), GeoPoint(39.1774, 9.6695), GeoPoint(40.5000, 9.8100), GeoPoint(41.2100, 9.2100),
        ], triangles: [
            0, 1, 2, 8, 0, 2, 8, 2, 3, 8, 3, 4, 8, 4, 5, 8, 5, 6, 6, 7, 8,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(39.1809, 141.8846), GeoPoint(41.3786, 141.3690), GeoPoint(40.5633, 139.8834), GeoPoint(38.2160, 139.4264), GeoPoint(36.8274, 137.3906),
            GeoPoint(37.3050, 136.7238), GeoPoint(35.5271, 135.6775), GeoPoint(35.4334, 132.6177), GeoPoint(33.2961, 129.4085), GeoPoint(32.3195, 130.4477),
            GeoPoint(31.4182, 130.2024), GeoPoint(31.4504, 131.3328), GeoPoint(33.1500, 132.0000), GeoPoint(33.8858, 130.9861), GeoPoint(34.5965, 135.0794),
            GeoPoint(33.4648, 135.7930), GeoPoint(34.6063, 137.2176), GeoPoint(35.1381, 140.2533), GeoPoint(37.1421, 140.9764),
        ], triangles: [
            18, 0, 1, 18, 1, 2, 18, 2, 3, 18, 3, 4, 4, 5, 6, 18, 4, 6, 9, 10, 11, 9, 11, 12,
            8, 9, 12, 8, 12, 13, 7, 8, 13, 6, 7, 13, 18, 6, 13, 18, 13, 14, 14, 15, 16, 18, 14, 16,
            16, 17, 18,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(43.0100, 9.3900), GeoPoint(42.6281, 8.7460), GeoPoint(42.2565, 8.5442), GeoPoint(41.5836, 8.7757), GeoPoint(41.3800, 9.2298),
            GeoPoint(42.1525, 9.5600),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(45.5515, 141.9676), GeoPoint(43.3888, 141.3805), GeoPoint(42.5638, 139.8175), GeoPoint(41.5696, 139.9551), GeoPoint(41.5846, 141.0673),
            GeoPoint(42.6788, 141.6115), GeoPoint(41.9952, 143.1839), GeoPoint(43.2621, 145.5431), GeoPoint(44.3847, 145.3208), GeoPoint(44.1741, 143.9102),
        ], triangles: [
            9, 0, 1, 9, 1, 2, 2, 3, 4, 2, 4, 5, 9, 2, 5, 9, 5, 6, 9, 6, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(47.0360, -64.0149), GeoPoint(46.7275, -64.3926), GeoPoint(46.3927, -64.1428), GeoPoint(45.9682, -62.8743), GeoPoint(46.0334, -62.5039),
            GeoPoint(46.4431, -62.0121), GeoPoint(46.4159, -62.9393), GeoPoint(46.5500, -63.6645),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 4, 5, 6, 4, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(49.2886, -61.8356), GeoPoint(49.7064, -62.8583), GeoPoint(49.9572, -64.1732), GeoPoint(49.8730, -64.5191), GeoPoint(49.4007, -63.5893),
            GeoPoint(49.0872, -62.2932), GeoPoint(49.1051, -61.8063),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(50.2950, -125.7550), GeoPoint(50.7706, -128.3584), GeoPoint(48.8250, -125.6550), GeoPoint(48.5100, -123.5100),
        ], triangles: [
            3, 0, 1, 1, 2, 3,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(51.5883, -55.4070), GeoPoint(50.7183, -57.3587), GeoPoint(47.6033, -59.2660), GeoPoint(47.6325, -56.2508), GeoPoint(46.8850, -55.4008),
            GeoPoint(47.7523, -54.2405), GeoPoint(46.8071, -54.1789), GeoPoint(46.6555, -53.0692), GeoPoint(47.5355, -52.6481), GeoPoint(48.6878, -53.0861),
            GeoPoint(48.5168, -53.7860), GeoPoint(49.2491, -53.4765), GeoPoint(49.8123, -56.7959), GeoPoint(50.6870, -56.1340),
        ], triangles: [
            13, 0, 1, 13, 1, 2, 3, 4, 5, 2, 3, 5, 5, 6, 7, 5, 7, 8, 5, 8, 9, 5, 9, 10,
            2, 5, 10, 2, 10, 11, 2, 11, 12, 2, 12, 13,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(54.1700, -133.1800), GeoPoint(53.8511, -133.2397), GeoPoint(53.4115, -133.0546), GeoPoint(53.1000, -132.5500), GeoPoint(52.6397, -132.1804),
            GeoPoint(52.1824, -131.5778), GeoPoint(52.1804, -131.1790), GeoPoint(52.9846, -132.0495), GeoPoint(54.1200, -131.7500), GeoPoint(54.0400, -132.7100),
            GeoPoint(54.0400, -132.7100), GeoPoint(54.0400, -132.7100),
        ], triangles: [
            0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 5, 5, 6, 7, 0, 5, 7, 11, 0, 7, 7, 8, 11,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(54.2255, 142.2097), GeoPoint(51.9354, 141.5941), GeoPoint(45.9668, 142.0920), GeoPoint(46.7408, 142.7477), GeoPoint(46.1379, 143.5053),
            GeoPoint(47.8616, 142.5587), GeoPoint(49.3066, 143.1739), GeoPoint(48.9764, 144.6541), GeoPoint(50.7476, 143.6480),
        ], triangles: [
            8, 0, 1, 1, 2, 3, 3, 4, 5, 1, 3, 5, 8, 1, 5, 8, 5, 6, 6, 7, 8,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(53.1532, -6.0330), GeoPoint(53.8676, -6.1979), GeoPoint(54.5546, -5.6619), GeoPoint(55.1729, -6.7338), GeoPoint(55.1316, -7.5722),
            GeoPoint(54.6645, -8.3280), GeoPoint(53.8814, -9.6885), GeoPoint(52.8646, -9.1663), GeoPoint(51.8205, -9.9771), GeoPoint(51.6693, -8.5616),
            GeoPoint(52.2601, -6.7889),
        ], triangles: [
            10, 0, 1, 1, 2, 3, 10, 1, 3, 10, 3, 4, 10, 4, 5, 10, 5, 6, 10, 6, 7, 10, 7, 8,
            8, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(56.1114, 12.3709), GeoPoint(55.7800, 10.9039), GeoPoint(55.3649, 11.0435), GeoPoint(54.8000, 12.0900), GeoPoint(55.6100, 12.6900),
        ], triangles: [
            4, 0, 1, 4, 1, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(57.5911, -152.1411), GeoPoint(57.9014, -152.5648), GeoPoint(57.9690, -153.2287), GeoPoint(57.8166, -153.7628), GeoPoint(57.4612, -154.6710),
            GeoPoint(56.9927, -154.5164), GeoPoint(56.7347, -154.0051), GeoPoint(57.1158, -153.0063),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(58.6300, -5.0100), GeoPoint(56.7850, -6.1500), GeoPoint(55.3111, -5.5864), GeoPoint(55.7840, -5.0480), GeoPoint(54.7910, -4.8442),
            GeoPoint(53.9850, -2.9450), GeoPoint(53.4950, -4.5800), GeoPoint(52.3014, -4.2223), GeoPoint(51.9914, -5.2673), GeoPoint(51.4260, -3.4149),
            GeoPoint(50.1597, -5.7766), GeoPoint(49.9600, -5.2450), GeoPoint(51.2894, 1.4499), GeoPoint(52.7395, 1.6815), GeoPoint(55.9738, -3.1190),
            GeoPoint(57.6848, -1.9593), GeoPoint(57.5530, -4.0738), GeoPoint(58.6350, -3.0050),
        ], triangles: [
            17, 0, 1, 1, 2, 3, 3, 4, 5, 1, 3, 5, 5, 6, 7, 7, 8, 9, 5, 7, 9, 9, 10, 11,
            9, 11, 12, 5, 9, 12, 1, 5, 12, 1, 12, 13, 1, 13, 14, 1, 14, 15, 1, 15, 16, 1, 16, 17,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(60.2936, -165.6744), GeoPoint(60.3842, -166.4678), GeoPoint(60.2131, -167.4553), GeoPoint(59.9414, -166.8483), GeoPoint(59.7544, -166.1928),
            GeoPoint(59.9100, -165.5792),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(62.3637, -79.5200), GeoPoint(62.3856, -79.9294), GeoPoint(62.0856, -80.3154), GeoPoint(62.0165, -80.3621), GeoPoint(61.7181, -80.0996),
            GeoPoint(61.6331, -79.6575), GeoPoint(62.1587, -79.2658),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(62.9046, -81.8770), GeoPoint(62.9141, -83.2505), GeoPoint(62.4528, -83.9937), GeoPoint(62.1823, -83.7746), GeoPoint(62.1592, -83.0686),
            GeoPoint(62.7108, -81.8983),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(63.4058, -171.7911), GeoPoint(63.3178, -171.5531), GeoPoint(63.3758, -170.6714), GeoPoint(63.1944, -170.2906), GeoPoint(62.9769, -169.5294),
            GeoPoint(63.1886, -168.7719), GeoPoint(63.2975, -168.6894), GeoPoint(63.4311, -169.6825), GeoPoint(63.6950, -170.4911), GeoPoint(63.5922, -171.1144),
            GeoPoint(63.7825, -171.7317),
        ], triangles: [
            10, 0, 1, 10, 1, 2, 2, 3, 4, 10, 2, 4, 4, 5, 6, 4, 6, 7, 4, 7, 8, 4, 8, 9,
            4, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(65.7388, -85.8838), GeoPoint(63.5412, -87.2220), GeoPoint(63.7260, -80.1035), GeoPoint(65.6573, -85.1613),
        ], triangles: [
            3, 0, 1, 1, 2, 3,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(65.7321, -20.5763), GeoPoint(66.4105, -22.1349), GeoPoint(65.6112, -24.3262), GeoPoint(65.3786, -22.2274), GeoPoint(64.8911, -23.9550),
            GeoPoint(64.4021, -21.7785), GeoPoint(63.9602, -22.7630), GeoPoint(63.4964, -18.6562), GeoPoint(65.1267, -13.6097), GeoPoint(65.8087, -14.7396),
            GeoPoint(66.4559, -14.5087),
        ], triangles: [
            0, 1, 2, 0, 2, 3, 10, 0, 3, 10, 3, 4, 10, 4, 5, 10, 5, 6, 10, 6, 7, 7, 8, 9,
            7, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(67.4442, -75.2160), GeoPoint(67.5820, -75.1033), GeoPoint(68.0104, -75.1145), GeoPoint(68.2872, -75.8952), GeoPoint(68.1486, -76.8117),
            GeoPoint(67.5881, -77.2364), GeoPoint(67.0987, -76.9869), GeoPoint(67.1489, -75.8659),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(67.2059, -174.9282), GeoPoint(68.9636, -180.0000), GeoPoint(64.9797, -180.0000), GeoPoint(65.8746, -179.8838), GeoPoint(66.1121, -178.6861),
            GeoPoint(65.3905, -178.3599), GeoPoint(64.2527, -172.9553), GeoPoint(65.4379, -172.5302), GeoPoint(65.9772, -169.8996), GeoPoint(66.9131, -171.8573),
            GeoPoint(66.5844, -175.0143),
        ], triangles: [
            10, 0, 1, 1, 2, 3, 1, 3, 4, 10, 1, 4, 10, 4, 5, 10, 5, 6, 10, 6, 7, 10, 7, 8,
            8, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(69.4900, -96.2574), GeoPoint(69.6800, -96.5574), GeoPoint(69.8600, -97.1574), GeoPoint(70.1435, -98.2183), GeoPoint(69.7100, -98.9174),
            GeoPoint(69.4000, -99.7974), GeoPoint(68.9507, -98.4318), GeoPoint(69.0600, -97.6174), GeoPoint(68.7570, -96.2695), GeoPoint(69.1077, -95.6477),
        ], triangles: [
            0, 1, 2, 9, 0, 2, 9, 2, 3, 9, 3, 4, 9, 4, 5, 5, 6, 7, 9, 5, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(71.5157, 180.0000), GeoPoint(71.0988, 178.7253), GeoPoint(70.7811, 178.9034), GeoPoint(70.8322, 180.0000),
        ], triangles: [
            3, 0, 1, 1, 2, 3,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(71.1328, -177.6636), GeoPoint(71.2695, -177.5779), GeoPoint(71.5555, -179.0243), GeoPoint(71.5576, -179.8719), GeoPoint(71.5157, -180.0000),
            GeoPoint(70.8322, -180.0000), GeoPoint(70.8930, -178.6938),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(69.7001, -92.4069), GeoPoint(70.1913, -91.5196), GeoPoint(71.9205, -95.2088), GeoPoint(71.1949, -96.3911), GeoPoint(70.0899, -96.4713),
            GeoPoint(69.0691, -94.2328), GeoPoint(67.2935, -96.1258), GeoPoint(68.2395, -96.1199), GeoPoint(68.5787, -97.6695), GeoPoint(67.7817, -98.4432),
            GeoPoint(67.6469, -101.4543), GeoPoint(68.8001, -106.1500), GeoPoint(68.6539, -108.1672), GeoPoint(68.3117, -108.8130), GeoPoint(67.8875, -107.7924),
            GeoPoint(67.3815, -108.8802), GeoPoint(67.9027, -115.3048), GeoPoint(68.3989, -113.8979), GeoPoint(69.7979, -121.4723), GeoPoint(69.3997, -124.2896),
            GeoPoint(70.1585, -124.4248), GeoPoint(69.4807, -125.7563), GeoPoint(70.4839, -128.1382), GeoPoint(68.8981, -136.5036), GeoPoint(71.3579, -156.5808),
            GeoPoint(68.3589, -166.7644), GeoPoint(66.1161, -161.6778), GeoPoint(66.5767, -164.4747), GeoPoint(65.6701, -168.1105), GeoPoint(64.4471, -164.9608),
            GeoPoint(64.7887, -160.7777), GeoPoint(64.4029, -161.5180), GeoPoint(63.7661, -160.7725), GeoPoint(63.1465, -164.5625), GeoPoint(61.5001, -166.1214),
            GeoPoint(59.7981, -163.8183), GeoPoint(59.6337, -161.8741), GeoPoint(58.6717, -161.9688), GeoPoint(58.9189, -157.0417), GeoPoint(57.5701, -157.7228),
            GeoPoint(54.4043, -164.7856), GeoPoint(55.9941, -158.4333), GeoPoint(58.1465, -154.2325), GeoPoint(58.8647, -153.2875), GeoPoint(59.3503, -154.0191),
            GeoPoint(61.2845, -150.6211), GeoPoint(59.1559, -151.7163), GeoPoint(60.8847, -147.1144), GeoPoint(58.1231, -134.0780), GeoPoint(52.7555, -129.1297),
            GeoPoint(52.3297, -127.8503), GeoPoint(50.8307, -127.4356), GeoPoint(49.0001, -122.8400), GeoPoint(47.0961, -122.5873), GeoPoint(48.0401, -123.1200),
            GeoPoint(48.1845, -124.6872), GeoPoint(45.5235, -123.8989), GeoPoint(40.3133, -124.3980), GeoPoint(34.6085, -120.6228), GeoPoint(33.0463, -117.2959),
            GeoPoint(28.5661, -114.1620), GeoPoint(27.7227, -115.0551), GeoPoint(26.0121, -112.3007), GeoPoint(24.7385, -112.1820), GeoPoint(22.8231, -110.0313),
            GeoPoint(23.1857, -109.4334), GeoPoint(30.1627, -114.6739), GeoPoint(31.7997, -114.7764), GeoPoint(31.1711, -113.1487), GeoPoint(28.9545, -112.2282),
            GeoPoint(22.7737, -106.0287), GeoPoint(19.9469, -105.4930), GeoPoint(18.2923, -103.5010), GeoPoint(15.6535, -96.5574), GeoPoint(16.2011, -94.6916),
            GeoPoint(13.9279, -91.2324), GeoPoint(13.2975, -87.4894), GeoPoint(9.9333, -85.6607), GeoPoint(7.2205, -80.8864), GeoPoint(8.9325, -79.5578),
            GeoPoint(8.3193, -78.1820), GeoPoint(3.8497, -77.1277), GeoPoint(-1.0574, -80.9336), GeoPoint(-2.2469, -80.9677), GeoPoint(-2.6575, -79.7702),
            GeoPoint(-4.7367, -81.4109), GeoPoint(-6.1368, -81.2500), GeoPoint(-7.1943, -79.7605), GeoPoint(-14.6493, -76.0092), GeoPoint(-17.3634, -71.4620),
            GeoPoint(-19.7564, -70.1644), GeoPoint(-32.4189, -71.4385), GeoPoint(-37.1563, -73.5880), GeoPoint(-39.2586, -73.2176), GeoPoint(-43.2250, -74.3319),
            GeoPoint(-42.3833, -72.7177), GeoPoint(-44.4549, -73.2403), GeoPoint(-44.1030, -74.3517), GeoPoint(-46.6476, -75.6444), GeoPoint(-46.9392, -74.1266),
            GeoPoint(-48.6737, -75.6080), GeoPoint(-52.2627, -74.9468), GeoPoint(-53.8332, -71.0063), GeoPoint(-52.8992, -70.8451), GeoPoint(-52.3500, -68.1500),
            GeoPoint(-50.7325, -69.1385), GeoPoint(-48.1333, -65.9851), GeoPoint(-47.2361, -65.6410), GeoPoint(-46.3017, -67.5805), GeoPoint(-45.5519, -67.2938),
            GeoPoint(-45.0368, -65.5652), GeoPoint(-43.4953, -65.1818), GeoPoint(-42.5631, -63.4580), GeoPoint(-42.0580, -64.9786), GeoPoint(-41.0643, -65.1180),
            GeoPoint(-41.0287, -62.7458), GeoPoint(-38.8277, -62.3359), GeoPoint(-38.7202, -59.2318), GeoPoint(-36.9015, -56.7882), GeoPoint(-33.9095, -58.4270),
            GeoPoint(-34.8598, -56.2152), GeoPoint(-34.3968, -53.8064), GeoPoint(-28.6741, -48.8884), GeoPoint(-24.8852, -47.6490), GeoPoint(-21.9373, -40.9447),
            GeoPoint(-17.8677, -39.2673), GeoPoint(-13.0577, -38.6739), GeoPoint(-8.9964, -35.1282), GeoPoint(-7.3432, -34.7300), GeoPoint(-5.1495, -35.5978),
            GeoPoint(-2.8730, -39.9786), GeoPoint(-2.6913, -44.5816), GeoPoint(-1.5517, -44.9057), GeoPoint(-0.5816, -47.8249), GeoPoint(-1.2378, -48.5844),
            GeoPoint(-0.2354, -48.6205), GeoPoint(-0.0784, -50.3882), GeoPoint(1.7365, -49.9740), GeoPoint(4.2035, -51.3171), GeoPoint(5.7565, -53.9580),
            GeoPoint(5.9731, -57.1474), GeoPoint(9.9483, -62.3885), GeoPoint(10.7157, -61.8809), GeoPoint(10.0773, -64.8904), GeoPoint(10.5547, -68.1941),
            GeoPoint(12.1623, -69.9432), GeoPoint(10.9691, -71.4006), GeoPoint(9.0723, -71.6956), GeoPoint(11.4233, -71.9470), GeoPoint(12.1131, -71.1374),
            GeoPoint(12.4373, -71.7541), GeoPoint(11.0831, -74.9069), GeoPoint(8.6387, -76.8366), GeoPoint(9.6117, -79.5733), GeoPoint(8.7863, -81.4392),
            GeoPoint(11.1031, -83.8089), GeoPoint(15.2709, -83.4104), GeoPoint(15.8873, -88.9306), GeoPoint(21.5435, -87.0519), GeoPoint(20.9999, -90.2786),
            GeoPoint(19.2841, -90.7718), GeoPoint(18.7047, -92.0373), GeoPoint(18.1443, -94.4257), GeoPoint(19.3205, -96.2921), GeoPoint(22.4443, -97.8724),
            GeoPoint(27.3801, -97.3700), GeoPoint(28.3075, -96.5940), GeoPoint(29.7137, -93.8484), GeoPoint(29.1175, -90.1546), GeoPoint(29.2911, -89.2176),
            GeoPoint(30.3161, -89.1805), GeoPoint(30.0901, -84.1000), GeoPoint(25.8701, -81.7100), GeoPoint(25.2063, -80.3810), GeoPoint(26.8801, -80.0565),
            GeoPoint(31.4405, -81.3363), GeoPoint(35.5507, -75.7275), GeoPoint(38.2329, -76.9600), GeoPoint(38.0833, -76.3293), GeoPoint(39.1501, -76.3500),
            GeoPoint(37.2169, -75.9402), GeoPoint(38.4041, -75.0567), GeoPoint(39.4985, -75.5281), GeoPoint(38.9395, -74.9060), GeoPoint(40.7507, -73.9523),
            GeoPoint(40.9301, -71.9450), GeoPoint(40.9311, -73.7100), GeoPoint(41.6371, -69.9650), GeoPoint(43.0301, -70.6900), GeoPoint(45.1375, -67.1374),
            GeoPoint(45.2921, -64.4255), GeoPoint(44.4651, -66.1617), GeoPoint(43.5453, -65.3641), GeoPoint(45.9205, -59.8028), GeoPoint(47.0079, -60.5181),
            GeoPoint(45.8839, -61.5207), GeoPoint(46.2385, -64.4721), GeoPoint(48.0709, -65.1155), GeoPoint(48.7425, -64.1710), GeoPoint(49.2329, -65.0562),
            GeoPoint(46.8217, -71.1045), GeoPoint(50.2289, -66.3990), GeoPoint(50.2429, -60.0331), GeoPoint(52.1467, -55.6833), GeoPoint(53.2705, -55.7563),
            GeoPoint(54.6265, -57.3332), GeoPoint(56.3395, -61.7986), GeoPoint(56.9675, -61.3965), GeoPoint(60.3357, -64.5835), GeoPoint(58.2121, -67.6498),
            GeoPoint(58.9573, -69.2879), GeoPoint(61.0615, -69.5904), GeoPoint(62.4439, -73.8399), GeoPoint(62.3197, -78.1068), GeoPoint(59.8527, -77.3367),
            GeoPoint(58.8047, -78.5169), GeoPoint(56.5343, -76.5414), GeoPoint(54.6677, -79.8296), GeoPoint(52.5621, -78.6019), GeoPoint(51.2085, -79.9129),
            GeoPoint(53.2771, -82.1250), GeoPoint(55.1483, -82.2728), GeoPoint(57.0871, -92.2970), GeoPoint(58.7821, -93.2150), GeoPoint(58.9489, -94.6845),
            GeoPoint(62.0247, -93.1570), GeoPoint(64.7757, -87.3232), GeoPoint(66.5583, -85.7694), GeoPoint(66.4117, -83.3445), GeoPoint(67.5973, -81.2593),
            GeoPoint(68.1325, -81.9643), GeoPoint(69.1621, -81.2804), GeoPoint(69.6583, -82.6225), GeoPoint(69.8821, -85.5219), GeoPoint(68.7845, -85.5766),
            GeoPoint(67.1987, -87.3501), GeoPoint(69.2587, -89.2151), GeoPoint(68.4751, -90.5515), GeoPoint(69.4977, -90.5471),
        ], triangles: [
            0, 1, 2, 0, 2, 3, 0, 3, 4, 238, 0, 4, 238, 4, 5, 238, 5, 6, 6, 7, 8, 6, 8, 9,
            6, 9, 10, 10, 11, 12, 10, 12, 13, 10, 13, 14, 6, 10, 14, 6, 14, 15, 16, 17, 18, 16, 18, 19,
            19, 20, 21, 16, 19, 21, 21, 22, 23, 16, 21, 23, 15, 16, 23, 23, 24, 25, 15, 23, 25, 15, 25, 26,
            6, 15, 26, 26, 27, 28, 6, 26, 28, 28, 29, 30, 6, 28, 30, 6, 30, 31, 6, 31, 32, 6, 32, 33,
            6, 33, 34, 34, 35, 36, 36, 37, 38, 34, 36, 38, 39, 40, 41, 38, 39, 41, 38, 41, 42, 34, 38, 42,
            34, 42, 43, 34, 43, 44, 34, 44, 45, 6, 34, 45, 45, 46, 47, 6, 45, 47, 6, 47, 48, 6, 48, 49,
            238, 6, 49, 238, 49, 50, 238, 50, 51, 238, 51, 52, 238, 52, 53, 53, 54, 55, 53, 55, 56, 238, 53, 56,
            238, 56, 57, 238, 57, 58, 238, 58, 59, 60, 61, 62, 59, 60, 62, 62, 63, 64, 59, 62, 64, 59, 64, 65,
            59, 65, 66, 59, 66, 67, 238, 59, 67, 238, 67, 68, 238, 68, 69, 70, 71, 72, 70, 72, 73, 69, 70, 73,
            69, 73, 74, 69, 74, 75, 69, 75, 76, 76, 77, 78, 81, 82, 83, 81, 83, 84, 84, 85, 86, 84, 86, 87,
            81, 84, 87, 81, 87, 88, 81, 88, 89, 80, 81, 89, 80, 89, 90, 91, 92, 93, 93, 94, 95, 91, 93, 95,
            96, 97, 98, 96, 98, 99, 99, 100, 101, 96, 99, 101, 95, 96, 101, 95, 101, 102, 91, 95, 102, 90, 91, 102,
            90, 102, 103, 103, 104, 105, 90, 103, 105, 105, 106, 107, 105, 107, 108, 90, 105, 108, 90, 108, 109, 90, 109, 110,
            90, 110, 111, 111, 112, 113, 90, 111, 113, 90, 113, 114, 90, 114, 115, 80, 90, 115, 80, 115, 116, 80, 116, 117,
            117, 118, 119, 80, 117, 119, 80, 119, 120, 80, 120, 121, 80, 121, 122, 80, 122, 123, 80, 123, 124, 80, 124, 125,
            80, 125, 126, 80, 126, 127, 79, 80, 127, 79, 127, 128, 128, 129, 130, 128, 130, 131, 79, 128, 131, 131, 132, 133,
            131, 133, 134, 79, 131, 134, 134, 135, 136, 79, 134, 136, 79, 136, 137, 79, 137, 138, 138, 139, 140, 79, 138, 140,
            141, 142, 143, 140, 141, 143, 140, 143, 144, 144, 145, 146, 140, 144, 146, 140, 146, 147, 148, 149, 150, 148, 150, 151,
            147, 148, 151, 147, 151, 152, 140, 147, 152, 79, 140, 152, 79, 152, 153, 78, 79, 153, 78, 153, 154, 76, 78, 154,
            76, 154, 155, 69, 76, 155, 155, 156, 157, 157, 158, 159, 157, 159, 160, 157, 160, 161, 155, 157, 161, 155, 161, 162,
            69, 155, 162, 69, 162, 163, 69, 163, 164, 69, 164, 165, 69, 165, 166, 69, 166, 167, 167, 168, 169, 167, 169, 170,
            69, 167, 170, 171, 172, 173, 171, 173, 174, 171, 174, 175, 170, 171, 175, 69, 170, 175, 69, 175, 176, 69, 176, 177,
            177, 178, 179, 69, 177, 179, 179, 180, 181, 179, 181, 182, 69, 179, 182, 182, 183, 184, 69, 182, 184, 184, 185, 186,
            69, 184, 186, 186, 187, 188, 69, 186, 188, 69, 188, 189, 190, 191, 192, 190, 192, 193, 189, 190, 193, 193, 194, 195,
            189, 193, 195, 189, 195, 196, 69, 189, 196, 69, 196, 197, 69, 197, 198, 69, 198, 199, 69, 199, 200, 69, 200, 201,
            201, 202, 203, 201, 203, 204, 201, 204, 205, 69, 201, 205, 69, 205, 206, 69, 206, 207, 207, 208, 209, 69, 207, 209,
            210, 211, 212, 210, 212, 213, 209, 210, 213, 209, 213, 214, 209, 214, 215, 209, 215, 216, 209, 216, 217, 209, 217, 218,
            209, 218, 219, 69, 209, 219, 69, 219, 220, 69, 220, 221, 69, 221, 222, 69, 222, 223, 69, 223, 224, 238, 69, 224,
            238, 224, 225, 225, 226, 227, 227, 228, 229, 227, 229, 230, 227, 230, 231, 227, 231, 232, 225, 227, 232, 232, 233, 234,
            232, 234, 235, 225, 232, 235, 225, 235, 236, 225, 236, 237, 225, 237, 238,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(72.7059, -117.8664), GeoPoint(71.5586, -119.4020), GeoPoint(71.3092, -116.1131), GeoPoint(70.9092, -118.4324), GeoPoint(70.5406, -117.9048),
            GeoPoint(70.3664, -112.4161), GeoPoint(69.9600, -117.3400), GeoPoint(68.5355, -113.3132), GeoPoint(68.7528, -102.4302), GeoPoint(69.5040, -102.7312),
            GeoPoint(69.5845, -101.0893), GeoPoint(70.9930, -104.4648), GeoPoint(73.0760, -106.5226), GeoPoint(73.0895, -108.3964), GeoPoint(72.0655, -107.6860),
            GeoPoint(71.6509, -108.1883), GeoPoint(72.9611, -109.9203), GeoPoint(72.6528, -114.6663), GeoPoint(73.1214, -114.1672),
        ], triangles: [
            18, 0, 1, 18, 1, 2, 2, 3, 4, 2, 4, 5, 5, 6, 7, 5, 7, 8, 2, 5, 8, 2, 8, 9,
            2, 9, 10, 2, 10, 11, 11, 12, 13, 11, 13, 14, 11, 14, 15, 2, 11, 15, 2, 15, 16, 2, 16, 17,
            2, 17, 18,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(73.6400, -105.2600), GeoPoint(73.6000, -106.6000), GeoPoint(73.4600, -106.9400), GeoPoint(72.7600, -105.3800), GeoPoint(73.4200, -104.5000),
        ], triangles: [
            4, 0, 1, 4, 1, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(73.6519, -78.0644), GeoPoint(73.7597, -80.3531), GeoPoint(73.6932, -80.8339), GeoPoint(73.3332, -80.8761), GeoPoint(72.8029, -79.7758),
            GeoPoint(72.7422, -79.4863), GeoPoint(72.8767, -78.3917), GeoPoint(72.8555, -77.3144), GeoPoint(72.8264, -76.2514), GeoPoint(73.1027, -76.3400),
        ], triangles: [
            9, 0, 1, 9, 1, 2, 9, 2, 3, 9, 3, 4, 4, 5, 6, 9, 4, 6, 9, 6, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(73.8038, -85.8262), GeoPoint(73.1295, -89.4366), GeoPoint(71.2226, -89.8882), GeoPoint(69.9666, -84.9447), GeoPoint(70.1669, -78.9572),
            GeoPoint(67.7269, -72.9261), GeoPoint(65.4548, -73.9598), GeoPoint(65.3092, -77.8973), GeoPoint(64.5729, -78.5559), GeoPoint(64.2295, -77.7100),
            GeoPoint(64.6791, -74.8344), GeoPoint(61.9309, -66.1656), GeoPoint(63.7457, -68.7832), GeoPoint(62.6742, -65.0138), GeoPoint(63.3929, -64.6694),
            GeoPoint(66.2627, -68.0150), GeoPoint(64.9987, -63.9184), GeoPoint(66.8621, -61.8520), GeoPoint(68.7202, -68.8051), GeoPoint(69.1861, -66.9690),
            GeoPoint(71.5569, -72.2422), GeoPoint(71.3308, -74.0991), GeoPoint(72.7496, -77.8246), GeoPoint(72.0619, -80.7489), GeoPoint(72.7165, -80.6001),
            GeoPoint(73.7510, -82.3156), GeoPoint(72.5341, -85.7744), GeoPoint(73.1574, -86.5622),
        ], triangles: [
            27, 0, 1, 27, 1, 2, 27, 2, 3, 6, 7, 8, 6, 8, 9, 6, 9, 10, 6, 10, 11, 6, 11, 12,
            5, 6, 12, 5, 12, 13, 5, 13, 14, 5, 14, 15, 4, 5, 15, 4, 15, 16, 4, 16, 17, 4, 17, 18,
            4, 18, 19, 4, 19, 20, 3, 4, 20, 3, 20, 21, 3, 21, 22, 3, 22, 23, 3, 23, 24, 3, 24, 25,
            3, 25, 26, 3, 26, 27,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(73.3600, -101.5400), GeoPoint(72.7059, -100.4384), GeoPoint(72.5100, -102.5000), GeoPoint(71.3564, -99.3229), GeoPoint(71.6600, -96.7200),
            GeoPoint(72.5600, -96.5400), GeoPoint(72.9905, -98.0536), GeoPoint(73.7600, -97.3800), GeoPoint(73.8439, -100.3564),
        ], triangles: [
            8, 0, 1, 1, 2, 3, 8, 1, 3, 8, 3, 4, 4, 5, 6, 8, 4, 6, 6, 7, 8,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(73.4753, 143.4828), GeoPoint(73.8576, 142.0621), GeoPoint(73.7651, 140.8117), GeoPoint(73.3698, 139.8631), GeoPoint(73.3169, 140.0382),
            GeoPoint(73.2054, 142.0876), GeoPoint(73.2124, 143.6038),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(72.9662, -92.0040), GeoPoint(73.8567, -90.5098), GeoPoint(74.1000, -92.4200), GeoPoint(74.1349, -94.5037), GeoPoint(73.8624, -95.4958),
            GeoPoint(73.4374, -96.0183), GeoPoint(72.9403, -96.0337), GeoPoint(72.0619, -95.4099), GeoPoint(72.0246, -94.2690), GeoPoint(72.7720, -93.1963),
        ], triangles: [
            9, 0, 1, 9, 1, 2, 9, 2, 3, 9, 3, 4, 9, 4, 5, 9, 5, 6, 9, 6, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(72.5200, -119.2200), GeoPoint(73.4752, -115.5108), GeoPoint(74.2927, -124.9177), GeoPoint(73.6800, -123.9400), GeoPoint(71.8687, -125.9290),
            GeoPoint(70.9016, -123.0922), GeoPoint(71.4000, -120.4600),
        ], triangles: [
            0, 1, 2, 0, 2, 3, 6, 0, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(75.3458, 148.2222), GeoPoint(75.4968, 146.3585), GeoPoint(75.1730, 146.1192), GeoPoint(74.7784, 147.9775), GeoPoint(74.6889, 149.5759),
            GeoPoint(75.0841, 150.7317),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(75.2965, -93.9777), GeoPoint(75.6472, -94.8508), GeoPoint(75.3778, -96.2886), GeoPoint(74.9276, -96.8209), GeoPoint(74.6669, -95.6087),
            GeoPoint(74.5923, -94.1569), GeoPoint(74.9800, -93.6128),
        ], triangles: [
            6, 0, 1, 6, 1, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(76.0929, 141.4716), GeoPoint(76.1368, 138.8311), GeoPoint(75.9492, 137.5118), GeoPoint(75.2617, 136.9744), GeoPoint(74.6115, 138.9554),
            GeoPoint(74.8477, 140.6138), GeoPoint(74.8200, 144.3000), GeoPoint(75.5626, 145.0863),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(76.5886, -98.5770), GeoPoint(76.6463, -99.9835), GeoPoint(76.3054, -101.4897), GeoPoint(76.3366, -102.5655), GeoPoint(75.5638, -102.5021),
            GeoPoint(75.6407, -100.8629), GeoPoint(75.0574, -100.8837), GeoPoint(74.8974, -99.8087), GeoPoint(75.0000, -98.1600), GeoPoint(75.7434, -97.7044),
            GeoPoint(76.2566, -97.7356), GeoPoint(76.7200, -98.5000),
        ], triangles: [
            0, 1, 2, 2, 3, 4, 0, 2, 4, 0, 4, 5, 0, 5, 6, 0, 6, 7, 0, 7, 8, 11, 0, 8,
            11, 8, 9, 9, 10, 11,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(76.4298, -110.4973), GeoPoint(75.4732, -109.0671), GeoPoint(76.4789, -115.4049), GeoPoint(75.2222, -117.7104), GeoPoint(75.1625, -111.7942),
            GeoPoint(74.7203, -113.8714), GeoPoint(74.4170, -112.2231), GeoPoint(75.4795, -105.7050), GeoPoint(76.2017, -108.2114),
        ], triangles: [
            8, 0, 1, 1, 2, 3, 1, 3, 4, 1, 4, 5, 1, 5, 6, 1, 6, 7, 1, 7, 8,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(72.3713, 55.4193), GeoPoint(74.3091, 58.4771), GeoPoint(76.5448, 68.8522), GeoPoint(76.2519, 61.1700), GeoPoint(75.0814, 55.6319),
            GeoPoint(72.0149, 51.4558), GeoPoint(70.7627, 53.6774), GeoPoint(70.7205, 57.5357),
        ], triangles: [
            1, 2, 3, 0, 1, 3, 0, 3, 4, 0, 4, 5, 7, 0, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(76.7511, -97.1214), GeoPoint(74.5156, -89.7647), GeoPoint(74.9231, -79.8339), GeoPoint(75.7140, -81.1285), GeoPoint(75.6102, -89.1871),
            GeoPoint(77.0979, -94.6841),
        ], triangles: [
            5, 0, 1, 1, 2, 3, 1, 3, 4, 1, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(77.4983, -117.5701), GeoPoint(77.5122, -119.1039), GeoPoint(76.8645, -121.1575), GeoPoint(76.1165, -122.8549), GeoPoint(76.1165, -122.8549),
            GeoPoint(75.9000, -121.5000), GeoPoint(76.0532, -119.8993), GeoPoint(76.4812, -118.0404), GeoPoint(76.5300, -117.1061), GeoPoint(76.8770, -116.3358),
            GeoPoint(77.6453, -116.1986),
        ], triangles: [
            0, 1, 2, 10, 0, 2, 10, 2, 3, 10, 3, 4, 10, 4, 5, 10, 5, 6, 10, 6, 7, 10, 7, 8,
            8, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(77.6979, 104.3517), GeoPoint(76.4303, 100.7597), GeoPoint(75.1165, 87.1669), GeoPoint(74.4597, 86.0097), GeoPoint(73.9369, 86.8223),
            GeoPoint(73.6483, 80.5111), GeoPoint(71.7501, 81.5001), GeoPoint(72.2673, 77.5767), GeoPoint(71.8741, 75.9031), GeoPoint(71.1529, 76.3591),
            GeoPoint(71.3357, 75.2891), GeoPoint(72.3005, 75.6835), GeoPoint(72.8323, 74.6593), GeoPoint(72.1213, 74.8909), GeoPoint(71.4471, 73.1011),
            GeoPoint(70.6319, 74.3999), GeoPoint(69.6277, 73.6019), GeoPoint(68.9893, 74.9359), GeoPoint(67.7605, 75.0521), GeoPoint(66.1727, 72.4231),
            GeoPoint(66.3201, 71.2801), GeoPoint(68.4079, 73.6679), GeoPoint(69.0209, 72.5647), GeoPoint(70.3911, 72.7919), GeoPoint(71.4091, 71.8481),
            GeoPoint(72.7763, 72.5875), GeoPoint(72.8435, 69.1963), GeoPoint(71.0291, 66.6947), GeoPoint(69.4547, 66.9301), GeoPoint(68.6157, 69.1807),
            GeoPoint(68.0923, 68.5121), GeoPoint(69.8501, 60.5501), GeoPoint(69.5201, 60.0301), GeoPoint(68.9407, 61.0779), GeoPoint(68.2785, 59.9415),
            GeoPoint(68.8809, 58.8021), GeoPoint(68.2013, 53.4859), GeoPoint(68.8083, 54.4717), GeoPoint(68.8575, 53.7175), GeoPoint(66.6677, 46.3491),
            GeoPoint(67.0101, 45.5621), GeoPoint(67.6899, 46.8213), GeoPoint(68.2501, 46.2501), GeoPoint(68.5709, 43.4529), GeoPoint(66.7563, 44.5323),
            GeoPoint(66.0691, 43.9499), GeoPoint(66.4763, 42.0931), GeoPoint(65.4969, 39.7627), GeoPoint(64.7645, 40.4357), GeoPoint(64.5209, 39.5935),
            GeoPoint(65.1433, 37.1761), GeoPoint(64.7803, 36.5177), GeoPoint(63.8499, 37.0129), GeoPoint(64.4145, 34.9439), GeoPoint(65.9001, 34.8149),
            GeoPoint(66.6325, 33.1845), GeoPoint(65.9995, 38.3829), GeoPoint(66.7917, 41.1261), GeoPoint(67.4573, 41.0599), GeoPoint(69.0635, 36.5141),
            GeoPoint(69.5581, 31.1011), GeoPoint(70.1863, 30.0055), GeoPoint(70.4539, 31.2935), GeoPoint(71.1855, 28.1655), GeoPoint(71.0305, 24.5467),
            GeoPoint(67.8107, 14.7613), GeoPoint(64.4861, 10.5277), GeoPoint(61.9711, 4.9921), GeoPoint(58.5881, 5.6659), GeoPoint(58.3133, 8.3821),
            GeoPoint(59.4699, 10.3567), GeoPoint(55.3619, 12.9429), GeoPoint(56.1043, 15.8799), GeoPoint(58.7199, 16.8293), GeoPoint(60.0819, 18.7877),
            GeoPoint(61.3413, 17.1197), GeoPoint(62.7495, 17.8479), GeoPoint(64.4137, 21.3697), GeoPoint(65.7239, 22.1833), GeoPoint(66.0069, 23.9035),
            GeoPoint(65.1115, 25.3981), GeoPoint(63.1899, 21.5361), GeoPoint(60.7203, 21.3223), GeoPoint(59.8465, 22.8697), GeoPoint(60.0281, 29.1177),
            GeoPoint(59.1873, 23.3399), GeoPoint(58.3835, 24.4291), GeoPoint(57.0257, 24.1207), GeoPoint(57.4119, 21.5819), GeoPoint(55.1905, 21.2685),
            GeoPoint(54.4261, 19.6607), GeoPoint(54.0087, 10.9395), GeoPoint(55.4701, 9.6501), GeoPoint(56.4587, 10.9123), GeoPoint(57.7301, 10.5801),
            GeoPoint(57.1101, 8.5435), GeoPoint(55.5177, 8.1203), GeoPoint(54.0209, 8.8007), GeoPoint(53.5279, 8.1217), GeoPoint(53.0919, 4.7061),
            GeoPoint(50.1273, 1.3387), GeoPoint(49.7765, -1.9334), GeoPoint(48.6445, -1.6165), GeoPoint(48.6841, -4.5923), GeoPoint(46.0149, -1.1938),
            GeoPoint(44.0227, -1.3842), GeoPoint(43.0267, -9.3929), GeoPoint(36.8689, -8.8988), GeoPoint(36.9429, -6.5202), GeoPoint(35.9469, -5.3771),
            GeoPoint(36.6741, -2.1464), GeoPoint(38.7385, 0.1113), GeoPoint(41.0147, 0.8105), GeoPoint(41.8921, 3.0395), GeoPoint(43.0753, 3.1005),
            GeoPoint(43.1289, 6.5293), GeoPoint(44.3663, 8.8889), GeoPoint(40.0483, 15.4137), GeoPoint(37.9859, 16.1011), GeoPoint(38.9029, 17.0529),
            GeoPoint(40.4423, 16.8697), GeoPoint(40.1689, 18.4803), GeoPoint(44.0915, 12.5893), GeoPoint(45.3819, 12.3287), GeoPoint(45.7367, 13.1417),
            GeoPoint(41.7201, 19.5401), GeoPoint(40.2509, 19.4061), GeoPoint(36.4101, 22.4901), GeoPoint(36.4225, 23.1543), GeoPoint(37.9201, 23.1151),
            GeoPoint(37.6551, 24.0401), GeoPoint(40.2565, 22.6263), GeoPoint(39.9621, 23.9001), GeoPoint(40.6871, 23.7149), GeoPoint(40.9471, 24.9259),
            GeoPoint(40.1521, 26.3581), GeoPoint(41.0549, 28.8065), GeoPoint(42.5779, 27.6739), GeoPoint(46.5831, 30.7489), GeoPoint(46.0807, 33.2987),
            GeoPoint(45.3275, 32.4543), GeoPoint(44.3615, 33.8825), GeoPoint(45.1133, 36.3347), GeoPoint(46.2733, 34.9623), GeoPoint(47.2635, 39.1213),
            GeoPoint(45.2447, 36.6755), GeoPoint(41.9631, 41.7033), GeoPoint(40.9487, 38.3477), GeoPoint(42.0191, 33.5133), GeoPoint(41.2201, 29.2401),
            GeoPoint(39.4637, 26.1709), GeoPoint(36.6589, 27.6413), GeoPoint(36.6507, 36.1609), GeoPoint(34.6449, 35.9985), GeoPoint(30.9675, 33.7735),
            GeoPoint(31.5559, 30.9769), GeoPoint(30.8701, 28.9135), GeoPoint(32.8433, 21.5431), GeoPoint(32.2383, 20.1341), GeoPoint(30.2665, 19.0865),
            GeoPoint(33.7859, 10.3397), GeoPoint(36.9001, 11.1001), GeoPoint(37.3501, 9.5101), GeoPoint(36.6057, 1.4669), GeoPoint(35.1685, -2.1699),
            GeoPoint(35.7601, -5.9300), GeoPoint(32.5647, -9.3007), GeoPoint(29.9337, -9.5648), GeoPoint(26.2545, -14.4399), GeoPoint(21.8857, -16.9732),
            GeoPoint(18.1085, -16.1463), GeoPoint(14.7297, -17.6250), GeoPoint(12.1709, -16.6138), GeoPoint(7.2629, -12.4281), GeoPoint(4.8325, -9.0048),
            GeoPoint(4.7105, -1.9647), GeoPoint(6.2707, 4.3257), GeoPoint(4.2625, 5.8983), GeoPoint(4.7721, 8.5003), GeoPoint(3.7345, 9.4045),
            GeoPoint(-1.1113, 8.7981), GeoPoint(-5.0379, 11.9151), GeoPoint(-10.7311, 13.6865), GeoPoint(-15.7938, 11.7787), GeoPoint(-18.0691, 11.7949),
            GeoPoint(-22.1112, 14.2577), GeoPoint(-27.0909, 15.2105), GeoPoint(-31.6616, 18.2217), GeoPoint(-34.1365, 18.3775), GeoPoint(-34.8191, 19.6165),
            GeoPoint(-33.9446, 25.7807), GeoPoint(-32.7719, 28.2197), GeoPoint(-28.7524, 32.2035), GeoPoint(-25.7273, 32.5747), GeoPoint(-23.7065, 35.6075),
            GeoPoint(-19.7840, 34.7865), GeoPoint(-16.7209, 39.4527), GeoPoint(-14.6917, 40.7755), GeoPoint(-10.7654, 40.4785), GeoPoint(-6.4756, 38.7997),
            GeoPoint(-4.6767, 39.2023), GeoPoint(-2.5731, 40.2631), GeoPoint(4.2195, 47.7409), GeoPoint(10.6409, 51.0453), GeoPoint(12.0247, 51.1113),
            GeoPoint(10.4423, 44.6143), GeoPoint(11.7357, 42.7159), GeoPoint(12.3901, 43.3179), GeoPoint(18.6141, 37.4819), GeoPoint(22.0001, 36.8663),
            GeoPoint(23.1025, 35.5261), GeoPoint(29.8511, 32.4233), GeoPoint(27.6487, 33.9215), GeoPoint(29.5013, 34.9227), GeoPoint(28.0585, 34.6323),
            GeoPoint(23.6885, 38.4929), GeoPoint(21.2919, 39.1395), GeoPoint(16.7747, 42.6497), GeoPoint(12.6369, 43.4831), GeoPoint(14.0033, 48.6793),
            GeoPoint(17.2283, 55.2749), GeoPoint(18.9447, 57.6945), GeoPoint(20.2431, 57.8265), GeoPoint(22.3105, 59.8063), GeoPoint(24.2417, 56.8453),
            GeoPoint(26.3959, 56.3621), GeoPoint(24.1219, 54.0081), GeoPoint(24.0199, 51.7945), GeoPoint(25.8011, 51.5891), GeoPoint(26.0071, 51.0135),
            GeoPoint(24.7549, 50.8101), GeoPoint(29.9759, 47.9745), GeoPoint(30.1479, 50.1151), GeoPoint(27.8657, 51.5209), GeoPoint(26.4807, 54.7151),
            GeoPoint(27.1433, 56.4921), GeoPoint(25.7399, 57.3973), GeoPoint(25.4253, 66.3729), GeoPoint(20.8773, 70.4705), GeoPoint(21.3561, 72.6307),
            GeoPoint(15.9907, 73.5343), GeoPoint(7.9655, 77.5399), GeoPoint(10.3573, 79.8581), GeoPoint(15.8993, 80.3249), GeoPoint(20.1517, 86.4993),
            GeoPoint(21.4955, 86.9757), GeoPoint(21.8365, 90.2729), GeoPoint(22.8051, 90.4961), GeoPoint(22.7651, 91.4171), GeoPoint(18.2135, 94.3249),
            GeoPoint(16.0381, 94.1889), GeoPoint(15.7145, 95.3693), GeoPoint(16.9287, 97.1647), GeoPoint(11.4413, 98.7645), GeoPoint(7.7945, 98.3397),
            GeoPoint(8.3823, 98.5039), GeoPoint(6.4645, 100.0859), GeoPoint(2.7609, 101.3907), GeoPoint(1.2931, 104.2289), GeoPoint(5.5245, 102.9617),
            GeoPoint(9.2393, 99.2225), GeoPoint(13.4069, 100.0979), GeoPoint(9.9185, 105.0763), GeoPoint(8.5997, 105.1583), GeoPoint(11.6669, 109.2001),
            GeoPoint(13.4261, 109.3353), GeoPoint(19.7521, 105.8817), GeoPoint(21.7153, 108.5229), GeoPoint(20.3411, 110.4441), GeoPoint(21.3973, 110.7855),
            GeoPoint(22.7829, 115.8907), GeoPoint(24.5475, 118.6569), GeoPoint(28.2255, 121.6845), GeoPoint(29.8325, 122.0921), GeoPoint(30.6763, 121.2643),
            GeoPoint(31.6923, 121.9081), GeoPoint(34.9099, 119.1513), GeoPoint(37.4545, 122.3579), GeoPoint(37.4485, 118.9117), GeoPoint(38.7377, 117.5327),
            GeoPoint(39.2043, 118.0427), GeoPoint(40.9465, 121.6405), GeoPoint(40.4225, 122.1687), GeoPoint(38.8975, 121.0547), GeoPoint(39.5515, 125.3211),
            GeoPoint(38.1083, 124.7123), GeoPoint(36.8939, 126.8603), GeoPoint(36.7255, 126.1175), GeoPoint(34.3901, 126.4857), GeoPoint(35.0825, 129.0915),
            GeoPoint(36.7843, 129.4605), GeoPoint(39.7569, 127.5335), GeoPoint(43.2845, 132.2781), GeoPoint(43.3983, 134.8695), GeoPoint(46.3079, 138.2197),
            GeoPoint(48.4467, 140.0621), GeoPoint(52.2389, 141.3793), GeoPoint(54.1897, 139.9015), GeoPoint(53.7551, 138.1647), GeoPoint(54.7297, 135.1263),
            GeoPoint(59.0401, 142.1979), GeoPoint(59.6557, 149.7837), GeoPoint(59.5041, 151.3381), GeoPoint(58.7809, 151.2657), GeoPoint(59.1451, 155.0439),
            GeoPoint(59.7583, 154.2181), GeoPoint(61.4345, 156.7207), GeoPoint(61.7741, 159.3023), GeoPoint(60.5443, 160.1215), GeoPoint(62.5507, 164.4737),
            GeoPoint(61.1409, 163.6697), GeoPoint(56.7679, 155.9145), GeoPoint(55.3811, 155.4337), GeoPoint(51.0111, 156.7899), GeoPoint(52.9587, 158.5309),
            GeoPoint(53.2027, 160.0217), GeoPoint(54.3445, 160.3689), GeoPoint(54.8553, 162.1175), GeoPoint(57.6151, 163.1919), GeoPoint(58.2433, 162.0173),
            GeoPoint(59.8687, 163.5393), GeoPoint(60.5735, 168.9005), GeoPoint(59.8819, 170.3309), GeoPoint(61.6527, 173.6801), GeoPoint(62.3041, 179.2283),
            GeoPoint(64.6083, 177.4113), GeoPoint(64.9796, 180.0000), GeoPoint(68.9637, 180.0000), GeoPoint(69.8773, 175.7241), GeoPoint(70.0971, 170.4535),
            GeoPoint(69.6529, 170.0083), GeoPoint(69.0137, 170.8169), GeoPoint(68.6939, 169.5777), GeoPoint(69.5827, 167.8357), GeoPoint(69.4373, 160.9407),
            GeoPoint(70.8667, 158.9979), GeoPoint(70.8423, 152.9689), GeoPoint(72.2001, 149.5001), GeoPoint(72.8495, 140.4681), GeoPoint(72.4163, 139.1479),
            GeoPoint(71.4879, 139.8699), GeoPoint(71.8363, 132.2535), GeoPoint(70.7871, 131.2887), GeoPoint(73.5655, 126.9765), GeoPoint(73.7351, 123.2579),
            GeoPoint(72.9713, 123.2007), GeoPoint(74.1801, 109.4001), GeoPoint(75.8477, 114.1343), GeoPoint(76.9743, 106.9703),
        ], triangles: [
            348, 0, 1, 348, 1, 2, 348, 2, 3, 348, 3, 4, 4, 5, 6, 348, 4, 6, 6, 7, 8, 6, 8, 9,
            10, 11, 12, 10, 12, 13, 10, 13, 14, 9, 10, 14, 9, 14, 15, 6, 9, 15, 6, 15, 16, 348, 6, 16,
            348, 16, 17, 348, 17, 18, 348, 18, 19, 20, 21, 22, 20, 22, 23, 20, 23, 24, 24, 25, 26, 20, 24, 26,
            26, 27, 28, 26, 28, 29, 20, 26, 29, 20, 29, 30, 20, 30, 31, 20, 31, 32, 20, 32, 33, 20, 33, 34,
            34, 35, 36, 20, 34, 36, 19, 20, 36, 36, 37, 38, 36, 38, 39, 19, 36, 39, 40, 41, 42, 40, 42, 43,
            40, 43, 44, 39, 40, 44, 39, 44, 45, 19, 39, 45, 45, 46, 47, 19, 45, 47, 19, 47, 48, 19, 48, 49,
            49, 50, 51, 49, 51, 52, 19, 49, 52, 53, 54, 55, 55, 56, 57, 55, 57, 58, 55, 58, 59, 55, 59, 60,
            55, 60, 61, 53, 55, 61, 61, 62, 63, 53, 61, 63, 53, 63, 64, 53, 64, 65, 52, 53, 65, 66, 67, 68,
            65, 66, 68, 65, 68, 69, 65, 69, 70, 65, 70, 71, 65, 71, 72, 65, 72, 73, 73, 74, 75, 65, 73, 75,
            65, 75, 76, 65, 76, 77, 65, 77, 78, 65, 78, 79, 52, 65, 79, 52, 79, 80, 52, 80, 81, 52, 81, 82,
            19, 52, 82, 19, 82, 83, 19, 83, 84, 19, 84, 85, 19, 85, 86, 19, 86, 87, 87, 88, 89, 19, 87, 89,
            19, 89, 90, 92, 93, 94, 92, 94, 95, 92, 95, 96, 91, 92, 96, 91, 96, 97, 91, 97, 98, 90, 91, 98,
            90, 98, 99, 90, 99, 100, 19, 90, 100, 100, 101, 102, 19, 100, 102, 102, 103, 104, 19, 102, 104, 19, 104, 105,
            105, 106, 107, 105, 107, 108, 105, 108, 109, 105, 109, 110, 105, 110, 111, 105, 111, 112, 105, 112, 113, 105, 113, 114,
            19, 105, 114, 348, 19, 114, 114, 115, 116, 348, 114, 116, 117, 118, 119, 117, 119, 120, 116, 117, 120, 116, 120, 121,
            116, 121, 122, 116, 122, 123, 116, 123, 124, 348, 116, 124, 125, 126, 127, 125, 127, 128, 125, 128, 129, 125, 129, 130,
            125, 130, 131, 124, 125, 131, 124, 131, 132, 124, 132, 133, 124, 133, 134, 134, 135, 136, 124, 134, 136, 124, 136, 137,
            124, 137, 138, 348, 124, 138, 348, 138, 139, 348, 139, 140, 140, 141, 142, 140, 142, 143, 348, 140, 143, 348, 143, 144,
            348, 144, 145, 348, 145, 146, 147, 148, 149, 147, 149, 150, 147, 150, 151, 146, 147, 151, 146, 151, 152, 348, 146, 152,
            348, 152, 153, 348, 153, 154, 154, 155, 156, 156, 157, 158, 156, 158, 159, 154, 156, 159, 160, 161, 162, 160, 162, 163,
            159, 160, 163, 159, 163, 164, 159, 164, 165, 159, 165, 166, 159, 166, 167, 159, 167, 168, 154, 159, 168, 154, 168, 169,
            154, 169, 170, 154, 170, 171, 154, 171, 172, 154, 172, 173, 154, 173, 174, 154, 174, 175, 176, 177, 178, 179, 180, 181,
            179, 181, 182, 182, 183, 184, 182, 184, 185, 182, 185, 186, 182, 186, 187, 187, 188, 189, 182, 187, 189, 182, 189, 190,
            179, 182, 190, 179, 190, 191, 179, 191, 192, 179, 192, 193, 179, 193, 194, 178, 179, 194, 178, 194, 195, 178, 195, 196,
            178, 196, 197, 178, 197, 198, 178, 198, 199, 178, 199, 200, 176, 178, 200, 176, 200, 201, 176, 201, 202, 176, 202, 203,
            203, 204, 205, 176, 203, 205, 176, 205, 206, 176, 206, 207, 176, 207, 208, 175, 176, 208, 175, 208, 209, 175, 209, 210,
            175, 210, 211, 154, 175, 211, 348, 154, 211, 211, 212, 213, 348, 211, 213, 348, 213, 214, 348, 214, 215, 215, 216, 217,
            217, 218, 219, 215, 217, 219, 215, 219, 220, 215, 220, 221, 215, 221, 222, 215, 222, 223, 224, 225, 226, 223, 224, 226,
            223, 226, 227, 215, 223, 227, 227, 228, 229, 227, 229, 230, 215, 227, 230, 215, 230, 231, 348, 215, 231, 348, 231, 232,
            348, 232, 233, 348, 233, 234, 348, 234, 235, 348, 235, 236, 348, 236, 237, 348, 237, 238, 348, 238, 239, 348, 239, 240,
            240, 241, 242, 240, 242, 243, 348, 240, 243, 243, 244, 245, 348, 243, 245, 245, 246, 247, 348, 245, 247, 348, 247, 248,
            348, 248, 249, 348, 249, 250, 348, 250, 251, 348, 251, 252, 348, 252, 253, 348, 253, 254, 348, 254, 255, 256, 257, 258,
            256, 258, 259, 255, 256, 259, 255, 259, 260, 348, 255, 260, 348, 260, 261, 348, 261, 262, 348, 262, 263, 263, 264, 265,
            263, 265, 266, 348, 263, 266, 348, 266, 267, 348, 267, 268, 348, 268, 269, 348, 269, 270, 348, 270, 271, 271, 272, 273,
            271, 273, 274, 274, 275, 276, 271, 274, 276, 276, 277, 278, 271, 276, 278, 271, 278, 279, 348, 271, 279, 348, 279, 280,
            348, 280, 281, 348, 281, 282, 282, 283, 284, 348, 282, 284, 284, 285, 286, 348, 284, 286, 286, 287, 288, 286, 288, 289,
            348, 286, 289, 289, 290, 291, 348, 289, 291, 348, 291, 292, 348, 292, 293, 293, 294, 295, 293, 295, 296, 293, 296, 297,
            293, 297, 298, 293, 298, 299, 302, 303, 304, 301, 302, 304, 301, 304, 305, 301, 305, 306, 300, 301, 306, 307, 308, 309,
            306, 307, 309, 310, 311, 312, 310, 312, 313, 310, 313, 314, 314, 315, 316, 316, 317, 318, 314, 316, 318, 314, 318, 319,
            310, 314, 319, 309, 310, 319, 309, 319, 320, 309, 320, 321, 321, 322, 323, 309, 321, 323, 309, 323, 324, 309, 324, 325,
            306, 309, 325, 325, 326, 327, 306, 325, 327, 300, 306, 327, 300, 327, 328, 328, 329, 330, 328, 330, 331, 300, 328, 331,
            300, 331, 332, 300, 332, 333, 300, 333, 334, 300, 334, 335, 299, 300, 335, 299, 335, 336, 299, 336, 337, 299, 337, 338,
            338, 339, 340, 299, 338, 340, 299, 340, 341, 293, 299, 341, 293, 341, 342, 293, 342, 343, 293, 343, 344, 293, 344, 345,
            293, 345, 346, 348, 293, 346, 346, 347, 348,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(77.6343, -93.7207), GeoPoint(77.8200, -94.4226), GeoPoint(77.8346, -96.4363), GeoPoint(77.5551, -96.1697), GeoPoint(77.4913, -94.2956),
            GeoPoint(77.5200, -93.8400),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(77.9963, -109.8545), GeoPoint(78.1530, -111.2644), GeoPoint(78.0511, -112.7246), GeoPoint(77.7322, -113.5343), GeoPoint(77.4092, -112.0512),
            GeoPoint(77.6970, -110.1869),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(78.0795, 23.2813), GeoPoint(78.4549, 22.8843), GeoPoint(78.2546, 20.8119), GeoPoint(77.9350, 21.4161), GeoPoint(77.6770, 20.7260),
            GeoPoint(77.4449, 22.4903), GeoPoint(77.8538, 24.7241),
        ], triangles: [
            0, 1, 2, 6, 0, 2, 6, 2, 3, 6, 3, 4, 4, 5, 6,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(78.8044, -110.9637), GeoPoint(78.8500, -111.5000), GeoPoint(78.5506, -112.5259), GeoPoint(78.4079, -112.5421), GeoPoint(78.4069, -110.8813),
            GeoPoint(78.6020, -109.6631),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(78.4183, -95.5593), GeoPoint(78.7658, -96.7544), GeoPoint(78.8320, -97.3372), GeoPoint(78.8719, -98.6320), GeoPoint(78.4581, -98.5529),
            GeoPoint(78.0829, -98.1243), GeoPoint(77.8506, -97.3098), GeoPoint(78.0569, -95.8303),
        ], triangles: [
            7, 0, 1, 7, 1, 2, 7, 2, 3, 7, 3, 4, 7, 4, 5, 5, 6, 7,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(78.8005, -100.8252), GeoPoint(79.1653, -103.5293), GeoPoint(79.3016, -105.4923), GeoPoint(78.9183, -105.4196), GeoPoint(78.6774, -104.2104),
            GeoPoint(78.3803, -105.1761), GeoPoint(78.3432, -102.9498), GeoPoint(78.0190, -101.3039), GeoPoint(77.9075, -99.6709), GeoPoint(78.3248, -100.0602),
        ], triangles: [
            9, 0, 1, 9, 1, 2, 9, 2, 3, 9, 3, 4, 9, 4, 5, 9, 5, 6, 9, 6, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(78.7133, 105.3724), GeoPoint(79.2813, 102.8378), GeoPoint(79.3464, 102.0863), GeoPoint(79.2340, 101.2649), GeoPoint(77.9210, 99.4381),
            GeoPoint(78.3069, 105.0755),
        ], triangles: [
            5, 0, 1, 5, 1, 2, 5, 2, 3, 3, 4, 5,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(79.6524, 10.4445), GeoPoint(76.7704, 15.9131), GeoPoint(78.9561, 21.5438), GeoPoint(79.7018, 18.2518),
        ], triangles: [
            3, 0, 1, 1, 2, 3,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(80.6571, 22.9193), GeoPoint(80.3577, 21.9079), GeoPoint(80.5982, 20.4560), GeoPoint(80.3189, 17.3680), GeoPoint(79.8599, 18.4623),
            GeoPoint(79.8424, 19.8973), GeoPoint(79.5668, 20.0752), GeoPoint(79.4000, 23.0245), GeoPoint(79.5178, 25.9247), GeoPoint(80.0564, 27.4075),
            GeoPoint(80.4073, 25.4476),
        ], triangles: [
            10, 0, 1, 1, 2, 3, 1, 3, 4, 10, 1, 4, 10, 4, 5, 10, 5, 6, 10, 6, 7, 10, 7, 8,
            8, 9, 10,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(80.5898, 44.8470), GeoPoint(80.0102, 47.5861), GeoPoint(80.5473, 51.1362),
        ], triangles: [
            0, 1, 2,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(79.7801, 100.1867), GeoPoint(80.7470, 97.8838), GeoPoint(81.2504, 95.9409), GeoPoint(81.0246, 93.7777), GeoPoint(80.3415, 91.1811),
            GeoPoint(80.1438, 92.5454), GeoPoint(79.4265, 93.3129), GeoPoint(79.0447, 94.9726), GeoPoint(78.7562, 97.7579), GeoPoint(78.8809, 99.9398),
        ], triangles: [
            9, 0, 1, 9, 1, 2, 9, 2, 3, 3, 4, 5, 9, 3, 5, 9, 5, 6, 9, 6, 7, 7, 8, 9,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(81.2574, -92.4098), GeoPoint(80.1578, -96.7097), GeoPoint(78.2153, -90.8044), GeoPoint(79.3369, -85.8144), GeoPoint(79.6600, -87.0200),
        ], triangles: [
            4, 0, 1, 4, 1, 2, 2, 3, 4,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(83.1306, -79.3066), GeoPoint(81.8943, -91.5870), GeoPoint(80.5163, -87.5990), GeoPoint(80.4644, -81.8482), GeoPoint(80.2515, -86.9318),
            GeoPoint(79.3454, -85.0949), GeoPoint(78.3718, -87.9619), GeoPoint(77.5387, -84.9763), GeoPoint(77.9000, -88.2600), GeoPoint(77.1783, -87.7674),
            GeoPoint(76.4724, -89.4907), GeoPoint(76.1781, -80.5613), GeoPoint(76.7780, -77.8891), GeoPoint(77.2097, -79.7595), GeoPoint(78.5258, -75.3935),
            GeoPoint(79.3231, -76.9077), GeoPoint(79.8000, -71.1800), GeoPoint(81.5066, -65.4803), GeoPoint(81.5014, -67.6576), GeoPoint(82.6286, -61.8500),
            GeoPoint(83.1063, -68.5000),
        ], triangles: [
            20, 0, 1, 20, 1, 2, 20, 2, 3, 3, 4, 5, 20, 3, 5, 20, 5, 6, 20, 6, 7, 7, 8, 9,
            7, 9, 10, 7, 10, 11, 7, 11, 12, 7, 12, 13, 7, 13, 14, 7, 14, 15, 20, 7, 15, 20, 15, 16,
            16, 17, 18, 20, 16, 18, 18, 19, 20,
        ]),
        RouteAtlasLandPolygon(points: [
            GeoPoint(83.5490, -38.6221), GeoPoint(82.6280, -46.7638), GeoPoint(81.6607, -44.5230), GeoPoint(82.4388, -50.3906), GeoPoint(81.7704, -62.6512),
            GeoPoint(81.3211, -62.2344), GeoPoint(80.1172, -68.0230), GeoPoint(79.3944, -65.7107), GeoPoint(78.0442, -73.2970), GeoPoint(77.3760, -66.7640),
            GeoPoint(77.0086, -71.4026), GeoPoint(76.0614, -68.5044), GeoPoint(75.5173, -58.5852), GeoPoint(72.5863, -54.7182), GeoPoint(71.6544, -55.8347),
            GeoPoint(70.5698, -51.3901), GeoPoint(70.8213, -54.3588), GeoPoint(69.6100, -54.6834), GeoPoint(69.9291, -50.8712), GeoPoint(67.1890, -53.9691),
            GeoPoint(63.6269, -51.6332), GeoPoint(60.8584, -48.2629), GeoPoint(60.0977, -43.3784), GeoPoint(61.9009, -42.4167), GeoPoint(62.6823, -42.8194),
            GeoPoint(65.4585, -39.8122), GeoPoint(70.1295, -22.3490), GeoPoint(70.2265, -26.3628), GeoPoint(70.7523, -25.2014), GeoPoint(71.4309, -25.5434),
            GeoPoint(70.6637, -21.7536), GeoPoint(72.3302, -24.7930), GeoPoint(72.1841, -22.2995), GeoPoint(73.3066, -23.5659), GeoPoint(74.2956, -19.3728),
            GeoPoint(75.1559, -20.6682), GeoPoint(75.2484, -19.5990), GeoPoint(76.0981, -19.8341), GeoPoint(76.6279, -21.6794), GeoPoint(76.9857, -18.4729),
            GeoPoint(77.6386, -19.6735), GeoPoint(78.7513, -19.7050), GeoPoint(80.1291, -17.7304), GeoPoint(80.1771, -20.0462), GeoPoint(81.2915, -12.2086),
            GeoPoint(81.9125, -15.7682), GeoPoint(81.1527, -23.1696), GeoPoint(81.7345, -22.0718), GeoPoint(82.2000, -31.9000), GeoPoint(82.7267, -20.8454),
            GeoPoint(83.5197, -27.1005),
        ], triangles: [
            50, 0, 1, 50, 1, 2, 2, 3, 4, 2, 4, 5, 2, 5, 6, 2, 6, 7, 50, 2, 7, 50, 7, 8,
            50, 8, 9, 9, 10, 11, 50, 9, 11, 50, 11, 12, 13, 14, 15, 12, 13, 15, 15, 16, 17, 15, 17, 18,
            18, 19, 20, 18, 20, 21, 18, 21, 22, 18, 22, 23, 15, 18, 23, 15, 23, 24, 15, 24, 25, 12, 15, 25,
            25, 26, 27, 12, 25, 27, 12, 27, 28, 12, 28, 29, 29, 30, 31, 12, 29, 31, 12, 31, 32, 12, 32, 33,
            12, 33, 34, 12, 34, 35, 12, 35, 36, 12, 36, 37, 12, 37, 38, 12, 38, 39, 12, 39, 40, 12, 40, 41,
            12, 41, 42, 12, 42, 43, 12, 43, 44, 12, 44, 45, 12, 45, 46, 12, 46, 47, 12, 47, 48, 50, 12, 48,
            48, 49, 50,
        ]),
    ]
}
