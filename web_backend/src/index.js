const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const express = require('express');
const cors = require('cors');
const multer = require('multer');
const fs = require('fs');
const bcrypt = require('bcryptjs');
const { createClient } = require('@supabase/supabase-js');
const ws = require('ws');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// SERVE COMPILED CLIENT BINARY BEFORE STATIC MIDDLEWARE
app.get('/downloads/LuaniClient.x86_64', (req, res) => {
  const binPath = path.resolve(__dirname, '../../bin/LuaniClient.x86_64');
  if (fs.existsSync(binPath)) {
    res.setHeader('Content-Type', 'application/octet-stream');
    return res.sendFile(binPath);
  }
  const localProject = path.resolve(__dirname, '../../client_and_studio');
  res.setHeader('Content-Type', 'application/x-sh');
  res.send(`#!/usr/bin/env bash
echo "[Luani Client Runner] Launching Luani Game Client for URI: $1"
godot --path "${localProject}" -- "$1"
`);
});

// Serve static APK downloads with strict no-cache headers
app.use('/downloads', express.static(path.join(__dirname, '../public/downloads'), {
  setHeaders: (res, filePath) => {
    if (filePath.endsWith('.apk')) {
      res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
      res.setHeader('Content-Type', 'application/vnd.android.package-archive');
    }
  }
}));

// Serve static web portal frontend
app.use(express.static(path.join(__dirname, '../public')));

// SERVE 1-COMMAND INSTALLER SCRIPT
app.get('/install.sh', (req, res) => {
  const scriptPath = path.resolve(__dirname, '../../scripts/install.sh');
  if (fs.existsSync(scriptPath)) {
    res.setHeader('Content-Type', 'text/plain');
    return res.sendFile(scriptPath);
  }
  res.status(404).send('#!/bin/bash\necho "Error: install.sh not found on server."\nexit 1\n');
});

// Initialize Supabase Client
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

const isUnconfigured = !supabaseUrl || !supabaseKey ||
  supabaseUrl.includes('YOUR-PROJECT-ID') ||
  supabaseUrl.includes('YOUR-PROJECT-REF') ||
  supabaseKey.includes('YOUR_SECRET_KEY');

const supabase = !isUnconfigured ? createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: false },
  realtime: {
    transport: ws,
  },
}) : null;

if (!supabase) {
  console.log('[Supabase] ⚠️ Credentials unconfigured in .env. Operating in Local Memory Mode.');
} else {
  console.log('[Supabase] Initializing connection to:', supabaseUrl);
  supabase.from('users').select('id').limit(1).then(({ data, error }) => {
    if (error) {
      console.log('[Supabase] ❌ Connection failed:', error.message);
    } else {
      console.log('[Supabase] ✅ Connected to Supabase PostgreSQL successfully!');
    }
  });
}

// Memory stores
const users = [];
const sessions = new Map();
const friendRequests = [];
const friendships = new Set();
const blockList = new Set();

// Default Places Catalog
const places = [
  {
    id: 'place_sword_arena',
    name: 'Sword Fighting Arena',
    creator: 'Luani Team',
    description: 'Engage in fast-paced sword combat! Equip your sword (Key 1), swing with Left-Click, and fight for victory.',
    maxPlayers: 16,
    version: 1,
    format_version: 1,
    parts: []
  },
  {
    id: 'place_default_01',
    name: 'Luani Starter World',
    creator: 'Luani Team',
    description: 'Welcome to the Luani platform default sandbox world.',
    maxPlayers: 10,
    version: 1,
    format_version: 1,
    parts: [
      {
        name: "Baseplate",
        primitive_type: 0,
        position: [0, -0.5, 0],
        rotation: [0, 0, 0],
        scale: [30, 0.5, 30],
        anchored: true,
        color: [0.2, 0.25, 0.35, 1.0]
      },
      {
        name: "WelcomeBlock",
        primitive_type: 0,
        position: [0, 2, 0],
        rotation: [0, 0, 0],
        scale: [2, 2, 2],
        anchored: true,
        color: [0.9, 0.4, 0.2, 1.0],
        luau_script: "print('Welcome to Luani Starter World!')\nrotate_y(15)"
      }
    ]
  },
  {
    id: 'place_demo_02',
    name: 'Speedway Track',
    creator: 'Luani Team',
    description: 'High speed physics racing sandbox world.',
    maxPlayers: 10,
    version: 1,
    format_version: 1,
    parts: [
      {
        name: "Baseplate",
        primitive_type: 0,
        position: [0, -0.5, 0],
        rotation: [0, 0, 0],
        scale: [50, 0.5, 50],
        anchored: true,
        color: [0.15, 0.18, 0.2, 1.0]
      }
    ]
  }
];

// Active Game Servers List
const activeServers = [];

// Stale & Empty Server Cleanup Routine (runs every 10 seconds)
setInterval(() => {
  const now = Date.now();
  for (let i = activeServers.length - 1; i >= 0; i--) {
    const srv = activeServers[i];
    const isStale = srv.lastHeartbeat && (now - srv.lastHeartbeat > 30000);
    const isEmpty = srv.playerCount <= 0 && (now - new Date(srv.launchedAt).getTime() > 15000);

    if (isEmpty || isStale) {
      console.log(`[Luani Matchmaker] Purged inactive/empty server instance: ${srv.name} (${srv.requestId})`);
      activeServers.splice(i, 1);
    }
  }
}, 10000);

// Storage for uploaded place PCK / JSON files
const uploadsDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const placeId = req.body.placeId || `place_${Date.now()}`;
    cb(null, `${placeId}.pck`);
  }
});
const upload = multer({ storage });

// Helper: Extract user from Bearer Token
function getAuthUser(req) {
  const authHeader = req.headers.authorization;
  const token = authHeader ? authHeader.replace('Bearer ', '') : req.query.token;
  if (token && sessions.has(token)) {
    const sess = sessions.get(token);
    return users.find(u => u.id === sess.id) || null;
  }
  return null;
}

// --- API ROUTES ---

// Healthcheck
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'luani-web-backend',
    domain: 'luani.fyi',
    supabaseConfigured: !!supabase,
    activeServersCount: activeServers.length,
    timestamp: new Date().toISOString()
  });
});

// Website Version Indicator Endpoint
app.get('/api/version', (req, res) => {
  res.json({
    success: true,
    version: '0.2.10',
    timestamp: new Date().toISOString()
  });
});

const DEFAULT_AVATAR_COLORS = {
  head: "#e0ac69",
  torso: "#0000ff",
  left_arm: "#e0ac69",
  right_arm: "#e0ac69",
  left_leg: "#00ff00",
  right_leg: "#00ff00"
};

// AUTH SYSTEM (Username + Password only, no email)
app.post('/api/auth/register', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ success: false, error: 'Username and password are required.' });
  }

  const cleanName = username.trim();

  if (supabase) {
    try {
      const { data: existing, error } = await supabase.from('users').select('id').eq('username', cleanName).single();
      if (error && error.code !== 'PGRST116') {
        console.error('[Supabase Auth Error]:', error.message);
      }
      if (existing) {
        return res.status(400).json({ success: false, error: 'Username is already taken.' });
      }
    } catch (e) {
      console.error('[Supabase Auth Error]:', e.message || e);
    }
  } else {
    const existing = users.find(u => u.username.toLowerCase() === cleanName.toLowerCase());
    if (existing) {
      return res.status(400).json({ success: false, error: 'Username is already taken.' });
    }
  }

  const hashedPassword = bcrypt.hashSync(password, 10);
  const isOwner = cleanName.toLowerCase() === 'owner' || cleanName.toLowerCase() === 'admin';
  const newUser = {
    id: `usr_${Date.now()}`,
    username: cleanName,
    password: hashedPassword,
    bio: `Hello! I am ${cleanName} on Luani.`,
    owner: isOwner,
    verified: isOwner,
    avatar_colors: { ...DEFAULT_AVATAR_COLORS },
    createdAt: new Date().toISOString()
  };

  if (supabase) {
    try {
      const { data, error } = await supabase
        .from('users')
        .insert([{
          username: cleanName,
          password_hash: hashedPassword,
          bio: newUser.bio,
          avatar_url: '',
          owner: isOwner,
          verified: isOwner,
          avatar_colors: newUser.avatar_colors
        }])
        .select();

      if (error) {
        console.error('[Supabase Auth Error]:', error.message);
      } else {
        console.log(`[Supabase Auth] Saved new user to Supabase: ${cleanName}`);
        if (data && data[0] && data[0].id) {
          newUser.id = data[0].id;
        }
      }
    } catch (err) {
      console.error('[Supabase Auth Error]:', err.message || err);
    }
  } else {
    console.log(`[Local Auth] Registered user: ${newUser.username}`);
  }

  users.push(newUser);
  const token = `luani_token_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  sessions.set(token, { id: newUser.id, username: newUser.username });

  res.json({
    success: true,
    token,
    user: {
      id: newUser.id,
      username: newUser.username,
      bio: newUser.bio,
      owner: newUser.owner,
      verified: newUser.verified,
      avatar_colors: newUser.avatar_colors
    }
  });
});

app.post('/api/auth/login', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ success: false, error: 'Username and password are required.' });
  }

  let user = users.find(u => u.username.toLowerCase() === username.trim().toLowerCase() && (bcrypt.compareSync(password, u.password) || u.password === password));

  if (!user && supabase) {
    try {
      const { data: dbUser, error } = await supabase
        .from('users')
        .select('*')
        .eq('username', username.trim())
        .single();

      if (error) {
        console.error('[Supabase Auth Error]:', error.message);
      }

      if (dbUser && dbUser.password_hash) {
        const matches = bcrypt.compareSync(password, dbUser.password_hash) || dbUser.password_hash === password;
        if (matches) {
          user = {
            id: dbUser.id,
            username: dbUser.username,
            password: dbUser.password_hash,
            bio: dbUser.bio || '',
            owner: !!dbUser.owner,
            verified: !!dbUser.verified,
            avatar_colors: dbUser.avatar_colors || { ...DEFAULT_AVATAR_COLORS },
            createdAt: dbUser.created_at
          };
          if (!users.find(u => u.id === user.id)) {
            users.push(user);
          }
          console.log(`[Supabase Auth] Logged in user: ${user.username}`);
        }
      }
    } catch (err) {
      console.error('[Supabase Auth Error]:', err.message || err);
    }
  }

  if (!user) {
    return res.status(401).json({ success: false, error: 'Invalid username or password.' });
  }

  const token = `luani_token_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  sessions.set(token, { id: user.id, username: user.username });

  if (supabase) {
    console.log(`[Supabase Auth] Logged in user: ${user.username}`);
  } else {
    console.log(`[Local Auth] Logged in user: ${user.username}`);
  }

  res.json({
    success: true,
    token,
    user: {
      id: user.id,
      username: user.username,
      bio: user.bio,
      owner: !!user.owner,
      verified: !!user.verified,
      avatar_colors: user.avatar_colors || { ...DEFAULT_AVATAR_COLORS }
    }
  });
});

app.get('/api/auth/me', (req, res) => {
  const user = getAuthUser(req);
  if (user) {
    return res.json({
      success: true,
      user: {
        id: user.id,
        username: user.username,
        bio: user.bio,
        owner: !!user.owner,
        verified: !!user.verified,
        avatar_colors: user.avatar_colors || { ...DEFAULT_AVATAR_COLORS }
      }
    });
  }
  res.status(401).json({ success: false, error: 'Not authenticated.' });
});

// USER PROFILE & DESCRIPTION BIO EDITING
app.get('/api/user/:username', async (req, res) => {
  const targetUsername = req.params.username;
  let targetUser = users.find(u => u.username.toLowerCase() === targetUsername.toLowerCase());

  if (!targetUser && supabase) {
    try {
      const { data } = await supabase.from('users').select('*').eq('username', targetUsername).single();
      if (data) {
        targetUser = {
          id: data.id,
          username: data.username,
          bio: data.bio || '',
          owner: !!data.owner,
          verified: !!data.verified,
          avatar_colors: data.avatar_colors || { ...DEFAULT_AVATAR_COLORS },
          createdAt: data.created_at
        };
        users.push(targetUser);
      }
    } catch (err) {
      console.warn('[Supabase] Fetch user error:', err);
    }
  }

  if (!targetUser) {
    return res.status(404).json({ success: false, error: 'User not found.' });
  }

  const currentUser = getAuthUser(req);
  let isFriend = false;
  let isPending = false;
  let isBlocked = false;

  if (currentUser) {
    const pair1 = `${currentUser.id}_${targetUser.id}`;
    const pair2 = `${targetUser.id}_${currentUser.id}`;
    isFriend = friendships.has(pair1) || friendships.has(pair2);
    isBlocked = blockList.has(`${currentUser.id}_${targetUser.id}`);

    const pendingReq = friendRequests.find(r =>
      r.status === 'PENDING' &&
      ((r.fromUserId === currentUser.id && r.toUserId === targetUser.id) || (r.fromUserId === targetUser.id && r.toUserId === currentUser.id))
    );
    if (pendingReq) isPending = true;
  }

  res.json({
    success: true,
    user: {
      id: targetUser.id,
      username: targetUser.username,
      bio: targetUser.bio || `Welcome to ${targetUser.username}'s profile.`,
      owner: !!targetUser.owner,
      verified: !!targetUser.verified,
      avatar_colors: targetUser.avatar_colors || { ...DEFAULT_AVATAR_COLORS },
      createdAt: targetUser.createdAt,
      isFriend,
      isPending,
      isBlocked
    }
  });
});

// AVATAR COLOR CUSTOMIZATION ENDPOINT
app.post('/api/user/avatar-colors', async (req, res) => {
  const user = getAuthUser(req);
  if (!user) {
    return res.status(401).json({ success: false, error: 'Must be logged in to update avatar colors.' });
  }

  const { avatar_colors } = req.body;
  if (!avatar_colors || typeof avatar_colors !== 'object') {
    return res.status(400).json({ success: false, error: 'Invalid avatar_colors object payload.' });
  }

  user.avatar_colors = {
    head: avatar_colors.head || DEFAULT_AVATAR_COLORS.head,
    torso: avatar_colors.torso || DEFAULT_AVATAR_COLORS.torso,
    left_arm: avatar_colors.left_arm || DEFAULT_AVATAR_COLORS.left_arm,
    right_arm: avatar_colors.right_arm || DEFAULT_AVATAR_COLORS.right_arm,
    left_leg: avatar_colors.left_leg || DEFAULT_AVATAR_COLORS.left_leg,
    right_leg: avatar_colors.right_leg || DEFAULT_AVATAR_COLORS.right_leg
  };

  if (supabase) {
    try {
      await supabase.from('users').update({ avatar_colors: user.avatar_colors }).eq('id', user.id);
    } catch (err) {
      console.warn('[Supabase] Update avatar_colors error:', err);
    }
  }

  console.log(`[Luani User] Updated avatar colors for ${user.username}`);
  res.json({ success: true, message: 'Avatar colors updated.', avatar_colors: user.avatar_colors });
});

// ADMIN / OWNER POWER PANEL ENDPOINTS
app.post('/api/admin/toggle-verified', async (req, res) => {
  const user = getAuthUser(req);
  if (!user || !user.owner) {
    return res.status(403).json({ success: false, error: 'Access denied. Owner privileges required.' });
  }

  const { targetUsername, verified } = req.body;
  const targetUser = users.find(u => u.username.toLowerCase() === (targetUsername || '').toLowerCase());
  if (!targetUser) {
    return res.status(404).json({ success: false, error: 'Target user not found.' });
  }

  targetUser.verified = typeof verified === 'boolean' ? verified : !targetUser.verified;

  if (supabase) {
    try {
      await supabase.from('users').update({ verified: targetUser.verified }).eq('id', targetUser.id);
    } catch (err) {
      console.warn('[Supabase] Update verified error:', err);
    }
  }

  console.log(`[Luani Admin] Owner ${user.username} toggled verified status for ${targetUser.username} to: ${targetUser.verified}`);
  res.json({ success: true, message: `Verified status updated for ${targetUser.username}.`, verified: targetUser.verified });
});

app.post('/api/admin/ban-user', (req, res) => {
  const user = getAuthUser(req);
  if (!user || !user.owner) {
    return res.status(403).json({ success: false, error: 'Access denied. Owner privileges required.' });
  }

  const { targetUsername, reason } = req.body;
  const targetUser = users.find(u => u.username.toLowerCase() === (targetUsername || '').toLowerCase());
  if (!targetUser) {
    return res.status(404).json({ success: false, error: 'Target user not found.' });
  }

  targetUser.isBanned = true;
  targetUser.banReason = reason || 'Violation of platform rules.';
  console.log(`[Luani Admin] Owner ${user.username} issued ban/warning to ${targetUser.username}: ${targetUser.banReason}`);
  res.json({ success: true, message: `Action applied to user ${targetUser.username}.` });
});

app.post('/api/admin/reset-password', async (req, res) => {
  const user = getAuthUser(req);
  if (!user || !user.owner) {
    return res.status(403).json({ success: false, error: 'Access denied. Owner privileges required.' });
  }

  const { targetUsername, newPassword } = req.body;
  const targetUser = users.find(u => u.username.toLowerCase() === (targetUsername || '').toLowerCase());
  if (!targetUser) {
    return res.status(404).json({ success: false, error: 'Target user not found.' });
  }

  const passToSet = newPassword || 'LuaniReset123!';
  targetUser.password = bcrypt.hashSync(passToSet, 10);

  if (supabase) {
    try {
      await supabase.from('users').update({ password_hash: targetUser.password }).eq('id', targetUser.id);
    } catch (err) {
      console.warn('[Supabase] Reset password error:', err);
    }
  }

  console.log(`[Luani Admin] Owner ${user.username} reset password for ${targetUser.username}`);
  res.json({ success: true, message: `Password reset for ${targetUser.username}. Temporary password: ${passToSet}` });
});

app.post('/api/user/description', async (req, res) => {
  const user = getAuthUser(req);
  if (!user) {
    return res.status(401).json({ success: false, error: 'Must be logged in to update profile bio.' });
  }

  const { bio } = req.body;
  user.bio = (bio || '').trim();

  if (supabase) {
    try {
      await supabase.from('users').update({ bio: user.bio }).eq('id', user.id);
    } catch (err) {
      console.warn('[Supabase] Update bio error:', err);
    }
  }

  console.log(`[Luani User] Updated bio for ${user.username}`);
  res.json({ success: true, message: 'Profile description updated.', bio: user.bio });
});

// FRIENDS & NOTIFICATION SYSTEM
app.get('/api/friends', (req, res) => {
  const user = getAuthUser(req);
  if (!user) {
    return res.json({ success: true, friends: [] });
  }

  const userFriends = users.filter(u => {
    if (u.id === user.id) return false;
    return friendships.has(`${user.id}_${u.id}`) || friendships.has(`${u.id}_${user.id}`);
  }).map(u => ({
    id: u.id,
    username: u.username,
    status: 'ONLINE',
    game: 'Luani Starter World',
    serverIp: '127.0.0.1',
    serverPort: 7777
  }));

  res.json({ success: true, friends: userFriends });
});

app.get('/api/notifications', (req, res) => {
  const user = getAuthUser(req);
  if (!user) {
    return res.json({ success: true, pendingRequests: [] });
  }

  const pending = friendRequests.filter(r => r.toUserId === user.id && r.status === 'PENDING');
  res.json({ success: true, pendingRequests: pending });
});

app.post('/api/friends/request', async (req, res) => {
  const user = getAuthUser(req);
  if (!user) {
    return res.status(401).json({ success: false, error: 'Must be logged in.' });
  }

  const { targetUsername } = req.body;
  const targetUser = users.find(u => u.username.toLowerCase() === (targetUsername || '').toLowerCase());
  if (!targetUser) {
    return res.status(404).json({ success: false, error: 'Target user not found.' });
  }

  if (targetUser.id === user.id) {
    return res.status(400).json({ success: false, error: 'Cannot friend yourself.' });
  }

  const reqId = `freq_${Date.now()}`;
  const newReq = {
    id: reqId,
    fromUserId: user.id,
    fromUsername: user.username,
    toUserId: targetUser.id,
    toUsername: targetUser.username,
    status: 'PENDING',
    createdAt: new Date().toISOString()
  };

  if (supabase) {
    try {
      await supabase.from('friend_requests').insert([
        { id: reqId, from_user_id: user.id, to_user_id: targetUser.id, status: 'PENDING' }
      ]);
    } catch (err) {
      console.warn('[Supabase] Friend request insert failed:', err);
    }
  }

  friendRequests.push(newReq);
  res.json({ success: true, message: `Friend request sent to ${targetUser.username}.` });
});

app.post('/api/friends/respond', (req, res) => {
  const user = getAuthUser(req);
  if (!user) {
    return res.status(401).json({ success: false, error: 'Must be logged in.' });
  }

  const { requestId, accept } = req.body;
  const freq = friendRequests.find(r => r.id === requestId && r.toUserId === user.id);

  if (!freq) {
    return res.status(404).json({ success: false, error: 'Friend request not found.' });
  }

  freq.status = accept ? 'ACCEPTED' : 'DECLINED';
  if (accept) {
    friendships.add(`${freq.fromUserId}_${freq.toUserId}`);
  }

  res.json({ success: true, message: accept ? 'Accepted friend request.' : 'Declined friend request.' });
});

app.post('/api/user/unfriend', (req, res) => {
  const user = getAuthUser(req);
  if (!user) {
    return res.status(401).json({ success: false, error: 'Must be logged in.' });
  }

  const { targetUsername } = req.body;
  const targetUser = users.find(u => u.username.toLowerCase() === (targetUsername || '').toLowerCase());
  if (targetUser) {
    friendships.delete(`${user.id}_${targetUser.id}`);
    friendships.delete(`${targetUser.id}_${user.id}`);
  }
  res.json({ success: true, message: 'Unfriended user.' });
});

app.post('/api/user/block', (req, res) => {
  const user = getAuthUser(req);
  if (!user) {
    return res.status(401).json({ success: false, error: 'Must be logged in.' });
  }

  const { targetUsername } = req.body;
  const targetUser = users.find(u => u.username.toLowerCase() === (targetUsername || '').toLowerCase());
  if (targetUser) {
    blockList.add(`${user.id}_${targetUser.id}`);
    friendships.delete(`${user.id}_${targetUser.id}`);
    friendships.delete(`${targetUser.id}_${user.id}`);
  }
  res.json({ success: true, message: 'Blocked user.' });
});

const PUBLIC_DOMAIN = process.env.PUBLIC_DOMAIN || 'luani.fyi';

let lastDaemonConfig = {
  publicHost: PUBLIC_DOMAIN,
  publicPort: null
};

function getPublicServerIp(rawIp) {
  if (!rawIp || rawIp === '127.0.0.1' || rawIp === 'localhost' || rawIp === '0.0.0.0' || rawIp === '::1') {
    return lastDaemonConfig.publicHost || PUBLIC_DOMAIN;
  }
  return rawIp;
}

// GLOBAL SEARCH SYSTEM (Places + Users)
app.get('/api/search', async (req, res) => {
  const query = (req.query.q || '').trim();
  const lowerQuery = query.toLowerCase();

  const matchedPlaces = places.filter(p =>
    p.name.toLowerCase().includes(lowerQuery) ||
    p.creator.toLowerCase().includes(lowerQuery) ||
    p.description.toLowerCase().includes(lowerQuery)
  );

  let matchedUsers = users.filter(u => u.username.toLowerCase().includes(lowerQuery)).map(u => ({
    id: u.id,
    username: u.username,
    bio: u.bio || '',
    owner: !!u.owner,
    verified: !!u.verified,
    avatar_colors: u.avatar_colors || DEFAULT_AVATAR_COLORS
  }));

  if (supabase && query) {
    try {
      const { data, error } = await supabase
        .from('users')
        .select('id, username, bio, avatar_colors, owner, verified')
        .ilike('username', `%${query}%`);

      if (!error && data) {
        data.forEach(dbUser => {
          if (!matchedUsers.some(u => u.username.toLowerCase() === dbUser.username.toLowerCase())) {
            matchedUsers.push({
              id: dbUser.id,
              username: dbUser.username,
              bio: dbUser.bio || '',
              owner: !!dbUser.owner,
              verified: !!dbUser.verified,
              avatar_colors: dbUser.avatar_colors || DEFAULT_AVATAR_COLORS
            });
          }
        });
      }
    } catch (err) {
      console.warn('[Supabase Search Error]:', err);
    }
  }

  res.json({ success: true, query, places: matchedPlaces, users: matchedUsers });
});

// ACTIVE MULTIPLAYER SERVERS LIST (Returns non-empty or spawning live active servers with public serverIp fallback)
app.get('/api/servers/active', (req, res) => {
  const placeId = req.query.placeId;
  let running = activeServers.filter(s => (s.status === 'RUNNING' || s.status === 'SPAWNING') && (s.playerCount > 0 || s.status === 'SPAWNING'));
  if (placeId) {
    running = running.filter(s => s.placeId === placeId);
  }

  const mapped = running.map(s => ({
    ...s,
    serverIp: getPublicServerIp(s.serverIp)
  }));

  res.json({ success: true, count: mapped.length, servers: mapped });
});

// Game / Place Listings
app.get('/api/places', (req, res) => {
  res.json({ success: true, count: places.length, places });
});

// Get Specific Place Data by ID
app.get('/api/places/:id', (req, res) => {
  const placeId = req.params.id;
  const found = places.find(p => p.id === placeId);
  if (found) {
    return res.json({ success: true, place: found });
  }

  res.json({
    success: true,
    place: {
      id: placeId,
      name: `Luani Dynamic World (${placeId})`,
      creator: 'Luani Team',
      description: 'Dynamic sandbox place instance.',
      maxPlayers: 10,
      format_version: 1,
      parts: [
        {
          name: "Baseplate",
          primitive_type: 0,
          position: [0, -0.5, 0],
          rotation: [0, 0, 0],
          scale: [30, 0.5, 30],
          anchored: true,
          color: [0.25, 0.3, 0.4, 1.0]
        }
      ]
    }
  });
});

// DIRECT PLACE JOIN ENDPOINT (Uses daemon publicHost & publicPort)
app.get('/api/places/join/:placeId', (req, res) => {
  const placeId = req.params.placeId;
  const running = activeServers.filter(s => (s.status === 'RUNNING' || s.status === 'SPAWNING') && s.placeId === placeId);

  if (running.length === 0) {
    return res.status(404).json({ success: false, error: "No active game server instance online for this place." });
  }

  const srv = running[0];
  const publicHost = getPublicServerIp(srv.serverIp);
  const publicPort = srv.serverPort;

  const user = getAuthUser(req);
  const playerUsername = user ? user.username : 'Player';
  const isOwner = user ? !!user.owner : false;
  const isVerified = user ? !!user.verified : false;
  const colorParam = encodeURIComponent(JSON.stringify(user && user.avatar_colors ? user.avatar_colors : DEFAULT_AVATAR_COLORS));

  const joinUri = `luani://join?server=${publicHost}:${publicPort}&auth=${srv.authToken}&username=${encodeURIComponent(playerUsername)}&owner=${isOwner}&verified=${isVerified}&avatar_colors=${colorParam}`;

  res.json({
    success: true,
    server_ip: publicHost,
    server_port: publicPort,
    joinUri
  });
});

// Publish Place file from Luani Studio
app.post('/api/places/publish', upload.single('placeFile'), (req, res) => {
  const { name, creator, description, maxPlayers, parts } = req.body;
  const placeId = `place_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

  let parsedParts = [];
  if (parts) {
    try {
      parsedParts = typeof parts === 'string' ? JSON.parse(parts) : parts;
    } catch (e) {
      console.warn('[Luani Web Backend] Could not parse parts JSON payload.');
    }
  }

  const newPlace = {
    id: placeId,
    name: name || 'Untitled Place',
    creator: creator || 'Anonymous Creator',
    description: description || '',
    maxPlayers: parseInt(maxPlayers) || 10,
    filePath: req.file ? req.file.path : null,
    createdAt: new Date().toISOString(),
    format_version: 1,
    parts: parsedParts
  };

  places.push(newPlace);

  // Save game file to disk: web_backend/games/<game_id>/game.json
  try {
    const gameDir = path.resolve(__dirname, `../games/${placeId}`);
    if (!fs.existsSync(gameDir)) {
      fs.mkdirSync(gameDir, { recursive: true });
    }
    fs.writeFileSync(path.join(gameDir, 'game.json'), JSON.stringify(newPlace, null, 2), 'utf8');
    console.log(`[Luani Studio] Saved game instance file to web_backend/games/${placeId}/game.json`);
  } catch (e) {
    console.error('[Luani Studio] Error writing game file to disk:', e.getMessage ? e.getMessage() : e);
  }

  console.log(`[Luani Web Backend] Published place file: ${newPlace.name} (${newPlace.id})`);

  res.json({
    success: true,
    message: 'Place published successfully to luani.fyi backend.',
    place: newPlace
  });
});

// LUANI STUDIO CREATOR PORTAL ENDPOINTS
app.get('/api/studio/games', (req, res) => {
  const user = getAuthUser(req);
  const username = user ? user.username : 'Guest';

  // Filter creator games or default sample games
  const userGames = places.filter(p => p.creator === username || p.creator === 'Luani Team' || p.creator === 'Anonymous Creator');
  const active = userGames.filter(g => !g.archived);
  const archived = userGames.filter(g => !!g.archived);

  res.json({ success: true, active, archived });
});

app.post('/api/studio/games/create', (req, res) => {
  const user = getAuthUser(req);
  const creator = user ? user.username : 'GuestCreator';
  const { name, description, thumbnail_url, allow_pets } = req.body;
  const placeId = `place_${Date.now()}_${Math.floor(Math.random() * 1000)}`;

  const newGame = {
    id: placeId,
    name: name || 'My New Luau Sandbox',
    creator,
    description: description || 'Built with Luani Studio.',
    thumbnail_url: thumbnail_url || '',
    is_public: true,
    archived: false,
    allow_pets: allow_pets !== undefined ? !!allow_pets : true,
    maxPlayers: 10,
    createdAt: new Date().toISOString(),
    format_version: 1,
    parts: [
      {
        name: "Baseplate",
        primitive_type: 0,
        position: [0, -0.5, 0],
        rotation: [0, 0, 0],
        scale: [50, 0.5, 50],
        anchored: true,
        color: [0.2, 0.25, 0.35, 1.0]
      }
    ]
  };

  places.push(newGame);

  try {
    const gameDir = path.resolve(__dirname, `../games/${placeId}`);
    if (!fs.existsSync(gameDir)) fs.mkdirSync(gameDir, { recursive: true });
    fs.writeFileSync(path.join(gameDir, 'game.json'), JSON.stringify(newGame, null, 2), 'utf8');
  } catch (e) {
    console.error('[Luani Studio] Error writing new game file to disk:', e);
  }

  res.json({ success: true, message: 'Game project created successfully.', place: newGame });
});

app.post('/api/studio/games/:id/update', (req, res) => {
  const placeId = req.params.id;
  const { name, description, thumbnail_url, is_public } = req.body;
  const place = places.find(p => p.id === placeId);

  if (!place) {
    return res.status(404).json({ success: false, error: 'Game not found.' });
  }

  if (name !== undefined) place.name = name;
  if (description !== undefined) place.description = description;
  if (thumbnail_url !== undefined) place.thumbnail_url = thumbnail_url;
  if (is_public !== undefined) place.is_public = !!is_public;

  try {
    const gameDir = path.resolve(__dirname, `../games/${placeId}`);
    if (!fs.existsSync(gameDir)) fs.mkdirSync(gameDir, { recursive: true });
    fs.writeFileSync(path.join(gameDir, 'game.json'), JSON.stringify(place, null, 2), 'utf8');
  } catch (e) { }

  res.json({ success: true, message: 'Game updated successfully.', place });
});

app.post('/api/studio/games/:id/archive', (req, res) => {
  const placeId = req.params.id;
  const place = places.find(p => p.id === placeId);

  if (!place) {
    return res.status(404).json({ success: false, error: 'Game not found.' });
  }

  place.archived = !place.archived;
  if (place.archived) {
    place.is_public = false; // Archiving automatically sets visibility to private
  }

  try {
    const gameDir = path.resolve(__dirname, `../games/${placeId}`);
    if (!fs.existsSync(gameDir)) fs.mkdirSync(gameDir, { recursive: true });
    fs.writeFileSync(path.join(gameDir, 'game.json'), JSON.stringify(place, null, 2), 'utf8');
  } catch (e) { }

  res.json({ success: true, message: place.archived ? 'Game archived.' : 'Game restored from archive.', place });
});

app.post('/api/studio/games/:id/pets', (req, res) => {
  const placeId = req.params.id;
  const place = places.find(p => p.id === placeId);

  if (!place) {
    return res.status(404).json({ success: false, error: 'Game not found.' });
  }

  place.allow_pets = req.body.allow_pets !== undefined ? !!req.body.allow_pets : !place.allow_pets;

  try {
    const gameDir = path.resolve(__dirname, `../games/${placeId}`);
    if (!fs.existsSync(gameDir)) fs.mkdirSync(gameDir, { recursive: true });
    fs.writeFileSync(path.join(gameDir, 'game.json'), JSON.stringify(place, null, 2), 'utf8');
  } catch (e) { }

  res.json({ success: true, message: `Pets setting set to ${place.allow_pets}.`, allow_pets: place.allow_pets, place });
});

// MATCHMAKING ENGINE: Request Server Join or Spin-up
app.post('/api/servers/request', (req, res) => {
  const { placeId, serverType, username, avatar } = req.body;

  if (!placeId) {
    return res.status(400).json({ success: false, error: 'Missing placeId parameter.' });
  }

  const targetType = serverType === 'hosted' ? 'hosted' : 'official';
  const playerUsername = (username || 'Player').trim();
  const playerAvatar = avatar || '';

  const user = getAuthUser(req);
  const playerAvatarColors = (user && user.avatar_colors) ? user.avatar_colors : DEFAULT_AVATAR_COLORS;
  const isOwner = user ? !!user.owner : false;
  const isVerified = user ? !!user.verified : false;
  const colorParam = encodeURIComponent(JSON.stringify(playerAvatarColors));

  // 1. Check for existing active server with capacity (current_players < max_players)
  const existingServer = activeServers.find(s =>
    s.placeId === placeId &&
    s.serverType === targetType &&
    (s.status === 'RUNNING' || s.status === 'SPAWNING') &&
    s.playerCount < s.maxPlayers
  );

  if (existingServer) {
    existingServer.playerCount += 1;
    existingServer.lastHeartbeat = Date.now();
    const publicIp = getPublicServerIp(existingServer.serverIp);
    const activePort = existingServer.serverPort;
    console.log(`[Luani Matchmaker] Reusing open ${targetType} server instance: ${existingServer.name} (${existingServer.playerCount}/${existingServer.maxPlayers} players) on ${publicIp}:${activePort}`);

    const joinUri = `luani://join?server=${publicIp}:${activePort}&auth=${existingServer.authToken}&username=${encodeURIComponent(playerUsername)}&avatar=${encodeURIComponent(playerAvatar)}&avatar_colors=${colorParam}&owner=${isOwner}&verified=${isVerified}`;

    return res.json({
      success: true,
      reused: true,
      requestId: existingServer.requestId,
      server: { ...existingServer, serverIp: publicIp, serverPort: activePort },
      joinUri
    });
  }

  // 2. Spawn new server instance if no open server exists or all are full
  const placeObj = places.find(p => p.id === placeId);
  const placeName = placeObj ? placeObj.name : placeId;
  const isOfficial = targetType === 'official';
  const serverName = isOfficial ? `${playerUsername}@server${Date.now()}q` : `${playerUsername}'s Hosted Server`;

  const requestId = `req_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
  const basePort = 7700 + (activeServers.length % 100);
  const assignedHost = lastDaemonConfig.publicHost || PUBLIC_DOMAIN;
  const assignedPort = lastDaemonConfig.publicPort || basePort;

  const newServer = {
    requestId,
    name: serverName,
    placeId,
    serverType: targetType,
    serverIp: assignedHost,
    serverPort: assignedPort,
    playerCount: 1,
    maxPlayers: 10,
    ping: 15,
    isUserHosted: !isOfficial,
    authToken: `tok_${Math.random().toString(36).substring(2, 15)}`,
    status: 'SPAWNING',
    lastHeartbeat: Date.now(),
    launchedAt: new Date().toISOString()
  };

  activeServers.push(newServer);
  console.log(`[Luani Matchmaker] Created new ${targetType} server instance: ${newServer.name} on host ${assignedHost}:${assignedPort}`);

  const joinUri = `luani://join?server=${assignedHost}:${assignedPort}&auth=${newServer.authToken}&username=${encodeURIComponent(playerUsername)}&avatar=${encodeURIComponent(playerAvatar)}&avatar_colors=${colorParam}&owner=${isOwner}&verified=${isVerified}`;

  res.json({
    success: true,
    reused: false,
    requestId,
    server: newServer,
    joinUri
  });
});

// Daemon / Server Heartbeat & Status Signaling
app.post('/api/daemon/heartbeat', (req, res) => {
  const { requestId, playerCount, status, serverIp, serverPort, publicHost, publicPort } = req.body;

  if (publicHost || serverIp) {
    lastDaemonConfig.publicHost = getPublicServerIp(publicHost || serverIp);
  }
  if (publicPort !== undefined && publicPort !== null && !isNaN(parseInt(publicPort))) {
    lastDaemonConfig.publicPort = parseInt(publicPort);
  }

  const srv = activeServers.find(s => s.requestId === requestId);
  if (srv) {
    srv.lastHeartbeat = Date.now();
    if (playerCount !== undefined) srv.playerCount = parseInt(playerCount);
    if (status) srv.status = status;
    if (serverIp || publicHost) srv.serverIp = getPublicServerIp(publicHost || serverIp);
    if (serverPort !== undefined && !isNaN(parseInt(serverPort))) srv.serverPort = parseInt(serverPort);
    return res.json({ success: true, server: { ...srv, serverIp: getPublicServerIp(srv.serverIp) } });
  }
  res.json({ success: true, message: 'Daemon config heartbeat recorded.', daemonConfig: lastDaemonConfig });
});

app.get('/api/daemon/pending-tasks', (req, res) => {
  const spawning = activeServers.filter(s => s.status === 'SPAWNING');
  res.json({ pendingCount: spawning.length, tasks: spawning });
});

app.post('/api/daemon/update-status', (req, res) => {
  const { requestId, status, playerCount, serverIp, serverPort, publicHost, publicPort } = req.body;

  if (publicHost || serverIp) {
    lastDaemonConfig.publicHost = getPublicServerIp(publicHost || serverIp);
  }
  if (publicPort !== undefined && publicPort !== null && !isNaN(parseInt(publicPort))) {
    lastDaemonConfig.publicPort = parseInt(publicPort);
  }

  const srv = activeServers.find(s => s.requestId === requestId);
  if (srv) {
    srv.status = status;
    srv.lastHeartbeat = Date.now();
    if (playerCount !== undefined) srv.playerCount = parseInt(playerCount);
    if (serverIp || publicHost) srv.serverIp = getPublicServerIp(publicHost || serverIp);
    if (serverPort !== undefined && !isNaN(parseInt(serverPort))) srv.serverPort = parseInt(serverPort);
    console.log(`[Luani Web Backend] Daemon updated server ${requestId} status to: ${status} (Public Host: ${getPublicServerIp(srv.serverIp)}:${srv.serverPort})`);
    return res.json({ success: true });
  }
  res.status(404).json({ success: false, error: 'Server instance request not found.' });
});

app.listen(PORT, () => {
  console.log(`[Luani Web Backend] Running on http://localhost:${PORT} (Domain target: ${PUBLIC_DOMAIN})`);
});
