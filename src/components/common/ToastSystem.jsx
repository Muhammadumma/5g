import React, { useState, useEffect, useCallback } from 'react';
import { CheckCircle, XCircle, AlertTriangle, Info, X, AlertCircle } from 'lucide-react';

// ── Toast Item ──────────────────────────────────────────────────────────────
const TOAST_ICONS = {
    success: <CheckCircle size={20} />,
    error:   <XCircle size={20} />,
    warning: <AlertTriangle size={20} />,
    info:    <Info size={20} />,
};

const TOAST_COLORS = {
    success: { bg: '#0f2a1a', border: '#22c55e', icon: '#22c55e', bar: '#22c55e' },
    error:   { bg: '#2a0f0f', border: '#ef4444', icon: '#ef4444', bar: '#ef4444' },
    warning: { bg: '#2a1f0a', border: '#f59e0b', icon: '#f59e0b', bar: '#f59e0b' },
    info:    { bg: '#0a1a2a', border: '#3b82f6', icon: '#3b82f6', bar: '#3b82f6' },
};

const ToastItem = ({ toast, onRemove }) => {
    const colors = TOAST_COLORS[toast.type] || TOAST_COLORS.info;

    useEffect(() => {
        const timer = setTimeout(() => onRemove(toast.id), 4000);
        return () => clearTimeout(timer);
    }, [toast.id, onRemove]);

    return (
        <div style={{
            display: 'flex', alignItems: 'flex-start', gap: '12px',
            background: colors.bg,
            border: `1px solid ${colors.border}`,
            borderRadius: '12px',
            padding: '14px 16px',
            minWidth: '300px', maxWidth: '420px',
            boxShadow: `0 8px 32px rgba(0,0,0,0.4), 0 0 0 1px ${colors.border}22`,
            animation: 'toastSlideIn 0.3s cubic-bezier(0.34,1.56,0.64,1)',
            position: 'relative', overflow: 'hidden',
        }}>
            {/* Progress bar */}
            <div style={{
                position: 'absolute', bottom: 0, left: 0, right: 0, height: '3px',
                background: `${colors.bar}33`,
            }}>
                <div style={{
                    height: '100%', background: colors.bar,
                    animation: 'toastProgress 4s linear forwards',
                }} />
            </div>

            {/* Icon */}
            <span style={{ color: colors.icon, marginTop: '1px', flexShrink: 0 }}>
                {TOAST_ICONS[toast.type]}
            </span>

            {/* Message */}
            <span style={{
                flex: 1, fontSize: '0.875rem', lineHeight: '1.5',
                color: '#f1f5f9', fontWeight: '500',
            }}>
                {toast.message}
            </span>

            {/* Close button */}
            <button
                onClick={() => onRemove(toast.id)}
                style={{
                    background: 'none', border: 'none', color: '#64748b',
                    cursor: 'pointer', padding: '0', flexShrink: 0,
                    display: 'flex', alignItems: 'center',
                    transition: 'color 0.2s',
                }}
                onMouseEnter={e => e.currentTarget.style.color = '#f1f5f9'}
                onMouseLeave={e => e.currentTarget.style.color = '#64748b'}
            >
                <X size={16} />
            </button>
        </div>
    );
};

// ── Confirm Modal ───────────────────────────────────────────────────────────
const ConfirmModal = ({ confirm, onResolve }) => {
    if (!confirm) return null;

    const isDanger = confirm.title?.toLowerCase().includes('delete') ||
                     confirm.title?.toLowerCase().includes('permanent') ||
                     confirm.message?.toLowerCase().includes('delete') ||
                     confirm.message?.toLowerCase().includes('permanently') ||
                     confirm.message?.toLowerCase().includes('critical');

    return (
        <div style={{
            position: 'fixed', inset: 0, zIndex: 100000,
            background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(6px)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            animation: 'fadeIn 0.2s ease',
        }}>
            <div style={{
                background: 'var(--surface, #1e293b)',
                border: `1px solid ${isDanger ? '#ef444444' : '#334155'}`,
                borderRadius: '16px',
                padding: '28px 32px',
                maxWidth: '440px', width: '90%',
                boxShadow: '0 24px 64px rgba(0,0,0,0.5)',
                animation: 'toastSlideIn 0.3s cubic-bezier(0.34,1.56,0.64,1)',
            }}>
                {/* Icon + Title */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '16px' }}>
                    <span style={{ color: isDanger ? '#ef4444' : '#f59e0b' }}>
                        <AlertCircle size={26} />
                    </span>
                    <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: '700', color: '#f1f5f9' }}>
                        {confirm.title || 'Confirm Action'}
                    </h3>
                </div>

                {/* Message */}
                <p style={{
                    margin: '0 0 24px',
                    fontSize: '0.9rem', lineHeight: '1.6',
                    color: '#94a3b8',
                }}>
                    {confirm.message}
                </p>

                {/* Buttons */}
                <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
                    <button
                        onClick={() => onResolve(false)}
                        style={{
                            padding: '10px 20px', borderRadius: '8px',
                            border: '1px solid #334155', background: 'transparent',
                            color: '#94a3b8', cursor: 'pointer', fontWeight: '600',
                            fontSize: '0.875rem', transition: 'all 0.2s',
                        }}
                        onMouseEnter={e => { e.currentTarget.style.background = '#334155'; e.currentTarget.style.color = '#f1f5f9'; }}
                        onMouseLeave={e => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = '#94a3b8'; }}
                    >
                        Cancel
                    </button>
                    <button
                        onClick={() => onResolve(true)}
                        style={{
                            padding: '10px 20px', borderRadius: '8px',
                            border: 'none',
                            background: isDanger
                                ? 'linear-gradient(135deg, #dc2626, #ef4444)'
                                : 'linear-gradient(135deg, #2563eb, #3b82f6)',
                            color: '#fff', cursor: 'pointer', fontWeight: '700',
                            fontSize: '0.875rem', transition: 'all 0.2s',
                            boxShadow: isDanger ? '0 4px 12px rgba(239,68,68,0.4)' : '0 4px 12px rgba(59,130,246,0.4)',
                        }}
                        onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-1px)'}
                        onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
                    >
                        {isDanger ? 'Yes, Delete' : 'Confirm'}
                    </button>
                </div>
            </div>
        </div>
    );
};

// ── Main ToastSystem Component ──────────────────────────────────────────────
const ToastSystem = () => {
    const [toasts, setToasts] = useState([]);
    const [confirm, setConfirm] = useState(null);

    const removeToast = useCallback((id) => {
        setToasts(prev => prev.filter(t => t.id !== id));
    }, []);

    useEffect(() => {
        const handleToast = (e) => {
            setToasts(prev => [...prev.slice(-4), e.detail]); // max 5 toasts
        };

        const handleConfirm = (e) => {
            setConfirm(e.detail);
        };

        window.addEventListener('app-toast', handleToast);
        window.addEventListener('app-confirm', handleConfirm);
        return () => {
            window.removeEventListener('app-toast', handleToast);
            window.removeEventListener('app-confirm', handleConfirm);
        };
    }, []);

    const handleConfirmResolve = (result) => {
        if (confirm?.resolve) confirm.resolve(result);
        setConfirm(null);
    };

    return (
        <>
            {/* Inject keyframe animations */}
            <style>{`
                @keyframes toastSlideIn {
                    from { opacity: 0; transform: translateY(20px) scale(0.95); }
                    to   { opacity: 1; transform: translateY(0) scale(1); }
                }
                @keyframes toastProgress {
                    from { width: 100%; }
                    to   { width: 0%; }
                }
                @keyframes fadeIn {
                    from { opacity: 0; }
                    to   { opacity: 1; }
                }
            `}</style>

            {/* Toast Container — bottom-right */}
            <div style={{
                position: 'fixed', bottom: '24px', right: '24px',
                zIndex: 99999,
                display: 'flex', flexDirection: 'column', gap: '10px',
                pointerEvents: 'none',
            }}>
                {toasts.map(t => (
                    <div key={t.id} style={{ pointerEvents: 'all' }}>
                        <ToastItem toast={t} onRemove={removeToast} />
                    </div>
                ))}
            </div>

            {/* Confirm Modal */}
            <ConfirmModal confirm={confirm} onResolve={handleConfirmResolve} />
        </>
    );
};

export default ToastSystem;
