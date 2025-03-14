document.getElementById('editInvoiceForm').addEventListener('submit', function(e) {
    e.preventDefault(); // Prevent the default form submission

    const formData = new FormData(this);
    const invoiceId = window.location.pathname.split('/').pop(); // Get the invoice ID from the URL

    fetch(`/update-invoice/${invoiceId}`, {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            alert('Invoice appearance updated successfully!');
            window.location.href = '/dashboard'; // Redirect to the dashboard
        } else {
            alert('Error updating invoice: ' + data.error);
        }
    })
    .catch(error => {
        console.error('Error updating invoice:', error);
        alert('Error updating invoice: ' + error.message);
    });
});