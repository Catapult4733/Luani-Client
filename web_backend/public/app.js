// web_backend/public/app.js
document.addEventListener('DOMContentLoaded', () => {
  // Navigation & Views
  const brandLogoBtn = document.getElementById('brandLogoBtn');
  const navDiscover = document.getElementById('navDiscover');
  const navStudio = document.getElementById('navStudio');
  const discoverView = document.getElementById('discoverView');
  const gameDetailsView = document.getElementById('gameDetailsView');
  const userProfileView = document.getElementById('userProfileView');
  const avatarEditorView = document.getElementById('avatarEditorView');
  const searchResultsView = document.getElementById('searchResultsView');

  const btnBackToDiscover = document.getElementById('btnBackToDiscover');
  const btnBackFromProfile = document.getElementById('btnBackFromProfile');
  const btnBackFromAvatar = document.getElementById('btnBackFromAvatar');
  const btnLaunchClient = document.getElementById('btnLaunchClient');
  const mobileMenuBtn = document.getElementById('mobileMenuBtn');
  const navLinksMenu = document.getElementById('navLinksMenu');

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

  // Install Prompt Modal
  const installPromptModal = document.getElementById('installPromptModal');
  const installPromptClose = document.getElementById('installPromptClose');
  const btnCopyInstallCmd = document.getElementById('btnCopyInstallCmd');
  const btnProceedToLaunch = document.getElementById('btnProceedToLaunch');

  // Game Loading Overlay Elements
  const gameLoadingOverlay = document.getElementById('gameLoadingOverlay');
  const loadingSpinner = document.getElementById('loadingSpinner');
  const loadingTitleText = document.getElementById('loadingTitleText');
  const loadingStatusText = document.getElementById('loadingStatusText');
  const loadingErrorBox = document.getElementById('loadingErrorBox');
  const loadingErrorText = document.getElementById('loadingErrorText');
  const btnCloseLoadingOverlay = document.getElementById('btnCloseLoadingOverlay');

  // User Profile Elements
  const profileAvatarLarge = document.getElementById('profileAvatarLarge');
  const profileUsernameTitle = document.getElementById('profileUsernameTitle');
  const profileJoinedText = document.getElementById('profileJoinedText');
  const profileBioText = document.getElementById('profileBioText');
  const btnSendFriendReq = document.getElementById('btnSendFriendReq');
  const btnUnfriend = document.getElementById('btnUnfriend');
  const btnBlockUser = document.getElementById('btnBlockUser');
  const ownerPowerPanel = document.getElementById('ownerPowerPanel');
  const btnAdminToggleVerified = document.getElementById('btnAdminToggleVerified');
  const btnAdminResetPassword = document.getElementById('btnAdminResetPassword');
  const btnAdminBanUser = document.getElementById('btnAdminBanUser');

  // Avatar Editor Elements
  const avatarSvgPreview = document.getElementById('avatarSvgPreview');
  const colorHead = document.getElementById('colorHead');
  const colorTorso = document.getElementById('colorTorso');
  const colorLeftArm = document.getElementById('colorLeftArm');
  const colorRightArm = document.getElementById('colorRightArm');
  const colorLeftLeg = document.getElementById('colorLeftLeg');
  const colorRightLeg = document.getElementById('colorRightLeg');
  const btnSaveAvatar = document.getElementById('btnSaveAvatar');
  const avatarSaveSuccess = document.getElementById('avatarSaveSuccess');

  // Auth Elements
  const authModal = document.getElementById('authModal');
  const authModalTitle = document.getElementById('authModalTitle');
  const authModalClose = document.getElementById('authModalClose');
  const authForm = document.getElementById('authForm');
  const authUsername = document.getElementById('authUsername');
  const authPassword = document.getElementById('authPassword');
  const btnTogglePassword = document.getElementById('btnTogglePassword');
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
  const menuAvatarEditor = document.getElementById('menuAvatarEditor');
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
  let currentProfileUser = null;
  let pendingLaunchUri = '';

  const DEFAULT_COLORS = {
    head: '#e0ac69',
    torso: '#0000ff',
    left_arm: '#e0ac69',
    right_arm: '#e0ac69',
    left_leg: '#00ff00',
    right_leg: '#00ff00'
  };

  // Helper: Get stored auth token
  function getAuthToken() {
    return localStorage.getItem('luani_auth_token');
  }

  function setAuthToken(token) {
    if (token) localStorage.setItem('luani_auth_token', token);
    else localStorage.removeItem('luani_auth_token');
  }

  // --- HOLD-TO-SHOW PASSWORD LOGIC ---
  if (btnTogglePassword && authPassword) {
    const showPassword = () => { authPassword.type = 'text'; };
    const hidePassword = () => { authPassword.type = 'password'; };

    btnTogglePassword.addEventListener('mousedown', showPassword);
    btnTogglePassword.addEventListener('mouseup', hidePassword);
    btnTogglePassword.addEventListener('mouseleave', hidePassword);
    btnTogglePassword.addEventListener('touchstart', (e) => { e.preventDefault(); showPassword(); });
    btnTogglePassword.addEventListener('touchend', (e) => { e.preventDefault(); hidePassword(); });
  }

  // --- MOBILE HAMBURGER MENU ---
  if (mobileMenuBtn && navLinksMenu) {
    mobileMenuBtn.addEventListener('click', () => {
      navLinksMenu.classList.toggle('mobile-open');
    });
  }

  // --- AVATAR SVG PREVIEW RENDERER ---
  function generateAvatarSvg(colors) {
    const c = colors || DEFAULT_COLORS;
    return `
      <svg width="180" height="240" viewBox="0 0 180 240" xmlns="http://www.w3.org/2000/svg">
        <!-- Head -->
        <rect x="65" y="20" width="50" height="50" rx="4" fill="${c.head || '#e0ac69'}" stroke="#000" stroke-width="2"/>
        <!-- Eyes -->
        <circle cx="78" cy="40" r="4" fill="#000"/>
        <circle cx="102" cy="40" r="4" fill="#000"/>
        <!-- Torso -->
        <rect x="50" y="75" width="80" height="90" rx="4" fill="${c.torso || '#0000ff'}" stroke="#000" stroke-width="2"/>
        <!-- Left Arm -->
        <rect x="15" y="75" width="30" height="80" rx="4" fill="${c.left_arm || c.head || '#e0ac69'}" stroke="#000" stroke-width="2"/>
        <!-- Right Arm -->
        <rect x="135" y="75" width="30" height="80" rx="4" fill="${c.right_arm || c.head || '#e0ac69'}" stroke="#000" stroke-width="2"/>
        <!-- Left Leg -->
        <rect x="52" y="170" width="35" height="60" rx="4" fill="${c.left_leg || '#00ff00'}" stroke="#000" stroke-width="2"/>
        <!-- Right Leg -->
        <rect x="93" y="170" width="35" height="60" rx="4" fill="${c.right_leg || '#00ff00'}" stroke="#000" stroke-width="2"/>
      </svg>
    `;
  }

  function updateAvatarSvgPreview() {
    if (!avatarSvgPreview) return;
    const colors = {
      head: colorHead.value,
      torso: colorTorso.value,
      left_arm: colorLeftArm.value,
      right_arm: colorRightArm.value,
      left_leg: colorLeftLeg.value,
      right_leg: colorRightLeg.value
    };
    avatarSvgPreview.innerHTML = generateAvatarSvg(colors);
  }

  [colorHead, colorTorso, colorLeftArm, colorRightArm, colorLeftLeg, colorRightLeg].forEach(picker => {
    if (picker) picker.addEventListener('input', updateAvatarSvgPreview);
  });

  function renderUserBadges(userObj) {
    let badges = '';
    if (userObj.owner) badges += '<span class="badge-crown" title="Platform Owner">👑</span>';
    if (userObj.verified) badges += '<span class="badge-verified" title="Verified User">☑️</span>';
    return badges;
  }

  function renderAvatarCircle(element, colors, username) {
    if (!element) return;
    const c = colors || DEFAULT_COLORS;
    element.innerHTML = generateAvatarSvg(c);
  }

  // --- ROUTING ENGINE ---
  function showView(viewToShow) {
    [discoverView, gameDetailsView, userProfileView, avatarEditorView, searchResultsView].forEach(v => {
      if (v) v.classList.add('hidden');
    });
    if (viewToShow) viewToShow.classList.remove('hidden');
    if (navLinksMenu) navLinksMenu.classList.remove('mobile-open');

    // Remove promo banner from profile view
    const studioBanner = document.getElementById('studio');
    if (studioBanner) {
      if (viewToShow === userProfileView || viewToShow === avatarEditorView) {
        studioBanner.classList.add('hidden');
      } else {
        studioBanner.classList.remove('hidden');
      }
    }

    window.scrollTo(0, 0);
  }

  brandLogoBtn.addEventListener('click', () => {
    window.history.pushState({}, '', '/');
    showView(discoverView);
  });

  navDiscover.addEventListener('click', (e) => {
    e.preventDefault();
    window.history.pushState({}, '', '/');
    showView(discoverView);
  });

  btnBackToDiscover.addEventListener('click', () => {
    window.history.pushState({}, '', '/');
    showView(discoverView);
  });

  btnBackFromProfile.addEventListener('click', () => {
    showView(discoverView);
  });

  if (btnBackFromAvatar) {
    btnBackFromAvatar.addEventListener('click', () => {
      showView(discoverView);
    });
  }

  btnLaunchClient.addEventListener('click', () => {
    const launchUri = `luani://join?server=luani.fyi:7700&username=${encodeURIComponent(currentUser ? currentUser.username : 'Player')}`;
    promptInstallOrLaunch(launchUri);
  });

  // --- INSTALL PROMPT TERMINAL MODAL ---
  function promptInstallOrLaunch(joinUri) {
    pendingLaunchUri = joinUri;
    if (installPromptModal) installPromptModal.classList.remove('hidden');
  }

  if (installPromptClose) {
    installPromptClose.addEventListener('click', () => {
      installPromptModal.classList.add('hidden');
    });
  }

  if (btnCopyInstallCmd) {
    btnCopyInstallCmd.addEventListener('click', () => {
      const codeText = "curl -fsSL https://www.luani.fyi/install.sh | bash";
      navigator.clipboard.writeText(codeText).then(() => {
        btnCopyInstallCmd.innerHTML = '✅ Copied!';
        setTimeout(() => { btnCopyInstallCmd.innerHTML = '📋 Copy'; }, 2000);
      });
    });
  }

  if (btnProceedToLaunch) {
    btnProceedToLaunch.addEventListener('click', () => {
      installPromptModal.classList.add('hidden');
      if (pendingLaunchUri) {
        window.location.href = pendingLaunchUri;
      }
    });
  }

  // --- INITIAL CHECK & URL PARAMETER ROUTING ---
  checkAuthStatus();
  fetchPlacesCatalog();
  handleUrlRouting();

  function handleUrlRouting() {
    const params = new URLSearchParams(window.location.search);
    const gameId = params.get('game');
    const usernameParam = params.get('user');

    if (gameId) {
      loadGameDetails(gameId);
    } else if (usernameParam) {
      loadUserProfile(usernameParam);
    } else {
      showView(discoverView);
    }
  }

  // --- AUTH SYSTEM ---
  function checkAuthStatus() {
    const token = getAuthToken();
    if (!token) {
      updateAuthUI(null);
      return;
    }

    fetch('/api/auth/me', {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        currentUser = data.user;
        updateAuthUI(currentUser);
        fetchFriendsList();
        fetchNotifications();
      } else {
        setAuthToken(null);
        updateAuthUI(null);
      }
    })
    .catch(() => updateAuthUI(null));
  }

  function updateAuthUI(user) {
    if (user) {
      loggedOutView.classList.add('hidden');
      loggedInView.classList.remove('hidden');
      userNameLabel.innerHTML = `${user.username} ${renderUserBadges(user)}`;
      renderAvatarCircle(userAvatar, user.avatar_colors, user.username);
    } else {
      loggedOutView.classList.remove('hidden');
      loggedInView.classList.add('hidden');
      friendsList.innerHTML = '<span class="friends-loading">Log in to view friends list</span>';
    }
  }

  btnLoginOpen.addEventListener('click', () => openAuthModal(false));
  btnRegisterOpen.addEventListener('click', () => openAuthModal(true));
  authModalClose.addEventListener('click', closeAuthModal);

  function openAuthModal(isRegister) {
    isRegisterMode = isRegister;
    authModalTitle.innerText = isRegister ? 'Sign Up for Luani' : 'Log In to Luani';
    authSubmitBtn.innerText = isRegister ? 'Create Account' : 'Log In';
    authSwitchText.innerText = isRegister ? 'Already have an account?' : "Don't have an account?";
    authSwitchLink.innerText = isRegister ? 'Log In' : 'Sign Up';
    authErrorMsg.classList.add('hidden');
    authUsername.value = '';
    authPassword.value = '';
    authModal.classList.remove('hidden');
  }

  function closeAuthModal() {
    authModal.classList.add('hidden');
  }

  authSwitchLink.addEventListener('click', (e) => {
    e.preventDefault();
    openAuthModal(!isRegisterMode);
  });

  authForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const endpoint = isRegisterMode ? '/api/auth/register' : '/api/auth/login';
    authErrorMsg.classList.add('hidden');

    fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: authUsername.value.trim(),
        password: authPassword.value
      })
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        setAuthToken(data.token);
        currentUser = data.user;
        updateAuthUI(currentUser);
        closeAuthModal();
        fetchFriendsList();
      } else {
        authErrorMsg.innerText = data.error || 'Authentication failed.';
        authErrorMsg.classList.remove('hidden');
      }
    })
    .catch(() => {
      authErrorMsg.innerText = 'Network error. Please try again.';
      authErrorMsg.classList.remove('hidden');
    });
  });

  // User Profile Dropdown Toggle
  userProfileWidget.addEventListener('click', (e) => {
    e.stopPropagation();
    userProfileDropdown.classList.toggle('hidden');
  });

  document.addEventListener('click', () => {
    if (userProfileDropdown) userProfileDropdown.classList.add('hidden');
    if (notificationDropdown) notificationDropdown.classList.add('hidden');
  });

  menuViewProfile.addEventListener('click', (e) => {
    e.preventDefault();
    if (currentUser) {
      window.history.pushState({}, '', `/?user=${encodeURIComponent(currentUser.username)}`);
      loadUserProfile(currentUser.username);
    }
  });

  if (menuAvatarEditor) {
    menuAvatarEditor.addEventListener('click', (e) => {
      e.preventDefault();
      if (!currentUser) {
        openAuthModal(false);
        return;
      }
      openAvatarEditor();
    });
  }

  menuEditBio.addEventListener('click', (e) => {
    e.preventDefault();
    if (currentUser) {
      bioInputText.value = currentUser.bio || '';
      editBioModal.classList.remove('hidden');
    }
  });

  menuLogout.addEventListener('click', (e) => {
    e.preventDefault();
    setAuthToken(null);
    currentUser = null;
    updateAuthUI(null);
    window.location.href = '/';
  });

  editBioClose.addEventListener('click', () => editBioModal.classList.add('hidden'));

  editBioForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const token = getAuthToken();
    fetch('/api/user/description', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ bio: bioInputText.value })
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        if (currentUser) currentUser.bio = data.bio;
        profileBioText.innerText = data.bio;
        editBioModal.classList.add('hidden');
      }
    });
  });

  // --- AVATAR EDITOR PAGE ---
  function openAvatarEditor() {
    if (!currentUser) return;
    const colors = currentUser.avatar_colors || DEFAULT_COLORS;
    colorHead.value = colors.head || DEFAULT_COLORS.head;
    colorTorso.value = colors.torso || DEFAULT_COLORS.torso;
    colorLeftArm.value = colors.left_arm || DEFAULT_COLORS.left_arm;
    colorRightArm.value = colors.right_arm || DEFAULT_COLORS.right_arm;
    colorLeftLeg.value = colors.left_leg || DEFAULT_COLORS.left_leg;
    colorRightLeg.value = colors.right_leg || DEFAULT_COLORS.right_leg;

    updateAvatarSvgPreview();
    avatarSaveSuccess.classList.add('hidden');
    showView(avatarEditorView);
  }

  btnSaveAvatar.addEventListener('click', () => {
    if (!currentUser) return;
    const token = getAuthToken();
    const updatedColors = {
      head: colorHead.value,
      torso: colorTorso.value,
      left_arm: colorLeftArm.value,
      right_arm: colorRightArm.value,
      left_leg: colorLeftLeg.value,
      right_leg: colorRightLeg.value
    };

    fetch('/api/user/avatar-colors', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ avatar_colors: updatedColors })
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        currentUser.avatar_colors = data.avatar_colors;
        renderAvatarCircle(userAvatar, currentUser.avatar_colors, currentUser.username);
        avatarSaveSuccess.classList.remove('hidden');
        setTimeout(() => avatarSaveSuccess.classList.add('hidden'), 3000);
      }
    });
  });

  // --- PLACES CATALOG & GAME DETAILS ---
  function fetchPlacesCatalog() {
    fetch('/api/places')
      .then(r => r.json())
      .then(data => {
        if (data.success) {
          renderPlacesGrid(data.places);
        }
      });
  }

  function renderPlacesGrid(placesList) {
    placesGrid.innerHTML = '';
    placesList.forEach(place => {
      const card = document.createElement('div');
      card.className = 'place-card';
      card.innerHTML = `
        <div class="place-thumbnail">🎮</div>
        <div class="place-info">
          <div class="place-title">${place.name}</div>
          <div class="place-creator">by ${place.creator}</div>
          <div class="place-meta">
            <span>👥 Max ${place.maxPlayers} Players</span>
          </div>
        </div>
      `;
      card.addEventListener('click', () => {
        window.history.pushState({}, '', `/?game=${encodeURIComponent(place.id)}`);
        loadGameDetails(place.id);
      });
      placesGrid.appendChild(card);
    });
  }

  function loadGameDetails(gameId) {
    fetch(`/api/places/${gameId}`)
      .then(r => r.json())
      .then(data => {
        if (data.success && data.place) {
          currentGame = data.place;
          detailGameTitle.innerText = currentGame.name;
          detailGameCreatorLink.innerText = currentGame.creator;
          detailGameCreatorLink.onclick = (e) => {
            e.preventDefault();
            window.history.pushState({}, '', `/?user=${encodeURIComponent(currentGame.creator)}`);
            loadUserProfile(currentGame.creator);
          };
          detailGameDescription.innerText = currentGame.description || 'Welcome to this Luani place instance.';
          showView(gameDetailsView);
          fetchActiveServersForGame(gameId);
        }
      });
  }

  btnDetailUnifiedJoin.addEventListener('click', () => {
    if (!currentUser) {
      openAuthModal(false);
      return;
    }
    serverTypeModal.classList.remove('hidden');
  });

  serverTypeModalClose.addEventListener('click', () => serverTypeModal.classList.add('hidden'));

  btnOptionOfficial.addEventListener('click', () => {
    serverTypeModal.classList.add('hidden');
    triggerOfficialServerAdFlow();
  });

  btnOptionHosted.addEventListener('click', () => {
    serverTypeModal.classList.add('hidden');
    requestAndLaunchServer('hosted');
  });

  function triggerOfficialServerAdFlow() {
    adModal.classList.remove('hidden');
    adProgressBar.style.width = '0%';
    btnSkipAd.classList.add('hidden');
    adCountdownText.innerText = 'Sponsored Ad Verification (5s)...';

    let elapsed = 0;
    const interval = setInterval(() => {
      elapsed += 1;
      const pct = (elapsed / 5) * 100;
      adProgressBar.style.width = `${pct}%`;
      adCountdownText.innerText = `Sponsored Ad Verification (${5 - elapsed}s)...`;

      if (elapsed >= 5) {
        clearInterval(interval);
        adCountdownText.innerText = 'Ad complete! You can now join official server.';
        btnSkipAd.classList.remove('hidden');
      }
    }, 1000);

    btnSkipAd.onclick = () => {
      adModal.classList.add('hidden');
      requestAndLaunchServer('official');
    };
  }

  function requestAndLaunchServer(type) {
    if (!currentGame) return;
    const token = getAuthToken();

    // Show Game Loading Overlay
    gameLoadingOverlay.classList.remove('hidden');
    loadingSpinner.classList.remove('hidden');
    loadingErrorBox.classList.add('hidden');
    loadingTitleText.innerText = 'Connecting to Server...';
    loadingStatusText.innerText = 'Requesting dynamic server instance from daemon...';

    fetch('/api/servers/request', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({
        placeId: currentGame.id,
        serverType: type,
        username: currentUser ? currentUser.username : 'Player'
      })
    })
    .then(r => r.json())
    .then(data => {
      if (data.success && data.joinUri) {
        loadingStatusText.innerText = `Server ready at ${data.server.serverIp}:${data.server.serverPort}. Launching Luani Client...`;
        setTimeout(() => {
          gameLoadingOverlay.classList.add('hidden');
          promptInstallOrLaunch(data.joinUri);
        }, 1200);
      } else {
        showLoadingError(data.error || 'Matchmaker returned invalid response.');
      }
    })
    .catch(err => {
      showLoadingError('Could not reach backend matchmaker API: ' + err.message);
    });
  }

  function showLoadingError(msg) {
    loadingSpinner.classList.add('hidden');
    loadingErrorBox.classList.remove('hidden');
    loadingErrorText.innerText = msg;
  }

  btnCloseLoadingOverlay.addEventListener('click', () => {
    gameLoadingOverlay.classList.add('hidden');
  });

  function fetchActiveServersForGame(placeId) {
    detailActiveServersList.innerHTML = '<div class="loading-spinner">Fetching running servers...</div>';
    fetch(`/api/servers/active?placeId=${placeId}`)
      .then(r => r.json())
      .then(data => {
        if (data.success && data.servers.length > 0) {
          detailActiveServersList.innerHTML = '';
          data.servers.forEach(srv => {
            const item = document.createElement('div');
            item.className = 'active-server-card';
            item.innerHTML = `
              <div class="srv-info">
                <strong>${srv.name}</strong> (${srv.playerCount}/${srv.maxPlayers} players)
                <div class="srv-sub">${srv.serverIp}:${srv.serverPort} - ${srv.serverType}</div>
              </div>
              <button class="btn btn-sm btn-primary">Join</button>
            `;
            item.querySelector('button').onclick = () => {
              if (!currentUser) { openAuthModal(false); return; }
              const joinUri = `luani://join?server=${srv.serverIp}:${srv.serverPort}&auth=${srv.authToken}&username=${encodeURIComponent(currentUser.username)}`;
              promptInstallOrLaunch(joinUri);
            };
            detailActiveServersList.appendChild(item);
          });
        } else {
          detailActiveServersList.innerHTML = '<div class="srv-empty">No active servers currently running for this place. Click "Join Game" above to launch one!</div>';
        }
      });
  }

  // --- USER PROFILES & OWNER POWER PANEL ---
  function loadUserProfile(username) {
    const token = getAuthToken();
    fetch(`/api/user/${encodeURIComponent(username)}`, {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    .then(r => r.json())
    .then(data => {
      if (data.success && data.user) {
        currentProfileUser = data.user;
        profileUsernameTitle.innerHTML = `${currentProfileUser.username} ${renderUserBadges(currentProfileUser)}`;
        renderAvatarCircle(profileAvatarLarge, currentProfileUser.avatar_colors, currentProfileUser.username);
        profileBioText.innerText = currentProfileUser.bio;

        // Render Owner Power Panel if currentUser is owner
        if (currentUser && currentUser.owner) {
          ownerPowerPanel.classList.remove('hidden');
          setupOwnerPowerPanel(currentProfileUser);
        } else {
          ownerPowerPanel.classList.add('hidden');
        }

        showView(userProfileView);
      }
    });
  }

  function setupOwnerPowerPanel(targetUser) {
    btnAdminToggleVerified.onclick = () => {
      const token = getAuthToken();
      fetch('/api/admin/toggle-verified', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ targetUsername: targetUser.username })
      })
      .then(r => r.json())
      .then(data => {
        if (data.success) {
          targetUser.verified = data.verified;
          profileUsernameTitle.innerHTML = `${targetUser.username} ${renderUserBadges(targetUser)}`;
          alert(data.message);
        }
      });
    };

    btnAdminResetPassword.onclick = () => {
      const token = getAuthToken();
      fetch('/api/admin/reset-password', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ targetUsername: targetUser.username })
      })
      .then(r => r.json())
      .then(data => alert(data.message));
    };

    btnAdminBanUser.onclick = () => {
      const reason = prompt(`Issue warning / ban for ${targetUser.username}:`, 'Violation of platform rules.');
      if (!reason) return;
      const token = getAuthToken();
      fetch('/api/admin/ban-user', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ targetUsername: targetUser.username, reason })
      })
      .then(r => r.json())
      .then(data => alert(data.message));
    };
  }

  // --- FRIENDS & NOTIFICATIONS ---
  function fetchFriendsList() {
    const token = getAuthToken();
    fetch('/api/friends', {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    .then(r => r.json())
    .then(data => {
      if (data.success && data.friends) {
        friendsList.innerHTML = '';
        data.friends.forEach(f => {
          const badge = document.createElement('span');
          badge.className = 'friend-chip';
          badge.innerHTML = `🟢 ${f.username}`;
          badge.onclick = () => {
            window.history.pushState({}, '', `/?user=${encodeURIComponent(f.username)}`);
            loadUserProfile(f.username);
          };
          friendsList.appendChild(badge);
        });
      }
    });
  }

  function fetchNotifications() {
    const token = getAuthToken();
    fetch('/api/notifications', {
      headers: { 'Authorization': `Bearer ${token}` }
    })
    .then(r => r.json())
    .then(data => {
      if (data.success && data.pendingRequests.length > 0) {
        notificationBadge.innerText = data.pendingRequests.length;
        notificationBadge.classList.remove('hidden');
      } else {
        notificationBadge.classList.add('hidden');
      }
    });
  }

  // Search input handler
  searchInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      const q = searchInput.value.trim();
      if (!q) return;
      searchQueryText.innerText = q;
      fetch(`/api/search?q=${encodeURIComponent(q)}`)
        .then(r => r.json())
        .then(data => {
          if (data.success) {
            renderPlacesGrid(data.places);
            showView(discoverView);
          }
        });
    }
  });

});
