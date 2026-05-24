import React, { createContext, useState, useContext, useEffect, useRef, useCallback } from 'react';
import { supabase, isSupabaseConfigured } from '../supabaseClient';
import Preloader from '../components/common/Preloader';
import auditLogger from '../utils/auditLogger';
import { toCamelCase, toSnakeCase } from '../utils/caseConverter';
import SupabaseSetupScreen from '../components/common/SupabaseSetupScreen';

const AuthContext = createContext(null);

// ── Super Admin emails — the ONLY accounts allowed to use Google sign-in ──
const SUPER_ADMIN_EMAILS = [
  'muhammadbindaddy@gmail.com',
  'devmuhamammadalbani@gmail.com',
  'yarmamaihsan@gmail.com'
];

const isSuperAdminEmail = (email) => SUPER_ADMIN_EMAILS.includes((email || '').toLowerCase());

// ── Fire-and-forget helper: run a DB call in the background, never block UI ──
const bg = (promise) => { promise.then().catch(() => {}); };

export const AuthProvider = ({ children }) => {
  const [authSession, setAuthSession] = useState(null);
  const [user, setUser]               = useState(null);
  const [users, setUsers]             = useState([]);
  const [authLoading, setAuthLoading] = useState(true);
  const [authError, setAuthError]     = useState(null);
  const [isFirstRun, setIsFirstRun]   = useState(false);

  const userRef = useRef(null);
  useEffect(() => { userRef.current = user; }, [user]);

  // ── LOGOUT ──────────────────────────────────────────────────────────────────
  const logout = async () => {
    const currentUser = user;
    sessionStorage.removeItem('clinical_login_logged');

    // Optimistically clear UI immediately — no waiting
    setUser(null);
    setAuthSession(null);
    setAuthError(null);

    // Fire background tasks without blocking
    if (currentUser?.id) {
      bg(supabase.from('users').update({ is_online: false, last_seen: new Date().toISOString() }).eq('id', currentUser.id));
      bg(auditLogger.log(currentUser, 'LOGOUT', 'AUTH', currentUser.id, `${currentUser.name} logged out manually`));
    }
    bg(supabase.auth.signOut());
  };

  // ── LOGIN WITH EMAIL/PASSWORD ────────────────────────────────────────────────
  // Direct Supabase Auth sign-in. Profile validation happens in onAuthStateChange.
  // We do NOT query the users table here (anon RLS blocks it).
  const login = async (email, password) => {
    const cleanEmail    = (email    || '').trim().toLowerCase();
    const cleanPassword = (password || '').trim();

    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: cleanEmail, password: cleanPassword
    });

    if (!signInError) return; // ✅ Fast path — signed in, onAuthStateChange takes over

    // First-time login for a provisioned staff member — create Auth account
    if (signInError.message.includes('Invalid login credentials')) {
      const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
        email: cleanEmail, password: cleanPassword,
      });

      if (signUpError) {
        if (signUpError.message.includes('already registered')) {
          throw new Error('Invalid email or password. Please use the credentials provided by your Administrator.');
        }
        throw new Error('Authentication setup failed. Please contact your Administrator.');
      }

      if (signUpData?.user?.identities?.length === 0) {
        throw new Error('Email confirmation is required. Ask your Administrator to run the auto-confirm SQL in Supabase.');
      }

      // Sign in immediately after signup
      const { error: retryError } = await supabase.auth.signInWithPassword({
        email: cleanEmail, password: cleanPassword
      });
      if (retryError) {
        if (retryError.message.includes('Email not confirmed')) {
          throw new Error('Account created! Please check your email to confirm your account, or ask the Admin to turn off Email Confirmation in Supabase.');
        }
        throw new Error(`Account created but login failed: ${retryError.message}`);
      }
    } else {
      throw new Error(signInError.message || 'Login failed. Please try again.');
    }
  };

  // ── LOGIN WITH GOOGLE (Super Admin ONLY) ────────────────────────────────────
  const loginWithGoogle = async () => {
    const { error } = await supabase.auth.signInWithOAuth({ provider: 'google' });
    if (error) throw error;
  };

  // ── ADD USER (Admin provisions a new staff account) ─────────────────────────
  // Optimized: single-column duplicate check + immediate insert in parallel prep
  const addUser = async (newUser) => {
    const toTitleCase = (str) => {
      if (!str || typeof str !== 'string') return str || '';
      return str.trim().split(/\s+/)
        .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(' ');
    };

    const cleanEmail      = newUser.email.trim().toLowerCase();
    const capitalizedName = toTitleCase(newUser.name);
    const tempId          = crypto.randomUUID();

    // Duplicate check: select only id (minimal data transfer)
    const { data: existing } = await supabase
      .from('users').select('id').eq('email', cleanEmail).maybeSingle();

    if (existing) throw new Error('A staff account with this email already exists.');

    const { error } = await supabase.from('users').insert([toSnakeCase({
      id:                   tempId,
      email:                cleanEmail,
      username:             cleanEmail.split('@')[0],
      password:             newUser.password,
      name:                 capitalizedName,
      fullName:             capitalizedName,
      role:                 newUser.role,
      specialty:            newUser.specialty || '',
      isActive:             true,
      adminVerificationCode: newUser.adminVerificationCode || ''
    })]);

    if (error) throw new Error(error.message);
  };

  // ── TOGGLE STATUS — single round-trip using DB-side negation ────────────────
  const toggleUserStatus = async (userId) => {
    // Optimistic update in local state for instant UI response
    setUsers(prev => prev.map(u =>
      u.id === userId ? { ...u, isActive: !u.isActive } : u
    ));
    // DB-side toggle — no read needed
    const { error } = await supabase.rpc('toggle_user_active', { user_id: userId });
    if (error) {
      // Revert optimistic update on failure
      setUsers(prev => prev.map(u =>
        u.id === userId ? { ...u, isActive: !u.isActive } : u
      ));
      throw new Error(error.message);
    }
  };

  // ── UPDATE USER FIELD ────────────────────────────────────────────────────────
  const updateUser = async (userId, fields) => {
    // Optimistic update
    setUsers(prev => prev.map(u => u.id === userId ? { ...u, ...fields } : u));
    const { error } = await supabase.from('users').update(toSnakeCase(fields)).eq('id', userId);
    if (error) throw new Error(error.message);
  };

  // ── DELETE USER ──────────────────────────────────────────────────────────────
  const deleteUser = async (userId) => {
    // Optimistic removal
    setUsers(prev => prev.filter(u => u.id !== userId));
    const { error } = await supabase.from('users').delete().eq('id', userId);
    if (error) throw new Error(error.message);
  };

  // ── DEEP CLEAN DUPLICATES — parallel deletes ────────────────────────────────
  const cleanDuplicateUsers = async () => {
    const { data: usersData } = await supabase.from('users').select('id,email,is_active,linked_uid,created_at');
    if (!usersData) return 0;

    const emailGroups = {};
    usersData.forEach(d => {
      const email = (d.email || '').toLowerCase();
      if (!email) return;
      (emailGroups[email] = emailGroups[email] || []).push(d);
    });

    const toDeleteIds = [];
    for (const group of Object.values(emailGroups)) {
      if (group.length > 1) {
        group.sort((a, b) => {
          if (a.is_active !== b.is_active) return b.is_active ? 1 : -1;
          if (!!a.linked_uid !== !!b.linked_uid) return a.linked_uid ? 1 : -1;
          return new Date(b.created_at || 0) - new Date(a.created_at || 0);
        });
        group.slice(1).forEach(dupe => toDeleteIds.push(dupe.id));
      }
    }

    if (toDeleteIds.length === 0) return 0;

    // Delete all duplicates in a single query
    await supabase.from('users').delete().in('id', toDeleteIds);
    return toDeleteIds.length;
  };

  // ── RESET PASSWORD ───────────────────────────────────────────────────────────
  const resetPassword = async (userProfile) => {
    const email = userProfile.email || `${userProfile.username.toLowerCase().replace(/\s+/g, '')}@sahara.local`;
    await supabase.auth.resetPasswordForEmail(email);
  };

  // ── Realtime users listener ──────────────────────────────────────────────────
  // Only re-fetches on structural changes (INSERT/DELETE/UPDATE on non-presence fields).
  // Presence heartbeat (is_online, last_seen) updates are handled locally to avoid
  // triggering a full refetch every 30s.
  useEffect(() => {
    if (!isSupabaseConfigured || !authSession) {
      setUsers([]);
      return;
    }

    const formatUsers = (data) => data.map(toCamelCase).map(u => {
      const lastSeenTime = u.lastSeen ? new Date(u.lastSeen).getTime() : 0;
      return { ...u, isOnline: u.isOnline && (Date.now() - lastSeenTime) < 90000 };
    });

    const fetchUsers = async () => {
      const { data } = await supabase.from('users').select('*');
      if (data) {
        const formatted = formatUsers(data);
        setUsers(formatted);
        setIsFirstRun(formatted.length === 0);
      }
    };

    fetchUsers();

    const subscription = supabase
      .channel(`public:users:structural-${Math.random().toString(36).substring(7)}`)
      .on('postgres_changes', {
        event: 'INSERT', schema: 'public', table: 'users'
      }, fetchUsers)
      .on('postgres_changes', {
        event: 'DELETE', schema: 'public', table: 'users'
      }, fetchUsers)
      .on('postgres_changes', {
        event: 'UPDATE', schema: 'public', table: 'users',
        // Only refetch if core fields changed (not presence heartbeat fields)
        filter: 'is_active=eq.true'
      }, (payload) => {
        // For updates: patch local state instead of full refetch
        const updated = toCamelCase(payload.new);
        setUsers(prev => {
          const exists = prev.some(u => u.id === updated.id);
          if (!exists) return [...prev, updated];
          return prev.map(u => u.id === updated.id ? { ...u, ...updated } : u);
        });
      });
      
    subscription.subscribe();

    return () => { 
        if (subscription) {
            try { supabase.removeChannel(subscription); } catch(e) {}
        }
    };
  }, [authSession]);

  // ── Supabase Auth state listener ─────────────────────────────────────────────
  useEffect(() => {
    if (!isSupabaseConfigured) return;

    const handleSessionState = async (session) => {
      try {
        if (!session) {
          if (userRef.current) {
            const current = userRef.current;
            bg(auditLogger.log(current, 'LOGOUT', 'AUTH', current.id, `${current.name} logged out (session ended)`));
          }
          setAuthSession(null);
          setUser(null);
          return;
        }

        setAuthSession(session);
        setAuthError(null);

        const sessionEmail      = (session.user?.email || '').toLowerCase();
        const isGoogleProvider  = session.user?.app_metadata?.provider === 'google';
        const isOwner           = isSuperAdminEmail(sessionEmail);
        const now               = new Date().toISOString();

        // ─── GOOGLE: non-admin rejected immediately ───
        if (isGoogleProvider && !isOwner) {
          setAuthError('Access denied. Google sign-in is reserved for the System Administrator only.');
          setUser(null);
          bg(supabase.auth.signOut());
          setAuthSession(null);
          return;
        }

        // ─── SUPER ADMIN via Google ───
        if (isGoogleProvider && isOwner) {
          const { data: existingProfile } = await supabase
            .from('users').select('*').eq('email', sessionEmail).maybeSingle();

          if (existingProfile) {
            if (existingProfile.id !== session.user.id) {
              // UID migration needed — do upsert + delete in parallel
              const updatedProfile = {
                ...existingProfile, id: session.user.id,
                linked_uid: session.user.id, is_active: true,
                is_online: true, last_seen: now, last_verified_at: now
              };
              setUser(toCamelCase(updatedProfile)); // Set immediately, write in background
              bg(supabase.from('users').update({
                id: session.user.id,
                linked_uid: session.user.id,
                is_active: true,
                is_online: true,
                last_seen: now,
                last_verified_at: now
              }).eq('id', existingProfile.id));
            } else {
              // Same UID — set user immediately, write presence in background
              setUser(toCamelCase({ ...existingProfile, is_active: true, is_online: true, linked_uid: session.user.id }));
              bg(supabase.from('users').update({ is_active: true, is_online: true, last_seen: now, linked_uid: session.user.id }).eq('id', session.user.id));
            }
          } else {
            // First time — auto-create profile, set user immediately
            const superAdminProfile = {
              id: session.user.id, email: sessionEmail, username: sessionEmail,
              password: 'Rama##12',
              name: session.user.user_metadata?.full_name || 'Super Administrator',
              role: 'Admin', is_active: true, is_online: true,
              linked_uid: session.user.id, last_seen: now, last_verified_at: now
            };
            setUser(toCamelCase(superAdminProfile));
            bg(supabase.from('users').upsert([superAdminProfile]));
          }
          return;
        }

        // ─── EMAIL/PASSWORD: Load staff profile ───
        const { data: staffProfile } = await supabase
          .from('users').select('*').eq('email', sessionEmail).maybeSingle();

        if (!staffProfile) {
          setAuthError('No staff profile found for this email. Please contact your Administrator.');
          setUser(null);
          bg(supabase.auth.signOut());
          setAuthSession(null);
          return;
        }

        if (!staffProfile.is_active) {
          setAuthError('Your account has been deactivated. Please contact your Administrator.');
          setUser(null);
          bg(supabase.auth.signOut());
          setAuthSession(null);
          return;
        }

        if (staffProfile.id !== session.user.id) {
          // UID migration — set user immediately, write in background
          const updatedProfile = {
            ...staffProfile, id: session.user.id,
            linked_uid: session.user.id, is_online: true, last_seen: now
          };
          setUser(toCamelCase(updatedProfile));
          bg(supabase.from('users').update({
            id: session.user.id,
            linked_uid: session.user.id,
            is_online: true,
            last_seen: now
          }).eq('id', staffProfile.id));
        } else {
          // Normal login — set user immediately, write presence in background
          setUser(toCamelCase({ ...staffProfile, is_online: true, linked_uid: session.user.id }));
          bg(supabase.from('users').update({ is_online: true, last_seen: now, linked_uid: session.user.id }).eq('id', session.user.id));
        }

      } catch (err) {
        console.error('Auth state error:', err);
        setAuthError('Authentication service temporarily unavailable.');
        setAuthSession(null);
        setUser(null);
      } finally {
        setAuthLoading(false);
      }
    };

    // Initial session check
    supabase.auth.getSession().then(({ data: { session } }) => handleSessionState(session));

    // Subscribe to auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'INITIAL_SESSION') return;
      handleSessionState(session);
    });

    return () => subscription.unsubscribe();
  }, []);

  // ── Login audit (fire-and-forget) ────────────────────────────────────────────
  useEffect(() => {
    if (!isSupabaseConfigured) return;
    if (user && !sessionStorage.getItem('clinical_login_logged')) {
      bg(auditLogger.log(user, 'LOGIN', 'AUTH', user.id, `${user.name} logged in (${user.email})`));
      sessionStorage.setItem('clinical_login_logged', 'true');
    }
    if (!user) sessionStorage.removeItem('clinical_login_logged');
  }, [user]);

  // ── Presence tracking — 60s heartbeat (was 30s) ──────────────────────────────
  useEffect(() => {
    if (!isSupabaseConfigured || !user?.id) return;

    const markOnline = () =>
      bg(supabase.from('users').update({ is_online: true, last_seen: new Date().toISOString() }).eq('id', user.id));

    markOnline();
    const heartbeat = setInterval(markOnline, 60000); // 60s — halves DB write load

    const markOffline = () =>
      bg(supabase.from('users').update({ is_online: false, last_seen: new Date().toISOString() }).eq('id', user.id));

    window.addEventListener('beforeunload', markOffline);
    return () => {
      clearInterval(heartbeat);
      window.removeEventListener('beforeunload', markOffline);
      markOffline();
    };
  }, [user?.id]);

  const value = {
    user, authSession, users, authLoading, authError, isFirstRun,
    login, loginWithGoogle, logout,
    addUser, toggleUserStatus, updateUser, deleteUser, resetPassword,
    cleanDuplicateUsers,
    // Expose setter so components can do optimistic updates locally
    setUsers,
  };

  if (!isSupabaseConfigured) return <SupabaseSetupScreen />;
  if (authLoading)           return <Preloader fullPage message="Connecting to 5G E-GURUCLINIC System..." />;

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => useContext(AuthContext);
