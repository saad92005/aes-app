import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
// Ties Flutter's own Navigator to the browser's real History API on web - without this, the
// browser's back button never maps to Navigator.pop() at all, so pressing it just falls
// through to whatever page was in the browser tab's history before this app loaded (e.g. a
// search results page), no matter how many screens deep the user actually is in the app. A
// no-op on non-web platforms, so this is safe to call unconditionally.
import 'package:flutter_web_plugins/url_strategy.dart';
// Prefixed - package:pdf/widgets.dart and package:excel/excel.dart both define their own
// Container/Text/Column/Row/Padding classes for layout, which would otherwise collide with
// every Flutter Material widget of the same name used throughout this file.
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pw;
import 'package:excel/excel.dart' as xls;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:file_selector/file_selector.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

part 'widgets/theme_i18n.dart';
part 'widgets/animations.dart';
part 'widgets/search_field.dart';
part 'widgets/full_screen_image_viewer.dart';
part 'widgets/line_item_editor.dart';
part 'services/photo_repo.dart';
part 'services/export_service.dart';
part 'models/user.dart';
part 'services/auth_service.dart';
part 'services/biometric_service.dart';
part 'services/local_notification_service.dart';
part 'services/data_service.dart';
part 'services/gmail_service.dart';
part 'models/permissions.dart';
part 'models/work_order.dart';
part 'models/vendor_bill.dart';
part 'models/expense.dart';
part 'models/attendance.dart';
part 'models/inventory.dart';
part 'models/tool_assignment.dart';
part 'models/ledger.dart';
part 'models/notification.dart';
part 'models/site.dart';
part 'models/client.dart';
part 'models/invoice.dart';
part 'models/leave.dart';
part 'models/account.dart';
part 'models/journal_entry.dart';
part 'models/customer.dart';
part 'models/customer_receipt.dart';
part 'models/payroll.dart';
part 'models/payroll_period.dart';
part 'models/payroll_extras.dart';
part 'services/payroll_engine.dart';
part 'widgets/starfield_background.dart';
part 'screens/login_screen.dart';
part 'screens/dashboard_screen.dart';
part 'screens/work_orders_screen.dart';
part 'screens/work_order_detail_screen.dart';
part 'screens/quotation_form_screen.dart';
part 'widgets/calculator_dialog.dart';
part 'screens/site_details_screen.dart';
part 'screens/completion_photos_screen.dart';
part 'services/quotation_sharing.dart';
part 'widgets/photo_widgets.dart';
part 'screens/language_screen.dart';
part 'screens/vendor_bills_screens.dart';
part 'services/attendance_helpers.dart';
part 'screens/my_attendance_screen.dart';
part 'screens/attendance_report_screen.dart';
part 'screens/my_expenses_screen.dart';
part 'screens/expenses_approval_screen.dart';
part 'screens/ai_assistant_screen.dart';
part 'screens/inventory_screen.dart';
part 'screens/gmail_sync_screen.dart';
part 'screens/manage_sites_screen.dart';
part 'screens/manage_clients_screen.dart';
part 'screens/add_employee_screen.dart';
part 'screens/reports_screen.dart';
part 'screens/regional_pnl_screen.dart';
part 'screens/regional_finance_screen.dart';
part 'screens/invoices_screen.dart';
part 'screens/leave_screen.dart';
part 'screens/ledger_screen.dart';
part 'screens/quotations_list_screen.dart';
part 'screens/chart_of_accounts_screen.dart';
part 'screens/account_detail_screen.dart';
part 'screens/journal_entries_screen.dart';
part 'screens/accounting_reports_screen.dart';
part 'screens/customers_screen.dart';
part 'screens/customer_receipt_screen.dart';
part 'screens/finance_dashboard_screen.dart';
part 'screens/payroll_settings_screen.dart';
part 'screens/employee_payroll_screen.dart';
part 'screens/process_payroll_screen.dart';
part 'screens/payroll_history_screen.dart';
part 'screens/payslips_screen.dart';
part 'screens/payroll_audit_log_screen.dart';
part 'screens/payroll_dashboard_screen.dart';
part 'screens/payroll_reports_screen.dart';

// AI Assistant backend. Calls the Groq API directly from the app (no backend/n8n) since
// this project stays off Firebase's paid Blaze plan, which Cloud Functions would require.
// Left empty, the Assistant screen shows a setup notice instead of trying to call it.
//
// Note: the key provided (prefix "gsk_") is a GroqCloud key, not an xAI/Grok key (those use
// a different prefix and endpoint) - wired up against Groq's actual OpenAI-compatible API
// accordingly so it authenticates correctly.
//
// SECURITY NOTE: because this is a client-side web app with no server to hide it behind,
// this key ends up visible in the compiled JS bundle to anyone who opens DevTools - there is
// no way around that without adding a paid backend. Only use a key you're comfortable being
// exposed this way (e.g. restricted to a low quota on Groq's side).
const String groqApiKey = '';
const String groqModel = 'llama-3.3-70b-versatile';
// Used only for messages that include an attached image - a plain text model can't accept
// an image_url content part at all, so image analysis needs a vision-capable model instead.
const String groqVisionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AlAreshApp());
}
