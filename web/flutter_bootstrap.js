{{flutter_js}}
{{flutter_build_config}}

// The embedded customer preview can run in browser contexts where WebGL is
// unavailable or repeatedly loses its context. Keep the normal customer web
// app hardware-accelerated, and use CanvasKit's CPU path only for the iframe.
const isCustomerPreview =
  new URLSearchParams(window.location.search).get('mode') === 'preview';

_flutter.loader.load({
  config: isCustomerPreview
    ? {
        renderer: 'canvaskit',
        canvasKitForceCpuOnly: true,
      }
    : {},
});
