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
  const privacyView = document.getElementById('privacyView');

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
  const profileRelationshipActions = document.getElementById('profileRelationshipActions');
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

  // --- AUTH TOKEN & FETCH WRAPPER ---
  function getAuthToken() {
    return localStorage.getItem('token') || localStorage.getItem('luani_auth_token') || '';
  }

  function setAuthToken(token) {
    if (token) {
      localStorage.setItem('token', token);
      localStorage.setItem('luani_auth_token', token);
    } else {
      localStorage.removeItem('token');
      localStorage.removeItem('luani_auth_token');
    }
  }

  function apiFetch(url, options = {}) {
    const token = getAuthToken();
    const headers = {
      'Content-Type': 'application/json',
      ...options.headers
    };
    if (token) {
      headers['Authorization'] = 'Bearer ' + token;
    }
    return fetch(url, { ...options, headers });
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
      </svg>
    `;
  }

  function renderUserBadges(user) {
    if (!user) return '';
    const isOwner = user.owner === true || user.owner === 'true';
    const isVerified = user.verified === true || user.verified === 'true';
    let html = '';
    if (isOwner) {
      html += ' <span class="badge-crown" title="Luani Owner / Creator">👑</span>';
    }
    if (isVerified) {
      html += ' <img src="/assets/verified_badge.png" class="badge-verified-img" title="Verified Account">';
    }
    return html;
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
    if (!userObj) return '';
    let badges = '';
    const isOwner = userObj.owner === true || userObj.owner === 'true';
    const isVerified = userObj.verified === true || userObj.verified === 'true';
    if (isOwner) badges += '<span class="badge-crown" title="Platform Owner">👑</span>';
    if (isVerified) badges += '<img src="/assets/verified_badge.png" class="verified-badge-img badge-verified-img" title="Verified User">';
    return badges;
  }

  function renderAvatarCircle(element, colors, username) {
    if (!element) return;
    const c = colors || DEFAULT_COLORS;
    element.innerHTML = generateAvatarSvg(c);
  }

  const studioDashboardView = document.getElementById('studioDashboardView');
  const btnCreateNewGame = document.getElementById('btnCreateNewGame');
  const tabStudioActive = document.getElementById('tabStudioActive');
  const tabStudioArchived = document.getElementById('tabStudioArchived');
  const studioGamesGrid = document.getElementById('studioGamesGrid');
  let currentStudioTab = 'active';

  const SITE_VERSION = '0.2.13';

  const navDownloads = document.getElementById('navDownloads');
  const downloadsView = document.getElementById('downloadsView');
  const btnCopyDownloadsCmd = document.getElementById('btnCopyDownloadsCmd');
  const downloadsCmdText = document.getElementById('downloadsCmdText');

  const navCatalog = document.getElementById('navCatalog');
  const catalogView = document.getElementById('catalogView');
  const catalogGrid = document.getElementById('catalogGrid');
  const avatarInventoryGrid = document.getElementById('avatarInventoryGrid');
  const updateNoticeBanner = document.getElementById('updateNoticeBanner');
  const btnRefreshPageNotice = document.getElementById('btnRefreshPageNotice');

  let purchasedAccessories = JSON.parse(localStorage.getItem('luani_purchased_accessories') || '["hat_cap", "glasses_shades"]');
  let equippedAccessories = JSON.parse(localStorage.getItem('luani_equipped_accessories') || '["hat_cap"]');

  const ACCESSORY_CATALOG = [
    { id: 'hat_cap', name: 'Red Cap', type: 'Hat', icon: '🧢', price: 0 },
    { id: 'glasses_shades', name: 'Dark Shades', type: 'Glasses', icon: '🕶️', price: 0 },
    { id: 'backpack_pack', name: 'Adventurer Pack', type: 'Backpack', icon: '🎒', price: 0 },
    { id: 'hat_crown', name: 'Golden Crown', type: 'Hat', icon: '👑', price: 0 },
    { id: 'headset_pro', name: 'Pro Headphones', type: 'Hat', icon: '🎧', price: 0 }
  ];

  const navPrivacyLink = document.getElementById('navPrivacyLink');

  // --- ROUTING ENGINE ---
  function showView(viewToShow) {
    [discoverView, gameDetailsView, userProfileView, avatarEditorView, searchResultsView, studioDashboardView, downloadsView, catalogView, privacyView].forEach(v => {
      if (v) v.classList.add('hidden');
    });
    if (viewToShow) viewToShow.classList.remove('hidden');
    if (navLinksMenu) navLinksMenu.classList.remove('mobile-open');

    const studioBanner = document.getElementById('studio');
    if (studioBanner) {
      if (viewToShow === userProfileView || viewToShow === avatarEditorView || viewToShow === studioDashboardView || viewToShow === downloadsView || viewToShow === catalogView || viewToShow === privacyView) {
        studioBanner.classList.add('hidden');
      } else {
        studioBanner.classList.remove('hidden');
      }
    }

    window.scrollTo(0, 0);
  }

  if (navCatalog) {
    navCatalog.addEventListener('click', (e) => {
      e.preventDefault();
      window.history.pushState({}, '', '#catalog');
      renderCatalogPage();
      showView(catalogView);
    });
  }

  if (navDownloads) {
    navDownloads.addEventListener('click', (e) => {
      e.preventDefault();
      window.history.pushState({}, '', '#downloads');
      showView(downloadsView);
    });
  }

  if (navPrivacyLink) {
    navPrivacyLink.addEventListener('click', (e) => {
      e.preventDefault();
      window.history.pushState({}, '', '#privacy');
      showView(privacyView);
    });
  }

  if (window.location.hash === '#privacy' || window.location.pathname === '/privacy') {
    showView(privacyView);
  }

  if (btnCopyDownloadsCmd && downloadsCmdText) {
    btnCopyDownloadsCmd.addEventListener('click', () => {
      navigator.clipboard.writeText(downloadsCmdText.innerText);
      btnCopyDownloadsCmd.innerText = '✅ Copied!';
      setTimeout(() => { btnCopyDownloadsCmd.innerText = '📋 Copy'; }, 2000);
    });
  }

  if (btnRefreshPageNotice) {
    btnRefreshPageNotice.addEventListener('click', () => {
      window.location.reload();
    });
  }

  // --- VERSION INDICATOR & UPDATE NOTIFICATION SYSTEM ---
  function checkWebsiteVersion() {
    fetch('/api/version')
      .then(res => res.json())
      .then(data => {
        if (data && data.version && data.version !== SITE_VERSION) {
          if (updateNoticeBanner) {
            updateNoticeBanner.classList.remove('hidden');
          }
        }
      })
      .catch(() => {});
  }

  // Check version on load and every 30 seconds
  checkWebsiteVersion();
  setInterval(checkWebsiteVersion, 30000);

  // Notify user once if website was updated since last visit
  const lastSeenVer = localStorage.getItem('last_seen_site_version');
  if (lastSeenVer && lastSeenVer !== SITE_VERSION) {
    alert(`🎉 Website updated! You are now on the latest version (${SITE_VERSION}).`);
  }
  localStorage.setItem('last_seen_site_version', SITE_VERSION);

  // --- SEPARATE CATALOG PAGE RENDERING ---
  function renderCatalogPage() {
    if (!catalogGrid) return;
    catalogGrid.innerHTML = '';

    ACCESSORY_CATALOG.forEach(item => {
      const isOwned = purchasedAccessories.includes(item.id);
      const card = document.createElement('div');
      card.className = 'catalog-card';
      card.style.cssText = `
        background: #0f172a;
        border: 1px solid ${isOwned ? '#10b981' : '#334155'};
        border-radius: 12px;
        padding: 1.25rem;
        text-align: center;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
      `;

      card.innerHTML = `
        <div>
          <div style="font-size: 3rem; margin-bottom: 0.5rem;">${item.icon}</div>
          <div style="font-weight: bold; font-size: 1.1rem; color: #fff;">${item.name}</div>
          <div style="font-size: 0.85rem; color: #94a3b8; margin-top: 2px;">${item.type}</div>
          <div style="margin-top: 0.6rem; display: inline-block; background: rgba(34, 197, 94, 0.2); color: #4ade80; font-size: 0.8rem; font-weight: bold; padding: 4px 10px; border-radius: 12px;">
            FREE ($0)
          </div>
        </div>
        <button class="btn btn-sm ${isOwned ? 'btn-secondary' : 'btn-primary'} btn-buy-catalog" style="margin-top: 1rem; width: 100%;">
          ${isOwned ? '✅ Acquired (In Inventory)' : '🛍️ Get for FREE'}
        </button>
      `;

      const btnBuy = card.querySelector('.btn-buy-catalog');
      btnBuy.addEventListener('click', () => {
        if (!isOwned) {
          purchasedAccessories.push(item.id);
          localStorage.setItem('luani_purchased_accessories', JSON.stringify(purchasedAccessories));
          alert(`🎉 Added ${item.name} to your Avatar Inventory!`);
          renderCatalogPage();
          renderAvatarInventory();
        }
      });

      catalogGrid.appendChild(card);
    });
  }

  // --- AVATAR PAGE INVENTORY RENDERING ---
  function renderAvatarInventory() {
    if (!avatarInventoryGrid) return;
    avatarInventoryGrid.innerHTML = '';

    const ownedItems = ACCESSORY_CATALOG.filter(item => purchasedAccessories.includes(item.id));

    if (ownedItems.length === 0) {
      avatarInventoryGrid.innerHTML = `
        <div style="color: var(--text-muted); grid-column: 1 / -1; padding: 1.5rem; text-align: center;">
          No accessories in your inventory yet. <a href="#catalog" id="linkCatalogEmpty" style="color: #60a5fa; font-weight: bold;">Browse the Catalog</a> to get free items!
        </div>
      `;
      const linkEmpty = avatarInventoryGrid.querySelector('#linkCatalogEmpty');
      if (linkEmpty) {
        linkEmpty.addEventListener('click', (e) => {
          e.preventDefault();
          showView(catalogView);
          renderCatalogPage();
        });
      }
      return;
    }

    ownedItems.forEach(item => {
      const isEquipped = equippedAccessories.includes(item.id);
      const card = document.createElement('div');
      card.className = 'inventory-card';
      card.style.cssText = `
        background: #1e293b;
        border: 1px solid ${isEquipped ? '#3b82f6' : '#334155'};
        border-radius: 10px;
        padding: 1rem;
        text-align: center;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
      `;

      card.innerHTML = `
        <div>
          <div style="font-size: 2.2rem; margin-bottom: 0.4rem;">${item.icon}</div>
          <div style="font-weight: bold; font-size: 0.9rem; color: #fff;">${item.name}</div>
          <div style="font-size: 0.75rem; color: #94a3b8;">${item.type}</div>
        </div>
        <button class="btn btn-sm ${isEquipped ? 'btn-secondary' : 'btn-primary'} btn-toggle-equip" style="margin-top: 0.75rem; width: 100%;">
          ${isEquipped ? '✅ Equipped' : '➕ Equip'}
        </button>
      `;

      const btnEquip = card.querySelector('.btn-toggle-equip');
      btnEquip.addEventListener('click', () => {
        if (isEquipped) {
          equippedAccessories = equippedAccessories.filter(id => id !== item.id);
        } else {
          equippedAccessories.push(item.id);
        }
        localStorage.setItem('luani_equipped_accessories', JSON.stringify(equippedAccessories));
        renderAvatarInventory();
      });

      avatarInventoryGrid.appendChild(card);
    });
  }

  // Initial renders
  renderCatalogPage();
  renderAvatarInventory();

  if (navStudio) {
    navStudio.addEventListener('click', (e) => {
      e.preventDefault();
      window.history.pushState({}, '', '#studio');
      loadStudioDashboard();
      showView(studioDashboardView);
    });
  }

  function loadStudioDashboard() {
    apiFetch('/api/studio/games')
      .then(res => res.json())
      .then(data => {
        if (!data.success) return;
        renderStudioGames(currentStudioTab === 'active' ? data.active : data.archived);
      })
      .catch(err => console.error('[Studio] Error loading games:', err));
  }

  if (tabStudioActive && tabStudioArchived) {
    tabStudioActive.addEventListener('click', () => {
      currentStudioTab = 'active';
      tabStudioActive.className = 'btn btn-sm btn-primary';
      tabStudioArchived.className = 'btn btn-sm btn-secondary';
      loadStudioDashboard();
    });
    tabStudioArchived.addEventListener('click', () => {
      currentStudioTab = 'archived';
      tabStudioActive.className = 'btn btn-sm btn-secondary';
      tabStudioArchived.className = 'btn btn-sm btn-primary';
      loadStudioDashboard();
    });
  }

  if (btnCreateNewGame) {
    btnCreateNewGame.addEventListener('click', () => {
      const name = prompt("Enter Game Title:", "My Luau Sandbox");
      if (!name) return;
      apiFetch('/api/studio/games/create', {
        method: 'POST',
        body: JSON.stringify({ name })
      })
      .then(res => res.json())
      .then(data => {
        if (data.success) {
          alert("Game Project Created!");
          loadStudioDashboard();
        }
      });
    });
  }

  function renderStudioGames(games) {
    if (!studioGamesGrid) return;
    studioGamesGrid.innerHTML = '';

    if (!games || games.length === 0) {
      studioGamesGrid.innerHTML = '<div style="color: var(--text-muted); grid-column: 1 / -1; padding: 2rem; text-align: center;">No projects in this tab yet.</div>';
      return;
    }

    games.forEach(game => {
      const card = document.createElement('div');
      card.className = 'place-card';
      card.style.position = 'relative';

      const petsChecked = game.allow_pets !== false ? 'checked' : '';
      const publicChecked = game.is_public !== false ? 'checked' : '';
      const selfHostedChecked = game.self_hosted_servers !== false ? 'checked' : '';

      card.innerHTML = `
        <div class="place-icon" style="background: rgba(30, 41, 59, 0.9); font-size: 2.5rem; display: flex; align-items: center; justify-content: center; height: 120px;">
          ${game.thumbnail_url ? `<img src="${game.thumbnail_url}" style="width:100%;height:100%;object-fit:cover;border-radius:12px;">` : '🎮'}
        </div>
        <div class="place-info" style="padding: 1rem;">
          <input type="text" class="studio-game-name-input" value="${game.name}" style="width:100%; background: #0f172a; border: 1px solid #334155; color: #fff; padding: 6px; border-radius: 6px; font-weight: bold; margin-bottom: 6px;">
          <textarea class="studio-game-desc-input" style="width:100%; background: #0f172a; border: 1px solid #334155; color: #94a3b8; padding: 6px; border-radius: 6px; font-size: 0.85rem; resize: vertical; height: 50px;">${game.description || ''}</textarea>

          <div style="display:flex; flex-direction:column; gap:0.4rem; margin-top: 0.8rem; font-size:0.85rem; color:#cbd5e1;">
            <label style="display:flex; align-items:center; gap:0.5rem; cursor:pointer;">
              <input type="checkbox" class="chk-allow-pets" ${petsChecked}>
              🐾 Allow Pets ON
            </label>
            <label style="display:flex; align-items:center; gap:0.5rem; cursor:pointer;">
              <input type="checkbox" class="chk-public-visibility" ${publicChecked}>
              🌐 Public Visibility
            </label>
            <label style="display:flex; align-items:center; gap:0.5rem; cursor:pointer;">
              <input type="checkbox" class="chk-self-hosted-servers" ${selfHostedChecked}>
              🖥️ Allow Self-Hosted Game Servers
            </label>
          </div>

          <div style="display:grid; grid-template-columns: 1fr 1fr; gap:0.5rem; margin-top: 1rem;">
            <button class="btn btn-sm btn-secondary btn-archive-game">${game.archived ? '📂 Restore' : '📦 Archive'}</button>
            <button class="btn btn-sm btn-primary btn-edit-studio">✏️ Edit in Studio</button>
          </div>
        </div>
      `;

      const nameInput = card.querySelector('.studio-game-name-input');
      const descInput = card.querySelector('.studio-game-desc-input');
      const chkPets = card.querySelector('.chk-allow-pets');
      const chkPublic = card.querySelector('.chk-public-visibility');
      const chkSelfHosted = card.querySelector('.chk-self-hosted-servers');
      const btnArchive = card.querySelector('.btn-archive-game');
      const btnEdit = card.querySelector('.btn-edit-studio');

      nameInput.addEventListener('change', () => {
        apiFetch(`/api/studio/games/${game.id}/update`, {
          method: 'POST',
          body: JSON.stringify({ name: nameInput.value })
        });
      });

      descInput.addEventListener('change', () => {
        apiFetch(`/api/studio/games/${game.id}/update`, {
          method: 'POST',
          body: JSON.stringify({ description: descInput.value })
        });
      });

      chkPets.addEventListener('change', () => {
        apiFetch(`/api/studio/games/${game.id}/pets`, {
          method: 'POST',
          body: JSON.stringify({ allow_pets: chkPets.checked })
        });
      });

      chkPublic.addEventListener('change', () => {
        apiFetch(`/api/studio/games/${game.id}/update`, {
          method: 'POST',
          body: JSON.stringify({ is_public: chkPublic.checked })
        });
      });

      chkSelfHosted.addEventListener('change', () => {
        apiFetch(`/api/studio/games/${game.id}/self-hosted`, {
          method: 'POST',
          body: JSON.stringify({ self_hosted_servers: chkSelfHosted.checked })
        });
      });

      btnArchive.addEventListener('click', () => {
        apiFetch(`/api/studio/games/${game.id}/archive`, { method: 'POST' })
          .then(res => res.json())
          .then(() => loadStudioDashboard());
      });

      btnEdit.addEventListener('click', () => {
        const studioUri = `luani://edit?game_id=${game.id}`;
        window.location.href = studioUri;
      });

      studioGamesGrid.appendChild(card);
    });
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
    const userToPass = currentUser ? currentUser.username : 'Player';
    const isOwner = currentUser ? (currentUser.owner === true || currentUser.owner === 'true') : false;
    const isVerified = currentUser ? (currentUser.verified === true || currentUser.verified === 'true') : false;
    const accParam = encodeURIComponent(JSON.stringify(equippedAccessories));
    const launchUri = `luani://join?server=luani.fyi:7700&username=${encodeURIComponent(userToPass)}&owner=${isOwner}&verified=${isVerified}&avatar_colors=${colorsParam}&accessory_ids=${accParam}`;
    promptInstallOrLaunch(launchUri);
  });

  // --- INSTALL PROMPT TERMINAL MODAL & INTENT PROTOCOL BUILDER ---
  function promptInstallOrLaunch(joinUri) {
    const isAndroid = /Android/i.test(navigator.userAgent);
    if (isAndroid && joinUri.startsWith('luani://join')) {
      const queryPart = joinUri.substring('luani://join'.length);
      joinUri = `intent://join${queryPart}#Intent;scheme=luani;package=com.luani.client;end;`;
    }
    pendingLaunchUri = joinUri;
    window.location.href = joinUri;
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
      if (installPromptModal) installPromptModal.classList.add('hidden');
      if (pendingLaunchUri) {
        const isAndroid = /Android/i.test(navigator.userAgent);
        const originalCustomUri = pendingLaunchUri.includes('#Intent;') 
          ? 'luani://join' + pendingLaunchUri.substring(pendingLaunchUri.indexOf('?'), pendingLaunchUri.indexOf('#Intent;')) 
          : pendingLaunchUri;

        window.location.href = pendingLaunchUri;

        if (isAndroid && pendingLaunchUri.startsWith('intent://')) {
          setTimeout(() => {
            console.log('[Luani Portal] Intent launch fallback trigger to custom scheme:', originalCustomUri);
            window.location.href = originalCustomUri;
          }, 1200);
        }
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
    } else if (window.location.hash === '#privacy' || window.location.pathname === '/privacy') {
      showView(privacyView);
    } else if (window.location.hash === '#catalog' || window.location.pathname === '/catalog') {
      renderCatalogPage();
      showView(catalogView);
    } else if (window.location.hash === '#studio' || window.location.pathname === '/studio') {
      loadStudioDashboard();
      showView(studioDashboardView);
    } else if (window.location.hash === '#downloads' || window.location.pathname === '/downloads') {
      showView(downloadsView);
    } else {
      showView(discoverView);
    }
  }

  // --- AUTH SYSTEM ---
  function checkAuthStatus() {
    const token = getAuthToken();
    const cachedUserRaw = localStorage.getItem('luani_user_session');
    let cachedUser = null;
    try { cachedUser = cachedUserRaw ? JSON.parse(cachedUserRaw) : null; } catch(e) {}

    if (!token && !cachedUser) {
      currentUser = null;
      window.currentUser = null;
      updateAuthUI(null);
      return;
    }

    // Immediately restore cached session so user is never logged off during updates
    if (cachedUser) {
      currentUser = cachedUser;
      window.currentUser = cachedUser;
      updateAuthUI(currentUser);
      fetchFriendsList();
      fetchNotifications();
    }

    apiFetch('/api/auth/me')
    .then(r => r.json())
    .then(data => {
      if (data.success && data.user) {
        currentUser = data.user;
        window.currentUser = data.user;
        localStorage.setItem('luani_user_session', JSON.stringify(data.user));
        updateAuthUI(currentUser);
        fetchFriendsList();
        fetchNotifications();
      } else if (data.success && data.token) {
        setAuthToken(data.token);
      }
    })
    .catch(() => {
      if (cachedUser) {
        currentUser = cachedUser;
        window.currentUser = cachedUser;
        updateAuthUI(currentUser);
        fetchFriendsList();
        fetchNotifications();
      }
    });
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

  if (btnLoginOpen) btnLoginOpen.addEventListener('click', () => openAuthModal(false));
  if (btnRegisterOpen) btnRegisterOpen.addEventListener('click', () => openAuthModal(true));
  if (authModalClose) authModalClose.addEventListener('click', closeAuthModal);

  function openAuthModal(isRegister) {
    isRegisterMode = isRegister;
    if (authModalTitle) authModalTitle.innerText = isRegister ? 'Sign Up for Luani' : 'Log In to Luani';
    if (authSubmitBtn) authSubmitBtn.innerText = isRegister ? 'Create Account' : 'Log In';
    if (authSwitchText) authSwitchText.innerText = isRegister ? 'Already have an account?' : "Don't have an account?";
    if (authSwitchLink) authSwitchLink.innerText = isRegister ? 'Log In' : 'Sign Up';
    if (authErrorMsg) authErrorMsg.classList.add('hidden');
    if (authUsername) authUsername.value = '';
    if (authPassword) authPassword.value = '';
    if (authModal) authModal.classList.remove('hidden');
  }

  function closeAuthModal() {
    if (authModal) authModal.classList.add('hidden');
  }

  if (authSwitchLink) {
    authSwitchLink.addEventListener('click', (e) => {
      e.preventDefault();
      openAuthModal(!isRegisterMode);
    });
  }

  if (authForm) {
    authForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const endpoint = isRegisterMode ? '/api/auth/register' : '/api/auth/login';
      if (authErrorMsg) authErrorMsg.classList.add('hidden');

      apiFetch(endpoint, {
        method: 'POST',
        body: JSON.stringify({
          username: authUsername ? authUsername.value.trim() : '',
          password: authPassword ? authPassword.value : ''
        })
      })
      .then(r => r.json())
      .then(data => {
        if (data.success) {
          setAuthToken(data.token);
          currentUser = data.user;
          window.currentUser = data.user;
          localStorage.setItem('luani_user_session', JSON.stringify(data.user));
          updateAuthUI(currentUser);
          closeAuthModal();
          fetchFriendsList();
        } else if (authErrorMsg) {
          authErrorMsg.innerText = data.error || 'Authentication failed.';
          authErrorMsg.classList.remove('hidden');
        }
      })
      .catch(() => {
        if (authErrorMsg) {
          authErrorMsg.innerText = 'Network error. Please try again.';
          authErrorMsg.classList.remove('hidden');
        }
      });
    });
  }

  // User Profile Dropdown Toggle & Actions
  if (userProfileWidget && userProfileDropdown) {
    userProfileWidget.addEventListener('click', (e) => {
      e.stopPropagation();
      userProfileDropdown.classList.toggle('hidden');
    });
  }

  document.addEventListener('click', () => {
    if (userProfileDropdown) userProfileDropdown.classList.add('hidden');
    if (notificationDropdown) notificationDropdown.classList.add('hidden');
  });

  if (menuViewProfile) {
    menuViewProfile.addEventListener('click', (e) => {
      e.preventDefault();
      if (currentUser) {
        window.history.pushState({}, '', `/?user=${encodeURIComponent(currentUser.username)}`);
        loadUserProfile(currentUser.username);
      }
    });
  }

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

  if (menuEditBio) {
    menuEditBio.addEventListener('click', (e) => {
      e.preventDefault();
      if (currentUser) {
        if (bioInputText) bioInputText.value = currentUser.bio || '';
        if (editBioModal) editBioModal.classList.remove('hidden');
      }
    });
  }

  if (menuLogout) {
    menuLogout.addEventListener('click', (e) => {
      e.preventDefault();
      setAuthToken(null);
      localStorage.removeItem('luani_user_session');
      currentUser = null;
      window.currentUser = null;
      updateAuthUI(null);
      window.location.href = '/';
    });
  }

  if (editBioClose && editBioModal) {
    editBioClose.addEventListener('click', () => editBioModal.classList.add('hidden'));
  }

  if (editBioForm) {
    editBioForm.addEventListener('submit', (e) => {
      e.preventDefault();
      apiFetch('/api/user/description', {
        method: 'POST',
        body: JSON.stringify({ bio: bioInputText ? bioInputText.value : '' })
      })
      .then(r => r.json())
      .then(data => {
        if (data.success) {
          if (currentUser) currentUser.bio = data.bio;
          if (profileBioText) profileBioText.innerText = data.bio;
          if (editBioModal) editBioModal.classList.add('hidden');
        }
      });
    });
  }

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
    const updatedColors = {
      head: colorHead.value,
      torso: colorTorso.value,
      left_arm: colorLeftArm.value,
      right_arm: colorRightArm.value,
      left_leg: colorLeftLeg.value,
      right_leg: colorRightLeg.value
    };

    apiFetch('/api/user/avatar-colors', {
      method: 'POST',
      body: JSON.stringify({ avatar_colors: updatedColors })
    })
    .then(r => r.json())
    .then(data => {
      if (data.success) {
        currentUser.avatar_colors = data.avatar_colors;
        if (window.currentUser) window.currentUser.avatar_colors = data.avatar_colors;
        renderAvatarCircle(userAvatar, currentUser.avatar_colors, currentUser.username);
        avatarSaveSuccess.classList.remove('hidden');
        setTimeout(() => avatarSaveSuccess.classList.add('hidden'), 3000);
      }
    });
  });

  // --- PLACES CATALOG & GAME DETAILS ---
  function fetchPlacesCatalog() {
    apiFetch('/api/places')
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
    apiFetch(`/api/places/${gameId}`)
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
    requestAndLaunchServer('official');
  });

  btnOptionHosted.addEventListener('click', () => {
    serverTypeModal.classList.add('hidden');
    requestAndLaunchServer('hosted');
  });

  function requestAndLaunchServer(type) {
    if (!currentGame) return;

    // Show Game Loading Overlay
    gameLoadingOverlay.classList.remove('hidden');
    loadingSpinner.classList.remove('hidden');
    loadingErrorBox.classList.add('hidden');
    loadingTitleText.innerText = 'Connecting to Server...';
    loadingStatusText.innerText = 'Requesting dynamic server instance from daemon...';

    apiFetch('/api/servers/request', {
      method: 'POST',
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
    apiFetch(`/api/servers/active?placeId=${placeId}`)
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
              const isOwner = currentUser ? (currentUser.owner === true || currentUser.owner === 'true') : false;
              const isVerified = currentUser ? (currentUser.verified === true || currentUser.verified === 'true') : false;
              const colorsParam = currentUser && currentUser.avatar_colors ? encodeURIComponent(JSON.stringify(currentUser.avatar_colors)) : '';
              const joinUri = `luani://join?server=${srv.serverIp}:${srv.serverPort}&auth=${srv.authToken}&username=${encodeURIComponent(currentUser.username)}&owner=${isOwner}&verified=${isVerified}&avatar_colors=${colorsParam}`;
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
    apiFetch(`/api/user/${encodeURIComponent(username)}`)
    .then(r => r.json())
    .then(data => {
      if (data.success && data.user) {
        currentProfileUser = data.user;
        profileUsernameTitle.innerHTML = `${currentProfileUser.username} ${renderUserBadges(currentProfileUser)}`;
        renderAvatarCircle(profileAvatarLarge, currentProfileUser.avatar_colors, currentProfileUser.username);
        profileBioText.innerText = currentProfileUser.bio;

        const btnEditBioInline = document.getElementById('btnEditBioInline');
        const isSelf = currentUser && currentUser.username.toLowerCase() === currentProfileUser.username.toLowerCase();
        if (isSelf) {
          if (profileRelationshipActions) profileRelationshipActions.classList.add('hidden');
          if (btnEditBioInline) btnEditBioInline.classList.remove('hidden');
        } else {
          if (profileRelationshipActions) profileRelationshipActions.classList.remove('hidden');
          if (btnEditBioInline) btnEditBioInline.classList.add('hidden');
        }

        // Render Owner Power Panel if logged-in user is an owner (to moderate ANY user profile)
        const isUserOwner = (currentUser && (currentUser.owner === true || currentUser.owner === 'true')) ||
                            (window.currentUser && (window.currentUser.owner === true || window.currentUser.owner === 'true'));

        if (isUserOwner) {
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
      apiFetch('/api/admin/toggle-verified', {
        method: 'POST',
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
      const newPass = prompt(`Set new password for ${targetUser.username} (leave blank for default temporary password):`);
      apiFetch('/api/admin/reset-password', {
        method: 'POST',
        body: JSON.stringify({ targetUsername: targetUser.username, newPassword: newPass || undefined })
      })
      .then(r => r.json())
      .then(data => alert(data.message));
    };

    btnAdminBanUser.onclick = () => {
      const reason = prompt(`Issue warning / ban for ${targetUser.username}:`, 'Violation of platform rules.');
      if (!reason) return;
      apiFetch('/api/admin/ban-user', {
        method: 'POST',
        body: JSON.stringify({ targetUsername: targetUser.username, reason })
      })
      .then(r => r.json())
      .then(data => alert(data.message));
    };

    // Active Server Monitor for Admin Power Panel
    const adminServerMonitorList = document.getElementById('adminServerMonitorList');
    if (adminServerMonitorList) {
      adminServerMonitorList.innerHTML = '<div class="loading-spinner">Fetching live server list...</div>';
      apiFetch('/api/servers/active')
        .then(r => r.json())
        .then(data => {
          if (data.success && data.servers.length > 0) {
            adminServerMonitorList.innerHTML = '';
            data.servers.forEach(srv => {
              const card = document.createElement('div');
              card.className = 'active-server-card';
              card.style.background = 'rgba(0,0,0,0.3)';
              card.style.padding = '0.8rem';
              card.style.borderRadius = '8px';
              card.style.border = '1px solid var(--border-card)';
              card.innerHTML = `
                <div class="srv-info">
                  <strong>${srv.name}</strong> (${srv.playerCount}/${srv.maxPlayers} players)
                  <div class="srv-sub" style="font-size:0.82rem; color:var(--text-muted);">${srv.serverIp}:${srv.serverPort} - RequestID: ${srv.requestId}</div>
                </div>
                <button class="btn btn-sm btn-primary" style="margin-top:0.4rem;">⚡ Force Join</button>
              `;
              card.querySelector('button').onclick = () => {
                const isOwner = currentUser ? (currentUser.owner === true || currentUser.owner === 'true') : false;
                const isVerified = currentUser ? (currentUser.verified === true || currentUser.verified === 'true') : false;
                const joinUri = `luani://join?server=${srv.serverIp}:${srv.serverPort}&auth=${srv.authToken}&username=${encodeURIComponent(currentUser ? currentUser.username : 'Owner')}&owner=${isOwner}&verified=${isVerified}`;
                promptInstallOrLaunch(joinUri);
              };
              adminServerMonitorList.appendChild(card);
            });
          } else {
            adminServerMonitorList.innerHTML = '<div class="srv-empty" style="font-size:0.9rem; color:var(--text-muted);">No active server instances running across the network.</div>';
          }
        });
    }
  }

  // --- FRIENDS & NOTIFICATIONS ---
  function fetchFriendsList() {
    apiFetch('/api/friends')
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
    apiFetch('/api/notifications')
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

  // --- NOTIFICATION BELL & NAV CLICK LISTENERS ---
  if (notificationBellBtn && notificationDropdown) {
    notificationBellBtn.onclick = (e) => {
      e.stopPropagation();
      notificationDropdown.classList.toggle('hidden');
    };
    document.addEventListener('click', (e) => {
      if (!notificationDropdown.contains(e.target) && e.target !== notificationBellBtn) {
        notificationDropdown.classList.add('hidden');
      }
    });
  }

  const navAvatarLink = document.getElementById('navAvatarLink');
  const navAvatar = document.getElementById('navAvatar');
  [navAvatarLink, navAvatar].forEach(link => {
    if (link) {
      link.onclick = (e) => {
        e.preventDefault();
        if (!currentUser) {
          openAuthModal(false);
          return;
        }
        openAvatarEditor();
      };
    }
  });

  const btnBio = document.getElementById('btnEditBioInline');
  if (btnBio) {
    btnBio.onclick = () => {
      const currentBio = profileBioText ? profileBioText.innerText : '';
      const newBio = prompt('Enter your new profile description / bio:', currentBio);
      if (newBio !== null) {
        apiFetch('/api/user/profile', {
          method: 'POST',
          body: JSON.stringify({ bio: newBio })
        })
        .then(r => r.json())
        .then(data => {
          if (data.success) {
            if (profileBioText) profileBioText.innerText = newBio;
            if (currentUser) currentUser.bio = newBio;
            alert('Profile description updated successfully!');
          }
        });
      }
    };
  }

  // Search input handler & Results Renderer
  function performSearch(q) {
    const query = (q || '').trim();
    if (!query) return;
    searchQueryText.innerText = query;

    apiFetch(`/api/search?q=${encodeURIComponent(query)}`)
      .then(r => r.json())
      .then(data => {
        if (data.success) {
          renderSearchResults(data.places || [], data.users || []);
          showView(searchResultsView);
        }
      });
  }

  function renderSearchResults(matchedPlaces, matchedUsers) {
    if (searchPlacesGrid) {
      searchPlacesGrid.innerHTML = '';
      if (matchedPlaces.length === 0) {
        searchPlacesGrid.innerHTML = '<div class="srv-empty">No matching places found.</div>';
      } else {
        matchedPlaces.forEach(place => {
          const card = document.createElement('div');
          card.className = 'place-card';
          card.innerHTML = `
            <div class="place-thumbnail">🎮</div>
            <div class="place-info">
              <div class="place-title">${place.name}</div>
              <div class="place-creator">by ${place.creator}</div>
              <div class="place-meta"><span>👥 Max ${place.maxPlayers} Players</span></div>
            </div>
          `;
          card.onclick = () => {
            window.history.pushState({}, '', `/?game=${encodeURIComponent(place.id)}`);
            loadGameDetails(place.id);
          };
          searchPlacesGrid.appendChild(card);
        });
      }
    }

    if (searchUsersGrid) {
      searchUsersGrid.innerHTML = '';
      if (matchedUsers.length === 0) {
        searchUsersGrid.innerHTML = '<div class="srv-empty">No matching users found.</div>';
      } else {
        matchedUsers.forEach(u => {
          const card = document.createElement('div');
          card.className = 'user-search-card';
          card.style.background = 'var(--bg-card)';
          card.style.border = '1px solid var(--border-card)';
          card.style.borderRadius = 'var(--radius)';
          card.style.padding = '1rem';
          card.style.display = 'flex';
          card.style.alignItems = 'center';
          card.style.gap = '1rem';
          card.style.cursor = 'pointer';

          const avatarCircle = document.createElement('div');
          avatarCircle.className = 'avatar-circle';
          avatarCircle.style.width = '48px';
          avatarCircle.style.height = '48px';
          renderAvatarCircle(avatarCircle, u.avatar_colors, u.username);

          const userInfo = document.createElement('div');
          userInfo.innerHTML = `
            <div style="font-weight:700; font-size:1.05rem;">${u.username} ${renderUserBadges(u)}</div>
            <div style="font-size:0.85rem; color:var(--text-muted);">${u.bio || 'Luani player'}</div>
          `;

          card.appendChild(avatarCircle);
          card.appendChild(userInfo);
          card.onclick = () => {
            window.history.pushState({}, '', `/?user=${encodeURIComponent(u.username)}`);
            loadUserProfile(u.username);
          };
          searchUsersGrid.appendChild(card);
        });
      }
    }
  }

  if (searchInput) {
    searchInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        performSearch(searchInput.value);
      }
    });

    let searchTimeout = null;
    searchInput.addEventListener('input', () => {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(() => {
        if (searchInput.value.trim().length >= 2) {
          performSearch(searchInput.value);
        }
      }, 400);
    });
  }

});
