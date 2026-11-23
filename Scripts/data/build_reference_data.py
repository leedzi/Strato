#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build Strato's bundled reference data (airports + airlines, with zh-Hans names).

Outputs (UTF-8, LF, tab-separated, one header line):

  Strato/Resources/Data/airports.tsv
      iata icao lat lon elev_ft country tz size city_en name_en city_zh name_zh
  Strato/Resources/Data/airlines.tsv
      icao iata name_en name_zh country callsign

Sources (downloaded at build time and cached in --cache):

  * OurAirports  airports.csv / countries.csv          (public domain)
  * OpenFlights  airports.dat / airlines.dat           (ODbL 1.0)
  * Wikidata     SPARQL: Chinese labels, served city   (CC0)
  * OpenCC       TSCharacters.txt / TSPhrases.txt      (Apache-2.0)

Standard library only.  Usage:

  python -I Scripts/data/build_reference_data.py            # build + validate
  python -I Scripts/data/build_reference_data.py --spot     # also print spot checks
  python -I Scripts/data/build_reference_data.py --refresh  # ignore the cache

Downloaded files are treated as untrusted data: they are only ever parsed as
CSV / JSON / plain text.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import os
import re
import sys
import tempfile
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

USER_AGENT = "StratoDataBuild/1.0 (personal project; python-urllib)"

URL_OA_AIRPORTS = "https://davidmegginson.github.io/ourairports-data/airports.csv"
URL_OA_COUNTRIES = "https://davidmegginson.github.io/ourairports-data/countries.csv"
URL_OF_AIRPORTS = "https://raw.githubusercontent.com/jpatokal/openflights/master/data/airports.dat"
URL_OF_AIRLINES = "https://raw.githubusercontent.com/jpatokal/openflights/master/data/airlines.dat"
URL_OPENCC_CHARS = "https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/TSCharacters.txt"
URL_OPENCC_PHRASES = "https://raw.githubusercontent.com/BYVoid/OpenCC/master/data/dictionary/TSPhrases.txt"
URL_SPARQL = "https://query.wikidata.org/sparql"

# Preference order for Chinese labels.
ZH_LANGS = ["zh-cn", "zh-hans", "zh", "zh-sg", "zh-hant", "zh-tw", "zh-hk"]
TRADITIONAL_LANGS = {"zh-hant", "zh-tw", "zh-hk"}

AIRPORT_HEADER = ["iata", "icao", "lat", "lon", "elev_ft", "country", "tz", "size",
                  "city_en", "name_en", "city_zh", "name_zh"]
AIRLINE_HEADER = ["icao", "iata", "name_en", "name_zh", "country", "callsign"]

# Countries/regions whose Chinese airport names follow the "城市+机场名" pattern,
# so the short display name is simply the airport name minus the 机场 suffix.
NAME_FORM_COUNTRIES = {"CN", "HK", "MO", "TW"}

# ---------------------------------------------------------------------------
# Hand-curated overrides
# ---------------------------------------------------------------------------

# iata -> city_zh (short display name used on flight cards).  These always win.
AIRPORT_CITY_ZH_OVERRIDES_TEXT = """
# --- Mainland China
PEK 北京首都
PKX 北京大兴
PVG 上海浦东
SHA 上海虹桥
CAN 广州白云
SZX 深圳宝安
CTU 成都双流
TFU 成都天府
CKG 重庆江北
KMG 昆明长水
XIY 西安咸阳
HGH 杭州萧山
NKG 南京禄口
CGO 郑州新郑
WUH 武汉天河
CSX 长沙黄花
XMN 厦门高崎
TAO 青岛胶东
HAK 海口美兰
SYX 三亚凤凰
URC 乌鲁木齐天山
TSN 天津滨海
DLC 大连周水子
SHE 沈阳桃仙
HRB 哈尔滨太平
CGQ 长春龙嘉
TNA 济南遥墙
KWE 贵阳龙洞堡
NNG 南宁吴圩
FOC 福州长乐
LHW 兰州中川
TYN 太原武宿
KHN 南昌昌北
HFE 合肥新桥
SJW 石家庄正定
NGB 宁波栎社
WNZ 温州龙湾
ZUH 珠海金湾
INC 银川河东
XNN 西宁曹家堡
LXA 拉萨贡嘎
KWL 桂林两江
LJG 丽江三义
WUX 无锡硕放
JJN 泉州晋江
SWA 揭阳潮汕
YNT 烟台蓬莱
CZX 常州奔牛
NTG 南通兴东
XUZ 徐州观音
YIW 义乌
JHG 西双版纳嘎洒
MIG 绵阳南郊
ZHA 湛江吴川
HIA 淮安涟水
YTY 扬州泰州
WEH 威海大水泊
DYG 张家界荷花
BHY 北海福成
KHG 喀什徕宁
DSN 鄂尔多斯伊金霍洛
YIH 宜昌三峡
XFN 襄阳刘集
TXN 黄山屯溪
EHU 鄂州花湖
# --- Hong Kong / Macau / Taiwan
HKG 香港
MFM 澳门
TPE 台北桃园
TSA 台北松山
KHH 高雄
RMQ 台中
# --- Japan / Korea
HND 东京羽田
NRT 东京成田
KIX 大阪关西
ITM 大阪伊丹
UKB 神户
NGO 名古屋中部
FUK 福冈
CTS 札幌新千岁
OKA 冲绳那霸
KOJ 鹿儿岛
SDJ 仙台
HIJ 广岛
KMJ 熊本
ICN 首尔仁川
GMP 首尔金浦
PUS 釜山金海
CJU 济州
TAE 大邱
# --- South-East Asia
SIN 新加坡
BKK 曼谷素万那普
DMK 曼谷廊曼
HKT 普吉
CNX 清迈
KUL 吉隆坡
PEN 槟城
BKI 亚庇
CGK 雅加达
DPS 巴厘岛
SUB 泗水
MNL 马尼拉
CEB 宿务
SGN 胡志明市
HAN 河内
DAD 岘港
CXR 芽庄
PQC 富国岛
PNH 金边
RGN 仰光
VTE 万象
BWN 斯里巴加湾
# --- South / Central Asia
DEL 德里
BOM 孟买
BLR 班加罗尔
MAA 金奈
HYD 海得拉巴
CCU 加尔各答
CMB 科伦坡
DAC 达卡
KTM 加德满都
MLE 马累
ISB 伊斯兰堡
KHI 卡拉奇
LHE 拉合尔
ALA 阿拉木图
NQZ 阿斯塔纳
TAS 塔什干
UBN 乌兰巴托
# --- Middle East
DXB 迪拜
DWC 迪拜世界中心
AUH 阿布扎比
SHJ 沙迦
DOH 多哈
RUH 利雅得
JED 吉达
MED 麦地那
KWI 科威特
BAH 巴林
MCT 马斯喀特
TLV 特拉维夫
AMM 安曼
BEY 贝鲁特
BGW 巴格达
IKA 德黑兰
IST 伊斯坦布尔
SAW 伊斯坦布尔萨比哈
AYT 安塔利亚
ESB 安卡拉
ADB 伊兹密尔
# --- Europe
LHR 伦敦希思罗
LGW 伦敦盖特威克
STN 伦敦斯坦斯特德
LTN 伦敦卢顿
LCY 伦敦城市
MAN 曼彻斯特
EDI 爱丁堡
BHX 伯明翰
GLA 格拉斯哥
DUB 都柏林
CDG 巴黎戴高乐
ORY 巴黎奥利
NCE 尼斯
LYS 里昂
MRS 马赛
TLS 图卢兹
FRA 法兰克福
MUC 慕尼黑
BER 柏林
DUS 杜塞尔多夫
HAM 汉堡
STR 斯图加特
CGN 科隆
AMS 阿姆斯特丹
BRU 布鲁塞尔
LUX 卢森堡
ZRH 苏黎世
GVA 日内瓦
VIE 维也纳
MAD 马德里
BCN 巴塞罗那
PMI 帕尔马
AGP 马拉加
ALC 阿利坎特
LIS 里斯本
OPO 波尔图
FCO 罗马菲乌米奇诺
MXP 米兰马尔彭萨
LIN 米兰利纳特
BGY 米兰贝加莫
VCE 威尼斯
NAP 那不勒斯
ATH 雅典
CPH 哥本哈根
ARN 斯德哥尔摩
OSL 奥斯陆
HEL 赫尔辛基
KEF 雷克雅未克
WAW 华沙
PRG 布拉格
BUD 布达佩斯
OTP 布加勒斯特
SOF 索非亚
BEG 贝尔格莱德
ZAG 萨格勒布
RIX 里加
VNO 维尔纽斯
TLL 塔林
KBP 基辅
SVO 莫斯科谢列梅捷沃
DME 莫斯科多莫杰多沃
VKO 莫斯科伏努科沃
LED 圣彼得堡
MSQ 明斯克
SVX 叶卡捷琳堡
OVB 新西伯利亚
IKT 伊尔库茨克
KHV 哈巴罗夫斯克
VVO 符拉迪沃斯托克
# --- North America
ATL 亚特兰大
DFW 达拉斯
DAL 达拉斯爱田
DEN 丹佛
ORD 芝加哥奥黑尔
MDW 芝加哥中途
LAX 洛杉矶
JFK 纽约肯尼迪
LGA 纽约拉瓜迪亚
EWR 纽约纽瓦克
SFO 旧金山
SJC 圣何塞
OAK 奥克兰
SEA 西雅图
LAS 拉斯维加斯
MCO 奥兰多
MIA 迈阿密
FLL 劳德代尔堡
TPA 坦帕
CLT 夏洛特
PHX 凤凰城
IAH 休斯敦
HOU 休斯敦霍比
BOS 波士顿
MSP 明尼阿波利斯
DTW 底特律
PHL 费城
BWI 巴尔的摩
IAD 华盛顿杜勒斯
DCA 华盛顿里根
SLC 盐湖城
SAN 圣迭戈
PDX 波特兰
HNL 檀香山
AUS 奥斯汀
SAT 圣安东尼奥
BNA 纳什维尔
STL 圣路易斯
MSY 新奥尔良
RDU 罗利
SMF 萨克拉门托
MCI 堪萨斯城
CLE 克利夫兰
PIT 匹兹堡
CVG 辛辛那提
IND 印第安纳波利斯
CMH 哥伦布
MEM 孟菲斯
SDF 路易斯维尔
ANC 安克雷奇
GUM 关岛
SPN 塞班
YYZ 多伦多
YVR 温哥华
YUL 蒙特利尔
YYC 卡尔加里
YEG 埃德蒙顿
YOW 渥太华
YWG 温尼伯
YHZ 哈利法克斯
MEX 墨西哥城
CUN 坎昆
GDL 瓜达拉哈拉
MTY 蒙特雷
TIJ 蒂华纳
# --- Latin America / Caribbean
GRU 圣保罗
CGH 圣保罗孔戈尼亚斯
GIG 里约热内卢
BSB 巴西利亚
EZE 布宜诺斯艾利斯
AEP 布宜诺斯艾利斯城
SCL 圣地亚哥
LIM 利马
BOG 波哥大
UIO 基多
PTY 巴拿马城
HAV 哈瓦那
PUJ 蓬塔卡纳
SJU 圣胡安
CCS 加拉加斯
MVD 蒙得维的亚
# --- Africa
JNB 约翰内斯堡
CPT 开普敦
DUR 德班
CAI 开罗
HRG 赫尔格达
SSH 沙姆沙伊赫
ADD 亚的斯亚贝巴
NBO 内罗毕
LOS 拉各斯
ACC 阿克拉
CMN 卡萨布兰卡
RAK 马拉喀什
ALG 阿尔及尔
TUN 突尼斯
DAR 达累斯萨拉姆
MRU 毛里求斯
SEZ 塞舌尔
# --- Oceania
SYD 悉尼
MEL 墨尔本
BNE 布里斯班
PER 珀斯
ADL 阿德莱德
OOL 黄金海岸
CNS 凯恩斯
CBR 堪培拉
AKL 奥克兰
CHC 基督城
WLG 惠灵顿
ZQN 皇后镇
NAN 楠迪
PPT 帕皮提
"""

# iata -> full name_zh, for airports whose Wikidata label is missing or stale.
AIRPORT_NAME_ZH_OVERRIDES = {
    "URC": "乌鲁木齐天山国际机场",   # renamed from 地窝堡 in April 2025
}

# icao -> (name_zh, iata, name_en, ISO country, callsign).
# name_zh / iata / name_en / country are authoritative; callsign is only a fallback.
AIRLINE_OVERRIDES_TEXT = """
CCA|中国国际航空|CA|Air China|CN|AIR CHINA
CES|中国东方航空|MU|China Eastern Airlines|CN|CHINA EASTERN
CSN|中国南方航空|CZ|China Southern Airlines|CN|CHINA SOUTHERN
CHH|海南航空|HU|Hainan Airlines|CN|HAINAN
CSC|四川航空|3U|Sichuan Airlines|CN|SICHUAN
CXA|厦门航空|MF|XiamenAir|CN|XIAMEN AIR
CSZ|深圳航空|ZH|Shenzhen Airlines|CN|SHENZHEN AIR
CDG|山东航空|SC|Shandong Airlines|CN|SHANDONG
DKH|吉祥航空|HO|Juneyao Air|CN|AIR JUNEYAO
CQH|春秋航空|9C|Spring Airlines|CN|AIR SPRING
CSH|上海航空|FM|Shanghai Airlines|CN|SHANGHAI AIR
CBJ|首都航空|JD|Capital Airlines|CN|CAPITAL JET
GCR|天津航空|GS|Tianjin Airlines|CN|BOHAI
CPA|国泰航空|CX|Cathay Pacific|HK|CATHAY
HKE|香港快运|UO|HK Express|HK|HONGKONG SHUTTLE
CRK|香港航空|HX|Hong Kong Airlines|HK|BAUHINIA
EVA|长荣航空|BR|EVA Air|TW|EVA
CAL|中华航空|CI|China Airlines|TW|DYNASTY
SJX|星宇航空|JX|Starlux Airlines|TW|STARWALKER
AMU|澳门航空|NX|Air Macau|MO|AIR MACAO
ANA|全日空|NH|All Nippon Airways|JP|ALL NIPPON
JAL|日本航空|JL|Japan Airlines|JP|JAPANAIR
APJ|乐桃航空|MM|Peach Aviation|JP|AIR PEACH
KAL|大韩航空|KE|Korean Air|KR|KOREANAIR
AAR|韩亚航空|OZ|Asiana Airlines|KR|ASIANA
JJA|济州航空|7C|Jeju Air|KR|JEJU AIR
SIA|新加坡航空|SQ|Singapore Airlines|SG|SINGAPORE
TGW|酷航|TR|Scoot|SG|SCOOTER
THA|泰国国际航空|TG|Thai Airways International|TH|THAI
MAS|马来西亚航空|MH|Malaysia Airlines|MY|MALAYSIAN
AXM|亚洲航空|AK|AirAsia|MY|RED CAP
GIA|印尼鹰航|GA|Garuda Indonesia|ID|INDONESIA
PAL|菲律宾航空|PR|Philippine Airlines|PH|PHILIPPINE
HVN|越南航空|VN|Vietnam Airlines|VN|VIET NAM AIRLINES
AIC|印度航空|AI|Air India|IN|AIRINDIA
IGO|靛蓝航空|6E|IndiGo|IN|IFLY
BAW|英国航空|BA|British Airways|GB|SPEEDBIRD
VIR|维珍航空|VS|Virgin Atlantic|GB|VIRGIN
EZY|易捷航空|U2|easyJet|GB|EASY
RYR|瑞安航空|FR|Ryanair|IE|RYANAIR
DLH|汉莎航空|LH|Lufthansa|DE|LUFTHANSA
EWG|欧洲之翼|EW|Eurowings|DE|EUROWINGS
AFR|法国航空|AF|Air France|FR|AIRFRANS
KLM|荷兰皇家航空|KL|KLM Royal Dutch Airlines|NL|KLM
SWR|瑞士国际航空|LX|Swiss International Air Lines|CH|SWISS
AUA|奥地利航空|OS|Austrian Airlines|AT|AUSTRIAN
IBE|西班牙国家航空|IB|Iberia|ES|IBERIA
ITY|ITA航空|AZ|ITA Airways|IT|ITARROW
SAS|北欧航空|SK|Scandinavian Airlines|SE|SCANDINAVIAN
FIN|芬兰航空|AY|Finnair|FI|FINNAIR
TAP|葡萄牙航空|TP|TAP Air Portugal|PT|AIR PORTUGAL
THY|土耳其航空|TK|Turkish Airlines|TR|TURKISH
AFL|俄罗斯航空|SU|Aeroflot|RU|AEROFLOT
UAE|阿联酋航空|EK|Emirates|AE|EMIRATES
QTR|卡塔尔航空|QR|Qatar Airways|QA|QATARI
ETD|阿提哈德航空|EY|Etihad Airways|AE|ETIHAD
SVA|沙特阿拉伯航空|SV|Saudia|SA|SAUDIA
ELY|以色列航空|LY|El Al|IL|ELAL
ETH|埃塞俄比亚航空|ET|Ethiopian Airlines|ET|ETHIOPIAN
DAL|达美航空|DL|Delta Air Lines|US|DELTA
UAL|美国联合航空|UA|United Airlines|US|UNITED
AAL|美国航空|AA|American Airlines|US|AMERICAN
SWA|西南航空|WN|Southwest Airlines|US|SOUTHWEST
JBU|捷蓝航空|B6|JetBlue|US|JETBLUE
ASA|阿拉斯加航空|AS|Alaska Airlines|US|ALASKA
ACA|加拿大航空|AC|Air Canada|CA|AIR CANADA
WJA|西捷航空|WS|WestJet|CA|WESTJET
AMX|墨西哥航空|AM|Aeromexico|MX|AEROMEXICO
LAN|南美航空|LA|LATAM Airlines|CL|LAN CHILE
QFA|澳洲航空|QF|Qantas|AU|QANTAS
VOZ|维珍澳洲航空|VA|Virgin Australia|AU|VELOCITY
JST|捷星航空|JQ|Jetstar|AU|JETSTAR
ANZ|新西兰航空|NZ|Air New Zealand|NZ|NEW ZEALAND
FDX|联邦快递|FX|FedEx Express|US|FEDEX
UPS|UPS航空|5X|UPS Airlines|US|UPS
CKK|中国货运航空|CK|China Cargo Airlines|CN|CARGO KING
CSS|顺丰航空|O3|SF Airlines|CN|SHUN FENG
CLX|卢森堡货运航空|CV|Cargolux|LU|CARGOLUX
"""

# OpenFlights country names that differ from OurAirports' countries.csv names.
COUNTRY_ALIASES = {
    "hong kong sar of china": "HK", "hong kong": "HK", "macao": "MO", "macau": "MO",
    "republic of korea": "KR", "south korea": "KR", "korea": "KR",
    "democratic people's republic of korea": "KP", "north korea": "KP",
    "russian federation": "RU", "russia": "RU", "burma": "MM", "myanmar": "MM",
    "lao peoples democratic republic": "LA", "laos": "LA", "viet nam": "VN",
    "syrian arab republic": "SY", "syria": "SY", "iran": "IR", "moldova": "MD",
    "republic of moldova": "MD", "macedonia": "MK", "north macedonia": "MK",
    "ivory coast": "CI", "cote d'ivoire": "CI", "democratic republic of the congo": "CD",
    "democratic republic of congo": "CD", "congo (kinshasa)": "CD",
    "congo (brazzaville)": "CG", "republic of the congo": "CG", "congo": "CG",
    "tanzania": "TZ", "united republic of tanzania": "TZ", "bolivia": "BO",
    "venezuela": "VE", "brunei": "BN", "czech republic": "CZ", "czechia": "CZ",
    "swaziland": "SZ", "eswatini": "SZ", "cape verde": "CV", "east timor": "TL",
    "timor-leste": "TL", "united states": "US", "united states of america": "US",
    "usa": "US", "united kingdom": "GB", "uk": "GB", "the netherlands": "NL",
    "netherlands antilles": "CW", "taiwan": "TW", "palestine": "PS", "bahamas": "BS",
    "gambia": "GM", "turkey": "TR", "türkiye": "TR", "reunion": "RE", "kyrgyzstan": "KG",
    "libyan arab jamahiriya": "LY", "serbia and montenegro": "RS", "faroe islands": "FO",
    "saint vincent and the grenadines": "VC", "st. kitts and nevis": "KN",
    "antigua and barbuda": "AG", "trinidad and tobago": "TT", "micronesia": "FM",
    "virgin islands": "VI", "british virgin islands": "VG", "sao tome and principe": "ST",
    "bosnia and herzegovina": "BA", "kosovo": "XK", "vatican city": "VA",
}

# Taiwan / Hong Kong wording -> mainland wording.  Only applied to labels that
# were Traditional to begin with (after character conversion).
REGIONAL_PHRASES = [
    ("甘乃迪", "肯尼迪"), ("甘迺迪", "肯尼迪"), ("纽西兰", "新西兰"), ("雪梨", "悉尼"),
    ("沙乌地阿拉伯", "沙特阿拉伯"), ("沙乌地", "沙特"), ("杜拜", "迪拜"), ("阿布达比", "阿布扎比"),
    ("卡达航空", "卡塔尔航空"), ("义大利", "意大利"), ("纽泽西", "新泽西"), ("寮国", "老挝"),
    ("肯亚", "肯尼亚"), ("奈及利亚", "尼日利亚"), ("坦尚尼亚", "坦桑尼亚"), ("尚比亚", "赞比亚"),
    ("辛巴威", "津巴布韦"), ("波札那", "博茨瓦纳"), ("莫三比克", "莫桑比克"), ("瓜地马拉", "危地马拉"),
    ("宏都拉斯", "洪都拉斯"), ("哥斯大黎加", "哥斯达黎加"), ("千里达", "特立尼达"), ("巴贝多", "巴巴多斯"),
    ("盖亚那", "圭亚那"), ("克罗埃西亚", "克罗地亚"), ("斯洛维尼亚", "斯洛文尼亚"), ("赛普勒斯", "塞浦路斯"),
    ("马尔他", "马耳他"), ("亚塞拜然", "阿塞拜疆"), ("吉里巴斯", "基里巴斯"), ("万那杜", "瓦努阿图"),
    ("索罗门", "所罗门"), ("吐瓦鲁", "图瓦卢"), ("帛琉", "帕劳"), ("汶莱", "文莱"),
    ("马尔地夫", "马尔代夫"), ("模里西斯", "毛里求斯"), ("塞席尔", "塞舌尔"), ("叶门", "也门"),
    ("突尼西亚", "突尼斯"), ("赖比瑞亚", "利比里亚"), ("衣索比亚", "埃塞俄比亚"), ("厄利垂亚", "厄立特里亚"),
    ("卢安达", "卢旺达"), ("蒲隆地", "布隆迪"), ("索马利亚", "索马里"), ("茅利塔尼亚", "毛里塔尼亚"),
    ("迦纳", "加纳"), ("加彭", "加蓬"), ("贝里斯", "伯利兹"), ("多明尼加", "多米尼加"),
    ("格瑞那达", "格林纳达"), ("苏利南", "苏里南"), ("乔治·布希", "乔治·布什"), ("三藩市", "旧金山"),
    ("蒙特娄", "蒙特利尔"), ("威灵顿", "惠灵顿"), ("墨尔钵", "墨尔本"), ("阿得雷德", "阿德莱德"),
    ("布里斯本", "布里斯班"), ("纽奥良", "新奥尔良"), ("休士顿", "休斯敦"),
]

SPOT_AIRPORTS = ("PEK PKX PVG SHA CAN SZX CTU HGH XIY URC HKG TPE HND NRT KIX ICN SIN BKK "
                 "DXB LHR CDG FRA AMS JFK LAX SFO ORD YYZ SYD GRU JNB").split()
SPOT_AIRLINES = "CCA CES CSN ANA JAL DLH BAW UAE DAL RYR".split()
TRADITIONAL_PROBE = "機場國際亞蘭"


def parse_airport_overrides(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        code, zh = line.split(None, 1)
        if code in out:
            raise SystemExit(f"duplicate airport override: {code}")
        out[code] = zh.strip()
    return out


def parse_airline_overrides(text: str) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        icao, zh, iata, en, cc, cs = line.split("|")
        if icao in out:
            raise SystemExit(f"duplicate airline override: {icao}")
        out[icao] = {"name_zh": zh, "iata": iata, "name_en": en, "country": cc, "callsign": cs}
    return out


AIRPORT_CITY_ZH_OVERRIDES = parse_airport_overrides(AIRPORT_CITY_ZH_OVERRIDES_TEXT)
AIRLINE_OVERRIDES = parse_airline_overrides(AIRLINE_OVERRIDES_TEXT)

# ---------------------------------------------------------------------------
# Download + cache
# ---------------------------------------------------------------------------


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


class Fetcher:
    def __init__(self, cache: Path, refresh: bool, offline_wikidata: bool = False) -> None:
        self.cache = cache
        self.refresh = refresh
        # When set, Wikidata queries that are not already cached return nothing instead of
        # going to the network (the service rate-limits hard); the hand-written override
        # tables still apply, everything else falls back to English names.
        self.offline_wikidata = offline_wikidata
        self.cache.mkdir(parents=True, exist_ok=True)
        self._last_sparql = 0.0

    def _http(self, url: str, headers: dict[str, str], timeout: int = 120) -> bytes:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, **headers})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read()   # raises IncompleteRead on a short body

    def _retry(self, what: str, fn, check, attempts: int = 6):
        delay = 5.0
        for attempt in range(1, attempts + 1):
            try:
                data = fn()
                check(data)
                return data
            except urllib.error.HTTPError as exc:
                err = f"HTTP {exc.code}"
                retry_after = exc.headers.get("Retry-After") if exc.headers else None
                if retry_after and retry_after.isdigit():
                    delay = max(delay, float(retry_after))
            except Exception as exc:  # network errors, truncated bodies, bad JSON
                err = f"{type(exc).__name__}: {exc}"
            if attempt == attempts:
                raise SystemExit(f"giving up on {what}: {err}")
            log(f"  {what}: {err}; retry {attempt}/{attempts - 1} in {delay:.0f}s")
            time.sleep(delay)
            delay = min(delay * 2, 90.0)

    def _store(self, path: Path, data: bytes) -> None:
        tmp = path.with_suffix(path.suffix + ".part")
        tmp.write_bytes(data)
        os.replace(tmp, path)

    def text(self, url: str, filename: str, min_lines: int) -> str:
        """Download a text file (cached).  min_lines guards against truncation."""
        path = self.cache / filename

        def check(data: bytes) -> None:
            if data.count(b"\n") < min_lines:
                raise ValueError(f"only {data.count(10)} lines, expected >= {min_lines}")

        if path.exists() and not self.refresh:
            data = path.read_bytes()
            try:
                check(data)
                return data.decode("utf-8-sig")
            except ValueError:
                pass
        log(f"download {url}")
        data = self._retry(filename, lambda: self._http(url, {}), check)
        self._store(path, data)
        return data.decode("utf-8-sig")

    def sparql(self, name: str, query: str) -> list[dict[str, dict]]:
        """Run a SPARQL SELECT (cached by query hash); returns the bindings."""
        digest = hashlib.sha1(query.encode("utf-8")).hexdigest()[:12]
        path = self.cache / f"wd_{name}_{digest}.json"
        if path.exists() and not self.refresh:
            try:
                return json.loads(path.read_text(encoding="utf-8"))["results"]["bindings"]
            except (ValueError, KeyError):
                pass
        if self.offline_wikidata:
            log(f"sparql {name}: skipped (offline)")
            return []
        url = URL_SPARQL + "?" + urllib.parse.urlencode({"query": query})

        def fetch() -> bytes:
            wait = 1.5 - (time.monotonic() - self._last_sparql)   # <= 1 request/second
            if wait > 0:
                time.sleep(wait)
            try:
                return self._http(url, {"Accept": "application/sparql-results+json"}, timeout=100)
            finally:
                self._last_sparql = time.monotonic()

        def check(data: bytes) -> None:
            json.loads(data.decode("utf-8"))["results"]["bindings"]   # complete JSON?

        log(f"sparql {name}")
        data = self._retry(f"sparql {name}", fetch, check)
        self._store(path, data)
        return json.loads(data.decode("utf-8"))["results"]["bindings"]


# ---------------------------------------------------------------------------
# Text helpers
# ---------------------------------------------------------------------------

_CJK_RE = re.compile(r"[㐀-䶿一-鿿]")
_WS_RE = re.compile(r"\s+")
_PAREN_RE = re.compile(r"\s*[（(][^（）()]*[）)]\s*")


def clean(value: str | None) -> str:
    """Collapse whitespace (incl. tabs/newlines) so a value is TSV-safe."""
    return _WS_RE.sub(" ", value or "").strip()


def cjk_count(value: str) -> int:
    return len(_CJK_RE.findall(value))


def norm_en(value: str) -> str:
    value = unicodedata.normalize("NFKD", value or "")
    value = "".join(ch for ch in value if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", "", value.lower())


class Simplifier:
    """Traditional -> Simplified using OpenCC's dictionaries (phrases, then chars)."""

    def __init__(self, chars_text: str, phrases_text: str) -> None:
        self.chars: dict[str, str] = {}
        self.phrases: dict[str, str] = {}
        for line in chars_text.splitlines():
            if not line or line.startswith("#") or "\t" not in line:
                continue
            key, values = line.split("\t", 1)
            options = values.split()
            # If the character is also valid Simplified (it maps to itself as one
            # option, e.g. 乾/著/瞭), leave it alone: safer for proper nouns.
            if options and key not in options and len(key) == 1:
                self.chars[key] = options[0]
        for line in phrases_text.splitlines():
            if not line or line.startswith("#") or "\t" not in line:
                continue
            key, values = line.split("\t", 1)
            options = values.split()
            if options:
                self.phrases[key] = options[0]
        self.max_phrase = max((len(k) for k in self.phrases), default=1)

    def convert(self, text: str) -> str:
        out: list[str] = []
        i, n = 0, len(text)
        while i < n:
            for size in range(min(self.max_phrase, n - i), 1, -1):
                hit = self.phrases.get(text[i:i + size])
                if hit is not None:
                    out.append(hit)
                    i += size
                    break
            else:
                out.append(self.chars.get(text[i], text[i]))
                i += 1
        return "".join(out)

    def label(self, text: str, lang: str) -> str:
        """Normalise one Wikidata label to mainland Simplified Chinese."""
        text = clean(text).replace("‧", "·").replace("・", "·").replace("•", "·")
        converted = self.convert(text)
        if lang in TRADITIONAL_LANGS or (lang == "zh" and converted != text):
            for src, dst in REGIONAL_PHRASES:
                if src in converted:
                    converted = converted.replace(src, dst)
        return converted


def pick_zh(labels: dict[str, str] | None, simp: Simplifier, min_cjk: int = 1) -> str:
    """Best Chinese label by language preference, converted to Simplified."""
    if not labels:
        return ""
    for lang in ZH_LANGS:
        raw = labels.get(lang)
        if not raw:
            continue
        value = _PAREN_RE.sub("", simp.label(raw, lang)).strip()
        if cjk_count(value) >= min_cjk:
            return value
    return ""


_NAME_SUFFIXES = sorted([
    "国际机场", "国际航空站", "国际航空港", "国际空港", "国际飞行场", "地区机场", "区域机场",
    "民用机场", "军民合用机场", "机场", "空港", "航空站", "航空港", "飞行场", "国际",
], key=len, reverse=True)


def strip_airport_suffix(name_zh: str) -> str:
    value = name_zh
    changed = True
    while changed and value:
        changed = False
        for suffix in _NAME_SUFFIXES:
            if value.endswith(suffix) and len(value) > len(suffix):
                value = value[: -len(suffix)]
                changed = True
                break
    return value.strip(" -·/")


_CITY_SUFFIXES = ["特别行政区", "特别自治市", "特别市", "广域市", "直辖市", "地区", "市"]
_CITY_FIXED = {"东京都": "东京", "大阪府": "大阪", "京都府": "京都", "纽约市": "纽约",
               "新加坡共和国": "新加坡", "香港特别行政区": "香港", "澳门特别行政区": "澳门"}


def tidy_city_zh(label: str) -> str:
    value = label.strip()
    if value in _CITY_FIXED:
        return _CITY_FIXED[value]
    for suffix in _CITY_SUFFIXES:
        if value.endswith(suffix) and len(value) - len(suffix) >= 2:
            return value[: -len(suffix)]
    return value


_EN_NAME_WORDS = re.compile(
    r"\b(international|intl|regional|municipal|domestic|airport|airfield|airstrip|aerodrome|"
    r"air base|airbase|air force base|afb|field)\b", re.I)


def city_from_name(name_en: str) -> str:
    value = clean(_EN_NAME_WORDS.sub(" ", name_en)).strip(" -/,")
    return value or clean(name_en)


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    a = (math.sin((p2 - p1) / 2) ** 2
         + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lon2 - lon1) / 2) ** 2)
    return 6371.0 * 2 * math.asin(min(1.0, math.sqrt(a)))


def qid(binding: dict, var: str) -> str:
    return binding[var]["value"].rsplit("/", 1)[-1]


def qnum(q: str) -> int:
    return int(q[1:]) if q[1:].isdigit() else 10 ** 12


# ---------------------------------------------------------------------------
# Wikidata
# ---------------------------------------------------------------------------


def wd_multimap(fetcher: Fetcher, name: str, query: str, key: str, val: str) -> dict[str, list[str]]:
    out: dict[str, list[str]] = defaultdict(list)
    for b in fetcher.sparql(name, query):
        if key not in b or val not in b:
            continue
        k = qid(b, key) if b[key]["type"] == "uri" else b[key]["value"]
        v = qid(b, val) if b[val]["type"] == "uri" else b[val]["value"]
        if v not in out[k]:
            out[k].append(v)
    return out


def wd_labels(fetcher: Fetcher, name: str, pattern: str, var: str, langs: list[str]) -> dict[str, dict[str, str]]:
    """labels[qid][lang] for every ?var matched by `pattern` (one query per language)."""
    out: dict[str, dict[str, str]] = defaultdict(dict)
    for lang in langs:
        query = (f"SELECT DISTINCT ?{var} ?label WHERE {{ {pattern} "
                 f"?{var} rdfs:label ?label . FILTER(LANG(?label) = \"{lang}\") }}")
        for b in fetcher.sparql(f"{name}_{lang}", query):
            out[qid(b, var)].setdefault(lang, b["label"]["value"])
    return out


def fetch_wikidata_airports(fetcher: Fetcher) -> dict:
    base = "?item wdt:P238 [] ."
    wd = {
        "iata": wd_multimap(fetcher, "ap_iata", "SELECT ?item ?iata WHERE { ?item wdt:P238 ?iata }", "iata", "item"),
        "icao": wd_multimap(fetcher, "ap_icao", f"SELECT DISTINCT ?item ?icao WHERE {{ {base} ?item wdt:P239 ?icao }}", "item", "icao"),
        "coord": wd_multimap(fetcher, "ap_coord", f"SELECT DISTINCT ?item ?coord WHERE {{ {base} ?item wdt:P625 ?coord }}", "item", "coord"),
        "sitelinks": wd_multimap(fetcher, "ap_sitelinks", f"SELECT DISTINCT ?item ?sl WHERE {{ {base} ?item wikibase:sitelinks ?sl }}", "item", "sl"),
        "closed": wd_multimap(fetcher, "ap_closed", f"SELECT DISTINCT ?item ?d WHERE {{ {base} ?item wdt:P576|wdt:P3999 ?d }}", "item", "d"),
        "served": wd_multimap(fetcher, "ap_served", f"SELECT DISTINCT ?item ?city WHERE {{ {base} ?item wdt:P931 ?city }}", "item", "city"),
        "admin": wd_multimap(fetcher, "ap_admin", f"SELECT DISTINCT ?item ?city WHERE {{ {base} ?item wdt:P131 ?city }}", "item", "city"),
        "labels": wd_labels(fetcher, "ap_label", base, "item", ZH_LANGS),
        "city_labels": wd_labels(fetcher, "ap_served_label", "[] wdt:P238 [] ; wdt:P931 ?city .", "city", ZH_LANGS + ["en"]),
    }
    admin_labels = wd_labels(fetcher, "ap_admin_label", "[] wdt:P238 [] ; wdt:P131 ?city .", "city", ZH_LANGS + ["en"])
    for city, labels in admin_labels.items():
        merged = wd["city_labels"].setdefault(city, {})
        for lang, value in labels.items():
            merged.setdefault(lang, value)
    return wd


def fetch_wikidata_airlines(fetcher: Fetcher) -> dict:
    base = "?item wdt:P230 [] ."
    return {
        "icao": wd_multimap(fetcher, "al_icao", "SELECT ?item ?icao WHERE { ?item wdt:P230 ?icao }", "icao", "item"),
        "iata": wd_multimap(fetcher, "al_iata", f"SELECT DISTINCT ?item ?iata WHERE {{ {base} ?item wdt:P229 ?iata }}", "item", "iata"),
        "callsign": wd_multimap(fetcher, "al_callsign", f"SELECT DISTINCT ?item ?cs WHERE {{ {base} ?item wdt:P432 ?cs }}", "item", "cs"),
        "country": wd_multimap(fetcher, "al_country", f"SELECT DISTINCT ?item ?cc WHERE {{ {base} ?item wdt:P17 ?c . ?c wdt:P297 ?cc }}", "item", "cc"),
        "dissolved": wd_multimap(fetcher, "al_dissolved", f"SELECT DISTINCT ?item ?d WHERE {{ {base} ?item wdt:P576 ?d }}", "item", "d"),
        "sitelinks": wd_multimap(fetcher, "al_sitelinks", f"SELECT DISTINCT ?item ?sl WHERE {{ {base} ?item wikibase:sitelinks ?sl }}", "item", "sl"),
        "labels": wd_labels(fetcher, "al_label", base, "item", ZH_LANGS + ["en"]),
    }


# ---------------------------------------------------------------------------
# Airports
# ---------------------------------------------------------------------------

_IATA_RE = re.compile(r"^[A-Z]{3}$")
_ICAO_RE = re.compile(r"^[A-Z]{4}$")
_TYPE_RANK = {"large_airport": 0, "medium_airport": 1, "small_airport": 2}
_EXCLUDED_TYPES = {"closed", "heliport", "seaplane_base", "balloonport"}
_TZ_RE = re.compile(r"^[A-Za-z_]+(/[A-Za-z0-9_+\-]+)+$")


def load_ourairports(text: str) -> list[dict]:
    best: dict[str, tuple] = {}
    for row in csv.DictReader(io.StringIO(text)):
        iata = (row.get("iata_code") or "").strip().upper()
        kind = (row.get("type") or "").strip()
        scheduled = (row.get("scheduled_service") or "").strip().lower() == "yes"
        if not _IATA_RE.match(iata) or kind in _EXCLUDED_TYPES:
            continue
        if kind not in ("large_airport", "medium_airport") and not scheduled:
            continue
        try:
            lat, lon = float(row["latitude_deg"]), float(row["longitude_deg"])
        except (KeyError, ValueError):
            continue
        icao = ""
        for field in ("icao_code", "gps_code", "ident"):
            candidate = (row.get(field) or "").strip().upper()
            if _ICAO_RE.match(candidate):
                icao = candidate
                break
        try:
            elev = str(int(round(float(row.get("elevation_ft") or ""))))
        except ValueError:
            elev = ""
        name = clean(row.get("name"))
        entry = {
            "iata": iata, "icao": icao, "lat": lat, "lon": lon, "elev_ft": elev,
            "country": (row.get("iso_country") or "").strip().upper(),
            "size": {"large_airport": "L", "medium_airport": "M"}.get(kind, "S"),
            "scheduled": scheduled,
            "city_en": clean(row.get("municipality")) or city_from_name(name),
            "name_en": name,
        }
        try:
            row_id = int(row.get("id") or 0)
        except ValueError:
            row_id = 0
        rank = (_TYPE_RANK.get(kind, 3), 0 if scheduled else 1, 0 if icao else 1, row_id)
        if iata not in best or rank < best[iata][0]:
            best[iata] = (rank, entry)
    return [entry for _, entry in best.values()]


def load_openflights_tz(text: str) -> tuple[dict[str, str], dict[str, str]]:
    by_iata: dict[str, str] = {}
    by_icao: dict[str, str] = {}
    for row in csv.reader(io.StringIO(text)):
        if len(row) < 12:
            continue
        tz = row[11].strip()
        if not _TZ_RE.match(tz):          # "\N" / garbage -> unknown
            continue
        iata, icao = row[4].strip().upper(), row[5].strip().upper()
        if _IATA_RE.match(iata):
            by_iata.setdefault(iata, tz)
        if _ICAO_RE.match(icao):
            by_icao.setdefault(icao, tz)
    return by_iata, by_icao


def parse_point(wkt: str) -> tuple[float, float] | None:
    m = re.match(r"Point\(([-\d.eE]+) ([-\d.eE]+)\)", wkt)
    return (float(m.group(2)), float(m.group(1))) if m else None


def match_wd_airport(ap: dict, wd: dict) -> str:
    """Pick the Wikidata item for an airport (by IATA, verified by ICAO / distance)."""
    scored = []
    for item in wd["iata"].get(ap["iata"], []):
        icaos = {c.strip().upper() for c in wd["icao"].get(item, [])}
        dist = None
        for wkt in wd["coord"].get(item, []):
            point = parse_point(wkt)
            if point:
                d = haversine_km(ap["lat"], ap["lon"], point[0], point[1])
                dist = d if dist is None else min(dist, d)
        icao_ok = bool(ap["icao"]) and ap["icao"] in icaos
        if not icao_ok and dist is not None and dist > 80:
            continue                       # same IATA, different place: not this airport
        if not icao_ok and dist is None and icaos and ap["icao"]:
            continue                       # conflicting ICAO and nothing to confirm with
        sitelinks = max((int(s) for s in wd["sitelinks"].get(item, []) if s.isdigit()), default=0)
        scored.append((0 if icao_ok else 1, 1 if item in wd["closed"] else 0,
                       0 if wd["labels"].get(item) else 1, -sitelinks, qnum(item), item))
    return min(scored)[-1] if scored else ""


def choose_city(ap: dict, item: str, wd: dict, simp: Simplifier) -> str:
    """Chinese name of the city the airport serves (P931, else a matching P131)."""
    muni = ap["city_en"]
    parts = {norm_en(p) for p in re.split(r"[/,(;]| - ", muni)} | {norm_en(muni)}
    parts.discard("")

    def candidates(prop: str):
        for city in sorted(wd[prop].get(item, []), key=qnum):
            labels = wd["city_labels"].get(city, {})
            zh = tidy_city_zh(pick_zh(labels, simp, min_cjk=2))
            if zh:
                yield norm_en(labels.get("en", "")) in parts, zh

    served = list(candidates("served"))
    for matches, zh in served:
        if matches:
            return zh
    for matches, zh in candidates("admin"):
        if matches:                         # P131 is only trusted when it is the municipality
            return zh
    return served[0][1] if served else ""


def build_airports(fetcher: Fetcher, simp: Simplifier) -> list[dict]:
    airports = load_ourairports(fetcher.text(URL_OA_AIRPORTS, "ourairports_airports.csv", 60000))
    tz_iata, tz_icao = load_openflights_tz(fetcher.text(URL_OF_AIRPORTS, "openflights_airports.dat", 7000))
    wd = fetch_wikidata_airports(fetcher)

    # Time zone: OpenFlights by IATA, then ICAO; then, for countries where every
    # OpenFlights airport shares one zone, that zone.
    country_tz: dict[str, Counter] = defaultdict(Counter)
    for ap in airports:
        ap["tz"] = tz_iata.get(ap["iata"]) or (tz_icao.get(ap["icao"]) if ap["icao"] else "") or ""
        if ap["tz"]:
            country_tz[ap["country"]][ap["tz"]] += 1
    for ap in airports:
        zones = country_tz.get(ap["country"])
        if not ap["tz"] and zones and len(zones) == 1 and sum(zones.values()) >= 3:
            ap["tz"] = next(iter(zones))

    # Chinese names.
    for ap in airports:
        item = match_wd_airport(ap, wd)
        name_zh = pick_zh(wd["labels"].get(item), simp, min_cjk=2) if item else ""
        ap["name_zh"] = AIRPORT_NAME_ZH_OVERRIDES.get(ap["iata"], name_zh)
        ap["_city"] = choose_city(ap, item, wd, simp) if item else ""

    # Cities served by 2+ sizeable airports need "city + distinguisher".
    big_per_city: Counter = Counter()
    for ap in airports:
        if ap["_city"] and (ap["size"] == "L" or (ap["size"] == "M" and ap["scheduled"])):
            big_per_city[(ap["country"], ap["_city"])] += 1

    for ap in airports:
        city, name_zh = ap["_city"], ap["name_zh"]
        short = strip_airport_suffix(name_zh) if name_zh else ""
        if ap["iata"] in AIRPORT_CITY_ZH_OVERRIDES:
            result = AIRPORT_CITY_ZH_OVERRIDES[ap["iata"]]
        elif ap["country"] in NAME_FORM_COUNTRIES:
            # "城市+机场名" form: 杭州萧山国际机场 -> 杭州萧山
            result = short if short and len(short) <= 10 else (city or short)
        elif city and big_per_city[(ap["country"], city)] >= 2 and short:
            if short.startswith(city):
                result = short if len(short) <= 8 else city
            elif city not in short and len(short) <= 6 and "·" not in short:
                result = city + short
            else:
                result = city
        elif city:
            result = city
        else:
            result = short if len(short) <= 10 else ""
        ap["city_zh"] = result

    order = {"L": 0, "M": 1, "S": 2}
    airports.sort(key=lambda a: (order[a["size"]], a["iata"]))
    return airports


def airport_row(ap: dict) -> list[str]:
    return [ap["iata"], ap["icao"], f"{ap['lat']:.4f}", f"{ap['lon']:.4f}", ap["elev_ft"],
            ap["country"], ap["tz"], ap["size"], clean(ap["city_en"]), clean(ap["name_en"]),
            clean(ap["city_zh"]), clean(ap["name_zh"])]


# ---------------------------------------------------------------------------
# Airlines
# ---------------------------------------------------------------------------

_AL_ICAO_RE = re.compile(r"^[A-Z]{3}$")
_AL_IATA_RE = re.compile(r"^[A-Z0-9]{2}$")
_AL_WORDS = re.compile(r"\b(airlines?|airways|aviation|air|ltd|limited|inc|corp|corporation|company|co|"
                       r"international|intl|the|group|s\.?a\.?|gmbh|llc)\b", re.I)
_ZH_CORP_SUFFIXES = ["股份有限公司", "有限责任公司", "有限公司", "公司"]


def norm_airline(name: str) -> str:
    return norm_en(_AL_WORDS.sub(" ", name or ""))


def same_airline(a: str, b: str) -> bool:
    na, nb = norm_airline(a), norm_airline(b)
    if not na or not nb:
        return False
    if na == nb:
        return True
    short, long_ = sorted((na, nb), key=len)
    return len(short) >= 4 and short in long_


def tidy_airline_zh(name: str) -> str:
    for suffix in _ZH_CORP_SUFFIXES:
        if name.endswith("航空" + suffix):
            return name[: -len(suffix)]
    return name


def load_country_codes(text: str) -> dict[str, str]:
    codes: dict[str, str] = dict(COUNTRY_ALIASES)
    for row in csv.DictReader(io.StringIO(text)):
        code = (row.get("code") or "").strip().upper()
        if re.match(r"^[A-Z]{2}$", code):
            codes.setdefault(clean(row.get("name")).lower(), code)
    return codes


def load_openflights_airlines(text: str, countries: dict[str, str]) -> tuple[dict[str, dict], Counter]:
    """ICAO -> best OpenFlights record (active ones win)."""
    out: dict[str, dict] = {}
    unmapped: Counter = Counter()
    for row in csv.reader(io.StringIO(text)):
        if len(row) < 8:
            continue
        fields = ["" if v.strip() in ("\\N", "N/A", "-") else clean(v) for v in row]
        icao = fields[4].upper()
        if not _AL_ICAO_RE.match(icao) or not fields[1]:
            continue
        iata = fields[3].upper()
        country = countries.get(fields[6].lower(), "")
        active = fields[7].upper() == "Y"
        if fields[6] and not country and active:
            unmapped[fields[6]] += 1
        rec = {"name_en": fields[1], "iata": iata if _AL_IATA_RE.match(iata) else "",
               "callsign": fields[5].upper(), "country": country, "active": active}
        old = out.get(icao)
        if old is None or (rec["active"] and not old["active"]):
            out[icao] = rec
    return out, unmapped


def build_airlines(fetcher: Fetcher, simp: Simplifier) -> list[dict]:
    countries = load_country_codes(fetcher.text(URL_OA_COUNTRIES, "ourairports_countries.csv", 200))
    of, unmapped = load_openflights_airlines(
        fetcher.text(URL_OF_AIRLINES, "openflights_airlines.dat", 5500), countries)
    if unmapped:
        log("  OpenFlights countries without ISO mapping: "
            + ", ".join(f"{k} ({v})" for k, v in unmapped.most_common(15)))
    wd = fetch_wikidata_airlines(fetcher)

    wd_by_icao: dict[str, list[str]] = defaultdict(list)
    for code, items in wd["icao"].items():
        code = code.strip().upper()
        if _AL_ICAO_RE.match(code):
            wd_by_icao[code].extend(i for i in items if i not in wd_by_icao[code])

    def first(values: list[str], prefer: str = "") -> str:
        values = sorted({clean(v) for v in values if clean(v)})
        return prefer if prefer and prefer in values else (values[0] if values else "")

    rows: dict[str, dict] = {}
    for icao in sorted(set(of) | set(wd_by_icao) | set(AIRLINE_OVERRIDES)):
        ofr = of.get(icao)
        of_name = ofr["name_en"] if ofr else ""
        items = wd_by_icao.get(icao, [])
        live = [i for i in items if i not in wd["dissolved"]]
        dead = [i for i in items if i in wd["dissolved"]]

        def score(item: str):
            labels = wd["labels"].get(item, {})
            sitelinks = max((int(s) for s in wd["sitelinks"].get(item, []) if s.isdigit()), default=0)
            return (0 if same_airline(labels.get("en", ""), of_name) else 1,
                    0 if pick_zh(labels, simp) else 1, -sitelinks, qnum(item))

        item = min(live, key=score) if live else ""
        labels = wd["labels"].get(item, {}) if item else {}
        name_zh = tidy_airline_zh(pick_zh(labels, simp)) if item else ""
        wd_matches_of = bool(item) and same_airline(labels.get("en", ""), of_name)
        of_active = bool(ofr and ofr["active"])

        if icao in AIRLINE_OVERRIDES:
            pass                                       # always kept
        elif item and name_zh:
            pass                                       # Wikidata: has ICAO + zh label, not dissolved
        elif of_active:
            # Known defunct (same airline, dissolved in Wikidata)?  Drop it.
            if not live and any(same_airline(wd["labels"].get(d, {}).get("en", ""), of_name) for d in dead):
                continue
        else:
            continue

        use_wd = bool(item) and (bool(name_zh) or wd_matches_of)
        row = {"icao": icao, "iata": "", "name_en": "", "name_zh": "", "country": "", "callsign": ""}
        if use_wd:
            use_of = bool(ofr) and (wd_matches_of or not labels.get("en"))
            wd_iatas = [v.strip().upper() for v in wd["iata"].get(item, []) if _AL_IATA_RE.match(v.strip().upper())]
            row["name_en"] = clean(labels.get("en")) or of_name
            row["name_zh"] = name_zh
            row["iata"] = first(wd_iatas, ofr["iata"] if use_of else "") or (ofr["iata"] if use_of else "")
            row["country"] = first([c.upper() for c in wd["country"].get(item, []) if re.match(r"^[A-Za-z]{2}$", c)],
                                   ofr["country"] if use_of else "") or (ofr["country"] if use_of else "")
            row["callsign"] = first([c.upper() for c in wd["callsign"].get(item, [])],
                                    ofr["callsign"] if use_of else "") or (ofr["callsign"] if use_of else "")
        elif ofr:
            row.update(name_en=of_name, iata=ofr["iata"], country=ofr["country"], callsign=ofr["callsign"])

        override = AIRLINE_OVERRIDES.get(icao)
        if override:
            for key in ("name_zh", "iata", "name_en", "country"):
                row[key] = override[key]
            row["callsign"] = row["callsign"] or override["callsign"]
        if not row["name_en"]:
            continue
        rows[icao] = row
    return [rows[k] for k in sorted(rows)]


def airline_row(al: dict) -> list[str]:
    return [clean(al[k]) for k in AIRLINE_HEADER]


# ---------------------------------------------------------------------------
# Output + validation
# ---------------------------------------------------------------------------


def write_tsv(path: Path, header: list[str], rows: list[list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write("\t".join(header) + "\n")
        for row in rows:
            if len(row) != len(header) or any("\t" in v or "\n" in v or "\r" in v for v in row):
                raise SystemExit(f"bad row for {path.name}: {row!r}")
            fh.write("\t".join(row) + "\n")


def read_tsv(path: Path, header: list[str]) -> list[dict[str, str]]:
    raw = path.read_bytes()
    if b"\r" in raw:
        raise SystemExit(f"{path.name}: contains CR characters")
    lines = raw.decode("utf-8").split("\n")
    if lines[-1] != "":
        raise SystemExit(f"{path.name}: missing trailing newline")
    lines.pop()
    if lines[0].split("\t") != header:
        raise SystemExit(f"{path.name}: unexpected header {lines[0]!r}")
    rows = []
    for number, line in enumerate(lines[1:], start=2):
        fields = line.split("\t")
        if len(fields) != len(header):
            raise SystemExit(f"{path.name}:{number}: {len(fields)} fields, expected {len(header)}")
        rows.append(dict(zip(header, fields)))
    return rows


def pct(part: int, whole: int) -> str:
    return f"{part} ({100.0 * part / whole:.1f}%)" if whole else "0"


def validate(airports_path: Path, airlines_path: Path, spot: bool) -> None:
    out = sys.stdout
    airports = read_tsv(airports_path, AIRPORT_HEADER)
    airlines = read_tsv(airlines_path, AIRLINE_HEADER)

    n = len(airports)
    print(f"airports.tsv: {n} rows, every row has {len(AIRPORT_HEADER)} fields", file=out)
    print("  by size: " + ", ".join(f"{k}={v}" for k, v in sorted(Counter(a['size'] for a in airports).items())), file=out)
    for column in ("city_zh", "name_zh", "tz", "icao", "elev_ft"):
        print(f"  {column:8s} non-empty: {pct(sum(1 for a in airports if a[column]), n)}", file=out)
    for size in "LMS":
        subset = [a for a in airports if a["size"] == size]
        print(f"  size {size}: city_zh {pct(sum(1 for a in subset if a['city_zh']), len(subset))}, "
              f"name_zh {pct(sum(1 for a in subset if a['name_zh']), len(subset))}, "
              f"tz {pct(sum(1 for a in subset if a['tz']), len(subset))}", file=out)
    missing_large = [a["iata"] for a in airports if a["size"] == "L" and not a["city_zh"]]
    print(f"  large airports without city_zh ({len(missing_large)}): {' '.join(missing_large)}", file=out)
    missing_tz = [a["iata"] for a in airports if a["size"] == "L" and not a["tz"]]
    print(f"  large airports without tz ({len(missing_tz)}): {' '.join(missing_tz)}", file=out)
    if len({a["iata"] for a in airports}) != n:
        raise SystemExit("airports.tsv: duplicate IATA codes")
    for a in airports:
        if not _IATA_RE.match(a["iata"]) or a["size"] not in "LMS" or (a["icao"] and not _ICAO_RE.match(a["icao"])):
            raise SystemExit(f"airports.tsv: bad row {a}")
        if not (-90 <= float(a["lat"]) <= 90 and -180 <= float(a["lon"]) <= 180):
            raise SystemExit(f"airports.tsv: bad coordinates {a}")
    unused = sorted(set(AIRPORT_CITY_ZH_OVERRIDES) - {a["iata"] for a in airports})
    if unused:
        print(f"  overrides not present in data: {' '.join(unused)}", file=out)

    m = len(airlines)
    print(f"airlines.tsv: {m} rows, every row has {len(AIRLINE_HEADER)} fields", file=out)
    for column in ("name_zh", "iata", "country", "callsign"):
        print(f"  {column:8s} non-empty: {pct(sum(1 for a in airlines if a[column]), m)}", file=out)
    if len({a["icao"] for a in airlines}) != m:
        raise SystemExit("airlines.tsv: duplicate ICAO codes")
    by_icao = {a["icao"]: a for a in airlines}
    wrong = [k for k, v in AIRLINE_OVERRIDES.items() if by_icao.get(k, {}).get("name_zh") != v["name_zh"]]
    print(f"  curated airline names applied: {len(AIRLINE_OVERRIDES) - len(wrong)}/{len(AIRLINE_OVERRIDES)}"
          + (f" (missing: {' '.join(wrong)})" if wrong else ""), file=out)

    for path in (airports_path, airlines_path):
        text = path.read_text(encoding="utf-8")
        hits = {ch: text.count(ch) for ch in TRADITIONAL_PROBE}
        print(f"  {path.name}: Traditional probe {hits} -> {'OK' if not any(hits.values()) else 'FOUND'}", file=out)

    if spot:
        by_iata = {a["iata"]: a for a in airports}
        print("\n" + "\t".join(AIRPORT_HEADER), file=out)
        for code in SPOT_AIRPORTS:
            row = by_iata.get(code)
            print("\t".join(row[c] for c in AIRPORT_HEADER) if row else f"{code}\tMISSING", file=out)
        print("\n" + "\t".join(AIRLINE_HEADER), file=out)
        for code in SPOT_AIRLINES:
            row = by_icao.get(code)
            print("\t".join(row[c] for c in AIRLINE_HEADER) if row else f"{code}\tMISSING", file=out)


def main() -> None:
    repo = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--cache", type=Path, default=Path(tempfile.gettempdir()) / "strato_data_cache",
                        help="directory for downloaded source files (default: <tmp>/strato_data_cache)")
    parser.add_argument("--out", type=Path, default=repo / "Strato" / "Resources" / "Data",
                        help="output directory (default: Strato/Resources/Data)")
    parser.add_argument("--refresh", action="store_true", help="re-download everything, ignoring the cache")
    parser.add_argument("--spot", action="store_true", help="print spot-check rows after validating")
    parser.add_argument("--validate-only", action="store_true", help="only validate the existing output files")
    parser.add_argument("--offline-wikidata", action="store_true",
                        help="do not query Wikidata; use cached results and the override tables only")
    args = parser.parse_args()

    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", newline="\n")

    airports_path, airlines_path = args.out / "airports.tsv", args.out / "airlines.tsv"
    if not args.validate_only:
        fetcher = Fetcher(args.cache, args.refresh, args.offline_wikidata)
        simp = Simplifier(fetcher.text(URL_OPENCC_CHARS, "opencc_TSCharacters.txt", 3000),
                          fetcher.text(URL_OPENCC_PHRASES, "opencc_TSPhrases.txt", 100))
        airports = build_airports(fetcher, simp)
        airlines = build_airlines(fetcher, simp)
        write_tsv(airports_path, AIRPORT_HEADER, [airport_row(a) for a in airports])
        write_tsv(airlines_path, AIRLINE_HEADER, [airline_row(a) for a in airlines])
        log(f"wrote {airports_path}\nwrote {airlines_path}")
    validate(airports_path, airlines_path, args.spot)


if __name__ == "__main__":
    main()
