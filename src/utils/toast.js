/**
 * Global Toast Utility
 * Works from ANY file (React or plain JS) by dispatching a CustomEvent.
 * The ToastSystem component in App.jsx listens to these events and renders the UI.
 */

const dispatch = (type, message) => {
    window.dispatchEvent(new CustomEvent('app-toast', {
        detail: { type, message, id: Date.now() + Math.random() }
    }));
};

export const toast = {
    success: (msg) => dispatch('success', msg),
    error:   (msg) => dispatch('error',   msg),
    info:    (msg) => dispatch('info',    msg),
    warning: (msg) => dispatch('warning', msg),
};
