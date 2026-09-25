part of '../main.dart';

// ---------------- SITE-TO-REGION LOOKUP ----------------
class SiteEntry {
  final String id;
  final String siteName;
  final String region;

  SiteEntry({required this.id, required this.siteName, required this.region});

  Map<String, dynamic> toMap() => {
    'id': id,
    'siteName': siteName,
    'region': region,
  };

  static SiteEntry fromMap(Map<String, dynamic> m) => SiteEntry(
    id: m['id'],
    siteName: m['siteName'] ?? '',
    region: m['region'] ?? '',
  );
}

int _siteCounter = 179;
final List<SiteEntry> sampleSites = [
  // Lahore region
  SiteEntry(
    id: 'SITE-1',
    siteName: 'NEW GARDEN TOWN FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-2',
    siteName: 'RACE COURSE FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-3', siteName: 'BRIGHT FILLING STATION', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-4',
    siteName: 'NEW AL HABIB TRUCKING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-5',
    siteName: 'RUKHAN PETROLEUM SERVICE',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-6',
    siteName: 'BRIGHT STAR FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-7',
    siteName: 'SADHOKI FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-8',
    siteName: 'HP - NEW PEARL FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-9', siteName: 'RAJOKE FILLING STATION', region: 'Lahore'),
  SiteEntry(id: 'SITE-10', siteName: 'SAGGIAN VIEW FS', region: 'Lahore'),
  SiteEntry(id: 'SITE-11', siteName: 'DINGA FILLING STATION', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-22',
    siteName: 'A & A FILLING STATION LHR',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-23', siteName: 'ASIF FILLING STATION', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-24',
    siteName: 'PREMIUM - BATTLE AXE FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-25',
    siteName: 'REHMAN FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-26',
    siteName: 'BUKHARI FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-27', siteName: 'BUTT BROTHERS', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-28',
    siteName: 'CANAL VIEW FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-29',
    siteName: 'CHOHAN FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-30',
    siteName: 'EXPO CENTRE FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-31',
    siteName: 'FAIZAN FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-32',
    siteName: 'GARRISON FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-33',
    siteName: 'GHAUSIA FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-34',
    siteName: 'GRACE FILLING STATION LHR',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-35',
    siteName: 'H A BROTHERS FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-36',
    siteName: 'HAFIZABAD FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-37', siteName: 'HIGHWAY TRADERS', region: 'Lahore'),
  SiteEntry(id: 'SITE-38', siteName: 'J Z ENTERPRISES', region: 'Lahore'),
  SiteEntry(id: 'SITE-39', siteName: 'JOHOR TOWN FS', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-40',
    siteName: 'KASHMIR PETROLEUM SERVICE',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-41',
    siteName: '(CF) KASHMIR POINT FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-42',
    siteName: 'KHALID SERVICE STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-43',
    siteName: 'KHAN BABA PETROLEUM SERVICE',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-44',
    siteName: 'THE LAHORE CNG SERVICES & FUELLING STATION, MULTAN ROAD, LAHORE',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-45',
    siteName: 'MADANI FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-46',
    siteName: 'MOTORWAY FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-47',
    siteName: 'SPL ALLAMA IQBAL FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-48',
    siteName: 'MURTAZA SERVICE STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-49',
    siteName: 'NAROWAL FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-50',
    siteName: 'NEW ABDULLAH FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-51',
    siteName: 'AL SIDDIQUE PETROLEUM SERVICE',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-52',
    siteName: 'NEW IQRA FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-53',
    siteName: 'PREMIUM - NEW PEARL FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-54',
    siteName: 'SPL ABBOT ROAD FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-55',
    siteName: 'RACHNA FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-56',
    siteName: 'RAIWIND FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-57', siteName: 'RAVI TRUCKING STATION', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-58',
    siteName: 'RUKHAN PETROLEUM SERVICE',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-59',
    siteName: 'SHAD BAGH PETROLEUM SERVICE',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-60',
    siteName: 'SHAKIL FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-61',
    siteName: 'SHIBLI PETROLEUM SERVICE',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-62',
    siteName: 'PREMIUM - SPL SHIMLA HILL FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-63',
    siteName: 'PREMIUM - SPL GARDEN TOWN FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-64',
    siteName: 'SPL RAVI VIEW SERVICE STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-65',
    siteName: 'SULTAN FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-66', siteName: 'TAJ FILLING STATION', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-67',
    siteName: 'UMER PERTOLEUM SERVICE',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-68', siteName: 'USMAN FILLING STATION', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-69',
    siteName: 'WAHDAT FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-70', siteName: 'SADIQ GASOLINE LAHORE', region: 'Lahore'),
  SiteEntry(id: 'SITE-71', siteName: 'ZAMAN PETROL STATION', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-72',
    siteName: 'SHELL ASKARI 11 FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-73', siteName: 'SHELL DHA PHASE 5', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-74',
    siteName: 'BADIANA FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-75',
    siteName: 'SPL- GARRISON FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-76',
    siteName: 'SPL- MODEL TOWN FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-77',
    siteName: 'SAGGIAN VIEW FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-78',
    siteName: 'GHOUSIA FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-79', siteName: 'CANAL FILLING STATION', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-80',
    siteName: 'SUKHEKI FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-81', siteName: 'SHAHEEN TRUCKING F/S', region: 'Lahore'),
  SiteEntry(id: 'SITE-82', siteName: 'SHELL MARWAT', region: 'Lahore'),
  SiteEntry(id: 'SITE-83', siteName: 'MASHAALLAH F/S', region: 'Lahore'),
  SiteEntry(id: 'SITE-84', siteName: 'SPL- GOLF VIEW', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-85',
    siteName: 'DEFENCE SERVICE STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-86', siteName: 'SPL DEFENCE ROAD', region: 'Lahore'),
  SiteEntry(id: 'SITE-87', siteName: 'AL-ASAD GASOLINE', region: 'Lahore'),
  SiteEntry(
    id: 'SITE-88',
    siteName: 'SPL- FEROZPUR FILLING STATION',
    region: 'Lahore',
  ),
  SiteEntry(
    id: 'SITE-89',
    siteName: 'SPL IQBAL TOWN SERVICE STATION',
    region: 'Lahore',
  ),
  SiteEntry(id: 'SITE-90', siteName: 'CH MOHD SHARIF FS', region: 'Lahore'),
  // Multan region
  SiteEntry(id: 'SITE-12', siteName: 'BOSAN FILLING STATION', region: 'Multan'),
  SiteEntry(
    id: 'SITE-13',
    siteName: 'EID GAH FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-14',
    siteName: 'HP - NEW GATEWAY FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-15',
    siteName: 'HP - NEW MULTAN GASOLINE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-16',
    siteName: 'RAJANPUR FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-91', siteName: 'A HUSSAIN & SONS', region: 'Multan'),
  SiteEntry(
    id: 'SITE-92',
    siteName: 'AL ATTA FILLING SERVICE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-93',
    siteName: 'AL BURHAN PETROLEUM SERVICE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-94',
    siteName: 'AL HILAL PETROL SERVICE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-95',
    siteName: 'APNA TAJ 3 PETROLEUM SERVICE',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-96', siteName: 'APNA TRUCKING', region: 'Multan'),
  SiteEntry(
    id: 'SITE-97',
    siteName: 'BAHAWALPUR FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-98', siteName: 'BOSAN FILLING STATION', region: 'Multan'),
  SiteEntry(id: 'SITE-99', siteName: 'CITY FUELS MULTAN', region: 'Multan'),
  SiteEntry(
    id: 'SITE-100',
    siteName: 'DARYA KHAN FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-101',
    siteName: 'DERA OKARA FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-102', siteName: 'FRIENDS PETROLEUM', region: 'Multan'),
  SiteEntry(
    id: 'SITE-103',
    siteName: 'GOLRA FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-104',
    siteName: 'HAMRAHI FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-105',
    siteName: 'PREMIUM - HAMSAFAR FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-106',
    siteName: 'PREMIUM - HAROON FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-107',
    siteName:
        '(NDF) - INDUS HIGHWAY SHINWARI F/S DG KHAN, Kot Chutta Indus Highway DG Khan',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-108',
    siteName: 'KHANEWAL FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-109',
    siteName: 'KIRMANI PETROLEUM SERVICE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-110',
    siteName: 'LONDEN PETROLEUM SERVICE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-111',
    siteName: 'LUCKY AFGHAN FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-112',
    siteName: 'MADINA FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-113',
    siteName: 'MINHAJ FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-114',
    siteName: 'MODEL TOWN FILLING STATION MULTAN',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-115', siteName: 'MUKHTAR & COMPANY', region: 'Multan'),
  SiteEntry(
    id: 'SITE-116',
    siteName: 'PREMIUM - MULTAN PETROLEUM SERVICE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-117',
    siteName: 'MUSAFIR FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-118',
    siteName: 'NAYYAB PETROLEUM SERVICE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-119',
    siteName: 'NEW GATEWAY FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-120', siteName: 'NEW MULTAN GASOLINE', region: 'Multan'),
  SiteEntry(id: 'SITE-121', siteName: 'NIAZ KHAN NIAZI FS', region: 'Multan'),
  SiteEntry(
    id: 'SITE-122',
    siteName: 'OKARA SERVICE STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-123',
    siteName: 'PAK PATTAN FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-124', siteName: 'POLWEL D G KHAN', region: 'Multan'),
  SiteEntry(
    id: 'SITE-125',
    siteName: 'ROYAL FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-126',
    siteName: 'TARIQ BROS FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-127',
    siteName: 'PREMIUM - SHALIMAR FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-128',
    siteName: 'PREMIUM - SHARIF FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-129',
    siteName: 'SHELL AL MEHMOOD FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-130', siteName: 'SHELL CLASSIC 2 FS', region: 'Multan'),
  SiteEntry(
    id: 'SITE-131',
    siteName: 'SHELL CLASSIC FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-132',
    siteName: 'SHELL JAHANIA FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-133',
    siteName: 'ZAFAR BROTHERS MULTAN',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-134',
    siteName: 'SHELL SHUJABAD FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-135', siteName: 'SINDHU 1 PETROLEUM', region: 'Multan'),
  SiteEntry(
    id: 'SITE-136',
    siteName: 'SPENZER FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-137',
    siteName: 'SPL BHAWALPUR (RAZA PS) FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-138',
    siteName: 'SPL M3 VHR INTERCHANGE (RAHI FILLING STN) MULTAN',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-139',
    siteName: 'SPL MUMTAZABAD SERVICE STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-140',
    siteName: 'PREMIUM - SPL MUZAFFARGARH SERVICE STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-141',
    siteName: 'SPL QASIM PUR SERVICE STATION',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-142',
    siteName: 'SPL SHERSHAH (SHAHRAM) FILLING STATION',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-143', siteName: 'SUPER GAS', region: 'Multan'),
  SiteEntry(
    id: 'SITE-144',
    siteName: 'SUPER WAZIRISTAN TRADERS',
    region: 'Multan',
  ),
  SiteEntry(id: 'SITE-145', siteName: 'RAZI FILLING STATION', region: 'Multan'),
  SiteEntry(
    id: 'SITE-146',
    siteName: 'TIBBA PETROLEUM SERVICE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-147',
    siteName: 'UCH SHARIF PETROLEUM SERVICE',
    region: 'Multan',
  ),
  SiteEntry(
    id: 'SITE-148',
    siteName: 'SHELL NASEEM FILLING STATION',
    region: 'Multan',
  ),
  // Faisalabad region
  SiteEntry(
    id: 'SITE-17',
    siteName: 'BLUE SKY PETROLEUM SERVICE',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-18',
    siteName: 'RANA PETROLEUM SERVICE',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-19',
    siteName: 'SADIQ CHINIOT 2 FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-20',
    siteName: 'RAJANA FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-21',
    siteName: 'DODHA FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-149',
    siteName: 'GHANTA GHAR FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-150',
    siteName: 'AL GHAEES FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-151',
    siteName: 'BLUE SKY PETROLEUM SERVICE',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-152',
    siteName: 'CANAL FILLING STATION FSB',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-153',
    siteName: 'CITY PETROLEUM COMPANY',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-154',
    siteName: 'CRESCENT PETROLEUM SERVICE',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-155',
    siteName: 'DARUL-EHSAN FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-156',
    siteName: 'FAIZ PETROLEUM SERVICE',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-157',
    siteName: 'FIVE STAR FILLING STATION FBD',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-158',
    siteName: 'GULBERG FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-159',
    siteName: 'IDEAL FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-160',
    siteName: 'KHURRIANWALA FUEL STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-161',
    siteName: 'KHURRIANWALA TRUCK STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-162',
    siteName: 'KHUSHAB FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-163',
    siteName: 'MANTHAR PETROLEUM SERVICE',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-164',
    siteName: 'MILLAT PETROLEUM SERVICE',
    region: 'Faisalabad',
  ),
  SiteEntry(id: 'SITE-165', siteName: 'MODERN PETROLEUM', region: 'Faisalabad'),
  SiteEntry(
    id: 'SITE-166',
    siteName: 'POLWEL FAISALABAD',
    region: 'Faisalabad',
  ),
  SiteEntry(id: 'SITE-167', siteName: 'POLWEL SARGODHA', region: 'Faisalabad'),
  SiteEntry(
    id: 'SITE-168',
    siteName: 'SADIQ FILLING STATION CHINIOT',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-169',
    siteName: 'SAIF UL MALOOK FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-170',
    siteName: 'SALEEM FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-171',
    siteName: 'SHARIF PETROLEUM SERVICE',
    region: 'Faisalabad',
  ),
  SiteEntry(id: 'SITE-172', siteName: 'SHELL KOH E NOOR', region: 'Faisalabad'),
  SiteEntry(id: 'SITE-173', siteName: 'SPL Dground', region: 'Faisalabad'),
  SiteEntry(
    id: 'SITE-174',
    siteName: 'SPL SAMUNDARI ROAD FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-175',
    siteName: 'SYED MOHD YOUNIS SHAH',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-176',
    siteName: 'UNITED FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-177',
    siteName: 'AHMED NAGAR FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-178',
    siteName: 'SHELL CHAK JHUMRA FILLING STATION',
    region: 'Faisalabad',
  ),
  SiteEntry(
    id: 'SITE-179',
    siteName: 'ROYALTON FILLING STATION',
    region: 'Faisalabad',
  ),
];
final List<VendorBill> sampleVendorBills = [];

// Counter for custom work orders/projects created directly by users (not from email)
int _customWorkOrderCounter = 9001;
String _nextCustomWorkOrderId() => (_customWorkOrderCounter++).toString();

int _trailingNumber(String id) {
  final match = RegExp(r'(\d+)$').firstMatch(id);
  return match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
}

// All the *Counter variables above start from a hardcoded seed value and only live in this
// browser tab's memory - a page refresh used to reset them straight back to that seed no
// matter how many real records already existed in Firestore, so the very next thing created
// after a refresh could silently overwrite an existing site/notification/inventory
// item/transaction/quotation that happened to reuse the same now-repeated ID. This scans
// whatever's actually loaded and bumps each counter past the highest ID already in use -
// safe to call as often as needed since it only ever moves a counter up, never down.
void _resyncIdCounters() {
  final maxSite = sampleSites
      .map((s) => _trailingNumber(s.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxSite + 1 > _siteCounter) _siteCounter = maxSite + 1;

  final maxCustomWo = sampleWorkOrders
      .map((w) => int.tryParse(w.id))
      .whereType<int>()
      .where((n) => n >= 9001)
      .fold(9000, (a, b) => a > b ? a : b);
  if (maxCustomWo + 1 > _customWorkOrderCounter)
    _customWorkOrderCounter = maxCustomWo + 1;

  final maxQuotation = sampleWorkOrders
      .map((w) => w.quotation?.id)
      .whereType<String>()
      .map(_trailingNumber)
      .fold(1750, (a, b) => a > b ? a : b);
  if (maxQuotation + 1 > _quotationCounter)
    _quotationCounter = maxQuotation + 1;

  final maxNotif = sampleNotifications
      .map((n) => _trailingNumber(n.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxNotif + 1 > _notificationCounter) _notificationCounter = maxNotif + 1;

  final maxInvItem = sampleInventoryItems
      .map((i) => _trailingNumber(i.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxInvItem + 1 > _inventoryItemCounter)
    _inventoryItemCounter = maxInvItem + 1;

  final maxInvTxn = sampleInventoryTransactions
      .map((t) => _trailingNumber(t.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxInvTxn + 1 > _inventoryTxnCounter)
    _inventoryTxnCounter = maxInvTxn + 1;

  final maxBill = sampleVendorBills
      .map((b) => _trailingNumber(b.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxBill + 1 > _billCounter) _billCounter = maxBill + 1;

  final maxExpense = sampleExpenses
      .map((e) => _trailingNumber(e.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxExpense + 1 > _expenseCounter) _expenseCounter = maxExpense + 1;

  final maxClient = sampleClients
      .map((c) => _trailingNumber(c.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxClient + 1 > _clientCounter) _clientCounter = maxClient + 1;

  final maxToolAssignment = sampleToolAssignments
      .map((a) => _trailingNumber(a.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxToolAssignment + 1 > _toolAssignmentCounter)
    _toolAssignmentCounter = maxToolAssignment + 1;

  final maxLedger = sampleLedgerEntries
      .map((e) => _trailingNumber(e.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxLedger + 1 > _ledgerCounter) _ledgerCounter = maxLedger + 1;

  final maxJournalEntry = sampleJournalEntries
      .map((e) => _trailingNumber(e.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxJournalEntry + 1 > _journalEntryCounter)
    _journalEntryCounter = maxJournalEntry + 1;

  final maxCustomer = sampleCustomers
      .map((c) => _trailingNumber(c.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxCustomer + 1 > _customerCounter) _customerCounter = maxCustomer + 1;

  final maxReceipt = sampleCustomerReceipts
      .map((r) => _trailingNumber(r.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxReceipt + 1 > _receiptCounter) _receiptCounter = maxReceipt + 1;

  final maxInvoice = sampleInvoices
      .map((i) => _trailingNumber(i.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxInvoice + 1 > _invoiceCounter) _invoiceCounter = maxInvoice + 1;

  final maxSalaryHistory = sampleSalaryHistory
      .map((s) => _trailingNumber(s.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxSalaryHistory + 1 > _salaryHistoryCounter)
    _salaryHistoryCounter = maxSalaryHistory + 1;

  final maxHoliday = sampleHolidays
      .map((h) => _trailingNumber(h.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxHoliday + 1 > _holidayCounter) _holidayCounter = maxHoliday + 1;

  final maxPayrollAudit = samplePayrollAuditLog
      .map((a) => _trailingNumber(a.id))
      .fold(0, (a, b) => a > b ? a : b);
  if (maxPayrollAudit + 1 > _payrollAuditCounter)
    _payrollAuditCounter = maxPayrollAudit + 1;
}

// Live in-memory list of work orders, kept in sync with Firestore by the watchWorkOrders()
// subscription in _loadRealData(). Starts empty - real work orders come from Firestore only.
final List<WorkOrder> sampleWorkOrders = [];
