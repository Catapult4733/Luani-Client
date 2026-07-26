// web_backend/public/app.js
document.addEventListener('DOMContentLoaded', () => {
  const placesGrid = document.getElementById('placesGrid');
  const adModal = document.getElementById('adModal');
  const adProgressBar = document.getElementById('adProgressBar');
  const adCountdownText = document.getElementById('adCountdownText');
  const btnLaunchClient = document.getElementById('btnLaunchClient');

  // Auth elements
  const authModal = document.getElementById('authModal');
  const authModalTitle = document.getElementById('authModalTitle');
  const authModalClose = document.getElementById('authModalClose');
  const authForm = document.getElementById('authForm');
  const authUsername = document.getElementById('authUsername');
  const authPassword = document.getElementById('authPassword');
  const authErrorMsg = document.getElementById('authErrorMsg');
  const authSubmitBtn = document.getElementById('authSubmitBtn');
  const authSwitchLink = document.getElementById('authSwitchLink');
  const authSwitchText = document.getElementById('authSwitchText');

  const btnLoginOpen = document.getElementById('btnLoginOpen');
  const btnRegisterOpen = document.getElementById('btnRegisterOpen');
  const btnLogout = document.getElementById('btnLogout');
  const loggedOutView = document.getElementById('loggedOutView');
  const loggedInView = document.getElementById('loggedInView');
  const userNameLabel = document.getElementById('userNameLabel');
  const userAvatar = document.getElementById('userAvatar');

  // Search & Friends elements
  const searchInput = document.getElementById('searchInput');
  const searchResultsSection = document.getElementById('searchResultsSection');
  const searchQueryText = document.getElementById('searchQueryText');
  const searchPlacesGrid = document.getElementById('searchPlacesGrid');
  const searchUsersGrid = document.getElementById('searchUsersGrid');
  const friendsList = document.getElementById('friendsList');

  let isRegisterMode = false;
  let currentUser = null;

  // Initialize
  checkAuth();
  loadPlaces();
  loadFriends();

  if (btnLaunchClient) {
    btnLaunchClient.addEventListener('click', () => {
      window.location.href = 'luani://join?server=127.0.0.1:7777';
    });
  }

  // --- AUTH SYSTEM ---

  function checkAuth() {
    const token = localStorage.getItem('luani_auth_token');
    if (token) {
      fetch('/api/auth/me', {
        headers: { 'Authorization': `Bearer ${token}` }
      })
      .then(res => res.json())
      .then(data => {
        if (data.success && data.user) {
          setLoggedInUser(data.user);
        } else {
          clearAuth();
        }
      })
      .catch(() => clearAuth());
    } else {
      clearAuth();
    }
  }

  function setLoggedInUser(user) {
    currentUser = user;
    userNameLabel.textContent = user.username;
    userAvatar.textContent = user.username.charAt(0).toUpperCase();
    loggedOutView.classList.add('hidden');
    loggedInView.classList.remove('hidden');
  }

  function clearAuth() {
    currentUser = null;
    localStorage.removeItem('luani_auth_token');
    loggedOutView.classList.remove('hidden');
    loggedInView.classList.add('hidden');
  }

  btnLoginOpen.addEventListener('click', () => openAuthModal(false));
  btnRegisterOpen.addEventListener('click', () => openAuthModal(true));
  authModalClose.addEventListener('click', () => authModal.classList.add('hidden'));
  btnLogout.addEventListener('click', () => clearAuth());

  authSwitchLink.addEventListener('click', (e) => {
    e.preventDefault();
    openAuthModal(!isRegisterMode);
  });

  function openAuthModal(registerMode) {
    isRegisterMode = registerMode;
    authErrorMsg.classList.add('hidden');
    authUsername.value = '';
    authPassword.value = '';

    if (isRegisterMode) {
      authModalTitle.textContent = 'Sign Up for Luani';
      authSubmitBtn.textContent = 'Create Account';
      authSwitchText.textContent = 'Already have an account?';
      authSwitchLink.textContent = 'Log In';
    } else {
      authModalTitle.textContent = 'Log In to Luani';
      authSubmitBtn.textContent = 'Log In';
      authSwitchText.textContent = "Don't have an account?";
      authSwitchLink.textContent = 'Sign Up';
    }
    authModal.classList.remove('hidden');
  }

  authForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    authErrorMsg.classList.add('hidden');

    const username = authUsername.value.trim();
    const password = authPassword.value;
    const endpoint = isRegisterMode ? '/api/auth/register' : '/api/auth/login';

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
      });
      const data = await response.json();

      if (data.success) {
        localStorage.setItem('luani_auth_token', data.token);
        setLoggedInUser(data.user);
        authModal.classList.add('hidden');
      } else {
        authErrorMsg.textContent = data.error || 'Authentication failed.';
        authErrorMsg.classList.remove('hidden');
      }
    } catch (err) {
      authErrorMsg.textContent = 'Network error.';
      authErrorMsg.classList.remove('hidden');
    }
  });

  // --- FRIENDS BAR ---

  async function loadFriends() {
    try {
      const response = await fetch('/api/friends');
      const data = await response.json();

      if (data.success && Array.isArray(data.friends)) {
        renderFriends(data.friends);
      }
    } catch (err) {
      console.error('Error fetching friends:', err);
    }
  }

  function renderFriends(friends) {
    friendsList.innerHTML = '';
    friends.forEach(f => {
      const item = document.createElement('div');
      item.className = 'friend-item';
      
      const isOnline = f.status === 'ONLINE';
      const statusClass = isOnline ? 'online' : 'offline';
      
      item.innerHTML = `
        <span class="status-dot ${statusClass}"></span>
        <span><strong>${escapeHtml(f.username)}</strong></span>
        ${isOnline && f.serverIp ? `<button class="btn-join-friend" data-ip="${f.serverIp}" data-port="${f.serverPort}">Join Game</button>` : `<span style="color:var(--text-muted); font-size:0.75rem;">${f.status}</span>`}
      `;

      const joinBtn = item.querySelector('.btn-join-friend');
      if (joinBtn) {
        joinBtn.addEventListener('click', () => {
          const ip = joinBtn.getAttribute('data-ip');
          const port = joinBtn.getAttribute('data-port');
          window.location.href = `luani://join?server=${ip}:${port}`;
        });
      }

      friendsList.appendChild(item);
    });
  }

  // --- GLOBAL SEARCH SYSTEM ---

  let searchTimeout = null;
  searchInput.addEventListener('input', () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      const query = searchInput.value.trim();
      if (query.length >= 2) {
        performSearch(query);
      } else {
        searchResultsSection.classList.add('hidden');
      }
    }, 250);
  });

  async function performSearch(query) {
    try {
      const response = await fetch(`/api/search?q=${encodeURIComponent(query)}`);
      const data = await response.json();

      if (data.success) {
        searchQueryText.textContent = query;
        renderSearchResults(data.places || [], data.users || []);
        searchResultsSection.classList.remove('hidden');
      }
    } catch (err) {
      console.error('Search error:', err);
    }
  }

  function renderSearchResults(matchedPlaces, matchedUsers) {
    searchPlacesGrid.innerHTML = '';
    searchUsersGrid.innerHTML = '';

    if (matchedPlaces.length === 0) {
      searchPlacesGrid.innerHTML = '<div style="color:var(--text-muted);">No matching places found.</div>';
    } else {
      matchedPlaces.forEach(place => {
        const card = createPlaceCardElement(place);
        searchPlacesGrid.appendChild(card);
      });
    }

    if (matchedUsers.length === 0) {
      searchUsersGrid.innerHTML = '<div style="color:var(--text-muted);">No matching users found.</div>';
    } else {
      matchedUsers.forEach(user => {
        const uCard = document.createElement('div');
        uCard.className = 'user-card';
        uCard.innerHTML = `
          <div class="avatar-circle">${user.username.charAt(0).toUpperCase()}</div>
          <div><strong>${escapeHtml(user.username)}</strong></div>
        `;
        searchUsersGrid.appendChild(uCard);
      });
    }
  }

  // --- PLACES DISCOVERY CATALOG ---

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
      const card = createPlaceCardElement(place);
      placesGrid.appendChild(card);
    });
  }

  function createPlaceCardElement(place) {
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
    return card;
  }

  function triggerPlayFlow(placeId) {
    adModal.classList.remove('hidden');
    adProgressBar.style.width = '0%';
    
    let duration = 5;
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
          userId: currentUser ? currentUser.id : 'guest_user',
          adWatchToken: `ad_token_${Date.now()}`
        })
      });
      
      const data = await response.json();
      if (data.success && data.joinUri) {
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
