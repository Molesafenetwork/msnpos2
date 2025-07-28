# MSN Tax Management System 
# Minding Your Buisness EST 2022

[![Version](https://img.shields.io/badge/version-1.9.4-blue.svg)](https://github.com/yourusername/msn-tax-management)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A comprehensive tax management system for handling invoices, deductions, receipts, and tax calculations with advanced export capabilities.

## 🚀 Current Version: 1.9.4

---

## 💰 Support Development

Help keep me and this project stay alive and maintained:

### Direct Crypto Donations

**Bitcoin (BTC)**
```
bc1qh5h5y3qyselke5g0x5mg8kw865wx084mnz3xne
```
[![Copy BTC Address](https://img.shields.io/badge/Copy_BTC_Address-orange.svg?logo=bitcoin)](https://trocador.app/?ticker_to=BTC&network_to=BTC&ref=6GZ3qkFXVy)  
[![Donate via AnonPay](https://img.shields.io/badge/Donate_via_AnonPay-orange?logo=bitcoin)](https://trocador.app/?ticker_to=BTC&network_to=BTC&ref=6GZ3qkFXVy)


**Litecoin (LTC)**
```
ltc1qq9m0x240ajc9lvh9zd43eznu08hs8u8wj7423l
```
[![Copy LTC Address](https://img.shields.io/badge/Copy_LTC_Address-lightgrey.svg?logo=litecoin)](https://trocador.app/?ticker_to=LTC&network_to=LTC&ref=6GZ3qkFXVy)  
[![Donate via AnonPay](https://img.shields.io/badge/Donate_via_AnonPay-lightgrey?logo=litecoin)](https://trocador.app/?ticker_to=LTC&network_to=LTC&ref=6GZ3qkFXVy)

**Monero (XMR)**
```
8AEbCxSZ2c9BKkAMghe7p8RvWt4CLv11XKQLyijzfA4dBRmHUFuh9aBZ9vsSdkjFPcS1HrNGvF8vAMN4KdRKtU8gPRpfwW9
```
[![Copy XMR Address](https://img.shields.io/badge/Copy_XMR_Address-orange.svg?logo=monero)](https://trocador.app/?ticker_to=XMR&network_to=XMR&ref=6GZ3qkFXVy)

### Need to Buy Crypto First?
If you don't have crypto yet, you can buy and exchange on [Trocador](https://trocador.app/?ref=6GZ3qkFXVy) and then send to the addresses above.
---

## 📞 Contact & Support

For technical support, bug reports, or general inquiries:

[![Contact Admin](https://img.shields.io/badge/Contact-Admin-blue.svg?logo=mail.ru)](mailto:admin@mole-safe.net)

**Email:** admin@mole-safe.net

---

## 📦 Installation Methods

### Method A: Automated Installation (Recommended)

Use our simple shell script for a one-click installation experience:

```bash
# Download and run the recommended installation script
curl -sSL https://github.com/Molesafenetwork/OEMSSDPROD.sh | bash
```
```bash
# if script downloads but isnt executable use this
chmod +x oemssdprod.sh
./oemssdprod.sh
```

**What the script does:**
- Sets up encryption keys automatically
- Configures admin commands
- Guides you through `.env` configuration
- Handles all dependencies and setup

**Available installation scripts:**
- `oemssdprod.sh` - **Recommended** for production environments
- Other scripts available for different hardware configurations

---

### Method B: Manual Installation

For users who prefer manual setup or need custom configurations:

#### Step 1: Generate Encryption Key

Use Node.js and crypto.js to generate a secure encryption key:

```bash
node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());"
```

#### Step 2: Configure Environment Variables

Copy the generated encryption key and update your `.env` file:

```bash
ENCRYPTION_KEY=your-generated-key-here
# Update other variables according to your needs
```

#### Step 3: Verify Configuration

- Check [`.bash_history`](/.bash_history) for crypto.js key generation details
- Review [`.env`](/.env) file for proper configuration layout
- Ensure all variables correspond to your requirements

**Note:** All generated data is stored in the `.data` directory and remains private, but encryption is still recommended for security.

---

## 📋 Changelog

### 2025-01-26 - V1.9.4 (Latest) - System-Wide Enhancements Update

<details>
<summary>🔍 Click to expand detailed changes</summary>

**TL;DR**: Major improvements to deductions handling, export functionality, and data management, along with bug fixes and performance optimizations.

#### 🎯 Detailed Changes

**Deductions & Receipts Management**
- Improved deductions handling with better validation
  - Auto removes duplicate and $0 value deductions
  - Enhanced filtering for invalid entries
  - Better source tracking for receipts vs manual deductions
- Added comprehensive export functionality
  - New PDF export for deductions and receipts
  - CSV and Excel export options added
  - Customizable date range filtering for exports
- Streamlined receipt management
  - All receipts now stored in `deductions.json`
  - Improved image handling and preview
  - Better categorization and filtering

**Performance & Stability**
- Fixed infinite recursion issue in deductions handling
- Optimized data retrieval and storage
- Added compression support for better response times
- Improved error handling across all operations

**UI/UX Improvements**
- Enhanced deductions page interface
  - Better visibility of valid entries
  - Improved sorting and filtering
  - Clearer display of receipt attachments
- Added export options to relevant pages
- Improved feedback for user actions
- Better error messaging and validation feedback

**Technical Improvements**
- Centralized data storage in `deductions.json`
- Enhanced validation for all data entries
- Improved file handling and storage efficiency
- Better memory management and performance

**Bug Fixes**
- Fixed issues with deductions not appearing in receipts view
- Resolved duplicate entries in exports
- Fixed Medicare Levy calculation issues
- Improved handling of invalid data entries

#### ⚠️ Known Issues
- Medicare Levy calculations may need further refinement
- Some POS terminal features may be unstable for admin users (e.g., edit functionality)

#### 🔮 Coming Soon
- Enhanced reporting features
- Improved tax calculation accuracy
- Further POS terminal stability improvements

</details>

---

### 2025-01-25 - V1.9.3 - Admin Access Control Update

<details>
<summary>🔍 Click to expand changes</summary>

**Key Changes:**
- Added admin-only restrictions for receipt and deduction management
- Improved dashboard organization and UI
- Enhanced security features and access controls
- Added server-side validation and better error handling
- Updated documentation and deployment instructions

**Known Issues:**
- None noticed

**Planned Features:**
- Enhanced audit logging
- Granular permissions
- Improved admin reporting

</details>

---

## 🔧 Features

- **Invoice Management** - Create, edit, and track invoices
- **Deductions & Receipts** - Comprehensive receipt management with image support
- **Export Capabilities** - PDF, CSV, and Excel export options
- **Tax Calculations** - Automated tax calculations including Medicare Levy
- **Admin Controls** - Secure admin-only features and access controls
- **Data Security** - Encrypted data storage and secure authentication

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**MSN Tax Management System - Minding Your Buisness v1.9.4** - Streamlining your tax management needs.
