// web_backend/public/app.js
document.addEventListener('DOMContentLoaded', () => {
  const placesGrid = document.getElementById('placesGrid');
  const adModal = document.getElementById('adModal');
  const adProgressBar = document.getElementById('adProgressBar');
  const adCountdownText = document.getElementById('adCountdownText');
  const btnLaunchClient = document.getElementById('btnLaunchClient');

  // Load places from backend API
  loadPlaces();

  if (btnLaunchClient) {
    btnLaunchClient.addEventListener('click', () => {
      window.location.href = 'luani://join?server=127.0.0.1:7777';
    });
  }

  async function loadPlaces() {
    try {
      const response = await fetch('/api/places');
      const data = await response.json();
      
      if (data.success && Array.isArray(data.places)) {
        renderPlaces(data.places);
      } else {
        placesGrid.innerHTML = '<div class="error">Failed to load places catalog.</div>';
      }
    } catch (err) {
      console.error('Error fetching places:', err);
      placesGrid.innerHTML = '<div class="error">API connection error.</div>';
    }
  }

  function renderPlaces(places) {
    placesGrid.innerHTML = '';
    
    places.forEach(place => {
      const card = document.createElement('div');
      card.className = 'place-card';
      
      const icons = ['🎮', '🏎', '🏙', '⚔️', '🚀'];
      const icon = icons[Math.floor(Math.random() * icons.length)];
      
      card.innerHTML = `
        <div class="card-banner">${icon}</div>
        <div class="card-title">${escapeHtml(place.name)}</div>
        <div class="card-meta">By ${escapeHtml(place.creator || 'Luani Creator')} • Max Players: ${place.maxPlayers || 16}</div>
        <div class="card-desc">${escapeHtml(place.description || 'No description provided.')}</div>
        <button class="btn btn-primary btn-play" data-id="${place.id}">▶ Play Game</button>
      `;
      
      const playBtn = card.querySelector('.btn-play');
      playBtn.addEventListener('click', () => triggerPlayFlow(place.id));
      
      placesGrid.appendChild(card);
    });
  }

  function triggerPlayFlow(placeId) {
    // Open Ad Modal
    adModal.classList.remove('hidden');
    adProgressBar.style.width = '0%';
    
    let duration = 5; // 5 seconds ad simulation
    let elapsed = 0;
    
    const interval = setInterval(async () => {
      elapsed += 0.1;
      const progress = (elapsed / duration) * 100;
      adProgressBar.style.width = `${Math.min(progress, 100)}%`;
      
      const remaining = Math.ceil(duration - elapsed);
      adCountdownText.textContent = `Verification in progress (${remaining}s)...`;
      
      if (elapsed >= duration) {
        clearInterval(interval);
        adCountdownText.textContent = 'Ad verified! Requesting server spin-up...';
        
        await requestServerSpinUp(placeId);
      }
    }, 100);
  }

  async function requestServerSpinUp(placeId) {
    try {
      const response = await fetch('/api/servers/request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          placeId: placeId,
          userId: 'user_web_portal',
          adWatchToken: `ad_token_${Date.now()}`
        })
      });
      
      const data = await response.json();
      if (data.success && data.joinUri) {
        console.log('[Luani Web Portal] Triggering launch URI:', data.joinUri);
        
        adCountdownText.textContent = 'Launching native Luani client...';
        setTimeout(() => {
          adModal.classList.add('hidden');
          window.location.href = data.joinUri;
        }, 1000);
      } else {
        alert('Server spin-up failed: ' + (data.error || 'Unknown error'));
        adModal.classList.add('hidden');
      }
    } catch (err) {
      console.error('Error requesting server launch:', err);
      alert('Network error connecting to luani.fyi backend.');
      adModal.classList.add('hidden');
    }
  }

  function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, match => {
      const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
      return map[match];
    });
  }
});
