/**
 * Egg Guardian Admin - Client-side JavaScript
 */

const API_BASE = 'http://localhost:8000/api/v1';

// State
let devices = [];
let alertRules = [];

// DOM elements
const deviceForm = document.getElementById('device-form');
const alertForm = document.getElementById('alert-form');
const devicesList = document.getElementById('devices-list');
const alertsList = document.getElementById('alerts-list');
const alertDeviceSelect = document.getElementById('alert-device');

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
            <div class="meta">${device.is_active ? '🟢 Active' : '⚪ Inactive'}</div>
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
                <div class="name">Device: ${rule.device_id}</div>
                <div class="meta">${rule.temp_min}°C – ${rule.temp_max}°C</div>
            </div>
            <div class="meta">${rule.is_active ? '🔔 Active' : '🔕 Muted'}</div>
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

// Fetch alert rules from API
async function fetchAlertRules() {
    try {
        const response = await fetch(`${API_BASE}/rules`);
        if (response.ok) {
            alertRules = await response.json();
            renderAlertRules();
        }
    } catch (error) {
        console.error('Failed to fetch alert rules:', error);
        // Use mock data for demo
        alertRules = [];
        renderAlertRules();
    }
}

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
});
