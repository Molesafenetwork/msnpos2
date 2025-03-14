document.addEventListener('DOMContentLoaded', () => {
    loadTimeLogs();
    populateEmployeeFilter();
});

async function loadTimeLogs() {
    try {
        const startDate = document.getElementById('startDate').value;
        const endDate = document.getElementById('endDate').value;
        const employee = document.getElementById('employeeFilter').value;

        const queryParams = new URLSearchParams();
        if (startDate) queryParams.append('start', startDate);
        if (endDate) queryParams.append('end', endDate);
        if (employee) queryParams.append('employee', employee);

        const response = await fetch(`/api/time-logs?${queryParams}`);
        const logs = await response.json();

        const logsContent = document.getElementById('timeLogsContent');
        logsContent.innerHTML = logs.map(log => `
            <div class="time-log-row">
                <span>${log.username}</span>
                <span>${formatDateTime(log.clockIn)}</span>
                <span>${log.clockOut ? formatDateTime(log.clockOut) : 'Active'}</span>
                <span>${calculateDuration(log.clockIn, log.clockOut)}</span>
            </div>
        `).join('');
    } catch (error) {
        console.error('Error loading time logs:', error);
    }
}

async function populateEmployeeFilter() {
    try {
        const response = await fetch('/api/employees');
        const employees = await response.json();
        
        const select = document.getElementById('employeeFilter');
        employees.forEach(employee => {
            const option = document.createElement('option');
            option.value = employee;
            option.textContent = employee;
            select.appendChild(option);
        });
    } catch (error) {
        console.error('Error loading employees:', error);
    }
}

function formatDateTime(dateString) {
    return new Date(dateString).toLocaleString();
}

function calculateDuration(start, end) {
    const startTime = new Date(start);
    const endTime = end ? new Date(end) : new Date();
    const duration = Math.floor((endTime - startTime) / 1000 / 60); // minutes
    
    const hours = Math.floor(duration / 60);
    const minutes = duration % 60;
    return `${hours}h ${minutes}m`;
}

function applyFilters() {
    loadTimeLogs();
} 