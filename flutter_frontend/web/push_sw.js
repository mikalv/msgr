// Web Push Service Worker for Msgr
// This runs in the background and handles push events even when the tab is closed.

self.addEventListener('push', function(event) {
  if (!event.data) return;

  let data;
  try {
    data = event.data.json();
  } catch (e) {
    data = { title: 'Msgr', body: event.data.text() };
  }

  const title = data.title || 'Msgr';
  const options = {
    body: data.body || '',
    icon: data.icon || '/icons/Icon-192.png',
    badge: data.badge || '/icons/Icon-192.png',
    tag: data.tag || 'msgr-notification',
    data: data.data || {},
    requireInteraction: false,
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// Handle notification click — focus or open the app
self.addEventListener('notificationclick', function(event) {
  event.notification.close();

  const data = event.notification.data || {};
  const teamSlug = data.team_slug;
  const channelId = data.channel_id;

  // Build URL to navigate to
  let url = '/';
  if (teamSlug && channelId) {
    url = '/?team=' + teamSlug + '&channel=' + channelId;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(windowClients) {
      // Focus existing tab if found
      for (var i = 0; i < windowClients.length; i++) {
        var client = windowClients[i];
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open new tab
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});
