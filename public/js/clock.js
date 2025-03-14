document.addEventListener('DOMContentLoaded', async () => {
    checkClockStatus();
    if (window.isAdmin) {
        await loadEmployees();
        loadTimeLogs();
    }
});

async function checkClockStatus() {
    try {
        const response = await fetch('/api/clock/status');
        const data = await response.json();
        updateStatusDisplay(data);
    } catch (error) {
        console.error('Error checking clock status:', error);
    }
}

async function clockIn() {
    try {
        const response = await fetch('/api/clock/in', { method: 'POST' });
        const data = await response.json();
        if (response.ok) {
            updateStatusDisplay(data);
            window.location.href = '/pos'; // Redirect to POS system
        } else {
            alert(data.error || 'Error clocking in');
        }
    } catch (error) {
        console.error('Error clocking in:', error);
    }
}

async function clockOut() {
    try {
        const response = await fetch('/api/clock/out', { method: 'POST' });
        const data = await response.json();
        if (response.ok) {
            updateStatusDisplay(data);
        } else {
            alert(data.error || 'Error clocking out');
        }
    } catch (error) {
        console.error('Error clocking out:', error);
    }
}

async function loadTimeLogs() {
    try {
        const response = await fetch('/api/time-logs');
        const logs = await response.json();
        const logsContainer = document.getElementById('timeLogs');
        
        if (logsContainer) {
            logsContainer.innerHTML = logs.map(log => `
                <div class="time-log">
                    <p><strong>Employee:</strong> ${log.username}</p>
                    <p><strong>Clock In:</strong> ${new Date(log.clockIn).toLocaleString()}</p>
                    <p><strong>Clock Out:</strong> ${log.clockOut ? new Date(log.clockOut).toLocaleString() : 'Still Working'}</p>
                    <p><strong>Duration:</strong> ${calculateDuration(log.clockIn, log.clockOut)}</p>
                    ${log.manualEntry ? '<p class="manual-entry">Manual Entry</p>' : ''}
                </div>
            `).join('');
        }
    } catch (error) {
        console.error('Error loading time logs:', error);
    }
}

function calculateDuration(start, end) {
    const startTime = new Date(start);
    const endTime = end ? new Date(end) : new Date();
    const duration = Math.floor((endTime - startTime) / 1000 / 60); // minutes
    
    const hours = Math.floor(duration / 60);
    const minutes = duration % 60;
    return `${hours}h ${minutes}m`;
}

function updateStatusDisplay(data) {
    const statusDiv = document.getElementById('currentStatus');
    if (data.isClockedIn) {
        statusDiv.innerHTML = `
            <p class="status-text">Currently Clocked In</p>
            <p>Since: ${new Date(data.clockInTime).toLocaleString()}</p>
        `;
    } else {
        statusDiv.innerHTML = '<p class="status-text">Not Clocked In</p>';
    }
}

// Add these new admin functions
async function viewEmployeeShifts() {
    const employee = document.getElementById('employeeFilter').value;
    if (!employee) return;

    try {
        const startDate = document.getElementById('startDate').value;
        const endDate = document.getElementById('endDate').value;
        
        const params = new URLSearchParams();
        if (startDate) params.append('start', startDate);
        if (endDate) params.append('end', endDate);
        params.append('employee', employee);

        const response = await fetch(`/api/clock/employee-shifts?${params}`);
        const shifts = await response.json();
        
        displayEmployeeShifts(shifts);
    } catch (error) {
        console.error('Error loading employee shifts:', error);
    }
}

function displayEmployeeShifts(shifts) {
    const container = document.getElementById('employeeShifts');
    container.innerHTML = shifts.map(shift => `
        <div class="shift-entry" data-id="${shift.id}">
            <div class="shift-info">
                <p>Clock In: ${new Date(shift.clockIn).toLocaleString()}</p>
                <p>Clock Out: ${shift.clockOut ? new Date(shift.clockOut).toLocaleString() : 'Still Working'}</p>
                <p>Duration: ${calculateDuration(shift.clockIn, shift.clockOut)}</p>
            </div>
            <div class="shift-actions">
                <button onclick="editShift('${shift.id}')">Edit</button>
                <button onclick="deleteShift('${shift.id}')">Delete</button>
            </div>
        </div>
    `).join('');
}

async function showAddShiftModal() {
    const modal = document.getElementById('addShiftModal');
    modal.style.display = 'block';
    
    // Populate employee dropdown
    const response = await fetch('/api/employees');
    const employees = await response.json();
    const select = document.getElementById('shiftEmployee');
    select.innerHTML = employees.map(emp => 
        `<option value="${emp}">${emp}</option>`
    ).join('');
}

async function addManualEntry(event) {
    event.preventDefault();
    const formData = {
        username: document.getElementById('shiftEmployee').value,
        clockIn: new Date(document.getElementById('clockInTime').value).toISOString(),
        clockOut: document.getElementById('clockOutTime').value ? 
            new Date(document.getElementById('clockOutTime').value).toISOString() : null
    };

    try {
        const response = await fetch('/api/clock/manual-entry', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        });

        if (response.ok) {
            document.getElementById('addShiftModal').style.display = 'none';
            viewEmployeeShifts();
        }
    } catch (error) {
        console.error('Error adding manual entry:', error);
    }
}

function exportTimeLogs() {
    const employee = document.getElementById('employeeFilter').value;
    const startDate = document.getElementById('startDate').value;
    const endDate = document.getElementById('endDate').value;
    
    const params = new URLSearchParams({ employee, startDate, endDate });
    window.location.href = `/api/clock/export?${params}`;
}

async function editShift(id) {
    try {
        const response = await fetch(`/api/clock/entry/${id}`);
        const shift = await response.json();
        
        const modal = document.getElementById('editShiftModal');
        modal.style.display = 'block';
        
        document.getElementById('editClockIn').value = new Date(shift.clockIn).toISOString().slice(0, 16);
        if (shift.clockOut) {
            document.getElementById('editClockOut').value = new Date(shift.clockOut).toISOString().slice(0, 16);
        }
        
        document.getElementById('editShiftForm').onsubmit = (e) => submitEditShift(e, id);
    } catch (error) {
        console.error('Error loading shift:', error);
    }
}

async function submitEditShift(event, id) {
    event.preventDefault();
    const formData = {
        clockIn: new Date(document.getElementById('editClockIn').value).toISOString(),
        clockOut: document.getElementById('editClockOut').value ? 
            new Date(document.getElementById('editClockOut').value).toISOString() : null
    };

    try {
        const response = await fetch(`/api/clock/entry/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(formData)
        });

        if (response.ok) {
            document.getElementById('editShiftModal').style.display = 'none';
            viewEmployeeShifts();
        }
    } catch (error) {
        console.error('Error updating shift:', error);
    }
}

async function deleteShift(id) {
    if (!confirm('Are you sure you want to delete this shift?')) return;

    try {
        const response = await fetch(`/api/clock/entry/${id}`, {
            method: 'DELETE'
        });

        if (response.ok) {
            viewEmployeeShifts();
        }
    } catch (error) {
        console.error('Error deleting shift:', error);
    }
}

async function loadEmployees() {
    try {
        const response = await fetch('/api/employees');
        const employees = await response.json();
        const employeeFilter = document.getElementById('employeeFilter');
        
        if (employeeFilter) {
            employeeFilter.innerHTML = `
                <option value="">Select Employee</option>
                ${employees.map(emp => `
                    <option value="${emp}">${emp}</option>
                `).join('')}
            `;
        }
    } catch (error) {
        console.error('Error loading employees:', error);
    }
}

async function filterLogs() {
    const employee = document.getElementById('employeeFilter').value;
    const startDate = document.getElementById('startDate').value;
    const endDate = document.getElementById('endDate').value;
    
    try {
        const params = new URLSearchParams();
        if (employee) params.append('employee', employee);
        if (startDate) params.append('start', startDate);
        if (endDate) params.append('end', endDate);
        
        const response = await fetch(`/api/time-logs?${params}`);
        const logs = await response.json();
        displayEmployeeShifts(logs);
    } catch (error) {
        console.error('Error filtering logs:', error);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    const manualEntryForm = document.getElementById('manualEntryForm');
    if (manualEntryForm) {
        manualEntryForm.addEventListener('submit', (e) => {
            e.preventDefault();
            addManualEntry(e);
        });
    }

    // Add modal close functionality
    const closeButtons = document.getElementsByClassName('close');
    Array.from(closeButtons).forEach(button => {
        button.onclick = function() {
            const modal = this.closest('.modal');
            if (modal) modal.style.display = 'none';
        };
    });
}); 