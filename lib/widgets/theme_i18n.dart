part of '../main.dart';

class AESColors {
  static const Color primaryGreen = Color(0xFF1B7A3D);
  static const Color brightGreen = Color(0xFF2FA35A);
  static const Color darkGreen = Color(0xFF14562C);
  static const Color lightGreen = Color(0xFFE8F5EC);
  static const Color grey = Color(0xFF9A9A9A);
  static const Color darkGrey = Color(0xFF2A2A2A);
  static const Color lightGrey = Color(0xFFF4F4F5);
  static const Color background = Color(0xFFF7F8F9);
  static const Color nearBlack = Color(0xFF0F1210);
}

// ---------------- LANGUAGE SYSTEM ----------------
enum AppLanguage { english, urdu }

// Global language state - any widget can listen to this to rebuild when language changes
final ValueNotifier<AppLanguage> appLanguage = ValueNotifier(AppLanguage.english);

// Translation dictionary: English text -> Urdu text.
// tr() looks up the current language and returns the right string.
const Map<String, String> _urduTranslations = {
  // Sidebar & navigation
  'Dashboard': 'ڈیش بورڈ',
  'Work Orders': 'ورک آرڈرز',
  'Quotations': 'کوٹیشنز',
  'Reports': 'رپورٹس',
  'Add Employee': 'ملازم شامل کریں',
  'Expenses': 'اخراجات',
  'Language': 'زبان',
  'Logout': 'لاگ آؤٹ',
  // Dashboard
  'Overview of all regional work orders': 'تمام علاقوں کے ورک آرڈرز کا جائزہ',
  'Modules': 'ماڈیولز',
  'Track and manage all work orders': 'تمام ورک آرڈرز کو ٹریک اور منظم کریں',
  'Full work order sheet, exportable to Excel': 'مکمل ورک آرڈر شیٹ، ایکسل میں محفوظ کی جا سکتی ہے',
  'Switch app language': 'ایپ کی زبان تبدیل کریں',
  'English / Urdu': 'انگریزی / اردو',
  // Login
  'Username': 'یوزر نیم',
  'Password': 'پاس ورڈ',
  'LOGIN': 'لاگ ان',
  'Forgot Password': 'پاس ورڈ بھول گئے؟',
  'Invalid username or password': 'غلط یوزر نیم یا پاس ورڈ',
  // Common actions
  'Save': 'محفوظ کریں',
  'Cancel': 'منسوخ کریں',
  'Create Account': 'اکاؤنٹ بنائیں',
  'Search work orders, employees...': 'ورک آرڈرز، ملازمین تلاش کریں...',
  'All Regions': 'تمام علاقے',
  // Work order statuses
  'Pending': 'زیر التوا',
  'Quotation Ready': 'کوٹیشن تیار',
  'Back Office Review': 'بیک آفس جائزہ',
  'Manager Approval': 'مینیجر کی منظوری',
  'Approved': 'منظور شدہ',
  'Completed': 'مکمل',
  'Rejected': 'مسترد',
  // Remaining sidebar nav items (labels already run through tr() at the call site - these
  // were simply missing from the dictionary, so Urdu mode silently fell back to English).
  'Invoices': 'انوائسز',
  'Multan Finance': 'ملتان فنانس',
  'Faisalabad Finance': 'فیصل آباد فنانس',
  'Company P&L': 'کمپنی منافع و نقصان',
  'My Bills': 'میرے بل',
  'Vendor Bills': 'وینڈر بلز',
  'My Expenses': 'میرے اخراجات',
  'Expense Approvals': 'اخراجات کی منظوری',
  'Attendance': 'حاضری',
  'Leave': 'چھٹی',
  'Manage Sites': 'سائٹس کا انتظام',
  'Manage Clients': 'کلائنٹس کا انتظام',
  'Inventory': 'انوینٹری',
  'Gmail Sync': 'جی میل سنک',
  'AI Assistant': 'AI اسسٹنٹ',
  // Common actions / buttons
  'Delete': 'حذف کریں',
  'Edit': 'ترمیم کریں',
  'Confirm': 'تصدیق کریں',
  'Submit': 'جمع کروائیں',
  'Approve': 'منظور کریں',
  'Reject': 'مسترد کریں',
  'Reject & Send Back': 'مسترد کریں اور واپس بھیجیں',
  'Send Back': 'واپس بھیجیں',
  'Export': 'ایکسپورٹ',
  'Export Report': 'رپورٹ ایکسپورٹ کریں',
  'Export as': 'بطور ایکسپورٹ کریں',
  'Select All': 'سب منتخب کریں',
  'Skip': 'چھوڑیں',
  'Disconnect': 'منقطع کریں',
  'Connect with Google': 'گوگل سے منسلک کریں',
  'History': 'ہسٹری',
  'Status': 'حیثیت',
  'Status: All': 'حیثیت: تمام',
  'Type': 'قسم',
  'Date': 'تاریخ',
  'Month': 'مہینہ',
  'By Month': 'مہینے کے لحاظ سے',
  'Region': 'علاقہ',
  'Priority': 'ترجیح',
  'Note': 'نوٹ',
  'Remarks': 'تبصرے',
  'Reported': 'رپورٹ شدہ',
  'Started': 'شروع ہو گیا',
  'Late': 'تاخیر',
  'Not checked in yet': 'ابھی تک چیک ان نہیں کیا',
  'Check-In': 'چیک ان',
  'Check-Out': 'چیک آؤٹ',
  'Office hours: 9:30 AM - 6:00 PM': 'دفتری اوقات: 9:30 صبح - 6:00 شام',
  'Team Attendance': 'ٹیم کی حاضری',
  'My Attendance': 'میری حاضری',
  'My Leave': 'میری چھٹی',
  'Apply for Leave': 'چھٹی کے لیے درخواست دیں',
  'Leave Applications': 'چھٹی کی درخواستیں',
  'Leave approved': 'چھٹی منظور ہو گئی',
  'Leave rejected': 'چھٹی مسترد ہو گئی',
  'Reason for rejection': 'مسترد کرنے کی وجہ',
  'Reason for sending back': 'واپس بھیجنے کی وجہ',
  'Sent back to Back Office with a note': 'نوٹ کے ساتھ بیک آفس کو واپس بھیجا گیا',
  'Sent back to employee': 'ملازم کو واپس بھیجا گیا',
  'Sent back to employee with a note': 'نوٹ کے ساتھ ملازم کو واپس بھیجا گیا',
  'Sent to Operational Manager for approval': 'منظوری کے لیے آپریشنل مینیجر کو بھیجا گیا',
  'Expense approved': 'خرچہ منظور ہو گیا',
  'Work order approved': 'ورک آرڈر منظور ہو گیا',
  // Work orders
  'Add Work Order': 'ورک آرڈر شامل کریں',
  'Add Work Order Manually': 'ورک آرڈر دستی طور پر شامل کریں',
  'Create Work Order': 'ورک آرڈر بنائیں',
  'Work Order': 'ورک آرڈر',
  'Existing Work Orders': 'موجودہ ورک آرڈرز',
  'No existing work orders to quote': 'کوٹ کرنے کے لیے کوئی موجودہ ورک آرڈر نہیں',
  'No work orders yet': 'ابھی تک کوئی ورک آرڈر نہیں',
  'No work orders match these filters': 'ان فلٹرز سے کوئی ورک آرڈر مماثل نہیں',
  'No matching work orders': 'کوئی مماثل ورک آرڈر نہیں',
  'Work Orders by Region': 'علاقے کے لحاظ سے ورک آرڈرز',
  'Work Orders by Status': 'حیثیت کے لحاظ سے ورک آرڈرز',
  'Work Type': 'کام کی قسم',
  'Delete Work Order?': 'ورک آرڈر حذف کریں؟',
  'Target Finish': 'ہدف کی تکمیل',
  'Assign Vendor': 'وینڈر مقرر کریں',
  'Assign Worker': 'ملازم مقرر کریں',
  'Assigned Vendor': 'مقرر شدہ وینڈر',
  'Assigned Worker': 'مقرر شدہ ملازم',
  'Mark as Completed': 'مکمل شدہ نشان زد کریں',
  'Confirm Completion': 'تکمیل کی تصدیق کریں',
  'Start Job (log arrival time)': 'کام شروع کریں (آمد کا وقت درج کریں)',
  'End Job (log finish time)': 'کام ختم کریں (اختتامی وقت درج کریں)',
  'Job Timing': 'کام کا وقت',
  'Job Completion Time': 'کام مکمل ہونے کا وقت',
  'Time on Job': 'کام پر وقت',
  'Overtime': 'اوور ٹائم',
  'Site Details': 'سائٹ کی تفصیلات',
  'Site Details from Worker': 'ملازم کی جانب سے سائٹ کی تفصیلات',
  'Site Name': 'سائٹ کا نام',
  'Save Site Details': 'سائٹ کی تفصیلات محفوظ کریں',
  'Please describe what you found on site': 'براہ کرم بتائیں کہ آپ کو سائٹ پر کیا ملا',
  'Please add at least one after-completion photo': 'کم از کم ایک تکمیل کے بعد کی تصویر شامل کریں',
  'Add Photo': 'تصویر شامل کریں',
  'Take Photo': 'تصویر لیں',
  'Choose from Gallery': 'گیلری سے منتخب کریں',
  'Receipt Photos': 'رسید کی تصاویر',
  'Location permission is required to check in/out': 'چیک ان/آؤٹ کے لیے لوکیشن کی اجازت درکار ہے',
  'Please enable location services to check in/out': 'چیک ان/آؤٹ کے لیے براہ کرم لوکیشن سروسز آن کریں',
  'Recently Auto-Created': 'حال ہی میں خودکار طور پر بنائے گئے',
  'Recently Updated': 'حال ہی میں اپ ڈیٹ شدہ',
  // Quotations
  'New Quotation': 'نئی کوٹیشن',
  'Create My Own Project': 'اپنا پراجیکٹ بنائیں',
  'Create your own project, or pick from an existing work order': 'اپنا پراجیکٹ بنائیں، یا موجودہ ورک آرڈر میں سے منتخب کریں',
  'Continue to Quotation': 'کوٹیشن کی طرف جائیں',
  'Delete Quotation': 'کوٹیشن حذف کریں',
  'Delete this quotation and revert the work order back to pending? This cannot be undone.':
      'یہ کوٹیشن حذف کریں اور ورک آرڈر کو دوبارہ زیر التوا کر دیں؟ اسے واپس نہیں کیا جا سکتا۔',
  'Client Information': 'کلائنٹ کی معلومات',
  'Vendor Details': 'وینڈر کی تفصیلات',
  'Description of Work Order': 'ورک آرڈر کی تفصیل',
  'Description of Work Order:': 'ورک آرڈر کی تفصیل:',
  'Description': 'تفصیل',
  'Line Items': 'لائن آئٹمز',
  'Add Row': 'قطار شامل کریں',
  'Item': 'آئٹم',
  'Items': 'اشیاء',
  'Units': 'یونٹس',
  'Rate': 'قیمت',
  'Sub Total': 'سب ٹوٹل',
  'Quote Total': 'کوٹ ٹوٹل',
  'Quote Total: ': 'کوٹ ٹوٹل: ',
  'Notes / Terms': 'نوٹس / شرائط',
  'Notes / Terms:': 'نوٹس / شرائط:',
  'Non CMEP': 'غیر CMEP',
  'Internal Only (not shown on the quotation)': 'صرف اندرونی (کوٹیشن پر ظاہر نہیں ہوگا)',
  'Internal Only (not shown to client)': 'صرف اندرونی (کلائنٹ کو نہیں دکھایا جائے گا)',
  'Total Internal Cost': 'کل اندرونی لاگت',
  'Profit': 'منافع',
  'Profit Margin': 'منافع کا مارجن',
  'Revenue': 'آمدنی',
  'Tap a cell to edit, just like a spreadsheet': 'ترمیم کے لیے سیل پر ٹیپ کریں، بالکل اسپریڈ شیٹ کی طرح',
  'Enter the client name before submitting': 'جمع کروانے سے پہلے کلائنٹ کا نام درج کریں',
  'Add at least one item with a description': 'کم از کم ایک تفصیل والی چیز شامل کریں',
  'Add at least one line item before submitting': 'جمع کروانے سے پہلے کم از کم ایک لائن آئٹم شامل کریں',
  'At least one line item needs a rate greater than 0': 'کم از کم ایک لائن آئٹم کی قیمت صفر سے زیادہ ہونی چاہیے',
  'Attach as': 'بطور منسلک کریں',
  'Excel (.xlsx)': 'ایکسل (.xlsx)',
  'Image (PNG)': 'تصویر (PNG)',
  'Send Email': 'ای میل بھیجیں',
  'Send Quotation via Email': 'کوٹیشن ای میل کے ذریعے بھیجیں',
  'Sending email...': 'ای میل بھیجا جا رہا ہے...',
  'Share Quotation on WhatsApp': 'واٹس ایپ پر کوٹیشن شیئر کریں',
  'Connect Gmail first (Gmail Sync in the sidebar) before sending quotation emails.':
      'کوٹیشن ای میل بھیجنے سے پہلے پہلے جی میل کنیکٹ کریں (سائیڈبار میں جی میل سنک)۔',
  'No quotations for this region yet': 'اس علاقے کے لیے ابھی تک کوئی کوٹیشن نہیں',
  'No sent quotations to invoice yet - send a quotation via email first.':
      'انوائس کے لیے ابھی تک کوئی بھیجی گئی کوٹیشن نہیں - پہلے ایک کوٹیشن ای میل کے ذریعے بھیجیں۔',
  // Invoices
  'Generate Invoice': 'انوائس بنائیں',
  'No invoices generated yet': 'ابھی تک کوئی انوائس نہیں بنائی گئی',
  'Quotations to include': 'شامل کرنے کے لیے کوٹیشنز',
  'Select at least one quotation to include': 'شامل کرنے کے لیے کم از کم ایک کوٹیشن منتخب کریں',
  'No invoices, vendor bills, or approved expenses recorded for this region yet':
      'اس علاقے کے لیے ابھی تک کوئی انوائس، وینڈر بل، یا منظور شدہ اخراجات درج نہیں',
  // Expenses / bills
  'Submit Expense': 'خرچہ جمع کروائیں',
  'Delete Expense': 'خرچہ حذف کریں',
  'No expenses for this region yet': 'اس علاقے کے لیے ابھی تک کوئی اخراجات نہیں',
  'You need an assigned work order before you can submit an expense': 'خرچہ جمع کروانے سے پہلے آپ کو ایک مقرر شدہ ورک آرڈر درکار ہے',
  'You need an assigned work order before you can submit a bill': 'بل جمع کروانے سے پہلے آپ کو ایک مقرر شدہ ورک آرڈر درکار ہے',
  'Add Bill': 'بل شامل کریں',
  'Delete Bill': 'بل حذف کریں',
  'No bills submitted yet': 'ابھی تک کوئی بل جمع نہیں کروایا گیا',
  'Amount': 'رقم',
  // Inventory
  'Add Inventory Item': 'انوینٹری آئٹم شامل کریں',
  'Edit Inventory Item': 'انوینٹری آئٹم میں ترمیم کریں',
  'Delete Item': 'آئٹم حذف کریں',
  'Add Item': 'آئٹم شامل کریں',
  'No inventory items yet': 'ابھی تک کوئی انوینٹری آئٹم نہیں',
  'No stock movements recorded yet': 'ابھی تک اسٹاک کی کوئی نقل و حرکت درج نہیں',
  'Not enough stock for that quantity': 'اس مقدار کے لیے کافی اسٹاک نہیں',
  'None - general stock': 'کوئی نہیں - عام اسٹاک',
  'Choose Multiple (tens or hundreds)': 'متعدد منتخب کریں (درجنوں یا سینکڑوں)',
  // Sites / clients
  'Add Site': 'سائٹ شامل کریں',
  'Delete Site': 'سائٹ حذف کریں',
  'No sites added yet': 'ابھی تک کوئی سائٹ شامل نہیں کی گئی',
  'Add Client': 'کلائنٹ شامل کریں',
  'Delete Client': 'کلائنٹ حذف کریں',
  // Employees / accounts
  'Create a new login account for a team member': 'ٹیم ممبر کے لیے نیا لاگ ان اکاؤنٹ بنائیں',
  'No employee accounts yet': 'ابھی تک کوئی ملازم اکاؤنٹ نہیں',
  'Manage Access': 'رسائی کا انتظام کریں',
  'Turn access on or off for existing team members': 'موجودہ ٹیم ممبران کے لیے رسائی آن یا آف کریں',
  'Change username / password (optional)': 'یوزر نیم / پاس ورڈ تبدیل کریں (اختیاری)',
  'Leave both blank to keep the current login as-is.': 'موجودہ لاگ ان برقرار رکھنے کے لیے دونوں خالی چھوڑ دیں۔',
  'Delete this account?': 'یہ اکاؤنٹ حذف کریں؟',
  'Delete Leave Application': 'چھٹی کی درخواست حذف کریں',
  'Employee': 'ملازم',
  // Dates / misc
  'End date cannot be before start date': 'اختتامی تاریخ شروع کی تاریخ سے پہلے نہیں ہو سکتی',
  'Select both a start and end date': 'شروع اور اختتامی دونوں تاریخیں منتخب کریں',
  'Notifications': 'اطلاعات',
  'No notifications yet': 'ابھی تک کوئی اطلاع نہیں',
  'No past chats yet': 'ابھی تک کوئی پرانی چیٹ نہیں',
  'New Chat': 'نئی چیٹ',
  'AI Assistant not set up yet': 'AI اسسٹنٹ ابھی سیٹ اپ نہیں ہوا',
  'Nothing to show yet': 'ابھی دکھانے کے لیے کچھ نہیں',
  'No leave applications to show': 'دکھانے کے لیے کوئی چھٹی کی درخواست نہیں',
  'No leave applications yet': 'ابھی تک کوئی چھٹی کی درخواست نہیں',
  'No attendance records yet': 'ابھی تک حاضری کا کوئی ریکارڈ نہیں',
  'Loading your data...': 'آپ کا ڈیٹا لوڈ ہو رہا ہے...',
  'Calculator': 'کیلکولیٹر',
  '+ Add new item': '+ نئی چیز شامل کریں',
  '1 - High': '1 - اعلی',
  '2 - Medium': '2 - درمیانہ',
  '3 - Low': '3 - کم',
};

String tr(String englishText) {
  if (appLanguage.value == AppLanguage.english) return englishText;
  return _urduTranslations[englishText] ?? englishText;
}

class AlAreshApp extends StatelessWidget {
  const AlAreshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: appLanguage,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'AES - Al Areesh Engineering Solutions',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AESColors.primaryGreen,
              primary: AESColors.primaryGreen,
            ),
            scaffoldBackgroundColor: AESColors.background,
            fontFamily: 'Roboto',
            pageTransitionsTheme: premiumPageTransitionsTheme,
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}

