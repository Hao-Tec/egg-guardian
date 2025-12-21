/**
 * Egg Guardian Admin - Client-side JavaScript
 */

const API_BASE = 'http://localhost:8000/api/v1';

// State
let devices = [];
let alertRules = [];
let users = [];

// DOM elements
const deviceForm = document.getElementById('device-form');
const alertForm = document.getElementById('alert-form');
const devicesList = document.getElementById('devices-list');
const alertsList = document.getElementById('alerts-list');
const alertDeviceSelect = document.getElementById('alert-device');
const usersList = document.getElementById('users-list');

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

// Fetch alert rules from API (for all devices)
async function fetchAlertRules() {
    try {
        // Alert rules are per-device, so we need to fetch for each device
        alertRules = [];
        for (const device of devices) {
            try {
                const response = await fetch(`${API_BASE}/devices/${device.id}/rules`);
                if (response.ok) {
                    const rules = await response.json();
                    // Add device name to each rule for display
                    rules.forEach(rule => {
                        rule.device_name = device.name;
                    });
                    alertRules = alertRules.concat(rules);
                }
            } catch (e) {
                console.error(`Failed to fetch rules for device ${device.id}:`, e);
            }
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
                <div class="name">${user.email}</div>
                <div class="meta">${user.full_name || 'No name'} • Joined ${new Date(user.created_at).toLocaleDateString()}</div>
            </div>
            <div style="display: flex; align-items: center; gap: 12px;">
                <span class="meta">${user.is_active ? '🟢 Active' : '🔴 Inactive'}</span>
                <button class="delete-btn" onclick="deleteUser(${user.id}, '${user.email}')" title="Delete user">🗑️</button>
            </div>
        </div>
    `).join('');
}

// Fetch users from API
async function fetchUsers() {
    try {
        const response = await fetch(`${API_BASE}/users`);
        if (response.ok) {
            users = await response.json();
            renderUsers();
        }
    } catch (error) {
        console.error('Failed to fetch users:', error);
        users = [];
        renderUsers();
    }
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
    fetchDevices();
    fetchAlertRules();
    fetchUsers();
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
                showToast('User deleted successfully!');
                await fetchUsers();
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
