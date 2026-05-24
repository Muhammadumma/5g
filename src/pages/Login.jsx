import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Shield, Lock, User, AlertCircle, Loader } from 'lucide-react';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const { login, loginWithGoogle, user, authError } = useAuth();
    const navigate = useNavigate();

    // Auto-navigate if fully authorized
    useEffect(() => {
        if (user) {
            navigate('/');
        }
    }, [user, navigate]);

    // Show auth errors from context (e.g. Google rejection)
    useEffect(() => {
        if (authError) {
            setError(authError);
        }
    }, [authError]);

    const handleLogin = async (e) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            await login(email, password);
        } catch (err) {
            const msg = err.message || '';
            setError(msg || 'Login failed. Please check your connection and try again.');
        } finally {
            setLoading(false);
        }
    };

    const handleGoogleLogin = async () => {
        setError('');
        setLoading(true);
        try {
            await loginWithGoogle();
        } catch (err) {
            setError(err.message || 'Google authentication failed. Please try again.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="login-container">
            <div className="login-card">
                <div className="login-icon" style={{ display: 'flex', justifyContent: 'center', marginBottom: '1.5rem' }}>
                    <img src="/logo.png" alt="5G EGuruClinic Logo" style={{ width: '64px', height: '64px' }} />
                </div>
                <h1>5G EGuruClinic Portal Login</h1>
                <p className="login-subtitle">Secured Hospital Management System</p>

                {error && (
                    <div className="error-message-banner">
                        <AlertCircle size={18} />
                        <span>{error}</span>
                    </div>
                )}

                <form onSubmit={handleLogin} className="login-form">
                    <div className="form-group">
                        <label>Email Address</label>
                        <div className="input-with-icon">
                            <User size={18} />
                            <input
                                type="email"
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                placeholder="Enter your email..."
                                required
                                disabled={loading}
                            />
                        </div>
                    </div>
                    <div className="form-group">
                        <label>Password</label>
                        <div className="input-with-icon">
                            <Lock size={18} />
                            <input
                                type="password"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                placeholder="Enter password..."
                                required
                                disabled={loading}
                            />
                        </div>
                    </div>
                    <button type="submit" className="login-submit-btn" disabled={loading}>
                        {loading ? <><Loader size={16} className="spin-icon" /> Authenticating…</> : 'Sign In'}
                    </button>

                    <div className="divider">
                        <span>or</span>
                    </div>

                    <button 
                        type="button" 
                        className="google-login-btn" 
                        onClick={handleGoogleLogin} 
                        disabled={loading}
                    >
                        <svg className="google-icon" viewBox="0 0 24 24" width="20" height="20" xmlns="http://www.w3.org/2000/svg">
                            <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                            <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                            <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                            <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                            <path d="M1 1h22v22H1z" fill="none"/>
                        </svg>
                        Continue with Google
                    </button>

                    <div style={{ textAlign: 'center', marginTop: '0.75rem' }}>
                        <p style={{ color: '#94a3b8', fontSize: '0.7rem', fontStyle: 'italic' }}>
                            <Shield size={12} style={{ verticalAlign: 'middle', marginRight: '4px' }} />
                            Google sign-in is for System Administrator only
                        </p>
                    </div>
                </form>

                <div className="login-footer-info">
                    <p style={{ color: '#64748b', fontSize: '0.8rem' }}>
                        🔒 All sessions are securely encrypted and automatically audited
                    </p>
                </div>
            </div>
        </div>
    );
};

export default Login;
