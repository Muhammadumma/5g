/**
 * Global Confirm Utility
 * Returns a Promise<boolean> — use with await to replace window.confirm().
 * Usage: if (await showConfirm('Are you sure?')) { ... }
 */

export const showConfirm = (message, title = 'Confirm Action') => {
    return new Promise((resolve) => {
        window.dispatchEvent(new CustomEvent('app-confirm', {
            detail: { message, title, resolve }
        }));
    });
};
