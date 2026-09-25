# Play Store Listing Draft — AES App

## App name
AES - Al Areesh Engineering Solutions

## Short description (max 80 characters)
Field service management for Al Areesh Engineering Solutions teams

## Full description (max 4000 characters)
AES is the internal operations app for Al Areesh Engineering Solutions field service and
facilities maintenance teams across Multan, Lahore, and Faisalabad.

Features:
- Work order management with automatic creation from client dispatch emails
- Quotation creation and sending with PDF/Excel/image export
- Vendor bill and employee expense submission with approval workflow
- Region-based Profit & Loss reporting
- Attendance tracking with GPS check-in/check-out
- Leave applications and approvals
- Inventory tracking with stock in/out ledger
- AI assistant for quick answers about work orders, quotations, and expenses

This app is intended for use by Al Areesh Engineering Solutions employees and approved
vendors only. Access requires an account created by an AES administrator - there is no
public sign-up.

## Privacy Policy URL
https://aes-app-testing.web.app/privacy-policy.html

## Category
Business

## Content rating questionnaire (guidance)
This is an internal business tool with no user-generated public content, violence, or
mature themes - answer "No" to all content questions (violence, sexual content, gambling,
etc.). Expect a rating of "Everyone".

## Data Safety form (guidance - what the app actually collects, from lib/services and
## lib/screens across the codebase)
- **Location**: collected (precise), only at attendance check-in/check-out. Not shared with
  third parties. Not used for advertising.
- **Photos**: collected (user-uploaded), for work order/expense/vendor bill receipts.
- **Personal info**: username (not email/phone - login is username-based internally,
  though Firebase Auth stores a synthetic internal email under the hood).
- **App activity**: work orders, quotations, expenses assigned/created by the user.
- Data is NOT sold. Data is NOT shared with third parties for advertising.
- Data IS transmitted to: Firebase (Google) for storage/auth, Groq (AI assistant queries),
  Google Gmail API (only for the company account, Back Office/Head of Ops/CEO roles).
- Users can request data deletion by contacting the developer (see privacy policy).

## Screenshots needed (min 2, recommend 4-8)
Suggested screens to capture (log in in a real browser window sized like a phone, or run
on an actual Android device, and screenshot):
1. Login screen
2. Dashboard (main screen after login)
3. Work Orders list
4. A Quotation or the new Regional Finance screen
5. Attendance screen
6. AI Assistant screen

## App icon
1024x1024 PNG required for the Play Console listing itself (separate from the in-app
launcher icon already generated) - a clean square crop/export of assets/images/logo.png at
high resolution works; ask me to generate this if you don't have a source file that large.
