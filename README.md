# MSN Tax Management System

## Changelog

### 2025-01-26 - V1.9.4 (Latest) - System-Wide Enhancements Update
<details>
<summary>Click to expand</summary>
 
**TL;DR**: Major improvements to deductions handling, export functionality, and data management, along with bug fixes and performance optimizations.

#### Detailed Changes

**Deductions & Receipts Management**
* Improved deductions handling with better validation
  * Auto Removes duplicate and $0 value deductions
  * Enhanced filtering for invalid entries
  * Better source tracking for receipts vs manual deductions
* Added comprehensive export functionality
  * New PDF export for deductions and receipts
  * CSV and Excel export options added
  * Customizable date range filtering for exports
* Streamlined receipt management
  * All receipts now stored in `deductions.json`
  * Improved image handling and preview
  * Better categorization and filtering

**Performance & Stability**
* Fixed infinite recursion issue in deductions handling
* Optimized data retrieval and storage
* Added compression support for better response times
* Improved error handling across all operations

**UI/UX Improvements**
* Enhanced deductions page interface
  * Better visibility of valid entries
  * Improved sorting and filtering
  * Clearer display of receipt attachments
* Added export options to relevant pages
* Improved feedback for user actions
* Better error messaging and validation feedback

**Technical Improvements**
* Centralized data storage in `deductions.json`
* Enhanced validation for all data entries
* Improved file handling and storage efficiency
* Better memory management and performance

**Bug Fixes**
* Fixed issues with deductions not appearing in receipts view
* Resolved duplicate entries in exports
* Fixed Medicare Levy calculation issues
* Improved handling of invalid data entries

#### Known Issues
* Medicare Levy calculations may need further refinement
* Some POS terminal features may be unstable for admin users like edit for example

#### Coming Soon
* Enhanced reporting features
* Improved tax calculation accuracy
* Further POS terminal stability improvements
</details>
---

### 2025-01-25 - V1.9.3 - Admin Access Control Update

<details>
<summary>Click to expand</summary>

**Key Changes:**
* Added admin-only restrictions for receipt and deduction management
* Improved dashboard organization and UI
* Enhanced security features and access controls
* Added server-side validation and better error handling
* Updated documentation and deployment instructions

**Known Issues:**
* None noticed

**Planned Features:**
* Enhanced audit logging
* Granular permissions
* Improved admin reporting
</details>

---

<h1> msninvoices v1.9.4 </h1>
<h2>install guide</h2>
<b> A 1. use a simple .sh script to install theirs a couple for diffrent hardware and needs the reccomended is oemssdprod.sh this will setup encryption keys and setup admin commands pretty much a one click install itll also guide you through what needs changes eg the .env config </b>
<b>B 1. import this to glitch.me to use for free... nvm glitch is gone</b>

<b>2. use the terminal & crypto.js to generate a encryption key paste the below code into the terminal: 

node -e "const CryptoJS = require('crypto-js'); const key = CryptoJS.lib.WordArray.random(32); console.log(key.toString());

(although everything added and generated is sotred in the .data directory and isnt public this is recomended)</b>

<b>3. paste the encryption key beside the proper .env veriable ENCRYPTION_KEY=outputed-key</b>

<b>4. update the rest of the veriables to corespond with your needs</b>

<b>5. check  <a href="/.bash_history">.bash_history</a> for more info on crypto.js key generation </b>

<b>6. check  <a href="/.env">.env</a> to see the simple .env layout</b>
