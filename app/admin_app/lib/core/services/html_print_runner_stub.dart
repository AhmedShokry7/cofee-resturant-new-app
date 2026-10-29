/// The desktop and mobile builds have no browser to open a print dialog with,
/// so every print action on those targets reports a failure and the UI shows
/// [browserPrintingAvailable] as the reason instead of a generic error.
const bool browserPrintingAvailable = false;

Future<bool> printHtmlDocument(String document) async => false;
