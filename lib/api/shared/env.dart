String trimTrailingSlashes(String v) =>
    v.trim().replaceAll(RegExp(r'/+\$'), '');
