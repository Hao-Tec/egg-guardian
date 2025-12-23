/**
 * Egg Guardian Admin - Client-side JavaScript
 */

const API_BASE = 'http://localhost:8000/api/v1';

// State
let devices = [];
let alertRules = [];
let users = [];
let triggeredAlerts = [];
let authToken = localStorage.getItem('admin_token');
let currentUser = null;

// Session security
const SESSION_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes
const INACTIVITY_TIMEOUT_MS = 15 * 60 * 1000; // 15 minutes of inactivity
let sessionTimeoutId = null;
let inactivityTimeoutId = null;
let loginTimestamp = localStorage.getItem('admin_login_time');

// Security: HTML escape to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// DOM elements
const deviceForm = document.getElementById('device-form');
const alertForm = document.getElementById('alert-form');
const devicesList = document.getElementById('devices-list');
const alertsList = document.getElementById('alerts-list');
const alertDeviceSelect = document.getElementById('alert-device');
const usersList = document.getElementById('users-list');
const triggeredAlertsList = document.getElementById('triggered-alerts-list');
const loginScreen = document.getElementById('login-screen');
const adminPanel = document.getElementById('admin-panel');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');
const adminEmail = document.getElementById('admin-email');
const logoutBtn = document.getElementById('logout-btn');

// ============== Authentication ==============

async function checkAuth() {
    if (!authToken) {
        showLogin();
        return false;
    }
    
    // Check if session has expired (page was left open too long)
    if (checkSessionExpiry()) {
        logout(true);
        return false;
    }
    
    try {
        // Verify token by fetching current user info
        const response = await fetch(`${API_BASE}/auth/me`, {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        
        if (!response.ok) {
            throw new Error('Invalid token');
        }
        
        currentUser = await response.json();
        
        // Check if user is admin
        if (!currentUser.is_superuser) {
            loginError.textContent = 'Access denied. You are not an admin.';
            logout();
            return false;
        }
        
        showAdminPanel();
        return true;
    } catch (error) {
        console.error('Auth check failed:', error);
        logout();
        return false;
    }
}

function showLogin() {
    loginScreen.classList.remove('hidden');
    adminPanel.classList.add('hidden');
}

function showAdminPanel() {
    loginScreen.classList.add('hidden');
    adminPanel.classList.remove('hidden');
    adminEmail.textContent = `👤 ${currentUser?.email || 'Admin'}`;
    
    // Start session security
    startSession();
    
    // Load data
    fetchDevices();
    fetchAlertRules();
    fetchUsers();
    fetchTriggeredAlerts();
    
    // Start auto-refresh for all data
    startDataAutoRefresh();
}

async function login(email, password) {
    try {
        const response = await fetch(`${API_BASE}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password })
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.detail || 'Login failed');
        }
        
        const data = await response.json();
        authToken = data.access_token;
        localStorage.setItem('admin_token', authToken);
        
        await checkAuth();
    } catch (error) {
        loginError.textContent = error.message;
    }
}

function logout(showExpiredMessage = false) {
    stopDataAutoRefresh();
    stopSessionTimers();
    authToken = null;
    currentUser = null;
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_login_time');
    showLogin();
    
    if (showExpiredMessage) {
        showToast('Session expired. Please login again.', true);
    }
}

// Session security functions
function startSession() {
    loginTimestamp = Date.now();
    localStorage.setItem('admin_login_time', loginTimestamp);
    
    // Set absolute session timeout (30 minutes from login)
    sessionTimeoutId = setTimeout(() => {
        console.log('Session timeout reached');
        logout(true);
    }, SESSION_TIMEOUT_MS);
    
    // Start inactivity timer
    resetActivityTimer();
    
    // Add activity listeners
    ['mousedown', 'keydown', 'scroll', 'touchstart'].forEach(event => {
        document.addEventListener(event, resetActivityTimer);
    });
}

function resetActivityTimer() {
    if (inactivityTimeoutId) clearTimeout(inactivityTimeoutId);
    
    inactivityTimeoutId = setTimeout(() => {
        console.log('Inactivity timeout reached');
        logout(true);
    }, INACTIVITY_TIMEOUT_MS);
}

function stopSessionTimers() {
    if (sessionTimeoutId) {
        clearTimeout(sessionTimeoutId);
        sessionTimeoutId = null;
    }
    if (inactivityTimeoutId) {
        clearTimeout(inactivityTimeoutId);
        inactivityTimeoutId = null;
    }
    
    // Remove activity listeners
    ['mousedown', 'keydown', 'scroll', 'touchstart'].forEach(event => {
        document.removeEventListener(event, resetActivityTimer);
    });
}

function checkSessionExpiry() {
    if (!loginTimestamp) return false;
    
    const elapsed = Date.now() - parseInt(loginTimestamp);
    return elapsed > SESSION_TIMEOUT_MS;
}

// Login form handler
loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    loginError.textContent = '';
    
    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;
    
    await login(email, password);
});

// Logout handler
logoutBtn.addEventListener('click', () => logout(false));

// Password visibility toggle
document.getElementById('toggle-password').addEventListener('click', function() {
    const passwordInput = document.getElementById('login-password');
    const isPassword = passwordInput.type === 'password';
    passwordInput.type = isPassword ? 'text' : 'password';
    this.textContent = isPassword ? '🙈' : '👁️';
    this.title = isPassword ? 'Hide password' : 'Show password';
});

// Toast notification
function showToast(message, isError = false) {
    const toast = document.createElement('div');
    toast.className = `toast${isError ? ' error' : ''}`;
    toast.textContent = message;
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 3000);
}

// Render devices list
function renderDevices() {
    if (devices.length === 0) {
        devicesList.innerHTML = '<p class="empty-state">No devices registered yet.</p>';
        alertDeviceSelect.innerHTML = '<option value="">Select device...</option>';
        return;
    }
    
    devicesList.innerHTML = devices.map(device => `
        <div class="list-item">
            <div>
                <div class="name">${device.name}</div>
                <div class="meta">${device.device_id}</div>
            </div>
            <div style="display: flex; align-items: center; gap: 12px;">
                <span class="meta">${device.is_active ? '🟢 Active' : '⚪ Inactive'}</span>
                <button class="delete-btn" onclick="deleteDevice(${device.id}, '${device.name}')" title="Delete device">🗑️</button>
            </div>
        </div>
    `).join('');
    
    alertDeviceSelect.innerHTML = `
        <option value="">Select device...</option>
        ${devices.map(d => `<option value="${d.id}">${d.name} (${d.device_id})</option>`).join('')}
    `;
}

// Render alert rules
function renderAlertRules() {
    if (alertRules.length === 0) {
        alertsList.innerHTML = '<p class="empty-state">No alert rules configured.</p>';
        return;
    }
    
    alertsList.innerHTML = alertRules.map(rule => `
        <div class="list-item">
            <div>
                <div class="name">${rule.device_name || `Device #${rule.device_id}`}</div>
                <div class="meta">${rule.temp_min}°C – ${rule.temp_max}°C</div>
            </div>
            <div style="display: flex; align-items: center; gap: 12px;">
                <span class="meta">${rule.is_active ? '🔔 Active' : '🔕 Muted'}</span>
                <button class="delete-btn" onclick="deleteRule(${rule.device_id}, ${rule.id})" title="Delete rule">🗑️</button>
            </div>
        </div>
    `).join('');
}

// Fetch devices from API
async function fetchDevices() {
    try {
        const response = await fetch(`${API_BASE}/devices`);
        if (response.ok) {
            devices = await response.json();
            renderDevices();
        }
    } catch (error) {
        console.error('Failed to fetch devices:', error);
        // Use mock data for demo
        devices = [
            { id: 1, device_id: 'eggpod-01', name: 'Demo Incubator', is_active: true }
        ];
        renderDevices();
    }
}

// Fetch alert rules from API (bulk fetch - single request for all devices)
async function fetchAlertRules() {
    try {
        // Use bulk endpoint to avoid N+1 queries
        const response = await fetch(`${API_BASE}/devices/rules/all`);
        if (response.ok) {
            alertRules = await response.json();
        } else {
            alertRules = [];
        }
        renderAlertRules();
    } catch (error) {
        console.error('Failed to fetch alert rules:', error);
        alertRules = [];
        renderAlertRules();
    }
}

// Render users list
function renderUsers() {
    if (users.length === 0) {
        usersList.innerHTML = '<p class="empty-state">No users registered yet.</p>';
        return;
    }
    
    usersList.innerHTML = users.map(user => `
        <div class="list-item">
            <div>
                <div class="name">
                    ${escapeHtml(user.email)}
                    ${user.is_superuser ? '<span class="role-badge admin">Admin</span>' : '<span class="role-badge user">User</span>'}
                </div>
                <div class="meta">${escapeHtml(user.full_name || 'No name')} • Joined ${new Date(user.created_at).toLocaleDateString()}</div>
            </div>
            <div style="display: flex; align-items: center; gap: 8px;">
                <button class="btn-toggle ${user.is_superuser ? 'active' : ''}" 
                        onclick="toggleAdminStatus(${user.id})" 
                        title="${user.is_superuser ? 'Remove admin' : 'Make admin'}">
                    ${user.is_superuser ? '👑 Admin' : '🔓 Make Admin'}
                </button>
                <button class="delete-btn" onclick="deleteUser(${user.id}, '${escapeHtml(user.email)}')" title="Delete user">🗑️</button>
            </div>
        </div>
    `).join('');
}

// Toggle admin status for a user
async function toggleAdminStatus(userId) {
    try {
        const response = await fetch(`${API_BASE}/users/${userId}/toggle-admin`, {
            method: 'PATCH',
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        
        if (response.ok) {
            const user = await response.json();
            showToast(`${user.email} is now ${user.is_superuser ? 'an admin' : 'a regular user'}`);
            await fetchUsers();
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to toggle admin status', true);
        }
    } catch (error) {
        console.error('Toggle admin failed:', error);
        showToast('Failed to toggle admin status', true);
    }
}

// Fetch users from API (requires admin auth)
async function fetchUsers() {
    try {
        const response = await fetch(`${API_BASE}/users`, {
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        if (response.ok) {
            users = await response.json();
            renderUsers();
        } else if (response.status === 401 || response.status === 403) {
            console.warn('Not authorized to fetch users');
            users = [];
            renderUsers();
        }
    } catch (error) {
        console.error('Failed to fetch users:', error);
        users = [];
        renderUsers();
    }
}

// ============== Triggered Alerts ==============

// Render triggered alerts
function renderTriggeredAlerts() {
    if (triggeredAlerts.length === 0) {
        triggeredAlertsList.innerHTML = '<p class="empty-state">No alerts triggered yet. 🎉</p>';
        return;
    }
    
    triggeredAlertsList.innerHTML = triggeredAlerts.map(alert => {
        const device = devices.find(d => d.id === alert.device_id);
        const deviceName = device ? device.name : `Device #${alert.device_id}`;
        const time = new Date(alert.triggered_at).toLocaleString();
        const alertClass = alert.is_acknowledged ? 'acknowledged' : 'unacknowledged';
        const icon = alert.alert_type === 'high' ? '🔥' : '❄️';
        
        return `
            <div class="alert-item ${alertClass}">
                <div class="alert-info">
                    <div class="alert-header">
                        <span class="alert-icon">${icon}</span>
                        <span class="alert-type ${alert.alert_type}">${alert.alert_type.toUpperCase()}</span>
                        <span class="alert-device">${deviceName}</span>
                    </div>
                    <div class="alert-message">${alert.message}</div>
                    <div class="alert-time">${time}</div>
                </div>
                <div class="alert-actions">
                    ${!alert.is_acknowledged ? 
                        `<button class="btn btn-small" onclick="acknowledgeAlert(${alert.id})">✓ Acknowledge</button>` : 
                        '<span class="acknowledged-badge">✓ Acknowledged</span>'}
                </div>
            </div>
        `;
    }).join('');
}

// Fetch triggered alerts from API
let showAcknowledged = false;
let alertsRefreshInterval = null;

async function fetchTriggeredAlerts() {
    try {
        const url = showAcknowledged 
            ? `${API_BASE}/alerts?limit=200` 
            : `${API_BASE}/alerts?unacknowledged_only=true&limit=100`;
        const response = await fetch(url);
        if (response.ok) {
            triggeredAlerts = await response.json();
            renderTriggeredAlerts();
        }
    } catch (error) {
        console.error('Failed to fetch alerts:', error);
        triggeredAlerts = [];
        renderTriggeredAlerts();
    }
}

// Start auto-refresh for all data
let dataRefreshInterval = null;

function startDataAutoRefresh() {
    if (dataRefreshInterval) clearInterval(dataRefreshInterval);
    dataRefreshInterval = setInterval(() => {
        fetchDevices();          // Refresh devices
        fetchAlertRules();       // Refresh alert rules
        fetchTriggeredAlerts();  // Refresh triggered alerts
        // Note: Not refreshing users as it's less dynamic
    }, 5000); // Refresh every 5 seconds
}

// Stop auto-refresh
function stopDataAutoRefresh() {
    if (dataRefreshInterval) {
        clearInterval(dataRefreshInterval);
        dataRefreshInterval = null;
    }
}

// Toggle alert filter
function toggleAlertFilter() {
    showAcknowledged = document.getElementById('show-acknowledged').checked;
    fetchTriggeredAlerts();
}

// Acknowledge a single alert
async function acknowledgeAlert(alertId) {
    try {
        const response = await fetch(`${API_BASE}/alerts/${alertId}/acknowledge`, {
            method: 'PATCH',
        });
        
        if (response.ok) {
            showToast('Alert acknowledged!');
            await fetchTriggeredAlerts();
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to acknowledge alert', true);
        }
    } catch (error) {
        console.error('Acknowledge failed:', error);
        showToast('Failed to acknowledge alert', true);
    }
}

// Acknowledge all alerts
async function acknowledgeAllAlerts() {
    try {
        const response = await fetch(`${API_BASE}/alerts/acknowledge-all`, {
            method: 'PATCH',
        });
        
        if (response.ok) {
            const result = await response.json();
            showToast(`${result.acknowledged} alerts acknowledged!`);
            await fetchTriggeredAlerts();
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to acknowledge alerts', true);
        }
    } catch (error) {
        console.error('Acknowledge all failed:', error);
        showToast('Failed to acknowledge alerts', true);
    }
}

// Clear (delete) acknowledged alerts
async function clearAcknowledgedAlerts() {
    try {
        const response = await fetch(`${API_BASE}/alerts/clear-acknowledged`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        
        if (response.ok) {
            const result = await response.json();
            showToast(`${result.deleted} acknowledged alerts cleared!`);
            await fetchTriggeredAlerts();
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to clear alerts', true);
        }
    } catch (error) {
        console.error('Clear alerts failed:', error);
        showToast('Failed to clear alerts', true);
    }
}

// Delete ALL alerts (show custom modal)
function deleteAllAlerts() {
    document.getElementById('delete-all-modal').classList.remove('hidden');
}

// Actually delete all alerts after confirmation
async function confirmDeleteAllAlerts() {
    document.getElementById('delete-all-modal').classList.add('hidden');
    
    try {
        const response = await fetch(`${API_BASE}/alerts/delete-all`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${authToken}` }
        });
        
        if (response.ok) {
            const result = await response.json();
            showToast(`${result.deleted} alerts deleted!`);
            await fetchTriggeredAlerts();
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to delete alerts', true);
        }
    } catch (error) {
        console.error('Delete all alerts failed:', error);
        showToast('Failed to delete alerts', true);
    }
}

// Cancel delete all
function cancelDeleteAll() {
    document.getElementById('delete-all-modal').classList.add('hidden');
}

// Delete a user
function deleteUser(userId, userEmail) {
    pendingDeleteUserId = userId;
    pendingDeleteUserEmail = userEmail;
    pendingDeleteDeviceId = null;
    pendingDeleteRuleId = null;
    
    // Update modal text for user deletion
    document.querySelector('.modal-title').textContent = 'Delete User?';
    document.querySelector('.modal-message').textContent = 
        `Are you sure you want to delete "${userEmail}"? This cannot be undone.`;
    
    document.getElementById('confirm-modal').classList.remove('hidden');
}

let pendingDeleteUserId = null;
let pendingDeleteUserEmail = null;

// Handle device registration
deviceForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const deviceId = document.getElementById('device-id').value;
    const deviceName = document.getElementById('device-name').value;
    
    try {
        const response = await fetch(`${API_BASE}/devices`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                device_id: deviceId,
                name: deviceName
            })
        });
        
        if (response.ok) {
            showToast('Device registered successfully!');
            deviceForm.reset();
            await fetchDevices();
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to register device', true);
        }
    } catch (error) {
        // Demo mode - add locally
        devices.push({
            id: devices.length + 1,
            device_id: deviceId,
            name: deviceName,
            is_active: true
        });
        renderDevices();
        showToast('Device registered (demo mode)');
        deviceForm.reset();
    }
});

// Handle alert rule creation
alertForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const deviceId = document.getElementById('alert-device').value;
    const tempMin = parseFloat(document.getElementById('temp-min').value);
    const tempMax = parseFloat(document.getElementById('temp-max').value);
    
    if (!deviceId) {
        showToast('Please select a device', true);
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/devices/${deviceId}/rules`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                temp_min: tempMin,
                temp_max: tempMax
            })
        });
        
        if (response.ok) {
            showToast('Alert rule created successfully!');
            alertForm.reset();
            await fetchAlertRules();
        } else {
            const error = await response.json();
            showToast(error.detail || 'Failed to create rule', true);
        }
    } catch (error) {
        // Demo mode - add locally
        alertRules.push({
            id: alertRules.length + 1,
            device_id: deviceId,
            temp_min: tempMin,
            temp_max: tempMax,
            is_active: true
        });
        renderAlertRules();
        showToast('Alert rule created (demo mode)');
        alertForm.reset();
    }
});

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    checkAuth();
});

// Delete an alert rule
let pendingDeleteDeviceId = null;
let pendingDeleteRuleId = null;

function deleteRule(deviceId, ruleId) {
    pendingDeleteDeviceId = deviceId;
    pendingDeleteRuleId = ruleId;
    
    // Update modal text for rule deletion
    document.querySelector('.modal-title').textContent = 'Delete Alert Rule?';
    document.querySelector('.modal-message').textContent = 'This action cannot be undone.';
    
    document.getElementById('confirm-modal').classList.remove('hidden');
}

// Modal event handlers
document.getElementById('modal-cancel').addEventListener('click', () => {
    document.getElementById('confirm-modal').classList.add('hidden');
    pendingDeleteDeviceId = null;
    pendingDeleteRuleId = null;
});

// Close modal on overlay click
document.getElementById('confirm-modal').addEventListener('click', (e) => {
    if (e.target.id === 'confirm-modal') {
        document.getElementById('confirm-modal').classList.add('hidden');
        pendingDeleteDeviceId = null;
        pendingDeleteRuleId = null;
        pendingDeleteDeviceName = null;
    }
});

// Delete a device
let pendingDeleteDeviceName = null;

function deleteDevice(deviceId, deviceName) {
    pendingDeleteDeviceId = deviceId;
    pendingDeleteDeviceName = deviceName;
    pendingDeleteRuleId = null; // Not deleting a rule
    
    // Update modal text
    document.querySelector('.modal-title').textContent = 'Delete Device?';
    document.querySelector('.modal-message').textContent = 
        `Are you sure you want to delete "${deviceName}"? All telemetry data and alert rules will also be deleted.`;
    
    document.getElementById('confirm-modal').classList.remove('hidden');
}

// Override confirm click to handle both device and rule deletion
document.getElementById('modal-confirm').removeEventListener('click', handleConfirm);
async function handleConfirm() {
    document.getElementById('confirm-modal').classList.add('hidden');
    
    if (pendingDeleteRuleId) {
        // Delete rule
        try {
            const response = await fetch(`${API_BASE}/devices/${pendingDeleteDeviceId}/rules/${pendingDeleteRuleId}`, {
                method: 'DELETE',
            });
            
            if (response.ok || response.status === 204) {
                showToast('Alert rule deleted successfully!');
                await fetchAlertRules();
            } else {
                const error = await response.json();
                showToast(error.detail || 'Failed to delete rule', true);
            }
        } catch (error) {
            alertRules = alertRules.filter(r => r.id !== pendingDeleteRuleId);
            renderAlertRules();
            showToast('Alert rule deleted (demo mode)');
        }
    } else if (pendingDeleteUserId) {
        // Delete user
        try {
            const response = await fetch(`${API_BASE}/users/${pendingDeleteUserId}`, {
                method: 'DELETE',
            });
            
            if (response.ok || response.status === 204) {
                // Check if user deleted themselves
                if (currentUser && pendingDeleteUserId === currentUser.id) {
                    showToast('You deleted your own account. Logging out...');
                    setTimeout(() => logout(), 1500);
                } else {
                    showToast('User deleted successfully!');
                    await fetchUsers();
                }
            } else {
                const error = await response.json();
                showToast(error.detail || 'Failed to delete user', true);
            }
        } catch (error) {
            users = users.filter(u => u.id !== pendingDeleteUserId);
            renderUsers();
            showToast('User deleted (demo mode)');
        }
    } else if (pendingDeleteDeviceId) {
        // Delete device
        try {
            const response = await fetch(`${API_BASE}/devices/${pendingDeleteDeviceId}`, {
                method: 'DELETE',
            });
            
            if (response.ok || response.status === 204) {
                showToast('Device deleted successfully!');
                await fetchDevices();
                await fetchAlertRules();
            } else {
                const error = await response.json();
                showToast(error.detail || 'Failed to delete device', true);
            }
        } catch (error) {
            devices = devices.filter(d => d.id !== pendingDeleteDeviceId);
            renderDevices();
            showToast('Device deleted (demo mode)');
        }
    }
    
    pendingDeleteDeviceId = null;
    pendingDeleteRuleId = null;
    pendingDeleteDeviceName = null;
    pendingDeleteUserId = null;
    pendingDeleteUserEmail = null;
}
document.getElementById('modal-confirm').addEventListener('click', handleConfirm);

// Delete All Modal listeners
document.getElementById('delete-all-confirm').addEventListener('click', confirmDeleteAllAlerts);
document.getElementById('delete-all-cancel').addEventListener('click', cancelDeleteAll);
