# Rokter Badhon Ghatail — Localization

Rokter Badhon Ghatail  
Production Architecture v1.2.1  
Free V1 Implementation Profile  
Status: FROZEN FOR IMPLEMENTATION

## 1. Supported Languages

Default:

Bangla (bn)

Optional:

English (en)

---

## 2. Principle

UI text must use localization resources.

Avoid permanently hardcoding Bangla or English UI strings inside widgets, controllers, or services.

Services return stable error/result codes and interpolation parameters. The presentation layer translates them. Do not expose raw Firebase exceptions as user-facing text.

---

## 3. Flutter Localization Structure

Recommended:

lib/l10n/

app_bn.arb
app_en.arb

Configure supported locales, localization delegates, and runtime locale updates. Localize labels, validation, dialogs, date pickers, empty/error states, accessibility text, and formatted counts/dates. Bangla is the application default even when the device language differs.

---

## 4. Example

Database:

position = "president"

Bangla:

সভাপতি

English:

President

Database:

status = "pending"

Bangla:

অনুমোদনের অপেক্ষায়

English:

Pending

---

## 5. Controlled Database Values

The database stores stable language-neutral machine-readable keys (English identifiers), independent of the UI language.

Examples:

president
general_secretary
leader
executive
pending
approved
rejected
active
fulfilled

The database should not depend on UI language.

Role, position, status, gender, and other controlled choices separate stored keys from translated labels. UI-only filter sentinels also use stable keys, not words such as "সব".

users.access_role keys alone identify the current authorization role. Position translations are display-only and cannot affect permissions.

Do not blindly rewrite legacy Bangla place names. For controlled location choices, review the identifier mapping; preserve user-entered address content.

---

## 6. User-Generated Content

Do not automatically translate:

- person's name
- address
- notice body
- hospital name
- recipient name

These values remain exactly as users enter them.

---

## 7. Language Preference

Default language on first launch:

bn

Users may change language from Settings/Profile.

Preference should initially be stored locally using SharedPreferences.

Example:

language_code = "bn"

or

language_code = "en"

The app should change language without reinstalling.

---

## 8. Future Synchronization

If needed later, preferred language may also be stored in the User profile:

preferred_language = "bn"

This may allow language preference to follow the user across devices.

Synchronization remains optional for the initial production version. When an admitted User explicitly saves preferred_language through own-profile editing, only the private User stores it; user_directory does not include language preference.
---

## 9. Dates, Numbers, and Content Integrity

Firestore machine dates use Timestamp consistently. Formatting into Bangla or English occurs only for display. Do not persist localized date strings.

Missing/malformed required dates are validation failures, not DateTime.now(). Optional unknown dates stay null and use localized unknown-state labels.

Use locale-aware dates, numbers, and parameterized/pluralized messages. Organization calendar reports use the documented Asia/Dhaka boundaries regardless of the selected display language.

The full organization name is "রক্তের বাঁধন ঘাটাইল" / "Rokter Badhon Ghatail". Preserve user-generated content when switching language.

## 10. V1 Localization Acceptance

- First launch defaults to bn; en can be selected without reinstalling.
- Local preference persists across launches.
- Both languages cover labels, errors, status/role/position labels, dates, and dialogs.
- Language switching does not change stored controlled keys or authorization.
- Names, addresses, notice content, hospitals, and recipient names remain unchanged.
- No uncontrolled hardcoded UI text or raw backend exceptions remain in production flows.
- Profile language synchronization remains optional; local SharedPreferences are sufficient for V1.

## 11. Directory Presentation

Committee/member display resolves active user_directory records. Directory names and other user-entered safe fields are preserved when language changes. The directory contains no role or position authorization values; its labels/content never control permission. Missing/inactive directory entries use a localized unavailable label rather than a private User-profile fallback.

## 12. Events and Media Localization Keys

Store event_type keys below unchanged; translate only UI labels. Event titles/descriptions/locations, media captions and other user-generated content follow section 6 and are not automatically translated.

| Stable event_type | UI resource key | Bangla example | English example |
|---|---|---|---|
| meeting | eventTypeMeeting | সভা | Meeting |
| blood_donation_campaign | eventTypeBloodDonationCampaign | রক্তদান কর্মসূচি | Blood donation campaign |
| awareness_program | eventTypeAwarenessProgram | সচেতনতা কর্মসূচি | Awareness program |
| social_activity | eventTypeSocialActivity | সামাজিক কার্যক্রম | Social activity |
| celebration | eventTypeCelebration | উদ্‌যাপন | Celebration |
| emergency_activity | eventTypeEmergencyActivity | জরুরি কার্যক্রম | Emergency activity |
| other | eventTypeOther | অন্যান্য | Other |

| UI resource key | Bangla example | English example |
|---|---|---|
| mediaGallery | ছবির সংগ্রহ | Photo gallery |
| mediaCaption | ছবির বিবরণ | Caption |
| mediaHidden | লুকানো ছবি | Hidden image |
| eventDateRequired | অনুষ্ঠানের তারিখ দিন | Event date required |
| profilePhotoUnavailable | প্রোফাইল ছবি পাওয়া যায়নি | Profile photo unavailable |

These keys/labels, event types, external URLs and provider IDs never grant permission. Default bn and optional en remain unchanged.
