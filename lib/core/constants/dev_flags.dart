/// Central flags for local development.
///
/// IMPORTANT:
/// - Keep this file out of production toggles.
/// - These flags allow the app to run without Firebase during rebuild/testing.
///
/// Set to false once Firebase is fully working.
const bool DEV_DISABLE_FIREBASE = true;

/// Allow guest flow to bypass auth gates during UI development.
const bool DEV_AUTH_BYPASS = true;
