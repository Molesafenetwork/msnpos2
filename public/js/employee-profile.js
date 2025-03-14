document.addEventListener('DOMContentLoaded', () => {
    loadEmployeeData();
    loadEmployeeStats();
});

async function loadEmployeeData() {
    try {
        const params = new URLSearchParams();
        params.append('employee', window.employeeUsername);
        
        const response = await fetch(`/api/clock/employee-shifts?${params}`);
        const shifts = await response.json();
        
        displayShifts(shifts);
    } catch (error) {
        console.error('Error loading employee data:', error);
    }
}

async function loadEmployeeStats() {
    try {
        const response = await fetch(`/api/employee-stats/${window.employeeUsername}`);
        const stats = await response.json();
        
        document.getElementById('totalHours').textContent = `${stats.totalHours} hours`;
        document.getElementById('avgShiftLength').textContent = `${stats.avgShiftLength} hours`;
    } catch (error) {
        console.error('Error loading employee stats:', error);
    }
}

function displayShifts(shifts) {
    const container = document.getElementById('employeeShifts');
    container.innerHTML = shifts.map(shift => `
        <div class="shift-entry" data-id="${shift.id}">
            <div class="shift-info">
                <p><strong>Clock In:</strong> ${new Date(shift.clockIn).toLocaleString()}</p>
                <p><strong>Clock Out:</strong> ${shift.clockOut ? new Date(shift.clockOut).toLocaleString() : 'Still Working'}</p>
                <p><strong>Duration:</strong> ${calculateDuration(shift.clockIn, shift.clockOut)}</p>
                ${shift.manualEntry ? '<p class="manual-entry">Manual Entry</p>' : ''}
            </div>
            <div class="shift-actions">
                <button onclick="deleteShift(${shift.id})" class="delete-btn">Delete</button>
            </div>
        </div>
    `).join('');
}

function calculateDuration(start, end) {
    const startTime = new Date(start);
    const endTime = end ? new Date(end) : new Date();
    const duration = Math.floor((endTime - startTime) / 1000 / 60);
    const hours = Math.floor(duration / 60);
    const minutes = duration % 60;
    return `${hours}h ${minutes}m`;
}

async function showAddShiftModal() {
    const modal = document.getElementById('addShiftModal');
    modal.style.display = 'block';
}

async function exportEmployeeData() {
    const params = new URLSearchParams({
        employee: window.employeeUsername
    });
    window.location.href = `/api/clock/export?${params}`;
}

async function deleteShift(shiftId) {
    if (!confirm('Are you sure you want to delete this shift?')) return;
    
    try {
        const response = await fetch(`/api/clock/entry/${shiftId}`, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            loadEmployeeData();
            loadEmployeeStats();
        } else {
            alert('Error deleting shift');
        }
    } catch (error) {
        console.error('Error deleting shift:', error);
    }
}

// Close modal when clicking the close button or outside the modal
document.addEventListener('click', (e) => {
    const modal = document.getElementById('addShiftModal');
    if (e.target.classList.contains('close') || e.target === modal) {
        modal.style.display = 'none';
    }
});

async function addManualShift(event) {
    event.preventDefault();
    
    const clockInTime = document.getElementById('clockInTime').value;
    const clockOutTime = document.getElementById('clockOutTime').value;
    
    try {
        const response = await fetch('/api/clock/manual-entry', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                username: window.employeeUsername,
                clockIn: new Date(clockInTime).toISOString(),
                clockOut: clockOutTime ? new Date(clockOutTime).toISOString() : null
            })
        });
        
        if (response.ok) {
            document.getElementById('addShiftModal').style.display = 'none';
            document.getElementById('manualEntryForm').reset();
            loadEmployeeData();
            loadEmployeeStats();
        } else {
            alert('Error adding manual entry');
        }
    } catch (error) {
        console.error('Error adding manual entry:', error);
    }
} 