console.log("Invoice script loaded");

function addItem() {
    console.log("addItem function called");
    const itemsDiv = document.getElementById('items');
    const newItem = document.createElement('div');
    newItem.className = 'item';
    const itemCount = itemsDiv.children.length + 1;
    newItem.innerHTML = `
        <input type="text" name="itemName[]" placeholder="Item ${itemCount} Name" required>
        <input type="text" name="itemDescription[]" placeholder="Item ${itemCount} Description" required>
        <input type="number" name="itemUnitCost[]" placeholder="Unit Cost" step="0.01" required onchange="updateTotals()">
        <input type="number" name="itemQuantity[]" placeholder="Quantity" required onchange="updateTotals()">
        <input type="number" name="itemGST[]" placeholder="GST %" min="0" max="100" step="0.1" required value="10" onchange="updateTotals()">
        <span class="itemTotal">$0.00</span>
        <button type="button" onclick="this.parentElement.remove(); updateTotals();">Remove</button>
    `;
    itemsDiv.appendChild(newItem);
    updateTotals();
    console.log("New item added");
}

function updateTotals() {
    const items = document.querySelectorAll('.item');
    let subtotal = 0;
    let totalGST = 0;

    items.forEach(item => {
        const unitCost = parseFloat(item.querySelector('input[name="itemUnitCost[]"]').value) || 0;
        const quantity = parseInt(item.querySelector('input[name="itemQuantity[]"]').value) || 0;
        const gstPercentage = parseFloat(item.querySelector('input[name="itemGST[]"]').value) || 0;

        const itemSubtotal = unitCost * quantity;
        const itemGST = itemSubtotal * (gstPercentage / 100);
        const itemTotal = itemSubtotal + itemGST;

        subtotal += itemSubtotal;
        totalGST += itemGST;

        item.querySelector('.itemTotal').textContent = `$${itemTotal.toFixed(2)}`;
    });

    const total = subtotal + totalGST;

    document.getElementById('subtotal').textContent = `$${subtotal.toFixed(2)}`;
    document.getElementById('totalGST').textContent = `$${totalGST.toFixed(2)}`;
    document.getElementById('total').textContent = `$${total.toFixed(2)}`;
}

// Initial call to set up totals
document.addEventListener('DOMContentLoaded', updateTotals);