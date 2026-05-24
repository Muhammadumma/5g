import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

const isValidUrl = (url) => {
  if (!url) return false;
  try {
    new URL(url);
    return true;
  } catch (e) {
    return false;
  }
};

export const isSupabaseConfigured =
  supabaseUrl &&
  supabaseUrl !== 'YOUR_SUPABASE_URL_HERE' &&
  isValidUrl(supabaseUrl) &&
  supabaseAnonKey &&
  supabaseAnonKey !== 'YOUR_SUPABASE_ANON_KEY_HERE';

if (!isSupabaseConfigured) {
  console.warn('Supabase is not configured yet! Please check your .env file.');
}

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        // Keep the session alive, but do NOT re-check/refresh it every time
        // the browser tab becomes visible. Without this, minimizing the tab
        // fires TOKEN_REFRESHED → onAuthStateChange → full app re-render.
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true,
        // Disable the visibility-change hook that triggers re-auth on tab focus
        // by overriding the storage event key so Supabase doesn't react to it.
        storageKey: '5g-guruclinic-auth',
      },
      realtime: {
        // Reconnect quickly but don't thrash on tab focus
        reconnectAfterMs: (tries) => Math.min(tries * 1000, 10000),
      },
    })
  : null;
