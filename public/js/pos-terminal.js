let savedItems = [];
let categories = [];
let currentCart = [];
let currentCategory = 'all';

// Load saved items on page load
document.addEventListener('DOMContentLoaded', async () => {
    await loadCategories();
    await loadSavedItems();
});

async function loadCategories() {
    try {
        const response = await fetch('/api/pos-categories');
        categories = await response.json();
        renderCategories();
    } catch (error) {
        console.error('Error loading categories:', error);
    }
}

function renderCategories() {
    const tabs = document.getElementById('categoryTabs');
    const categorySelect = document.querySelector('select[name="category"]');
    
    // Populate category tabs
    const categoryTabs = categories.map(category => `
        <div class="category-tab-wrapper">
            <button class="category-tab ${currentCategory === category.id ? 'active' : ''}" 
                    onclick="filterByCategory('${category.id}')">
                ${category.name}
            </button>
            ${window.isAdmin ? `
                <button class="delete-category-btn" onclick="deleteCategory(${category.id})" title="Delete Category">×</button>
            ` : ''}
        </div>
    `).join('');
    
    tabs.innerHTML = `
        <button class="category-tab all-items ${currentCategory === 'all' ? 'active' : ''}" 
                onclick="filterByCategory('all')">All Items</button>
        ${categoryTabs}
    `;

    // Populate category select in add item form if admin
    if (window.isAdmin && categorySelect) {
        categorySelect.innerHTML = `
            <option value="">Select Category</option>
            ${categories.map(category => `
                <option value="${category.id}">${category.name}</option>
            `).join('')}
        `;
    }
}

function filterByCategory(categoryId) {
    currentCategory = categoryId;
    renderItems();
    renderCategories(); // Update active state of tabs
}

async function loadSavedItems() {
    try {
        const response = await fetch('/api/pos-items');
        savedItems = await response.json();
        renderItems();
    } catch (error) {
        console.error('Error loading items:', error);
    }
}

function renderItems() {
    const grid = document.getElementById('itemsGrid');
    const filteredItems = currentCategory === 'all' 
        ? savedItems 
        : savedItems.filter(item => item.categoryId === currentCategory);

    grid.innerHTML = filteredItems.map(item => `
        <div class="item-button">
            <h3>${item.name}</h3>
            <p>$${item.price.toFixed(2)}</p>
            ${window.isAdmin ? `
                <div class="item-actions">
                    <button onclick="addToCart(${item.id})">Add to Cart</button>
                    <button onclick="showEditItemModal(${JSON.stringify(item).replace(/"/g, '&quot;')})" class="edit-btn">Edit</button>
                    <button onclick="deleteItem(${item.id})" class="delete-btn">Delete</button>
                </div>
            ` : `
                <div class="item-actions">
                    <button onclick="addToCart(${item.id})">Add to Cart</button>
                </div>
            `}
        </div>
    `).join('');
}

function addToCart(itemId) {
    const item = savedItems.find(i => i.id === itemId);
    if (!item) return;

    const existingItem = currentCart.find(i => i.id === itemId);
    if (existingItem) {
        existingItem.quantity++;
    } else {
        currentCart.push({ ...item, quantity: 1 });
    }
    updateCartDisplay();
}

function updateCartDisplay() {
    const cartDiv = document.getElementById('cartItems');
    cartDiv.innerHTML = currentCart.map(item => `
        <div class="cart-item">
            <span>${item.name}</span>
            <div class="quantity-controls">
                <button onclick="updateQuantity(${item.id}, -1)">-</button>
                <input type="number" 
                       value="${item.quantity}" 
                       min="0" 
                       onchange="updateQuantityDirect(${item.id}, this.value)"
                       onkeyup="if(event.key === 'Enter') this.blur()">
                <button onclick="updateQuantity(${item.id}, 1)">+</button>
                <span>$${(item.price * item.quantity).toFixed(2)}</span>
            </div>
        </div>
    `).join('');

    const total = currentCart.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    document.getElementById('cartTotal').textContent = total.toFixed(2);

    // Add override button to total section
    const totalSection = document.querySelector('.total-section');
    if (!totalSection.querySelector('.override-button')) {
        const overrideButton = document.createElement('button');
        overrideButton.textContent = 'Price Override';
        overrideButton.onclick = showPriceOverridePopup;
        overrideButton.classList.add('override-button');
        totalSection.insertBefore(overrideButton, totalSection.lastElementChild);
    }
}

function updateQuantity(itemId, change) {
    const item = currentCart.find(i => i.id === itemId);
    if (!item) return;

    item.quantity += change;
    if (item.quantity <= 0) {
        currentCart = currentCart.filter(i => i.id !== itemId);
    }
    updateCartDisplay();
}

function updateQuantityDirect(itemId, newQuantity) {
    const item = currentCart.find(i => i.id === itemId);
    if (!item) return;

    newQuantity = parseInt(newQuantity) || 0;
    if (newQuantity <= 0) {
        currentCart = currentCart.filter(i => i.id !== itemId);
    } else {
        item.quantity = newQuantity;
    }
    updateCartDisplay();
}

function clearCart() {
    currentCart = [];
    updateCartDisplay();
}

async function deleteItem(itemId) {
    if (!window.isAdmin) return;
    if (!confirm('Are you sure you want to delete this item?')) return;
    
    try {
        const response = await fetch(`/api/pos-items/${itemId}`, {
            method: 'DELETE'
        });
        if (response.ok) {
            savedItems = savedItems.filter(item => item.id !== itemId);
            renderItems();
        }
    } catch (error) {
        console.error('Error deleting item:', error);
        alert('Error deleting item');
    }
}

async function generateInvoice() {
    if (currentCart.length === 0) {
        alert('Cart is empty!');
        return;
    }

    try {
        const response = await fetch('/api/generate-pos-invoice', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                items: currentCart.map(item => ({
                    name: item.name,
                    description: item.description || '',
                    unitCost: item.price,
                    quantity: item.quantity,
                    gstPercentage: item.gst || 0  // Default to 10% if not specified
                }))
            })
        });

        if (response.ok) {
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = 'invoice.pdf';
            a.click();
            clearCart();
        } else {
            alert('Error generating invoice');
        }
    } catch (error) {
        console.error('Error:', error);
        alert('Error generating invoice');
    }
}

function showAddItemModal() {
    if (!window.isAdmin) return;
    document.getElementById('addItemModal').style.display = 'block';
}

function closeAddItemModal() {
    document.getElementById('addItemModal').style.display = 'none';
}

function showAddCategoryModal() {
    if (!window.isAdmin) return;
    document.getElementById('addCategoryModal').style.display = 'block';
}

function closeAddCategoryModal() {
    document.getElementById('addCategoryModal').style.display = 'none';
}

document.getElementById('addItemForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    
    try {
        const response = await fetch('/api/pos-items', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                name: formData.get('name'),
                description: formData.get('description'),
                price: parseFloat(formData.get('price')),
                gst: parseFloat(formData.get('gst')),
                categoryId: formData.get('category')
            })
        });

        if (response.ok) {
            await loadSavedItems();
            closeAddItemModal();
            e.target.reset();
        } else {
            alert('Error saving item');
        }
    } catch (error) {
        console.error('Error:', error);
        alert('Error saving item');
    }
});

document.getElementById('addCategoryForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    
    try {
        const response = await fetch('/api/pos-categories', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                name: formData.get('name')
            })
        });

        if (response.ok) {
            await loadCategories();
            closeAddCategoryModal();
            e.target.reset();
        } else {
            alert('Error saving category');
        }
    } catch (error) {
        console.error('Error:', error);
        alert('Error saving category');
    }
});

async function deleteCategory(categoryId) {
    if (!window.isAdmin) return;
    if (!confirm('Are you sure you want to delete this category? All items in this category will be moved to "Uncategorized".')) return;
    
    try {
        const response = await fetch(`/api/pos-categories/${categoryId}`, {
            method: 'DELETE'
        });
        if (response.ok) {
            await loadCategories();
            await loadSavedItems();
            if (currentCategory === categoryId) {
                filterByCategory('all');
            }
        } else {
            alert('Error deleting category');
        }
    } catch (error) {
        console.error('Error deleting category:', error);
        alert('Error deleting category');
    }
}

function showEditItemModal(item) {
    if (!window.isAdmin) return;
    const modal = document.getElementById('editItemModal');
    if (!modal) return;
    
    const form = document.getElementById('editItemForm');
    form.querySelector('input[name="itemId"]').value = item.id;
    form.querySelector('input[name="name"]').value = item.name;
    form.querySelector('input[name="description"]').value = item.description || '';
    form.querySelector('input[name="price"]').value = item.price;
    form.querySelector('input[name="gst"]').value = item.gst || 0;
    form.querySelector('select[name="category"]').value = item.categoryId || '';
    
    modal.style.display = 'block';
}

function closeEditItemModal() {
    document.getElementById('editItemModal').style.display = 'none';
}

document.getElementById('editItemForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const itemId = formData.get('itemId');
    
    try {
        const response = await fetch(`/api/pos-items/${itemId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                name: formData.get('name'),
                description: formData.get('description'),
                price: parseFloat(formData.get('price')),
                gst: parseFloat(formData.get('gst')),
                categoryId: formData.get('category') || null
            })
        });

        if (response.ok) {
            await loadSavedItems();
            closeEditItemModal();
            e.target.reset();
        } else {
            alert('Error updating item');
        }
    } catch (error) {
        console.error('Error:', error);
        alert('Error updating item');
    }
});

// Add event listeners for search functionality
document.addEventListener('DOMContentLoaded', () => {
    console.log('Setting up search event listeners...');
    
    // Search button click event
    const searchButton = document.getElementById('searchButton');
    if (searchButton) {
        console.log('Search button found, adding click listener');
        searchButton.addEventListener('click', () => {
            const searchPopup = document.getElementById('searchPopup');
            if (searchPopup) {
                searchPopup.style.display = 'block';
                console.log('Search popup opened');
            } else {
                console.error('Search popup element not found');
            }
        });
    } else {
        console.error('Search button not found');
    }

    // Submit search button click event
    const submitSearchButton = document.getElementById('submitSearchButton');
    if (submitSearchButton) {
        console.log('Submit search button found, adding click listener');
        submitSearchButton.addEventListener('click', performSearch);
    } else {
        console.error('Submit search button not found');
    }

    // Search input Enter key event
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
        console.log('Search input found, adding keypress listener');
        searchInput.addEventListener('keypress', function(event) {
            if (event.key === 'Enter') {
                event.preventDefault();
                performSearch();
            }
        });
    } else {
        console.error('Search input not found');
    }
});

// Function to perform search
async function performSearch() {
    try {
        console.log('Performing search...');
        const searchInput = document.getElementById('searchInput');
        if (!searchInput) {
            throw new Error('Search input element not found');
        }

        const query = searchInput.value.toLowerCase().trim();
        if (!query) {
            console.log('Empty search query');
            return;
        }
        console.log('Search query:', query);

        // Make API call to search endpoint
        const response = await fetch(`/api/search?q=${encodeURIComponent(query)}`);
        if (!response.ok) {
            throw new Error('Search request failed');
        }

        const data = await response.json();
        console.log('Search results:', data);

        // Display results in the search results popup
        const searchResultsGrid = document.getElementById('searchResultsGrid');
        if (!searchResultsGrid) {
            throw new Error('Search results grid not found');
        }

        searchResultsGrid.innerHTML = data.items.map(item => `
            <div class="item-button">
                <h3>${item.name}</h3>
                <p>$${item.price.toFixed(2)}</p>
                <div class="item-actions">
                    <button onclick="addToCart(${item.id}); closeSearchResultsPopup();">Add to Cart</button>
                </div>
            </div>
        `).join('');

        // Close search popup and show results popup
        closeSearchPopup();
        document.getElementById('searchResultsPopup').style.display = 'block';

        console.log('Search completed successfully');
    } catch (error) {
        console.error('Error in performSearch:', error);
        alert('Error performing search. Please try again.');
    }
}

// Function to close search popup
function closeSearchPopup() {
    try {
        const searchInput = document.getElementById('searchInput');
        if (searchInput) {
            searchInput.value = ''; // Clear the input when closing
        }
        document.getElementById('searchPopup').style.display = 'none';
        console.log('Search popup closed');
    } catch (error) {
        console.error('Error closing search popup:', error);
    }
}

// Add this new function to close search results popup
function closeSearchResultsPopup() {
    document.getElementById('searchResultsPopup').style.display = 'none';
}

function showPriceOverridePopup() {
    document.getElementById('priceOverridePopup').style.display = 'block';
    document.getElementById('overrideAmount').value = '';
    document.getElementById('overrideReason').value = '';
}

function closePriceOverridePopup() {
    document.getElementById('priceOverridePopup').style.display = 'none';
}

function applyPriceOverride(action) {
    const amount = parseFloat(document.getElementById('overrideAmount').value);
    const reason = document.getElementById('overrideReason').value;
    
    if (!amount || !reason) {
        alert('Please enter both amount and reason for the override');
        return;
    }

    const currentTotal = parseFloat(document.getElementById('cartTotal').textContent);
    let newTotal = currentTotal;

    switch(action) {
        case 'add':
            newTotal = currentTotal + amount;
            break;
        case 'subtract':
            newTotal = Math.max(0, currentTotal - amount);
            break;
        case 'set':
            newTotal = amount;
            break;
    }

    // Add override to cart as a special item
    const overrideItem = {
        id: 'override_' + Date.now(),
        name: `Price Override (${reason})`,
        price: newTotal - currentTotal,
        quantity: 1,
        isOverride: true
    };

    currentCart.push(overrideItem);
    updateCartDisplay();
    closePriceOverridePopup();
}