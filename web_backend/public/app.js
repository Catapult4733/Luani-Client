// web_backend/public/app.js
document.addEventListener('DOMContentLoaded', () => {
  // Navigation & Views
  const brandLogoBtn = document.getElementById('brandLogoBtn');
  const navDiscover = document.getElementById('navDiscover');
  const discoverView = document.getElementById('discoverView');
  const gameDetailsView = document.getElementById('gameDetailsView');
  const userProfileView = document.getElementById('userProfileView');
  const searchResultsView = document.getElementById('searchResultsView');

  const btnBackToDiscover = document.getElementById('btnBackToDiscover');
  const btnBackFromProfile = document.getElementById('btnBackFromProfile');
  const btnLaunchClient = document.getElementById('btnLaunchClient');

  // Game Details Elements
  const detailGameIcon = document.getElementById('detailGameIcon');
  const detailGameTitle = document.getElementById('detailGameTitle');
  const detailGameCreatorLink = document.getElementById('detailGameCreatorLink');
  const detailGameDescription = document.getElementById('detailGameDescription');
  const btnDetailUnifiedJoin = document.getElementById('btnDetailUnifiedJoin');
  const detailActiveServersList = document.getElementById('detailActiveServersList');

  // Server Type Selection Modal
  const serverTypeModal = document.getElementById('serverTypeModal');
  const serverTypeModalClose = document.getElementById('serverTypeModalClose');
  const btnOptionOfficial = document.getElementById('btnOptionOfficial');
  const btnOptionHosted = document.getElementById('btnOptionHosted');

  // User Profile Elements
  const profileAvatarLarge = document.getElementById('profileAvatarLarge');
  const profileUsernameTitle = document.getElementById('profileUsernameTitle');
  const profileJoinedText = document.getElementById('profileJoinedText');
  const profileBioText = document.getElementById('profileBioText');
  const btnSendFriendReq = document.getElementById('btnSendFriendReq');
  const btnUnfriend = document.getElementById('btnUnfriend');
  const btnBlockUser = document.getElementById('btnBlockUser');

  // Auth Elements
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
  const loggedOutView = document.getElementById('loggedOutView');
  const loggedInView = document.getElementById('loggedInView');
  const userProfileWidget = document.getElementById('userProfileWidget');
  const userProfileDropdown = document.getElementById('userProfileDropdown');
  const userNameLabel = document.getElementById('userNameLabel');
  const userAvatar = document.getElementById('userAvatar');
  const menuViewProfile = document.getElementById('menuViewProfile');
  const menuEditBio = document.getElementById('menuEditBio');
  const menuLogout = document.getElementById('menuLogout');

  // Edit Bio Modal
  const editBioModal = document.getElementById('editBioModal');
  const editBioClose = document.getElementById('editBioClose');
  const editBioForm = document.getElementById('editBioForm');
  const bioInputText = document.getElementById('bioInputText');

  // Notifications Bell
  const notificationBellBtn = document.getElementById('notificationBellBtn');
  const notificationBadge = document.getElementById('notificationBadge');
  const notificationDropdown = document.getElementById('notificationDropdown');
  const notificationList = document.getElementById('notificationList');

  // Search Elements
  const searchInput = document.getElementById('searchInput');
  const searchQueryText = document.getElementById('searchQueryText');
  const searchPlacesGrid = document.getElementById('searchPlacesGrid');
  const searchUsersGrid = document.getElementById('searchUsersGrid');
  const placesGrid = document.getElementById('placesGrid');
  const friendsList = document.getElementById('friendsList');

  // Ad Modal Elements
  const adModal = document.getElementById('adModal');
  const adProgressBar = document.getElementById('adProgressBar');
  const adCountdownText = document.getElementById('adCountdownText');
  const btnSkipAd = document.getElementById('btnSkipAd');

  let isRegisterMode = false;
  let currentUser = null;
  let currentGame = null;

  // Initialize
  checkAuth();
  loadPlaces();

  // --- SPA VIEW ROUTER ---
  function showView(viewId) {
    [discoverView, gameDetailsView, userProfileView, searchResultsView].forEach(v => v.classList.add('hidden'));
    if (viewId === 'discover') discoverView.classList.remove('hidden');
    else if (viewId === 'details') gameDetailsView.classList.remove('hidden');
    else if (viewId === 'profile') userProfileView.classList.remove('hidden');
    else if (viewId === 'search') searchResultsView.classList.remove('hidden');

    window.scrollTo(0, 0);
  }

  brandLogoBtn.addEventListener('click', () => showView('discover'));
  navDiscover.addEventListener('click', (e) => { e.preventDefault(); showView('discover'); });
  btnBackToDiscover.addEventListener('click', () => showView('discover'));
  btnBackFromProfile.addEventListener('click', () => showView('discover'));

  if (btnLaunchClient) {
    btnLaunchClient.addEventListener('click', () => {
      if (!requireAuthGuard()) return;
      window.location.href = `luani://join?server=127.0.0.1:7777&username=${encodeURIComponent(currentUser.username)}`;
    });
  }

  // --- AUTH GUARD ENFORCEMENT ---
  function requireAuthGuard() {
    if (!currentUser) {
      authErrorMsg.textContent = 'Log in or sign up to play on Luani.';
      authErrorMsg.classList.remove('hidden');
      openAuthModal(false);
      return false;
    }
    return true;
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
    loadNotifications();
    loadFriends();
  }

  function clearAuth() {
    currentUser = null;
    localStorage.removeItem('luani_auth_token');
    loggedOutView.classList.remove('hidden');
    loggedInView.classList.add('hidden');
    friendsList.innerHTML = '<span class="friends-loading">Log in to view friends list</span>';
  }

  btnLoginOpen.addEventListener('click', () => openAuthModal(false));
  btnRegisterOpen.addEventListener('click', () => openAuthModal(true));
  authModalClose.addEventListener('click', () => authModal.classList.add('hidden'));
  menuLogout.addEventListener('click', (e) => { e.preventDefault(); clearAuth(); userProfileDropdown.classList.add('hidden'); });

  authSwitchLink.addEventListener('click', (e) => {
    e.preventDefault();
    openAuthModal(!isRegisterMode);
  });

  function openAuthModal(registerMode) {
    isRegisterMode = registerMode;
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

  // User Header Dropdown Toggle
  userProfileWidget.addEventListener('click', (e) => {
    e.stopPropagation();
    userProfileDropdown.classList.toggle('hidden');
    notificationDropdown.classList.add('hidden');
  });

  menuViewProfile.addEventListener('click', (e) => {
    e.preventDefault();
    userProfileDropdown.classList.add('hidden');
    if (currentUser) openUserProfile(currentUser.username);
  });

  menuEditBio.addEventListener('click', (e) => {
    e.preventDefault();
    userProfileDropdown.classList.add('hidden');
    if (currentUser) {
      bioInputText.value = currentUser.bio || '';
      editBioModal.classList.remove('hidden');
    }
  });

  editBioClose.addEventListener('click', () => editBioModal.classList.add('hidden'));

  editBioForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const token = localStorage.getItem('luani_auth_token');
    const newBio = bioInputText.value;

    try {
      const response = await fetch('/api/user/description', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ bio: newBio })
      });
      const data = await response.json();
      if (data.success) {
        if (currentUser) currentUser.bio = data.bio;
        editBioModal.classList.add('hidden');
        if (!userProfileView.classList.contains('hidden') && profileUsernameTitle.textContent === currentUser.username) {
          profileBioText.textContent = data.bio;
        }
      }
    } catch (err) {
      console.error('Error updating bio:', err);
    }
  });

  // --- NOTIFICATION BELL DROPDOWN ---
  notificationBellBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    notificationDropdown.classList.toggle('hidden');
    userProfileDropdown.classList.add('hidden');
  });

  document.addEventListener('click', () => {
    notificationDropdown.classList.add('hidden');
    userProfileDropdown.classList.add('hidden');
  });

  async function loadNotifications() {
    const token = localStorage.getItem('luani_auth_token');
    if (!token) return;

    try {
      const response = await fetch('/api/notifications', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await response.json();

      if (data.success && Array.isArray(data.pendingRequests)) {
        renderNotifications(data.pendingRequests);
      }
    } catch (err) {
      console.error('Error fetching notifications:', err);
    }
  }

  function renderNotifications(requests) {
    if (requests.length > 0) {
      notificationBadge.textContent = requests.length;
      notificationBadge.classList.remove('hidden');

      notificationList.innerHTML = '';
      requests.forEach(req => {
        const item = document.createElement('div');
        item.className = 'req-item';
        item.innerHTML = `
          <span><strong>${escapeHtml(req.fromUsername)}</strong> sent a friend request</span>
          <div class="req-actions">
            <button class="btn-xs btn-xs-accept" data-id="${req.id}">Accept</button>
            <button class="btn-xs btn-xs-decline" data-id="${req.id}">Decline</button>
          </div>
        `;

        item.querySelector('.btn-xs-accept').addEventListener('click', () => respondFriendRequest(req.id, true));
        item.querySelector('.btn-xs-decline').addEventListener('click', () => respondFriendRequest(req.id, false));
        notificationList.appendChild(item);
      });
    } else {
      notificationBadge.classList.add('hidden');
      notificationList.innerHTML = '<div class="dropdown-empty">No pending notifications</div>';
    }
  }

  async function respondFriendRequest(requestId, accept) {
    const token = localStorage.getItem('luani_auth_token');
    try {
      await fetch('/api/friends/respond', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ requestId, accept })
      });
      loadNotifications();
      loadFriends();
    } catch (err) {
      console.error('Error responding to request:', err);
    }
  }

  // --- FRIENDS LIST ---

  async function loadFriends() {
    const token = localStorage.getItem('luani_auth_token');
    if (!token) return;

    try {
      const response = await fetch('/api/friends', {
        headers: { 'Authorization': `Bearer ${token}` }
      });
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
    if (friends.length === 0) {
      friendsList.innerHTML = '<span class="friends-loading">No friends added yet. Search users to send requests!</span>';
      return;
    }

    friends.forEach(f => {
      const item = document.createElement('div');
      item.className = 'friend-item';
      const isOnline = f.status === 'ONLINE';

      item.innerHTML = `
        <span class="status-dot ${isOnline ? 'online' : 'offline'}"></span>
        <span style="cursor:pointer;" class="friend-name"><strong>${escapeHtml(f.username)}</strong></span>
        ${isOnline && f.serverIp ? `<button class="btn-join-friend" data-ip="${f.serverIp}" data-port="${f.serverPort}">Join</button>` : `<span style="color:var(--text-muted); font-size:0.75rem;">${f.status}</span>`}
      `;

      item.querySelector('.friend-name').addEventListener('click', () => openUserProfile(f.username));
      const joinBtn = item.querySelector('.btn-join-friend');
      if (joinBtn) {
        joinBtn.addEventListener('click', () => {
          if (!requireAuthGuard()) return;
          const uri = `luani://join?server=${joinBtn.getAttribute('data-ip')}:${joinBtn.getAttribute('data-port')}&username=${encodeURIComponent(currentUser.username)}`;
          triggerAdAndJoin(uri);
        });
      }

      friendsList.appendChild(item);
    });
  }

  // --- GAME DETAILS PAGE VIEW ---

  function openGameDetails(place) {
    currentGame = place;
    detailGameIcon.textContent = place.icon || '🎮';
    detailGameTitle.textContent = place.name;
    detailGameCreatorLink.textContent = place.creator || 'Luani Team';
    detailGameDescription.textContent = place.description || 'No description provided for this sandbox place.';

    detailGameCreatorLink.onclick = (e) => {
      e.preventDefault();
      openUserProfile(place.creator);
    };

    // Unified Join Button opens Server Type selection modal
    btnDetailUnifiedJoin.onclick = () => {
      if (!requireAuthGuard()) return;
      openServerTypeModal(place);
    };

    fetchActiveServersForPlace(place.id);
    showView('details');
  }

  // --- UNIFIED SERVER SELECTION MODAL ---

  function openServerTypeModal(place) {
    serverTypeModal.classList.remove('hidden');

    // 1. Join an Official Server: Shows 5-Second Sponsor Ad Modal while requesting matchmaking
    btnOptionOfficial.onclick = async () => {
      serverTypeModal.classList.add('hidden');
      triggerOfficialAdFlow(place.id);
    };

    // 2. Join a Hosted Server: Matchmaking request & luani:// launch IMMEDIATELY with NO ad modal
    btnOptionHosted.onclick = async () => {
      serverTypeModal.classList.add('hidden');
      await requestMatchmakingAndLaunch(place.id, 'hosted', false);
    };
  }

  if (serverTypeModalClose) {
    serverTypeModalClose.addEventListener('click', () => serverTypeModal.classList.add('hidden'));
  }

  async function fetchActiveServersForPlace(placeId) {
    detailActiveServersList.innerHTML = '<div class="loading-spinner">Fetching active servers...</div>';
    try {
      const response = await fetch(`/api/servers/active?placeId=${placeId}`);
      const data = await response.json();

      if (data.success && Array.isArray(data.servers)) {
        renderActiveServers(data.servers);
      } else {
        detailActiveServersList.innerHTML = '<div style="color:var(--text-muted);">No active server instances currently running. Click "Join Game" to select a server mode!</div>';
      }
    } catch (err) {
      detailActiveServersList.innerHTML = '<div style="color:var(--text-muted);">Could not load server list.</div>';
    }
  }

  function renderActiveServers(servers) {
    detailActiveServersList.innerHTML = '';
    if (servers.length === 0) {
      detailActiveServersList.innerHTML = '<div style="color:var(--text-muted);">No active servers running. Click "Join Game" to select a server mode!</div>';
      return;
    }

    servers.forEach(srv => {
      const row = document.createElement('div');
      row.className = 'server-item-row';
      row.innerHTML = `
        <div>
          <strong>${escapeHtml(srv.name || 'Managed Instance')}</strong>
          <div style="font-size:0.8rem; color:var(--text-muted);">${srv.serverIp}:${srv.serverPort} • ${srv.playerCount}/${srv.maxPlayers} Players (${srv.serverType || 'official'})</div>
        </div>
        <button class="btn btn-sm btn-primary btn-join-srv">Join</button>
      `;

      row.querySelector('.btn-join-srv').addEventListener('click', () => {
        if (!requireAuthGuard()) return;
        const uri = `luani://join?server=${srv.serverIp}:${srv.serverPort}&auth=${srv.authToken || ''}&username=${encodeURIComponent(currentUser.username)}`;
        if (srv.serverType === 'official' || !srv.serverType) {
          triggerAdAndJoin(uri);
        } else {
          window.location.href = uri;
        }
      });

      detailActiveServersList.appendChild(row);
    });
  }

  // --- USER PROFILE PAGE VIEW ---

  async function openUserProfile(username) {
    if (!username) return;
    const token = localStorage.getItem('luani_auth_token');

    try {
      const response = await fetch(`/api/user/${encodeURIComponent(username)}`, {
        headers: token ? { 'Authorization': `Bearer ${token}` } : {}
      });
      const data = await response.json();

      if (data.success && data.user) {
        const u = data.user;
        profileUsernameTitle.textContent = u.username;
        profileAvatarLarge.textContent = u.username.charAt(0).toUpperCase();
        profileJoinedText.textContent = `Registered Member`;
        profileBioText.textContent = u.bio || `No bio written yet.`;

        // Configure dynamic relationship buttons
        btnSendFriendReq.classList.add('hidden');
        btnUnfriend.classList.add('hidden');

        if (currentUser && currentUser.username === u.username) {
          // Own profile
          btnSendFriendReq.classList.add('hidden');
          btnUnfriend.classList.add('hidden');
        } else if (u.isFriend) {
          btnUnfriend.classList.remove('hidden');
        } else if (u.isPending) {
          btnSendFriendReq.textContent = '⏳ Friend Request Pending';
          btnSendFriendReq.disabled = true;
          btnSendFriendReq.classList.remove('hidden');
        } else {
          btnSendFriendReq.textContent = '➕ Send Friend Request';
          btnSendFriendReq.disabled = false;
          btnSendFriendReq.classList.remove('hidden');

          btnSendFriendReq.onclick = async () => {
            if (!requireAuthGuard()) return;
            await fetch('/api/friends/request', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
              body: JSON.stringify({ targetUsername: u.username })
            });
            openUserProfile(u.username);
          };
        }

        btnUnfriend.onclick = async () => {
          await fetch('/api/user/unfriend', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
            body: JSON.stringify({ targetUsername: u.username })
          });
          openUserProfile(u.username);
          loadFriends();
        };

        btnBlockUser.onclick = async () => {
          await fetch('/api/user/block', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
            body: JSON.stringify({ targetUsername: u.username })
          });
          alert(`Blocked user ${u.username}`);
          showView('discover');
        };

        showView('profile');
      }
    } catch (err) {
      console.error('Error fetching user profile:', err);
    }
  }

  // --- SEARCH SYSTEM ---

  let searchTimeout = null;
  searchInput.addEventListener('input', () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      const query = searchInput.value.trim();
      if (query.length >= 2) {
        performSearch(query);
      } else {
        showView('discover');
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
        showView('search');
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
        uCard.addEventListener('click', () => openUserProfile(user.username));
        searchUsersGrid.appendChild(uCard);
      });
    }
  }

  // --- DISCOVER PLACES CATALOG ---

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
    place.icon = icon;
    
    card.innerHTML = `
      <div class="card-banner">${icon}</div>
      <div class="card-title">${escapeHtml(place.name)}</div>
      <div class="card-meta">By ${escapeHtml(place.creator || 'Luani Creator')} • Max Players: ${place.maxPlayers || 10}</div>
      <div class="card-desc">${escapeHtml(place.description || 'No description provided.')}</div>
      <button class="btn btn-primary btn-play">Join Game</button>
    `;
    
    card.querySelector('.btn-play').addEventListener('click', (e) => {
      e.stopPropagation();
      if (!requireAuthGuard()) return;
      openGameDetails(place);
      openServerTypeModal(place);
    });

    card.addEventListener('click', () => openGameDetails(place));
    return card;
  }

  // --- MATCHMAKING & AD FLOW ---

  // Official Server Ad Flow: 5-Second Sponsor Ad Modal while requesting matchmaking
  async function triggerOfficialAdFlow(placeId) {
    adModal.classList.remove('hidden');
    if (btnSkipAd) btnSkipAd.classList.remove('hidden');
    adProgressBar.style.width = '0%';

    let readyJoinUri = null;
    let timerFinished = false;

    // Start backend matchmaking request concurrently
    requestMatchmakingAndLaunch(placeId, 'official', true).then(uri => {
      readyJoinUri = uri;
      if (timerFinished && readyJoinUri) {
        adModal.classList.add('hidden');
        window.location.href = readyJoinUri;
      }
    });

    let duration = 5;
    let elapsed = 0;

    const finishJoin = () => {
      clearInterval(interval);
      timerFinished = true;
      if (readyJoinUri) {
        adModal.classList.add('hidden');
        window.location.href = readyJoinUri;
      } else {
        adCountdownText.textContent = 'Connecting to official server...';
      }
    };

    if (btnSkipAd) {
      btnSkipAd.onclick = finishJoin;
    }

    const interval = setInterval(() => {
      elapsed += 0.1;
      const progress = (elapsed / duration) * 100;
      adProgressBar.style.width = `${Math.min(progress, 100)}%`;

      const remaining = Math.ceil(duration - elapsed);
      adCountdownText.textContent = `Sponsored Ad Verification (${remaining}s)...`;

      if (elapsed >= duration) {
        finishJoin();
      }
    }, 100);
  }

  // Generic ad trigger helper
  function triggerAdAndJoin(joinUri) {
    adModal.classList.remove('hidden');
    if (btnSkipAd) btnSkipAd.classList.remove('hidden');
    adProgressBar.style.width = '0%';

    let duration = 5;
    let elapsed = 0;

    const finishJoin = () => {
      clearInterval(interval);
      adModal.classList.add('hidden');
      window.location.href = joinUri;
    };

    if (btnSkipAd) btnSkipAd.onclick = finishJoin;

    const interval = setInterval(() => {
      elapsed += 0.1;
      const progress = (elapsed / duration) * 100;
      adProgressBar.style.width = `${Math.min(progress, 100)}%`;

      const remaining = Math.ceil(duration - elapsed);
      adCountdownText.textContent = `Sponsored Ad Verification (${remaining}s)...`;

      if (elapsed >= duration) {
        finishJoin();
      }
    }, 100);
  }

  // Core Matchmaking Backend Request (`type: official` vs `type: hosted`)
  async function requestMatchmakingAndLaunch(placeId, serverType, deferLaunch = false) {
    try {
      const response = await fetch('/api/servers/request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          placeId: placeId,
          serverType: serverType,
          username: currentUser ? currentUser.username : 'Player',
          adWatchToken: `token_${Date.now()}`
        })
      });

      const data = await response.json();
      if (data.success && data.joinUri) {
        if (!deferLaunch) {
          window.location.href = data.joinUri;
        }
        return data.joinUri;
      } else {
        alert('Server connection failed: ' + (data.error || 'Unknown error'));
        adModal.classList.add('hidden');
      }
    } catch (err) {
      console.error('Matchmaking error:', err);
      alert('Network error connecting to luani.fyi matchmaker.');
      adModal.classList.add('hidden');
    }
    return null;
  }

  function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, match => {
      const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
      return map[match];
    });
  }
});
