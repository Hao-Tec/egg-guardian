/**
 * Egg Guardian Admin - Client-side JavaScript
 * Updated for the new Design System
 */

const API_BASE = window.location.origin.includes('localhost') 
    ? 'http://localhost:8000/api/v1' 
    : '/api/v1';

// State
let devices = [];
let alertRules = [];
let users = [];
let triggeredAlerts = [];
let authToken = localStorage.getItem('admin_token');
let currentUser = null;

// Session security
const SESSION_TIMEOUT_MS = 30 * 60 * 1000;
const INACTIVITY_TIMEOUT_MS = 15 * 60 * 1000;
let sessionTimeoutId = null;
let inactivityTimeoutId = null;
let loginTimestamp = localStorage.getItem('admin_login_time');

// Security: HTML escape to prevent XSS
function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// ── DOM Elements ──────────────────────────────────────────────────────────

const els = {
    // Layout
    loginOverlay: document.getElementById('login-overlay'),
    app: document.getElementById('app'),
    
    // Login
    loginForm: document.getElementById('login-form'),
    loginError: document.getElementById('login-error'),
    loginEmail: document.getElementById('login-email'),
    loginPass: document.getElementById('login-password'),
    loginBtn: document.getElementById('login-btn'),
    loginBtnLabel: document.getElementById('login-btn-label'),
    loginSpinner: document.getElementById('login-spinner'),
    
    // Navigation
    sidebarToggle: document.getElementById('sidebar-toggle'),
    sidebar: document.querySelector('.sidebar'),
    navItems: document.querySelectorAll('.nav-item'),
    tabContents: document.querySelectorAll('.tab-content'),
    logoutBtn: document.getElementById('logout-btn'),
    
    // Badges
    alertsBadge: document.getElementById('alerts-badge'),
    usersBadge: document.getElementById('users-badge'),
    
    // Overview Tab
    statTotalDevices: document.getElementById('stat-total-devices'),
    statActiveDevices: document.getElementById('stat-active-devices'),
    statUnreadAlerts: document.getElementById('stat-unread-alerts'),
    statTotalUsers: document.getElementById('stat-total-users'),
    overviewDeviceList: document.getElementById('overview-device-list'),
    refreshOverviewBtn: document.getElementById('refresh-overview'),
    
    // Devices Tab
    registerForm: document.getElementById('register-device-form'),
    devIdInput: document.getElementById('device-id'),
    devNameInput: document.getElementById('device-name'),
    devicesList: document.getElementById('devices-list'),
    deviceCountTag: document.getElementById('device-count'),
    
    // Alerts Tab
    alertForm: document.getElementById('alert-rule-form'),
    ruleDevice: document.getElementById('rule-device'),
    ruleMin: document.getElementById('rule-min'),
    ruleMax: document.getElementById('rule-max'),
    alertsList: document.getElementById('alerts-list'),
    pendingAlertsCount: document.getElementById('pending-alerts-count'),
    ackAllBtn: document.getElementById('ack-all-btn'),
    
    // Live Monitor
    wsStatus: document.getElementById('ws-status'),
    liveTempValue: document.getElementById('live-temp-value'),
    
    // Users Tab
    pendingSection: document.getElementById('pending-section'),
    pendingCountBadge: document.getElementById('pending-count-badge'),
    pendingUsersList: document.getElementById('pending-users-list'),
    usersList: document.getElementById('users-list'),
    userCountTag: document.getElementById('user-count'),
    
    // Modal
    confirmModal: document.getElementById('confirm-modal'),
    confirmTitle: document.getElementById('confirm-title'),
    confirmBody: document.getElementById('confirm-body'),
    confirmCancel: document.getElementById('confirm-cancel'),
    confirmOk: document.getElementById('confirm-ok'),
    
    // Toast
    toastContainer: document.getElementById('toast-container')
};

// ── Initialization & Auth ───────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
    checkAuth();
});

function setupEventListeners() {
    els.loginForm.addEventListener('submit', handleLogin);
    els.logoutBtn.addEventListener('click', () => logout(false));
    els.refreshOverviewBtn.addEventListener('click', loadAllData);
    
    // Navigation
    els.navItems.forEach(btn => {
        btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });
    
    els.sidebarToggle.addEventListener('click', () => {
        els.sidebar.classList.toggle('open');
    });
    
    // Forms
    els.registerForm.addEventListener('submit', registerDevice);
    els.alertForm.addEventListener('submit', saveAlertRule);
    
    // Modal
    els.confirmCancel.addEventListener('click', closeModal);
    els.confirmModal.addEventListener('click', (e) => {
        if (e.target === els.confirmModal) closeModal();
    });
    
    // Alerts
    els.ackAllBtn.addEventListener('click', acknowledgeAllAlerts);
    els.ruleDevice.addEventListener('change', () => {
        setupWebSocket(els.ruleDevice.value);
    });
}

async function checkAuth() {
    if (!authToken) {
        showLogin();
        return false;
    }
    
    if (checkSessionExpiry()) {
        logout(true);
        return false;
    }
    
    try {
        const response = await fetch(`${API_BASE}/auth/me`, {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        
        if (!response.ok) throw new Error('Invalid token');
        
        currentUser = await response.json();
        
        if (!currentUser.is_superuser) {
            showLoginError('Access denied. Admin privileges required.');
            logout();
            return false;
        }
        
        showApp();
        return true;
    } catch (error) {
        console.error('Auth check failed:', error);
        logout();
        return false;
    }
}

function showLogin() {
    els.app.classList.add('hidden');
    els.loginOverlay.classList.remove('hidden');
}

function showApp() {
    els.loginOverlay.classList.add('hidden');
    els.app.classList.remove('hidden');
    startSession();
    loadAllData();
    startDataAutoRefresh();
}

async function handleLogin(e) {
    e.preventDefault();
    els.loginError.classList.add('hidden');
    els.loginBtnLabel.classList.add('hidden');
    els.loginSpinner.classList.remove('hidden');
    els.loginBtn.disabled = true;
    
    try {
        const response = await fetch(`${API_BASE}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                email: els.loginEmail.value, 
                password: els.loginPass.value 
            })
        });
        
        if (!response.ok) {
            const err = await response.json();
            throw new Error(err.detail || 'Login failed');
        }
        
        const data = await response.json();
        authToken = data.access_token;
        localStorage.setItem('admin_token', authToken);
        await checkAuth();
    } catch (error) {
        showLoginError(error.message);
    } finally {
        els.loginBtnLabel.classList.remove('hidden');
        els.loginSpinner.classList.add('hidden');
        els.loginBtn.disabled = false;
    }
}

function showLoginError(msg) {
    els.loginError.textContent = msg;
    els.loginError.classList.remove('hidden');
}

function logout(showExpiredMessage = false) {
    stopDataAutoRefresh();
    stopSessionTimers();
    if (ws) ws.close();
    authToken = null;
    currentUser = null;
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_login_time');
    showLogin();
    if (showExpiredMessage) showToast('Session expired. Please login again.', true);
}

// ── Session Timers ──────────────────────────────────────────────────────

function startSession() {
    loginTimestamp = Date.now();
    localStorage.setItem('admin_login_time', loginTimestamp);
    
    sessionTimeoutId = setTimeout(() => logout(true), SESSION_TIMEOUT_MS);
    resetActivityTimer();
    
    ['mousedown', 'keydown', 'scroll', 'touchstart'].forEach(evt => {
        document.addEventListener(evt, resetActivityTimer);
    });
}

function resetActivityTimer() {
    if (inactivityTimeoutId) clearTimeout(inactivityTimeoutId);
    inactivityTimeoutId = setTimeout(() => logout(true), INACTIVITY_TIMEOUT_MS);
}

function stopSessionTimers() {
    if (sessionTimeoutId) clearTimeout(sessionTimeoutId);
    if (inactivityTimeoutId) clearTimeout(inactivityTimeoutId);
    ['mousedown', 'keydown', 'scroll', 'touchstart'].forEach(evt => {
        document.removeEventListener(evt, resetActivityTimer);
    });
}

function checkSessionExpiry() {
    if (!loginTimestamp) return false;
    return (Date.now() - parseInt(loginTimestamp)) > SESSION_TIMEOUT_MS;
}

// ── Navigation ──────────────────────────────────────────────────────────

function switchTab(tabId) {
    els.navItems.forEach(btn => btn.classList.remove('active'));
    els.tabContents.forEach(tab => tab.classList.remove('active'));
    
    document.getElementById(`nav-${tabId}`).classList.add('active');
    document.getElementById(`tab-${tabId}`).classList.add('active');
    
    if (window.innerWidth <= 768) els.sidebar.classList.remove('open');
}

// ── Data Loading & Rendering ────────────────────────────────────────────

let dataRefreshInterval = null;

function startDataAutoRefresh() {
    if (dataRefreshInterval) clearInterval(dataRefreshInterval);
    dataRefreshInterval = setInterval(loadAllData, 10000);
}

function stopDataAutoRefresh() {
    if (dataRefreshInterval) clearInterval(dataRefreshInterval);
}

async function loadAllData() {
    try {
        await Promise.all([
            fetchDevices(),
            fetchUsers(),
            fetchAlerts()
        ]);
        updateUI();
    } catch (e) {
        console.error('Failed to load data', e);
    }
}

async function fetchDevices() {
    try {
        const res = await fetch(`${API_BASE}/devices`, { headers: { 'Authorization': `Bearer ${authToken}` } });
        if (res.ok) devices = await res.json();
    } catch (e) {}
}

async function fetchUsers() {
    try {
        const res = await fetch(`${API_BASE}/users`, { headers: { 'Authorization': `Bearer ${authToken}` } });
        if (res.ok) users = await res.json();
    } catch (e) {}
}

async function fetchAlerts() {
    try {
        const res = await fetch(`${API_BASE}/alerts?limit=100`, { headers: { 'Authorization': `Bearer ${authToken}` } });
        if (res.ok) triggeredAlerts = await res.json();
    } catch (e) {}
}

function updateUI() {
    const unreadAlerts = triggeredAlerts.filter(a => !a.is_acknowledged);
    const activeDevices = devices.filter(d => d.is_active);
    const pendingUsers = users.filter(u => !u.is_active);
    
    // Overview Stats
    els.statTotalDevices.textContent = devices.length;
    els.statActiveDevices.textContent = activeDevices.length;
    els.statUnreadAlerts.textContent = unreadAlerts.length;
    els.statTotalUsers.textContent = users.length;
    
    // Badges
    updateBadge(els.alertsBadge, unreadAlerts.length);
    updateBadge(els.usersBadge, pendingUsers.length);
    
    // Overivew Devices List
    renderDeviceList(els.overviewDeviceList, devices.slice(0, 5), true);
    
    // Devices Tab
    els.deviceCountTag.textContent = devices.length;
    renderDeviceList(els.devicesList, devices, false);
    
    // Alerts Tab
    els.pendingAlertsCount.textContent = `${unreadAlerts.length} Active`;
    if (unreadAlerts.length > 0) {
        els.pendingAlertsCount.classList.remove('hidden');
        els.ackAllBtn.classList.remove('hidden');
    } else {
        els.pendingAlertsCount.classList.add('hidden');
        els.ackAllBtn.classList.add('hidden');
    }
    renderAlertsList();
    updateDeviceSelect();
    
    // Users Tab
    els.userCountTag.textContent = users.length - pendingUsers.length;
    renderUsersList(pendingUsers, users.filter(u => u.is_active));
}

function updateBadge(el, count) {
    if (count > 0) {
        el.textContent = count;
        el.classList.remove('hidden');
    } else {
        el.classList.add('hidden');
    }
}

// ── Rendering HTML ──────────────────────────────────────────────────────

function renderDeviceList(container, list, compact) {
    if (list.length === 0) {
        container.innerHTML = '<p class="empty-msg">No devices found.</p>';
        return;
    }
    
    container.innerHTML = list.map(d => `
        <div class="device-row">
            <div class="device-icon" style="background: ${d.is_active ? 'rgba(16,185,129,.1)' : 'rgba(71,85,105,.1)'}; color: ${d.is_active ? 'var(--success)' : 'var(--text-muted)'}">
                <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
                    <path fill-rule="evenodd" d="M11.5 5.5a3.5 3.5 0 00-6 2.65V12a3 3 0 106 0V8.15a3.5 3.5 0 00-.5-2.65zM9 4.5a1.5 1.5 0 011.5 1.5v5.5a1.5 1.5 0 11-3 0V6a1.5 1.5 0 011.5-1.5z" clip-rule="evenodd"/>
                </svg>
            </div>
            <div class="device-info">
                <div class="device-name">${escapeHtml(d.name)}</div>
                <div class="device-id">${escapeHtml(d.device_id)}</div>
            </div>
            <span class="status-pill ${d.is_active ? 'status-connected' : ''}">${d.is_active ? 'Active' : 'Offline'}</span>
            ${!compact ? `
            <div class="device-actions">
                <button class="icon-btn danger" onclick="confirmDeleteDevice(${d.id}, '${escapeHtml(d.name)}')">
                    <svg viewBox="0 0 20 20" fill="currentColor" width="18" height="18"><path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>
                </button>
            </div>` : ''}
        </div>
    `).join('');
}

function updateDeviceSelect() {
    const currentVal = els.ruleDevice.value;
    els.ruleDevice.innerHTML = '<option value="">Select a device...</option>' + 
        devices.map(d => `<option value="${d.id}">${escapeHtml(d.name)}</option>`).join('');
    if (currentVal && devices.some(d => d.id == currentVal)) {
        els.ruleDevice.value = currentVal;
    }
}

function renderAlertsList() {
    if (triggeredAlerts.length === 0) {
        els.alertsList.innerHTML = '<p class="empty-msg">No alerts triggered.</p>';
        return;
    }
    
    els.alertsList.innerHTML = triggeredAlerts.map(a => {
        const isHigh = a.alert_type === 'high';
        const dName = devices.find(d => d.id === a.device_id)?.name || `Device #${a.device_id}`;
        const time = new Date(a.triggered_at).toLocaleString();
        
        return `
            <div class="alert-row ${a.is_acknowledged ? 'acknowledged' : ''}">
                <div class="alert-icon ${isHigh ? 'alert-icon--high' : 'alert-icon--low'}">
                    <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20">
                        <path fill-rule="evenodd" d="${isHigh ? 'M14.707 12.707a1 1 0 01-1.414 0L10 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 010 1.414z' : 'M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z'}" clip-rule="evenodd"/>
                    </svg>
                </div>
                <div class="alert-meta">
                    <div class="alert-msg"><strong>${escapeHtml(dName)}:</strong> ${escapeHtml(a.message)}</div>
                    <div class="alert-time">${time}</div>
                </div>
                ${!a.is_acknowledged ? `
                <button class="btn btn-outline-success" onclick="acknowledgeAlert(${a.id})">ACK</button>
                ` : `
                <svg viewBox="0 0 20 20" fill="currentColor" width="18" height="18" style="color: var(--success); flex-shrink: 0"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>
                `}
            </div>
        `;
    }).join('');
}

function renderUsersList(pending, active) {
    if (pending.length > 0) {
        els.pendingCountBadge.textContent = pending.length;
        els.pendingSection.classList.remove('hidden');
        els.pendingUsersList.innerHTML = pending.map(u => `
            <div class="pending-user-row">
                <div class="user-avatar" style="background: rgba(245,158,11,.15); color: var(--accent)">
                    ${u.email.charAt(0).toUpperCase()}
                </div>
                <div class="user-info">
                    <div class="user-email">${escapeHtml(u.email)}</div>
                    <div class="user-meta">${escapeHtml(u.full_name || 'No name')}</div>
                </div>
                <div class="user-actions">
                    <button class="btn btn-primary btn-sm" onclick="approveUser(${u.id})">Approve</button>
                    <button class="icon-btn danger" onclick="confirmDeleteUser(${u.id}, '${escapeHtml(u.email)}')">
                        <svg viewBox="0 0 20 20" fill="currentColor" width="18" height="18"><path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>
                    </button>
                </div>
            </div>
        `).join('');
    } else {
        els.pendingSection.classList.add('hidden');
    }
    
    if (active.length === 0) {
        els.usersList.innerHTML = '<p class="empty-msg">No active users.</p>';
        return;
    }
    
    els.usersList.innerHTML = active.map(u => `
        <div class="user-row">
            <div class="user-avatar" style="background: ${u.is_superuser ? 'rgba(245,158,11,.15)' : 'var(--bg-elevated)'}; color: ${u.is_superuser ? 'var(--accent)' : 'var(--text-secondary)'}">
                ${u.email.charAt(0).toUpperCase()}
            </div>
            <div class="user-info">
                <div style="display:flex; align-items:center; gap:8px">
                    <div class="user-email">${escapeHtml(u.email)}</div>
                    ${u.is_superuser ? '<span class="tag tag-amber">Admin</span>' : ''}
                </div>
                <div class="user-meta">${escapeHtml(u.full_name || 'No name')} • ${escapeHtml(u.job_role || 'No role')}</div>
            </div>
            <div class="user-actions">
                ${u.id !== currentUser.id ? `
                <button class="btn btn-ghost btn-sm" onclick="toggleAdmin(${u.id})">
                    ${u.is_superuser ? 'Revoke Admin' : 'Make Admin'}
                </button>
                <button class="icon-btn danger" onclick="confirmDeleteUser(${u.id}, '${escapeHtml(u.email)}')">
                    <svg viewBox="0 0 20 20" fill="currentColor" width="18" height="18"><path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"/></svg>
                </button>
                ` : '<span class="tag">You</span>'}
            </div>
        </div>
    `).join('');
}

// ── API Actions ─────────────────────────────────────────────────────────

async function registerDevice(e) {
    e.preventDefault();
    try {
        const res = await fetch(`${API_BASE}/devices`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${authToken}` },
            body: JSON.stringify({ device_id: els.devIdInput.value, name: els.devNameInput.value })
        });
        if (res.ok) {
            showToast('Device registered!');
            els.registerForm.reset();
            loadAllData();
        } else {
            const err = await res.json();
            showToast(err.detail || 'Failed to register', true);
        }
    } catch (e) {
        showToast('Error connecting to server', true);
    }
}

async function saveAlertRule(e) {
    e.preventDefault();
    const dId = els.ruleDevice.value;
    if (!dId) return showToast('Please select a device', true);
    
    try {
        const res = await fetch(`${API_BASE}/devices/${dId}/rules`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${authToken}` },
            body: JSON.stringify({ temp_min: parseFloat(els.ruleMin.value), temp_max: parseFloat(els.ruleMax.value) })
        });
        if (res.ok) {
            showToast('Alert rule saved!');
            loadAllData();
        } else {
            const err = await res.json();
            showToast(err.detail || 'Failed to save rule', true);
        }
    } catch (e) {
        showToast('Error saving rule', true);
    }
}

async function acknowledgeAlert(id) {
    try {
        await fetch(`${API_BASE}/alerts/${id}/acknowledge`, {
            method: 'PATCH', headers: { 'Authorization': `Bearer ${authToken}` }
        });
        loadAllData();
    } catch (e) {}
}

async function acknowledgeAllAlerts() {
    try {
        await fetch(`${API_BASE}/alerts/acknowledge-all`, {
            method: 'PATCH', headers: { 'Authorization': `Bearer ${authToken}` }
        });
        showToast('All alerts acknowledged');
        loadAllData();
    } catch (e) {}
}

async function approveUser(id) {
    try {
        const res = await fetch(`${API_BASE}/users/${id}/approve`, {
            method: 'PATCH', headers: { 'Authorization': `Bearer ${authToken}` }
        });
        if (res.ok) {
            showToast('User approved!');
            loadAllData();
        }
    } catch (e) {}
}

async function toggleAdmin(id) {
    try {
        const res = await fetch(`${API_BASE}/users/${id}/toggle-admin`, {
            method: 'PATCH', headers: { 'Authorization': `Bearer ${authToken}` }
        });
        if (res.ok) loadAllData();
    } catch (e) {}
}

// ── Modals & Deletion ───────────────────────────────────────────────────

let modalAction = null;

function showModal(title, body, action) {
    els.confirmTitle.textContent = title;
    els.confirmBody.textContent = body;
    modalAction = action;
    els.confirmModal.classList.remove('hidden');
}

function closeModal() {
    els.confirmModal.classList.add('hidden');
    modalAction = null;
}

els.confirmOk.addEventListener('click', () => {
    if (modalAction) modalAction();
    closeModal();
});

function confirmDeleteDevice(id, name) {
    showModal('Delete Device', `Are you sure you want to delete ${name}? All telemetry data will be lost.`, async () => {
        try {
            await fetch(`${API_BASE}/devices/${id}`, { method: 'DELETE', headers: { 'Authorization': `Bearer ${authToken}` } });
            showToast('Device deleted');
            loadAllData();
        } catch (e) {}
    });
}

function confirmDeleteUser(id, email) {
    showModal('Delete User', `Are you sure you want to delete ${email}?`, async () => {
        try {
            await fetch(`${API_BASE}/users/${id}`, { method: 'DELETE', headers: { 'Authorization': `Bearer ${authToken}` } });
            showToast('User deleted');
            loadAllData();
        } catch (e) {}
    });
}

// ── Toasts ──────────────────────────────────────────────────────────────

function showToast(msg, isError = false) {
    const t = document.createElement('div');
    t.className = `toast ${isError ? 'error' : 'success'}`;
    t.innerHTML = `<div class="toast-dot"></div><div>${msg}</div>`;
    els.toastContainer.appendChild(t);
    setTimeout(() => {
        t.style.animation = 'toast-in 0.25s ease reverse';
        setTimeout(() => t.remove(), 250);
    }, 3000);
}

// ── Live Monitor (WebSocket + Chart) ────────────────────────────────────

let ws = null;
let chart = null;

// Initialize simple canvas chart
function initChart() {
    const canvas = document.getElementById('live-chart');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    chart = new Chart(ctx, {
        type: 'line',
        data: { labels: [], datasets: [{ data: [], borderColor: '#F59E0B', borderWidth: 2, tension: 0.4, pointRadius: 0 }] },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: { x: { display: false }, y: { display: false, min: 33, max: 42 } },
            plugins: { legend: { display: false }, tooltip: { enabled: false } },
            animation: false
        }
    });
}

function setupWebSocket(dbId) {
    if (ws) ws.close();
    
    // Find device_id string from db ID
    const d = devices.find(x => x.id == dbId);
    if (!d) {
        els.wsStatus.className = 'status-pill status-syncing';
        els.wsStatus.textContent = 'Select Device';
        els.liveTempValue.textContent = '—';
        return;
    }
    
    if (!chart && window.Chart) initChart();
    if (chart) {
        chart.data.labels = [];
        chart.data.datasets[0].data = [];
        chart.update();
    }
    
    els.wsStatus.className = 'status-pill status-syncing';
    els.wsStatus.textContent = 'Connecting...';
    
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsHost = window.location.origin.includes('localhost') ? 'localhost:8000' : window.location.host;
    ws = new WebSocket(`${wsProtocol}//${wsHost}/ws/dashboard`);
    
    ws.onopen = () => {
        ws.send(JSON.stringify({ type: 'subscribe', channel: d.device_id }));
        els.wsStatus.className = 'status-pill status-connected';
        els.wsStatus.textContent = 'Connected';
    };
    
    ws.onmessage = (e) => {
        try {
            const data = JSON.parse(e.data);
            if (data.type === 'telemetry' && data.device_id === d.device_id) {
                els.liveTempValue.textContent = data.temperature.toFixed(1);
                
                if (chart) {
                    chart.data.labels.push('');
                    chart.data.datasets[0].data.push(data.temperature);
                    if (chart.data.datasets[0].data.length > 30) {
                        chart.data.labels.shift();
                        chart.data.datasets[0].data.shift();
                    }
                    chart.update();
                }
            } else if (data.type === 'alert') {
                loadAllData(); // Refresh alerts
            }
        } catch (err) {}
    };
    
    ws.onclose = () => {
        els.wsStatus.className = 'status-pill status-syncing';
        els.wsStatus.textContent = 'Disconnected';
    };
}

// Load chart.js dynamically for the live monitor
const script = document.createElement('script');
script.src = 'https://cdn.jsdelivr.net/npm/chart.js';
document.head.appendChild(script);
