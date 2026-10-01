{{flutter_js}}
{{flutter_build_config}}

// Flutter's own loader, with two changes:
//  - CanvasKit comes from this server (tool/build_pwa.sh keeps it in canvaskit/), not from
//    www.gstatic.com - Flutter 3.22's --no-web-resources-cdn does not reach the loader's config;
//  - the service worker is campus_sw.js, not Flutter's (see there why). The version suffix is what
//    tells the loader a new build is out.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
    serviceWorkerUrl: new URL('campus_sw.js?v=' + {{flutter_service_worker_version}}, document.baseURI).href,
  },
});
