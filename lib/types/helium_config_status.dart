enum HeliumConfigStatus {
  notYetDownloaded,
  downloading,
  downloadFailure,
  downloadSuccess;

  static HeliumConfigStatus? create(String statusString) {
    switch (statusString) {
      case "downloadFailure":
        return downloadFailure;
      case "downloadSuccess":
        return downloadSuccess;
      case "inProgress":
        return downloading;
      case "notDownloadedYet":
        return notYetDownloaded;
    }
    return null;
  }
}
