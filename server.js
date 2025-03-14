require("dotenv").config();
const express = require("express");
const session = require("express-session");
const PDFDocument = require("pdfkit");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const CryptoJS = require("crypto-js");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { v4: uuidv4 } = require("uuid");
const moment = require("moment");
const bcrypt = require("bcrypt");
const ejs = require("ejs");
const multer = require("multer");
const sharp = require("sharp");
const expressLayouts = require("express-ejs-layouts");
const taxConfig = require("./taxConfig");
const taxCalculator = require("./taxCalculator");
const fsPromises = require('fs').promises;

const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

const app = express();
const PORT = process.env.PORT || 3000;

app.use(expressLayouts);
app.set("layout", "layout");
app.set("view engine", "ejs");

// Add this near the top of your file
const users = process.env.MOLE_SAFE_USERS.split(",").reduce((acc, user) => {
  const [username, password] = user.split(":");
  acc[username] = password;
  return acc;
}, {});

// Set up EJS as the view engine
app.set("view engine", "ejs");
app.set("views", path.join(__dirname, "views"));

// Middleware
app.use(
  helmet({
    contentSecurityPolicy: false,
  })
);
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(
  session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: true,
    cookie: { secure: process.env.NODE_ENV === "production" },
  })
);

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 1000,
  message: "Too many requests from this IP, please try again later.",
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Encryption key
const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY ;

// Secure data directory
const dataDir = path.join(__dirname, ".data");
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}
if (!fs.existsSync(path.join(dataDir, "receipts"))) {
  fs.mkdirSync(path.join(dataDir, "receipts"), { recursive: true });
}

console.log("Data directory:", dataDir);
console.log("Receipts file path:", path.join(dataDir, "clientreceipts.json"));

// After loading taxConfig
taxConfig.taxFreeThreshold = parseFloat(taxConfig.taxFreeThreshold);
taxConfig.taxBrackets = taxConfig.taxBrackets.map((bracket) => ({
  min: parseFloat(bracket.min),
  max: parseFloat(bracket.max),
  rate: parseFloat(bracket.rate),
  base: parseFloat(bracket.base),
}));

// Password protection middleware
function checkAuth(req, res, next) {
  if (req.session && req.session.authenticated) {
    res.locals.username = req.session.username; // Make username available in templates
    return next();
  } else {
    if (req.xhr) {
      return res.status(401).json({ error: "Not authenticated" });
    }
    return res.redirect("/login");
  }
}

// Serve static files from the 'public' directory
app.use(express.static("public"));
// Route for /tos page
app.get('/tos', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'tos.html'));
});
// Serve the loading screen at the root URL
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'loading.html'));
});

// Routes
app.get("/", (req, res) => {
  res.redirect("/login");
});


app.get("/login", (req, res) => {
  res.render("login", {
    layout: "layout",
    title: "Login",
  });
});

app.post("/login", async (req, res) => {
  try {
    const { username, password } = req.body;
    if (users[username] && users[username] === password) {
      req.session.authenticated = true;
      req.session.username = username;
      req.session.isAdmin = username === 'admin'; // Explicitly set admin status
      res.redirect("/dashboard");
    } else {
      res.status(401).send("Invalid username or password");
    }
  } catch (error) {
    console.error("Error in login process:", error);
    res.status(500).send("Internal Server Error");
  }
});

app.get("/logout", (req, res) => {
  req.session.destroy((err) => {
    if (err) {
      console.error("Error destroying session:", err);
    }
    res.redirect("/login");
  });
});

app.get("/dashboard", checkAuth, (req, res) => {
  res.render("dashboard", {
    layout: "layout",
    title: "Dashboard",
    username: req.session.username,
  });
});

app.get("/create-invoice", checkAuth, (req, res) => {
  res.render("create-invoice");
});
app.post("/generate-invoice", checkAuth, async (req, res) => {
  try {
    const itemNames = Array.isArray(req.body.itemName)
      ? req.body.itemName
      : [req.body.itemName];
    const itemDescriptions = Array.isArray(req.body.itemDescription)
      ? req.body.itemDescription
      : [req.body.itemDescription];
    const itemUnitCosts = Array.isArray(req.body.itemUnitCost)
      ? req.body.itemUnitCost
      : [req.body.itemUnitCost];
    const itemQuantities = Array.isArray(req.body.itemQuantity)
      ? req.body.itemQuantity
      : [req.body.itemQuantity];
    const itemGSTs = Array.isArray(req.body.itemGST)
      ? req.body.itemGST
      : [req.body.itemGST];

    const items = itemNames.map((name, index) => {
      const unitCost = parseFloat(itemUnitCosts[index]);
      const quantity = parseInt(itemQuantities[index]);
      const gstPercentage = parseFloat(itemGSTs[index]);
      const subtotal = unitCost * quantity;
      const gstAmount = subtotal * (gstPercentage / 100);
      const total = subtotal + gstAmount;

      return {
        name: name,
        description: itemDescriptions[index],
        unitCost: unitCost,
        quantity: quantity,
        gstPercentage: gstPercentage,
        gstAmount: gstAmount,
        total: total,
      };
    });

    if (items.length === 0) {
      return res.status(400).send("At least one item is required");
    }

    const totalAmount = items.reduce((sum, item) => sum + item.total, 0);
    const totalGST = items.reduce((sum, item) => sum + item.gstAmount, 0);

    const invoice = {
      crn: generateUniqueCRN(),
      date: new Date().toISOString(),
      clientName: req.body.clientName,
      clientAddress: req.body.clientAddress,
      clientEmail: req.body.clientEmail,
      items: items,
      totalAmount: totalAmount,
      totalGST: totalGST,
      status: "Pending",
      paymentMethod: req.body.paymentMethod,
      cardLastFour:
        req.body.paymentMethod === "Card" ? req.body.cardLastFour : undefined,
    };

    const pdfBuffer = await createInvoicePDF(invoice);

    const encryptedInvoice = encryptData(invoice);
    fs.writeFileSync(
      path.join(dataDir, `${invoice.crn}.enc`),
      encryptedInvoice
    );

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename=invoice_${invoice.crn}.pdf`
    );
    res.send(pdfBuffer);
  } catch (error) {
    console.error("Error generating invoice:", error);
    res.status(500).send("Error generating invoice");
  }
});

app.get("/invoices", checkAuth, (req, res) => {
  try {
    const searchQuery = req.query.search ? req.query.search.toLowerCase() : "";
    const invoiceFiles = fs.readdirSync(dataDir);
    const invoices = invoiceFiles
      .filter((file) => file.endsWith(".enc"))
      .map((file) => {
        const filePath = path.join(dataDir, file);
        const encryptedData = fs.readFileSync(filePath, "utf8");
        try {
          const invoice = decryptData(encryptedData);
          if (
            !invoice ||
            !invoice.crn ||
            !invoice.date ||
            isNaN(new Date(invoice.date).getTime()) ||
            !invoice.totalAmount
          ) {
            return null;
          }
          return invoice;
        } catch (error) {
          console.error(`Error decrypting invoice ${file}:`, error);
          return null;
        }
      })
      .filter((invoice) => invoice !== null)
      .filter((invoice) => {
        if (!searchQuery) return true;
        return (
          invoice.crn.toLowerCase().includes(searchQuery) ||
          (invoice.clientName &&
            invoice.clientName.toLowerCase().includes(searchQuery)) ||
          (invoice.clientEmail &&
            invoice.clientEmail.toLowerCase().includes(searchQuery)) ||
          (invoice.clientAddress &&
            invoice.clientAddress.toLowerCase().includes(searchQuery))
        );
      })
      .sort((a, b) => new Date(b.date) - new Date(a.date));
    res.render("invoices", {
      layout: "layout",
      title: "Invoices",
      invoices: invoices,
      username: req.session.username,
    });
  } catch (error) {
    console.error("Error fetching invoices:", error);
    res.status(500).send("Error fetching invoices");
  }
});

app.get("/invoice/:crn", checkAuth, (req, res) => {
  try {
    const crn = req.params.crn;
    const filePath = path.join(dataDir, `${crn}.enc`);

    if (fs.existsSync(filePath)) {
      const encryptedData = fs.readFileSync(filePath, "utf8");
      let invoice = decryptData(encryptedData);

      console.log("Decrypted data:", invoice);

      if (typeof invoice === "string") {
        try {
          invoice = JSON.parse(invoice);
        } catch (parseError) {
          console.error("Error parsing invoice data:", parseError);
          console.log("Raw decrypted data:", invoice);
          return res.status(500).send("Error parsing invoice data");
        }
      }

      res.render("invoice-details", { invoice: invoice });
    } else {
      res.status(404).send("Invoice not found");
    }
  } catch (error) {
    console.error("Error retrieving invoice:", error);
    res.status(500).send("Error retrieving invoice");
  }
});

// Add a route to handle invoice deletion
app.post("/delete-invoice/:crn", checkAuth, (req, res) => {
  console.log("Delete invoice route hit for CRN:", req.params.crn);
  try {
    const crn = req.params.crn;
    const filePath = path.join(dataDir, `${crn}.enc`);

    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      console.log(`Deleted invoice: ${crn}`);
      res.redirect("/invoices");
    } else {
      res.status(404).send("Invoice not found");
    }
  } catch (error) {
    console.error("Error deleting invoice:", error);
    res.status(500).send("Error deleting invoice");
  }
});

// Helper functions
function generateUniqueCRN() {
  let crn;
  do {
    crn = uuidv4().replace(/-/g, "").substr(0, 10);
  } while (fs.existsSync(path.join(dataDir, `${crn}.enc`)));
  return crn;
}

function encryptData(data) {
  const jsonString = typeof data === "string" ? data : JSON.stringify(data);
  return CryptoJS.AES.encrypt(
    jsonString,
    process.env.ENCRYPTION_KEY
  ).toString();
}

function decryptData(encryptedData) {
  const bytes = CryptoJS.AES.decrypt(encryptedData, process.env.ENCRYPTION_KEY);
  const decryptedString = bytes.toString(CryptoJS.enc.Utf8);
  try {
    return JSON.parse(decryptedString);
  } catch (error) {
    // If parsing fails, return the string as is
    return decryptedString;
  }
}

function createInvoicePDF(invoice) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: "A4", margin: 50 });

    const buffers = [];
    doc.on("data", buffers.push.bind(buffers));
    doc.on("end", () => {
      const pdfData = Buffer.concat(buffers);
      resolve(pdfData);
    });
    // Header with company name and logo
    doc.fontSize(18).text(`${process.env.COMPANY_NAME}`, 50, 50);
    
  // Header with company name and logo
    doc.fontSize(18).text("Mole Safe Networking", 50, 50);
    const logoPath = path.join(__dirname, "public", "images", "logo.png");
    if (fs.existsSync(logoPath)) {
      doc.image(logoPath, 450, 30, { width: 100 });
    }
    
    // Company details
    doc
      .fontSize(10)
      .text(`${process.env.COMPANY_NAME}`, 50, 100)
      .text(`ADDRESS: ${process.env.COMPANY_ADDRESS}`, 50, 115)
      .text(`PHONE: ${process.env.COMPANY_PHONE}`, 50, 130)
      .text(`EMAIL: ${process.env.COMPANY_EMAIL}`, 50, 145)
      .text(`ABN: ${process.env.COMPANY_ABN}`, 50, 160);

    // Invoice details
    doc.fontSize(16).font("Helvetica-Bold").text("INVOICE", 350, 100);
    doc
      .fontSize(10)
      .font("Helvetica")
      .text(`Invoice Number: ${invoice.crn}`, 350, 125)
      .text(`Date: ${moment(invoice.date).format("MMMM D, YYYY")}`, 350, 140)
      .text(
        `Due Date: ${moment(invoice.date)
          .add(30, "days")
          .format("MMMM D, YYYY")}`,
        350,
        155
      )
      .text(`Status: ${invoice.status}`, 350, 170)
      .text(`Payment Method: ${invoice.paymentMethod}`, 350, 185);

    // Bill To section
    doc.text("Bill To:", 50, 220);
    doc.text(invoice.clientName || "N/A", 50, 235);
    doc.text(invoice.clientAddress || "N/A", 50, 250);
    doc.text(`Email: ${invoice.clientEmail || "N/A"}`, 50, 265);

    // Add last 4 digits of card if payment method is Card
    if (invoice.paymentMethod === "Card" && invoice.cardLastFour) {
      doc.text(`Card: **** **** **** ${invoice.cardLastFour}`, 350, 200);
    }

    // Separator line
    doc.moveTo(50, 290).lineTo(550, 290).stroke();

    // Add table header
    let yPos = 310;
    doc
      .fontSize(10)
      .font("Helvetica-Bold")
      .text("Item", 50, yPos, { width: 150 })
      .text("Description", 200, yPos, { width: 150 })
      .text("Unit Cost", 350, yPos, { width: 50, align: "right" })
      .text("Qty", 400, yPos, { width: 30, align: "right" })
      .text("GST", 430, yPos, { width: 50, align: "right" })
      .text("Total", 480, yPos, { width: 70, align: "right" });

    // Add table content
    yPos += 20;
    doc.font("Helvetica");
    invoice.items.forEach((item) => {
      doc
        .fontSize(8)
        .text(item.name, 50, yPos, { width: 150 })
        .text(item.description, 200, yPos, { width: 150 })
        .text(item.unitCost.toFixed(2), 350, yPos, {
          width: 50,
          align: "right",
        })
        .text(item.quantity.toString(), 400, yPos, {
          width: 30,
          align: "right",
        })
        .text(item.gstAmount.toFixed(2), 430, yPos, {
          width: 50,
          align: "right",
        })
        .text(item.total.toFixed(2), 480, yPos, { width: 70, align: "right" });
      yPos += 15;
    });

    // Add totals
    yPos += 10;
    doc
      .fontSize(10)
      .font("Helvetica-Bold")
      .text("Subtotal:", 350, yPos)
      .text((invoice.totalAmount - invoice.totalGST).toFixed(2), 480, yPos, {
        width: 70,
        align: "right",
      });
    yPos += 20;
    doc
      .text("Total GST:", 350, yPos)
      .text(invoice.totalGST.toFixed(2), 480, yPos, {
        width: 70,
        align: "right",
      });
    yPos += 20;
    doc
      .text("Total Payable:", 350, yPos)
      .text(invoice.totalAmount.toFixed(2), 480, yPos, {
        width: 70,
        align: "right",
      });

    // Add footer
    doc
      .fontSize(8)
      .font("Helvetica")
      .text("Thank you for your business", 50, 700, {
        align: "center",
        width: 500,
      });

    doc.end();
  });
}

// Function to delete old invoices
function deleteOldInvoices() {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - 450);

  const invoiceFiles = fs.readdirSync(dataDir);
  invoiceFiles.forEach((file) => {
    const filePath = path.join(dataDir, file);
    const encryptedData = fs.readFileSync(filePath, "utf8");
    const invoice = decryptData(encryptedData);

    if (invoice && new Date(invoice.date) < cutoffDate) {
      fs.unlinkSync(filePath);
      console.log(`Deleted old invoice: ${invoice.crn}`);
    }
  });
}

// Function to check and delete old invoices daily
function scheduleInvoiceDeletion() {
  const now = new Date();
  const nextMidnight = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate() + 1
  );
  const timeUntilMidnight = nextMidnight - now;

  setTimeout(() => {
    deleteOldInvoices();
    scheduleInvoiceDeletion(); // Schedule the next run
  }, timeUntilMidnight);
}

// Start the invoice deletion schedule
scheduleInvoiceDeletion();

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

app.post("/update-invoice/:crn", checkAuth, (req, res) => {
  console.log("Received update request for CRN:", req.params.crn);
  console.log("Request body:", req.body);

  try {
    const crn = req.params.crn;
    const updatedInvoice = req.body;

    // Ensure itemName is always an array
    const itemNames = Array.isArray(updatedInvoice["itemName[]"])
      ? updatedInvoice["itemName[]"]
      : [updatedInvoice["itemName[]"]];
    const itemDescriptions = Array.isArray(updatedInvoice["itemDescription[]"])
      ? updatedInvoice["itemDescription[]"]
      : [updatedInvoice["itemDescription[]"]];
    const itemUnitCosts = Array.isArray(updatedInvoice["itemUnitCost[]"])
      ? updatedInvoice["itemUnitCost[]"]
      : [updatedInvoice["itemUnitCost[]"]];
    const itemQuantities = Array.isArray(updatedInvoice["itemQuantity[]"])
      ? updatedInvoice["itemQuantity[]"]
      : [updatedInvoice["itemQuantity[]"]];
    const itemGSTs = Array.isArray(updatedInvoice["itemGST[]"])
      ? updatedInvoice["itemGST[]"]
      : [updatedInvoice["itemGST[]"]];

    const items = itemNames.map((name, index) => {
      const unitCost = parseFloat(itemUnitCosts[index] || 0);
      const quantity = parseInt(itemQuantities[index] || 0);
      const gstPercentage = parseFloat(itemGSTs[index] || 0);
      const subtotal = unitCost * quantity;
      const gstAmount = subtotal * (gstPercentage / 100);
      const total = subtotal + gstAmount;

      return {
        name: name || "",
        description: itemDescriptions[index] || "",
        unitCost: unitCost,
        quantity: quantity,
        gstPercentage: gstPercentage,
        gstAmount: gstAmount,
        total: total,
      };
    });

    const totalAmount = items.reduce((sum, item) => sum + item.total, 0);
    const totalGST = items.reduce((sum, item) => sum + item.gstAmount, 0);

    const invoice = {
      crn: crn,
      date: new Date(updatedInvoice.date).toISOString(),
      clientName: updatedInvoice.clientName || "",
      clientAddress: updatedInvoice.clientAddress || "",
      clientEmail: updatedInvoice.clientEmail || "",
      items: items,
      totalAmount: totalAmount,
      totalGST: totalGST,
      status: updatedInvoice.status || "Pending",
      paymentMethod: updatedInvoice.paymentMethod || "",
    };

    const encryptedInvoice = encryptData(invoice);
    fs.writeFileSync(path.join(dataDir, `${crn}.enc`), encryptedInvoice);

    res.json({ success: true, invoice: invoice });
  } catch (error) {
    console.error("Error updating invoice:", error);
    res.status(500).json({ success: false, error: error.message });
  }
});
app.post("/update-invoice-status/:crn", checkAuth, (req, res) => {
  try {
    const { crn } = req.params;
    const { status } = req.body;

    const filePath = path.join(dataDir, `${crn}.enc`);

    if (fs.existsSync(filePath)) {
      const encryptedData = fs.readFileSync(filePath, "utf8");
      let invoice = decryptData(encryptedData);

      if (typeof invoice === "string") {
        invoice = JSON.parse(invoice);
      }

      invoice.status = status;

      const updatedEncryptedData = encryptData(JSON.stringify(invoice));
      fs.writeFileSync(filePath, updatedEncryptedData);

      res.json({
        success: true,
        message: "Invoice status updated successfully",
      });
    } else {
      res.status(404).json({ success: false, error: "Invoice not found" });
    }
  } catch (error) {
    console.error("Error updating invoice status:", error);
    res.status(500).json({ success: false, error: "Internal server error" });
  }
});

app.get("/generate-pdf/:crn", checkAuth, async (req, res) => {
  try {
    const crn = req.params.crn;
    const filePath = path.join(dataDir, `${crn}.enc`);

    if (fs.existsSync(filePath)) {
      const encryptedData = fs.readFileSync(filePath, "utf8");
      const invoice = decryptData(encryptedData);
      const pdfBuffer = await createInvoicePDF(invoice);

      res.setHeader("Content-Type", "application/pdf");
      res.setHeader(
        "Content-Disposition",
        `attachment; filename=invoice_${crn}.pdf`
      );
      res.send(pdfBuffer);
    } else {
      res.status(404).send("Invoice not found");
    }
  } catch (error) {
    console.error("Error generating PDF:", error);
    res.status(500).send("Error generating PDF");
  }
});
//
function saveInvoices(invoices) {
  const encryptedInvoices = encryptData(invoices);
  fs.writeFileSync(path.join(dataDir, "invoices.json"), encryptedInvoices);
}
app.post("/cleanup-invoices", checkAuth, (req, res) => {
  try {
    const invoiceFiles = fs.readdirSync(dataDir);
    let deletedCount = 0;

    invoiceFiles.forEach((file) => {
      if (file.endsWith(".enc")) {
        const filePath = path.join(dataDir, file);
        const encryptedData = fs.readFileSync(filePath, "utf8");
        let invoice;
        try {
          invoice = decryptData(encryptedData);
        } catch (error) {
          // If decryption fails, delete the file
          fs.unlinkSync(filePath);
          deletedCount++;
          return;
        }

        // Check if the invoice data is valid
        if (
          !invoice ||
          !invoice.crn ||
          !invoice.date ||
          isNaN(new Date(invoice.date).getTime()) ||
          !invoice.totalAmount
        ) {
          fs.unlinkSync(filePath);
          deletedCount++;
        }
      }
    });

    console.log(`Cleaned up ${deletedCount} invalid invoices`);
    res.redirect("/invoices");
  } catch (error) {
    console.error("Error during invoice cleanup:", error);
    res.status(500).send("Error during invoice cleanup");
  }
});

// Add a route to get current user info
app.get("/api/user", checkAuth, (req, res) => {
  res.json({ username: req.session.username });
  res.json({ success: true });
});

// Add these routes after your other routes

app.get("/manage-users", checkAuth, (req, res) => {
  if (req.session.username === "admin") {
    // Only allow admin to manage users
    res.render("manage-users");
  } else {
    res.status(403).send("Access denied");
  }
});

app.get("/api/users", checkAuth, (req, res) => {
  if (req.session.username === "admin") {
    res.json(Object.keys(users));
  } else {
    res.status(403).json({ error: "Access denied" });
  }
});

// Add this helper function to update specific env variables
async function updateEnvVariable(key, value) {
    try {
        const envPath = path.join(__dirname, '.env');
        const envContent = await fsPromises.readFile(envPath, 'utf8');
        const envLines = envContent.split('\n');
        
        // Find and update the specific line
        const updatedLines = envLines.map(line => {
            if (line.startsWith(`${key}=`)) {
                return `${key}=${value}`;
            }
            return line;
        });
        
        // Write back to file
        await fsPromises.writeFile(envPath, updatedLines.join('\n'));
    } catch (error) {
        console.error('Error updating .env file:', error);
        throw error;
    }
}

// Update the user management endpoint
app.post('/api/users', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
        const { username, password } = req.body;
        const currentUsers = process.env.MOLE_SAFE_USERS.split(',');
        
        // Add new user to the list
        currentUsers.push(`${username}:${password}`);
        
        // Update only the MOLE_SAFE_USERS line in .env
        await updateEnvVariable('MOLE_SAFE_USERS', currentUsers.join(','));
        
        // Update the process.env variable
        process.env.MOLE_SAFE_USERS = currentUsers.join(',');
        
        res.json({ success: true });
    } catch (error) {
        console.error('Error adding user:', error);
        res.status(500).json({ error: 'Error adding user' });
    }
});

// Update the delete user endpoint similarly
app.delete('/api/users/:username', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
        const usernameToDelete = req.params.username;
        const currentUsers = process.env.MOLE_SAFE_USERS.split(',');
        
        // Filter out the user to delete
        const updatedUsers = currentUsers.filter(user => 
            !user.startsWith(`${usernameToDelete}:`)
        );
        
        // Update only the MOLE_SAFE_USERS line in .env
        await updateEnvVariable('MOLE_SAFE_USERS', updatedUsers.join(','));
        
        // Update the process.env variable
        process.env.MOLE_SAFE_USERS = updatedUsers.join(',');
        
        res.json({ success: true });
    } catch (error) {
        console.error('Error deleting user:', error);
        res.status(500).json({ error: 'Error deleting user' });
    }
});

app.get("/statistics", checkAuth, (req, res) => {
  res.render("statistics");
});

// POS Terminal routes

app.get("/pos-terminal", checkAuth, (req, res) => {
  res.render("pos-terminal", {
    layout: "layout",
    title: "POS Terminal",
    username: req.session.username,
  });
});

app.get("/api/pos-items", checkAuth, async (req, res) => {
  try {
    const itemsPath = path.join(dataDir, 'pos-items.json');
    let items = [];

    try {
      const data = await fsPromises.readFile(itemsPath, 'utf8');
      items = JSON.parse(data);
    } catch (error) {
      // File doesn't exist or is empty, return an empty array
    }

    res.json(items);
  } catch (error) {
    console.error('Error fetching items:', error);
    res.status(500).json({ error: 'Error fetching items' });
  }
});

app.post("/api/pos-items", checkAuth, async (req, res) => {
  try {
    const itemsPath = path.join(dataDir, 'pos-items.json');
    let items = [];

    try {
      const data = await fsPromises.readFile(itemsPath, 'utf8');
      items = JSON.parse(data);
    } catch (error) {
      // File doesn't exist or is empty, continue with an empty array
    }

    const newItem = {
      id: Date.now(),
      name: req.body.name,
      description: req.body.description,
      price: parseFloat(req.body.price),
      gst: parseFloat(req.body.gst),
      categoryId: req.body.categoryId || null
    };

    items.push(newItem);
    await fsPromises.writeFile(itemsPath, JSON.stringify(items, null, 2));
    res.json(newItem);
  } catch (error) {
    console.error('Error adding item:', error);
    res.status(500).json({ error: 'Error adding item' });
  }
});

app.delete("/api/pos-items/:id", checkAuth, async (req, res) => {
  try {
    const itemId = parseInt(req.params.id);
    const itemsPath = path.join(dataDir, 'pos-items.json');
    
    let items = [];
    try {
      const data = await fsPromises.readFile(itemsPath, 'utf8');
      items = JSON.parse(data);
    } catch (error) {
      return res.status(404).json({ error: 'Items not found' });
    }

    const itemIndex = items.findIndex(item => item.id === itemId);
    if (itemIndex === -1) {
      return res.status(404).json({ error: 'Item not found' });
    }

    items.splice(itemIndex, 1);
    await fsPromises.writeFile(itemsPath, JSON.stringify(items, null, 2));
    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting item:', error);
    res.status(500).json({ error: 'Error deleting item' });
  }
});

app.put('/api/pos-items/:id', checkAuth, async (req, res) => {
    try {
        const itemId = parseInt(req.params.id);
        const itemsPath = path.join(dataDir, 'pos-items.json');
        
        let items = [];
        try {
            const data = await fsPromises.readFile(itemsPath, 'utf8');
            items = JSON.parse(data);
        } catch (error) {
            return res.status(404).json({ error: 'Items not found' });
        }

        // Find and update the item
        const itemIndex = items.findIndex(item => item.id === itemId);
        if (itemIndex === -1) {
            return res.status(404).json({ error: 'Item not found' });
        }

        // Update item while preserving its ID
        items[itemIndex] = {
            ...items[itemIndex],
            ...req.body,
            id: itemId // Ensure ID doesn't change
        };

        await fsPromises.writeFile(itemsPath, JSON.stringify(items, null, 2));
        res.json(items[itemIndex]);
    } catch (error) {
        res.status(500).json({ error: 'Error updating item' });
    }
});

app.get("/api/pos-categories", checkAuth, async (req, res) => {
  try {
    const categoriesPath = path.join(dataDir, 'pos-categories.json');
    let categories = [];

    try {
      const data = await fsPromises.readFile(categoriesPath, 'utf8');
      categories = JSON.parse(data);
    } catch (error) {
      // File doesn't exist or is empty, return an empty array
    }

    res.json(categories);
  } catch (error) {
    console.error('Error fetching categories:', error);
    res.status(500).json({ error: 'Error fetching categories' });
  }
});

app.post("/api/pos-categories", checkAuth, async (req, res) => {
  try {
    const categoriesPath = path.join(dataDir, 'pos-categories.json');
    let categories = [];

    try {
      const data = await fsPromises.readFile(categoriesPath, 'utf8');
      categories = JSON.parse(data);
    } catch (error) {
      // File doesn't exist or is empty, continue with an empty array
    }

    const newCategory = {
      id: Date.now(),
      name: req.body.name
    };

    categories.push(newCategory);
    await fsPromises.writeFile(categoriesPath, JSON.stringify(categories, null, 2));
    res.json(newCategory);
  } catch (error) {
    console.error('Error adding category:', error);
    res.status(500).json({ error: 'Error adding category' });
  }
});

app.delete("/api/pos-categories/:id", checkAuth, async (req, res) => {
  try {
    const categoryId = parseInt(req.params.id);
    const categoriesPath = path.join(dataDir, 'pos-categories.json');
    const itemsPath = path.join(dataDir, 'pos-items.json');
    
    let categories = [];
    try {
      const data = await fsPromises.readFile(categoriesPath, 'utf8');
      categories = JSON.parse(data);
    } catch (error) {
      return res.status(404).json({ error: 'Categories not found' });
    }

    const categoryIndex = categories.findIndex(category => category.id === categoryId);
    if (categoryIndex === -1) {
      return res.status(404).json({ error: 'Category not found' });
    }

    categories.splice(categoryIndex, 1);
    await fsPromises.writeFile(categoriesPath, JSON.stringify(categories, null, 2));

    // Move items from the deleted category to "uncategorized"
    let items = [];
    try {
      const data = await fsPromises.readFile(itemsPath, 'utf8');
      items = JSON.parse(data);
    } catch (error) {
      // File doesn't exist or is empty, continue with an empty array
    }

    items = items.map(item => {
      if (item.categoryId === categoryId) {
        return { ...item, categoryId: null };
      }
      return item;
    });

    await fsPromises.writeFile(itemsPath, JSON.stringify(items, null, 2));
    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting category:', error);
    res.status(500).json({ error: 'Error deleting category' });
  }
});

app.post("/api/pos-generate-invoice", checkAuth, async (req, res) => {
  try {
    const { cartItems, clientName, clientAddress, clientEmail, paymentMethod, cardLastFour } = req.body;

    const items = cartItems.map(item => {
      const gstPercentage = item.gst || 0;
      const subtotal = item.price * item.quantity;
      const gstAmount = subtotal * (gstPercentage / 100);
      const total = subtotal + gstAmount;

      return {
        name: item.name,
        description: item.description || "",
        unitCost: item.price,
        quantity: item.quantity,
        gstPercentage: gstPercentage,
        gstAmount: gstAmount,
        total: total
      };
    });

    const totalAmount = items.reduce((sum, item) => sum + item.total, 0);
    const totalGST = items.reduce((sum, item) => sum + item.gstAmount, 0);

    const invoice = {
      crn: generateUniqueCRN(),
      date: new Date().toISOString(),
      items: items,
      totalAmount: totalAmount,
      totalGST: totalGST,
      status: "Pending"
    };

    const pdfBuffer = await createInvoicePDF(invoice);
    const encryptedInvoice = encryptData(invoice);
    
    await fsPromises.writeFile(
      path.join(dataDir, `${invoice.crn}.enc`),
      encryptedInvoice
    );

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=invoice_${invoice.crn}.pdf`);
    res.send(pdfBuffer);
  } catch (error) {
    console.error('Error generating invoice:', error);
    res.status(500).send('Error generating invoice');
  }
});

app.get("/api/invoice-stats", checkAuth, (req, res) => {
  try {
    const invoiceFiles = fs.readdirSync(dataDir);
    const invoices = invoiceFiles
      .filter((file) => file.endsWith(".enc"))
      .map((file) => {
        const filePath = path.join(dataDir, file);
        const encryptedData = fs.readFileSync(filePath, "utf8");
        return decryptData(encryptedData);
      })
      .filter((invoice) => invoice !== null);

    const totalInvoices = invoices.length;
    const paidInvoices = invoices.filter(
      (invoice) => invoice.status === "Paid"
    ).length;
    const pendingInvoices = totalInvoices - paidInvoices;

    res.json({
      totalInvoices,
      paidInvoices,
      pendingInvoices,
    });
  } catch (error) {
    console.error("Error fetching invoice stats:", error);
    res.status(500).json({ error: "Error fetching invoice stats" });
  }
});

app.get("/api-docs", checkAuth, (req, res) => {
  res.render("api-docs");
});
app.get("/income", checkAuth, (req, res) => {
  try {
    const financialYear = taxConfig.financialYear;
    const invoices = getInvoices();
    const totalRevenue = invoices.reduce(
      (sum, invoice) => sum + (invoice.totalAmount || 0),
      0
    );
    const businessLosses = getBusinessLosses();
    const deductions = getDeductions();

    const deductionsObject = deductions.reduce((obj, deduction) => {
      const category = deduction.category || "other";
      obj[category] = (obj[category] || 0) + Number(deduction.amount);
      return obj;
    }, {});

    const totalDeductions = Object.values(deductionsObject).reduce(
      (sum, amount) => sum + amount,
      0
    );
    const taxableIncome = Math.max(
      0,
      totalRevenue -
        totalDeductions -
        Object.values(businessLosses).reduce((sum, amount) => sum + amount, 0)
    );
    
    // Use the taxCalculator functions with taxConfig
    const incomeTax = taxCalculator.calculateIncomeTax(
      taxableIncome,
      taxConfig
    );
    const medicareLevy = taxCalculator.calculateMedicareLevy(
      taxableIncome,
      taxConfig
    );
    
    const totalTax = incomeTax + medicareLevy;
    const netIncome = taxableIncome - totalTax;

    res.render("income", {
      financialYear,
      totalRevenue,
      businessLosses,
      deductions: deductionsObject,
      totalDeductions,
      taxableIncome,
      incomeTax,
      medicareLevy,
      totalTax,
      netIncome,
      taxConfig,
    });
  } catch (error) {
    console.error("Error generating income summary:", error);
    res.status(500).send("Error generating income summary: " + error.message);
  }
});
app.post("/update-business-losses", checkAuth, (req, res) => {
  try {
    const { previousYearLosses, currentYearLosses, capitalLosses } = req.body;
    const businessLosses = {
      previousYearLosses: parseFloat(previousYearLosses) || 0,
      currentYearLosses: parseFloat(currentYearLosses) || 0,
      capitalLosses: parseFloat(capitalLosses) || 0,
    };
    const filePath = path.join(dataDir, "businessLosses.json");
    fs.writeFileSync(filePath, JSON.stringify(businessLosses, null, 2));
    res.redirect("/income");
  } catch (error) {
    console.error("Error updating business losses:", error);
    res.status(500).send("Error updating business losses");
  }
});
app.post("/delete-receipt/:id", checkAuth, (req, res) => {
  try {
    const receiptId = req.params.id;
    const receiptsFilePath = path.join(dataDir, "clientreceipts.json");

    // Read existing receipts
    let receipts = [];
    if (fs.existsSync(receiptsFilePath)) {
      const encryptedData = fs.readFileSync(receiptsFilePath, "utf8");
      receipts = decryptData(encryptedData);
    }

    // Find and remove the receipt
    const updatedReceipts = receipts.filter(
      (receipt) => receipt.id !== receiptId
    );

    // Save updated receipts
    const encryptedData = encryptData(updatedReceipts);
    fs.writeFileSync(receiptsFilePath, encryptedData);

    // Delete associated image if it exists
    const imageFilePath = path.join(
      dataDir,
      "receipts",
      `receipt_${receiptId}.jpg`
    );
    if (fs.existsSync(imageFilePath)) {
      fs.unlinkSync(imageFilePath);
    }

    res.redirect("/receipts");
  } catch (error) {
    console.error("Error deleting receipt:", error);
    res.status(500).send("Error deleting receipt");
  }
});
function calculateTaxableIncome(totalRevenue, businessLosses, deductions) {
  let taxableIncome = totalRevenue;

  // Apply business losses
  const totalLosses = Object.values(businessLosses).reduce(
    (sum, loss) => sum + loss,
    0
  );
  taxableIncome -= totalLosses;

  // Apply deductions
  const totalDeductions = Object.values(deductions).reduce(
    (sum, deduction) => sum + deduction,
    0
  );
  taxableIncome -= totalDeductions;

  return Math.max(taxableIncome, 0); // Ensure taxable income is not negative
}

function getBusinessLosses() {
  try {
    const filePath = path.join(dataDir, "businessLosses.json");
    if (fs.existsSync(filePath)) {
      const data = fs.readFileSync(filePath, "utf8");
      return JSON.parse(data);
    }
    return {
      previousYearLosses: 0,
      currentYearLosses: 0,
      capitalLosses: 0,
    };
  } catch (error) {
    console.error("Error getting business losses:", error);
    return {
      previousYearLosses: 0,
      currentYearLosses: 0,
      capitalLosses: 0,
    };
  }
}

function getReceiptDeductions() {
  const receipts = getReceipts();
  const deductions = {
    office_supplies: 0,
    travel: 0,
    meals: 0,
    equipment: 0,
    software: 0,
    utilities: 0,
    rent: 0,
    other: 0,
  };

  receipts.forEach((receipt) => {
    if (deductions.hasOwnProperty(receipt.category)) {
      deductions[receipt.category] += receipt.amount;
    } else {
      deductions.other += receipt.amount;
    }
  });

  // Convert to array format matching custom deductions
  return Object.entries(deductions).map(([category, amount]) => ({
    id: generateUniqueID(),
    description: `Receipt Deduction: ${category.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}`,
    amount: amount,
    category: category,
    date: new Date().toISOString(), // Use current date for consolidated deductions
    reviewed: true, // Mark as reviewed since they come from verified receipts
    userId: 'admin' // Assign to admin since receipts are admin-only
  }));
}

function getDeductions() {
  try {
    const filePath = path.join(dataDir, "deductions.json");
    if (!fs.existsSync(filePath)) {
      return [];
    }

    const encryptedData = fs.readFileSync(filePath, "utf8");
    let deductions = [];
    
    // If the data is not encrypted, parse it directly
    if (encryptedData.startsWith("[")) {
      deductions = JSON.parse(encryptedData);
    } else {
      deductions = decryptData(encryptedData);
    }

    // Filter out invalid deductions and duplicates
    const seenIds = new Set();
    const validDeductions = deductions
      .filter(deduction => {
        // Remove deductions with amount <= 0 or invalid amount
        if (!deduction.amount || deduction.amount <= 0) {
          return false;
        }
        
        // Remove duplicates based on id
        if (seenIds.has(deduction.id)) {
          return false;
        }
        seenIds.add(deduction.id);
        
        return true;
      })
      .map(deduction => ({
        id: deduction.id || generateUniqueID(),
        date: deduction.date || new Date().toISOString(),
        description: deduction.description || '',
        amount: parseFloat(deduction.amount) || 0,
        category: deduction.category || 'other',
        reviewed: Boolean(deduction.reviewed),
        userId: deduction.userId || 'admin',
        source: deduction.source || (deduction.imageFilename ? 'receipt' : 'manual'),
        imageFilename: deduction.imageFilename || null,
        vendor: deduction.vendor || '',
        paymentMethod: deduction.paymentMethod || ''
      }));

    // Sort by date, most recent first
    return validDeductions.sort((a, b) => new Date(b.date) - new Date(a.date));
  } catch (error) {
    console.error("Error getting deductions:", error);
    return [];
  }
}

function getCustomDeductions() {
  const filePath = path.join(dataDir, "deductions.json");
  if (fs.existsSync(filePath)) {
    try {
      const encryptedData = fs.readFileSync(filePath, "utf8");
      console.log("Encrypted custom deductions:", encryptedData);
      // If the data is not encrypted, parse it directly
      if (encryptedData.startsWith("[")) {
        return JSON.parse(encryptedData);
      }
      const decryptedData = decryptData(encryptedData);
      console.log("Decrypted custom deductions:", decryptedData);
      return Array.isArray(decryptedData) ? decryptedData : [];
    } catch (error) {
      console.error("Error reading or decrypting custom deductions:", error);
      return [];
    }
  }
  return [];
}

// Add admin check middleware
function checkAdmin(req, res, next) {
  if (req.session.username === 'admin' && req.session.isAdmin) {
    next();
  } else {
    if (req.xhr) {
      return res.status(403).json({ error: 'Admin access required' });
    }
    return res.redirect('/dashboard');
  }
}

// Update receipt routes to be admin-only and write directly to deductions.json
app.get("/add-receipt", checkAuth, checkAdmin, (req, res) => {
  res.render("add-receipt");
});

app.get("/receipts", checkAuth, checkAdmin, (req, res) => {
  try {
    const deductions = getDeductions();
    const receipts = deductions.filter(d => d.source === 'receipt')
      .sort((a, b) => new Date(b.date) - new Date(a.date));
    res.render("receipts", { receipts });
  } catch (error) {
    console.error("Error fetching receipts:", error);
    res.status(500).send("Error fetching receipts");
  }
});

app.post("/add-receipt", checkAuth, checkAdmin, upload.single("receiptImage"), async (req, res) => {
  try {
    const receipt = {
      id: generateUniqueID(),
      date: new Date(req.body.date).toISOString(),
      vendor: req.body.vendor,
      description: req.body.description,
      amount: parseFloat(req.body.amount),
      category: req.body.category,
      paymentMethod: req.body.paymentMethod,
      reviewed: true,
      userId: 'admin',
      source: 'receipt' // Always set source as receipt
    };

    if (req.file) {
      const filename = `receipt_${receipt.id}${path.extname(req.file.originalname)}`;
      const filepath = path.join(dataDir, "receipts", filename);

      if (!fs.existsSync(path.join(dataDir, "receipts"))) {
        fs.mkdirSync(path.join(dataDir, "receipts"), { recursive: true });
      }

      if (req.file.mimetype === "application/pdf") {
        await fs.promises.writeFile(filepath, req.file.buffer);
      } else {
        await sharp(req.file.buffer).resize(800).toFile(filepath);
      }

      receipt.imageFilename = filename;
    }

    const deductions = getDeductions();
    deductions.push(receipt);
    saveDeductions(deductions);

    res.redirect("/receipts");
  } catch (error) {
    console.error("Error adding receipt:", error);
    res.status(500).send("Error adding receipt");
  }
});

app.post("/delete-receipt/:id", checkAuth, checkAdmin, (req, res) => {
  try {
    const receiptId = req.params.id;
    const deductions = getDeductions();
    
    // Find the receipt to get its image filename
    const receipt = deductions.find(d => d.id === receiptId && d.source === 'receipt');
    
    if (receipt && receipt.imageFilename) {
      const imageFilePath = path.join(dataDir, "receipts", receipt.imageFilename);
      if (fs.existsSync(imageFilePath)) {
        fs.unlinkSync(imageFilePath);
      }
    }

    // Remove the receipt from deductions
    const updatedDeductions = deductions.filter(d => d.id !== receiptId);
    saveDeductions(updatedDeductions);

    res.redirect("/receipts");
  } catch (error) {
    console.error("Error deleting receipt:", error);
    res.status(500).send("Error deleting receipt");
  }
});

app.get("/receipt-image/:filename", checkAuth, (req, res) => {
  const filename = req.params.filename;
  const filepath = path.join(dataDir, "receipts", filename);
  res.download(filepath, (err) => {
    if (err) {
      console.error("Error downloading file:", err);
      res.status(404).send("File not found");
    }
  });
});

function generateUniqueID() {
  return "r" + uuidv4().replace(/-/g, "").substr(0, 9);
}

// Update deductions routes to be admin-only
app.get("/deductions", checkAuth, checkAdmin, (req, res) => {
  try {
    const deductions = getDeductions();
    res.render("deductions", { 
      deductions,
      user: {
        id: req.session.userId,
        isAdmin: true // Always true since we're using checkAdmin
      }
    });
  } catch (error) {
    console.error("Error rendering deductions page:", error);
    res.status(500).send("Error loading deductions. Please try again later.");
  }
});

app.post("/add-deduction", checkAuth, checkAdmin, upload.single("receiptImage"), async (req, res) => {
  try {
    const deduction = {
      id: generateUniqueID(),
      date: new Date(req.body.date).toISOString(),
      vendor: req.body.vendor,
      description: req.body.description,
      amount: parseFloat(req.body.amount),
      category: req.body.category,
      paymentMethod: req.body.paymentMethod,
      reviewed: true, // Mark as reviewed since it's admin-only
      userId: 'admin',
      source: 'receipt' // Always set source as receipt since these should appear in receipts view
    };

    if (req.file) {
      const filename = `receipt_${deduction.id}${path.extname(req.file.originalname)}`;
      const filepath = path.join(dataDir, "receipts", filename);

      if (!fs.existsSync(path.join(dataDir, "receipts"))) {
        fs.mkdirSync(path.join(dataDir, "receipts"), { recursive: true });
      }

      if (req.file.mimetype === "application/pdf") {
        await fs.promises.writeFile(filepath, req.file.buffer);
      } else {
        await sharp(req.file.buffer).resize(800).toFile(filepath);
      }

      deduction.imageFilename = filename;
    }

    const deductions = getDeductions();
    deductions.push(deduction);
    saveDeductions(deductions);

    res.json({ success: true, deduction });
  } catch (error) {
    console.error("Error adding deduction:", error);
    res.status(500).json({ success: false, error: "Error adding deduction" });
  }
});

app.post("/delete-deduction/:id", checkAuth, checkAdmin, (req, res) => {
  const id = req.params.id;
  const deductions = getDeductions();
  const deduction = deductions.find(d => d.id === id);
  
  // Check if user has permission to delete
  if (!deduction || (!req.session.isAdmin && deduction.userId !== req.session.userId)) {
    return res.status(403).json({ success: false, error: 'Permission denied' });
  }
  
  deleteDeduction(id);
  res.json({ success: true });
});

app.post("/update-deduction/:id", checkAuth, checkAdmin, upload.single("receiptImage"), async (req, res) => {
  try {
    const id = req.params.id;
    const deductions = getDeductions();
    const existingDeduction = deductions.find(d => d.id === id);
    
    if (!existingDeduction) {
      return res.status(404).json({ success: false, error: 'Deduction not found' });
    }
    
    // Update all fields while preserving the source
    const updatedDeduction = {
      ...existingDeduction,
      date: new Date(req.body.date).toISOString(),
      vendor: req.body.vendor,
      description: req.body.description,
      amount: parseFloat(req.body.amount),
      category: req.body.category,
      paymentMethod: req.body.paymentMethod,
      userId: req.session.username,
      reviewed: true // Mark as reviewed since it's being updated by admin
    };

    // Handle receipt image if provided
    if (req.file) {
      const filename = `receipt_${id}${path.extname(req.file.originalname)}`;
      const filepath = path.join(dataDir, "receipts", filename);

      if (!fs.existsSync(path.join(dataDir, "receipts"))) {
        fs.mkdirSync(path.join(dataDir, "receipts"), { recursive: true });
      }

      if (req.file.mimetype === "application/pdf") {
        await fs.promises.writeFile(filepath, req.file.buffer);
      } else {
        await sharp(req.file.buffer).resize(800).toFile(filepath);
      }

      updatedDeduction.imageFilename = filename;
      updatedDeduction.source = 'receipt'; // Update source to receipt if new image is uploaded
    }

    // Update the deduction in the array
    const updatedDeductions = deductions.map(d => 
      d.id === id ? updatedDeduction : d
    );

    // Save to file
    saveDeductions(updatedDeductions);

    res.json({ success: true, deduction: updatedDeduction });
  } catch (error) {
    console.error("Error updating deduction:", error);
    res.status(500).json({ success: false, error: "Error updating deduction" });
  }
});

function saveDeductions(deductions) {
  try {
    // Save all deductions to a single file
    const encryptedDeductions = encryptData(deductions);
    fs.writeFileSync(
      path.join(dataDir, "deductions.json"),
      encryptedDeductions
    );
  } catch (error) {
    console.error("Error saving deductions:", error);
    throw error;
  }
}

// Function to merge receipt data into deductions
async function mergeReceiptDataIntoDeductions() {
  try {
    const receiptFilePath = path.join(dataDir, "clientreceipts.json");
    const deductionsFilePath = path.join(dataDir, "deductions.json");
    
    // Get existing deductions
    let allDeductions = [];
    if (fs.existsSync(deductionsFilePath)) {
      const encryptedData = fs.readFileSync(deductionsFilePath, "utf8");
      if (encryptedData.startsWith("[")) {
        allDeductions = JSON.parse(encryptedData);
      } else {
        allDeductions = decryptData(encryptedData);
      }
    }

    // Check if receipts file exists
    if (fs.existsSync(receiptFilePath)) {
      console.log("Found clientreceipts.json, merging data...");
      const encryptedData = fs.readFileSync(receiptFilePath, "utf8");
      let receiptData = [];
      
      if (encryptedData.startsWith("[")) {
        receiptData = JSON.parse(encryptedData);
      } else {
        receiptData = decryptData(encryptedData);
      }

      // Convert receipt data to deduction format and merge
      const receiptDeductions = receiptData.map(receipt => ({
        ...receipt,
        source: 'receipt',
        reviewed: true
      }));

      // Merge arrays, avoiding duplicates by ID
      const existingIds = new Set(allDeductions.map(d => d.id));
      const newDeductions = receiptDeductions.filter(d => !existingIds.has(d.id));
      allDeductions = [...allDeductions, ...newDeductions];

      // Save merged data
      saveDeductions(allDeductions);

      // Remove the old receipts file
      fs.unlinkSync(receiptFilePath);
      console.log("Successfully merged receipt data and removed clientreceipts.json");
    } else {
      console.log("No clientreceipts.json found, no merge needed");
    }
  } catch (error) {
    console.error("Error merging receipt data:", error);
    throw error;
  }
}

// Call the merge function when the server starts
mergeReceiptDataIntoDeductions().catch(console.error);

// Update getReceipts to read directly from deductions.json
function getReceipts() {
  try {
    const deductions = getDeductions();
    // Filter deductions that are either:
    // 1. Marked as source: 'receipt'
    // 2. Have an imageFilename
    // 3. Were added through the add-receipt form (which sets reviewed=true and userId='admin')
    return deductions.filter(d => 
      d.source === 'receipt' || 
      d.imageFilename || 
      (d.reviewed === true && d.userId === 'admin')
    );
  } catch (error) {
    console.error("Error getting receipts:", error);
    return [];
  }
}

function addDeduction(deduction) {
  const deductions = getDeductions();
  deductions.push(deduction);
  fs.writeFileSync(
    path.join(dataDir, "deductions.json"),
    JSON.stringify(deductions)
  );
}

function deleteDeduction(id) {
  let deductions = getDeductions();
  deductions = deductions.filter((d) => d.id !== id);
  fs.writeFileSync(
    path.join(dataDir, "deductions.json"),
    JSON.stringify(deductions)
  );
}

// Add this helper function near readJsonFile
async function writeJsonFile(filePath, data) {
    // Ensure the directory exists
    const dir = path.dirname(filePath);
    if (!fs.existsSync(dir)) {
        await fsPromises.mkdir(dir, { recursive: true });
    }
    await fsPromises.writeFile(filePath, JSON.stringify(data, null, 2));
}

// Add this near the end of your file, before app.listen
const testData = { test: "data" };
const encrypted = encryptData(testData);
const decrypted = decryptData(encrypted);
console.log(
  "Encryption test:",
  JSON.stringify(testData) === JSON.stringify(decrypted) ? "PASSED" : "FAILED"
);

// Remove receipt from expenses
app.post("/remove-receipt/:id", checkAuth, (req, res) => {
  const receiptId = req.params.id;
  let receipts = getReceipts();
  receipts = receipts.filter((receipt) => receipt.id !== receiptId);
  saveReceipts(receipts);
  res.redirect("/receipts");
});

// Remove deduction
app.post("/remove-deduction/:id", checkAuth, (req, res) => {
  const deductionId = req.params.id;
  let deductions = getDeductions();
  deductions = deductions.filter((deduction) => deduction.id !== deductionId);
  saveDeductions(deductions);
  res.redirect("/deductions");
});

function saveReceipts(receipts) {
  const encryptedReceipts = encryptData(receipts);
  fs.writeFileSync(
    path.join(dataDir, "clientreceipts.json"),
    encryptedReceipts
  );
}

function calculateIncomeTax(taxableIncome) {
  if (taxableIncome <= 18200) {
    return 0;
  } else if (taxableIncome <= 45000) {
    return (taxableIncome - 18200) * 0.19;
  } else if (taxableIncome <= 120000) {
    return 5092 + (taxableIncome - 45000) * 0.325;
  } else if (taxableIncome <= 180000) {
    return 29467 + (taxableIncome - 120000) * 0.37;
  } else {
    return 51667 + (taxableIncome - 180000) * 0.45;
  }
}

function calculateMedicareLevy(taxableIncome) {
  if (taxableIncome <= 23365) {
    return 0;
  } else if (taxableIncome <= 29207) {
    return (taxableIncome - 23365) * 0.1;
  } else {
    return taxableIncome * 0.02;
  }
}

function getInvoices() {
  const invoices = fs
    .readdirSync(dataDir)
    .filter((file) => file.endsWith(".enc"))
    .map((file) => {
      const filePath = path.join(dataDir, file);
      const encryptedData = fs.readFileSync(filePath, "utf8");
      return decryptData(encryptedData);
    })
    .filter((invoice) => invoice !== null);
  return invoices;
}

app.get("/settings", checkAuth, (req, res) => {
  res.render("settings", {
    title: "Tax Settings",
    username: req.session.username,
    taxConfig: taxConfig, // Add this line
  });
});
app.post("/update-settings", checkAuth, (req, res) => {
    try {
        const { financialYear, taxFreeThreshold, medicareLevySettings, taxBrackets } = req.body;

        // Validate the data
        if (!financialYear || taxFreeThreshold === undefined || !medicareLevySettings || !taxBrackets) {
            return res.status(400).json({ 
                success: false, 
                error: "Missing required fields" 
            });
        }

        // Validate tax brackets
        if (!Array.isArray(taxBrackets) || taxBrackets.length === 0) {
            return res.status(400).json({ 
                success: false, 
                error: "Invalid tax brackets format" 
            });
        }

        // Ensure tax brackets are in ascending order
        for (let i = 1; i < taxBrackets.length; i++) {
            if (taxBrackets[i].min <= taxBrackets[i-1].min) {
                return res.status(400).json({ 
                    success: false, 
                    error: "Tax brackets must be in ascending order" 
                });
            }
        }

        // Create new tax config
        const newTaxConfig = {
            financialYear,
            taxFreeThreshold: parseInt(taxFreeThreshold),
            medicareLevySettings: {
                min: parseInt(medicareLevySettings.min) || 0,
                max: parseInt(medicareLevySettings.max) || 0,
                rate: parseFloat(medicareLevySettings.rate) || 0
            },
            taxBrackets: taxBrackets.map(bracket => ({
                min: parseInt(bracket.min) || 0,
                max: bracket.max === Infinity ? 1 : (parseInt(bracket.max) || 0),
                rate: parseFloat(bracket.rate) || 0
            }))
        };

        // Save to taxConfig.js
        fs.writeFileSync(
            path.join(__dirname, 'taxConfig.js'),
            `module.exports = ${JSON.stringify(newTaxConfig, null, 2)};`
        );

        // Also save to data directory for backup
        fs.writeFileSync(
            path.join(dataDir, 'taxConfig.json'),
            JSON.stringify(newTaxConfig, null, 2)
        );

        // Clear require cache and reload config
        delete require.cache[require.resolve('./taxConfig')];
        Object.assign(taxConfig, require('./taxConfig'));

        res.json({ success: true });
    } catch (error) {
        console.error('Error updating settings:', error);
        res.status(500).json({ 
            success: false, 
            error: error.message || 'Internal server error' 
        });
    }
});

app.post("/update-invoice/:id", checkAuth, (req, res) => {
  const invoiceId = req.params.id;
  const { companyName, logo, invoiceTitle, footerText, fontSize, color } =
    req.body;

  // Implement logic to update the invoice settings in your data store
  const updatedInvoice = {
    companyName,
    logo,
    title: invoiceTitle,
    footerText,
    fontSize: parseInt(fontSize),
    textColor: color,
  };

  // Save the updated invoice (implement saveInvoice function)
  saveInvoice(invoiceId, updatedInvoice);

  res.json({ success: true });
});

app.get("/edit-invoice/:id", checkAuth, (req, res) => {
  const invoiceId = req.params.id;
  const invoice = getInvoiceById(invoiceId); // Implement this function to fetch the invoice by ID
  if (!invoice) {
    return res.status(404).send("Invoice not found");
  }
  res.render("edit-invoice", { invoice });
});

app.get("/tax-report", checkAuth, (req, res) => {
  try {
    const financialYear = taxConfig.financialYear;
    const invoices = getInvoices();
    const totalRevenue = invoices.reduce(
      (sum, invoice) => sum + (invoice.totalAmount || 0),
      0
    );
    const deductions = getDeductions();
    const totalDeductions = deductions.reduce(
      (sum, deduction) => sum + deduction.amount,
      0
    );
    const taxableIncome = totalRevenue - totalDeductions;
    const incomeTax = taxCalculator.calculateIncomeTax(
      taxableIncome,
      taxConfig
    );
    const medicareLevy = taxCalculator.calculateMedicareLevy(
      taxableIncome,
      taxConfig
    );
    const totalTax = incomeTax + medicareLevy;
    const netIncome = taxableIncome - totalTax;

    res.render("taxReport", {
      financialYear,
      totalRevenue,
      totalDeductions,
      taxableIncome,
      incomeTax,
      medicareLevy,
      totalTax,
      netIncome,
      invoices,
      deductions,
      taxConfig,
    });
  } catch (error) {
    console.error("Error generating tax report:", error);
    res.status(500).send("Error generating tax report");
  }
});

app.get("/manifest.json", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "manifest.json"));
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send("Something broke! Please try again.");
});

app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

app.get('/pos-terminal', checkAuth, (req, res) => {
    res.render('pos-terminal', { username: req.session.username });
});

app.get('/api/pos-items', checkAuth, async (req, res) => {
    try {
        const itemsPath = path.join(dataDir, 'pos-items.json');
        try {
            const data = await fsPromises.readFile(itemsPath, 'utf8');
            const items = JSON.parse(data);
            res.json(items);
        } catch (error) {
            // If file doesn't exist or is invalid, return empty array
            res.json([]);
        }
    } catch (error) {
        res.status(500).json({ error: 'Error loading items' });
    }
});

app.post('/api/pos-items', checkAuth, async (req, res) => {
    try {
        const itemsPath = path.join(dataDir, 'pos-items.json');
        let items = [];
        try {
            const data = await fsPromises.readFile(itemsPath, 'utf8');
            items = JSON.parse(data);
        } catch (error) {
            // If file doesn't exist, start with empty array
        }

        const newItem = {
            id: items.length + 1,
            ...req.body
        };

        items.push(newItem);
        await fsPromises.writeFile(itemsPath, JSON.stringify(items, null, 2));
        res.json(newItem);
    } catch (error) {
        res.status(500).json({ error: 'Error saving item' });
    }
});

app.delete('/api/pos-items/:id', checkAuth, async (req, res) => {
    try {
        const itemId = parseInt(req.params.id);
        const itemsPath = path.join(dataDir, 'pos-items.json');
        
        let items = [];
        try {
            const data = await fsPromises.readFile(itemsPath, 'utf8');
            items = JSON.parse(data);
        } catch (error) {
            return res.status(404).json({ error: 'Items not found' });
        }

        const filteredItems = items.filter(item => item.id !== itemId);
        await fsPromises.writeFile(itemsPath, JSON.stringify(filteredItems, null, 2));
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Error deleting item' });
    }
});

app.post('/api/generate-pos-invoice', checkAuth, async (req, res) => {
    try {
        const items = req.body.items.map(item => {
            const unitCost = parseFloat(item.unitCost);
            const quantity = parseInt(item.quantity);
            const gstPercentage = parseFloat(item.gstPercentage);
            const subtotal = unitCost * quantity;
            const gstAmount = subtotal * (gstPercentage / 100);
            const total = subtotal + gstAmount;

            return {
                name: item.name,
                description: item.description,
                unitCost: unitCost,
                quantity: quantity,
                gstPercentage: gstPercentage,
                gstAmount: gstAmount,
                total: total
            };
        });

        const totalAmount = items.reduce((sum, item) => sum + item.total, 0);
        const totalGST = items.reduce((sum, item) => sum + item.gstAmount, 0);

        const invoice = {
            crn: generateUniqueCRN(),
            date: new Date().toISOString(),
            items: items,
            totalAmount: totalAmount,
            totalGST: totalGST,
            status: "Pending"
        };

        const pdfBuffer = await createInvoicePDF(invoice);
        const encryptedInvoice = encryptData(invoice);
        
        await fsPromises.writeFile(
            path.join(dataDir, `${invoice.crn}.enc`),
            encryptedInvoice
        );

        res.setHeader('Content-Type', 'application/pdf');
        res.setHeader('Content-Disposition', `attachment; filename=invoice_${invoice.crn}.pdf`);
        res.send(pdfBuffer);
    } catch (error) {
        console.error('Error generating invoice:', error);
        res.status(500).send('Error generating invoice');
    }
});

// Add near your other requires
const categoriesPath = path.join(dataDir, 'pos-categories.json');

// Add these new routes
app.get('/api/pos-categories', checkAuth, async (req, res) => {
    try {
        let categories = [];
        try {
            const data = await fsPromises.readFile(categoriesPath, 'utf8');
            categories = JSON.parse(data);
        } catch (error) {
            // If file doesn't exist, return empty array
            await fsPromises.writeFile(categoriesPath, '[]');
        }
        res.json(categories);
    } catch (error) {
        res.status(500).json({ error: 'Error loading categories' });
    }
});

app.post('/api/pos-categories', checkAuth, async (req, res) => {
    try {
        let categories = [];
        try {
            const data = await fsPromises.readFile(categoriesPath, 'utf8');
            categories = JSON.parse(data);
        } catch (error) {
            // If file doesn't exist, start with empty array
        }

        const newCategory = {
            id: categories.length + 1,
            name: req.body.name
        };

        categories.push(newCategory);
        await fsPromises.writeFile(categoriesPath, JSON.stringify(categories, null, 2));
        res.json(newCategory);
    } catch (error) {
        res.status(500).json({ error: 'Error saving category' });
    }
});

// Endpoint to search items
app.get('/api/search', async (req, res) => {
    const query = req.query.q.toLowerCase();
    try {
        // Use .data directory for Glitch.me
        const itemsData = await fsPromises.readFile('.data/pos-items.json', 'utf-8');
        const categoriesData = await fsPromises.readFile('.data/pos-categories.json', 'utf-8');
        
        const items = JSON.parse(itemsData);
        const categories = JSON.parse(categoriesData);

        // Filter items based on the search query
        const filteredItems = items.filter(item => 
            item.name.toLowerCase().includes(query)
        );
        
        // Get unique categories for the filtered items
        const matchingCategories = new Set(filteredItems.map(item => item.categoryId));
        const filteredCategories = categories.filter(category => 
            matchingCategories.has(category.id)
        );

        res.json({ items: filteredItems, categories: filteredCategories });
    } catch (error) {
        console.error('Error reading data:', error);
        res.status(500).json({ error: 'Error reading data' });
    }
});

// Clock-in system routes
app.get('/clock', checkAuth, (req, res) => {
    res.render('clock-in', {
        username: req.session.username,
        isAdmin: req.session.username === 'admin',
        isLoggedIn: true
    });
});

// Clock API endpoints
app.get('/api/clock/status', async (req, res) => {
    try {
        const clockDataPath = path.join(dataDir, 'clock-data.json');
        const clockData = await readJsonFile(clockDataPath);
        const userStatus = clockData.find(entry => 
            entry.username === req.session.username && !entry.clockOut
        );
        res.json({
            isClockedIn: !!userStatus,
            clockInTime: userStatus?.clockIn
        });
    } catch (error) {
        res.status(500).json({ error: 'Error checking clock status' });
    }
});

app.post('/api/clock/in', async (req, res) => {
    try {
        const clockDataPath = path.join(dataDir, 'clock-data.json');
        // Create file if it doesn't exist
        if (!fs.existsSync(clockDataPath)) {
            await fsPromises.writeFile(clockDataPath, JSON.stringify([]));
        }

        const clockData = await readJsonFile(clockDataPath);
        const isAlreadyClockedIn = clockData.some(entry => 
            entry.username === req.session.username && !entry.clockOut
        );

        if (isAlreadyClockedIn) {
            res.status(400).json({ error: 'Already clocked in' });
            return;
        }

        const newEntry = {
            id: Date.now(),
            username: req.session.username,
            clockIn: new Date().toISOString(),
            clockOut: null
        };

        clockData.push(newEntry);
        await writeJsonFile(clockDataPath, clockData);
        res.json(newEntry);
    } catch (error) {
        console.error('Error clocking in:', error);
        res.status(500).json({ error: 'Error clocking in' });
    }
});

app.post('/api/clock/out', async (req, res) => {
    try {
        const clockDataPath = path.join(dataDir, 'clock-data.json');
        const clockData = await readJsonFile(clockDataPath);
        const entryIndex = clockData.findIndex(entry => 
            entry.username === req.session.username && !entry.clockOut
        );

        if (entryIndex === -1) {
            res.status(400).json({ error: 'Not clocked in' });
            return;
        }

        clockData[entryIndex].clockOut = new Date().toISOString();
        await writeJsonFile(clockDataPath, clockData);
        res.json(clockData[entryIndex]);
    } catch (error) {
        res.status(500).json({ error: 'Error clocking out' });
    }
});

app.get('/api/clock/logs', async (req, res) => {
    if (req.session.username !== 'admin') {
        res.status(403).json({ error: 'Unauthorized' });
        return;
    }

    try {
        const clockDataPath = path.join(dataDir, 'clock-data.json');
        const clockData = await readJsonFile(clockDataPath);
        res.json(clockData);
    } catch (error) {
        res.status(500).json({ error: 'Error loading time logs' });
    }
});

// Middleware to check if user is clocked in
async function requireClockIn(req, res, next) {
    if (req.session.username === 'admin') {
        return next(); // Admins can bypass this check
    }

    // Ensure the clock data file exists
    const clockDataPath = path.join(dataDir, 'clock-data.json');
    if (!fs.existsSync(clockDataPath)) {
        await fsPromises.writeFile(clockDataPath, JSON.stringify([]));
    }

    const clockData = await readJsonFile(clockDataPath);
    const isClockedIn = clockData.some(entry => 
        entry.username === req.session.username && !entry.clockOut
    );

    if (!isClockedIn) {
        return res.redirect('/clock'); // Redirect to clock-in page if not clocked in
    }
    next();
}

// Add clock-in requirement to POS routes
app.get('/pos', requireClockIn, (req, res) => {
    // Your existing POS route code
    res.render('pos-terminal', {
        username: req.session.username,
        isAdmin: req.session.username === 'admin'
    });
});

async function readJsonFile(filePath) {
    const data = await fsPromises.readFile(filePath, 'utf8');
    return JSON.parse(data);
}

// Admin time logs page
app.get('/time-logs', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.redirect('/dashboard');
    }

    try {
        // Get all clock data
        const clockData = await readJsonFile(path.join(dataDir, 'clock-data.json'));
        
        // Get unique employees
        const employees = [...new Set(clockData.map(entry => entry.username))];
        
        // Calculate last active time for each employee
        const lastActive = {};
        employees.forEach(employee => {
            const employeeEntries = clockData.filter(entry => entry.username === employee);
            const lastEntry = employeeEntries.sort((a, b) => 
                new Date(b.clockIn) - new Date(a.clockIn)
            )[0];
            lastActive[employee] = lastEntry ? new Date(lastEntry.clockIn).toLocaleString() : 'Never';
        });

        res.render('time-logs', { 
            employees,
            lastActive,
            username: req.session.username,
            isAdmin: req.session.username === 'admin'
        });
    } catch (error) {
        console.error('Error loading time logs:', error);
        res.status(500).send('Error loading time logs');
    }
});

// API endpoint for getting unique employees
app.get('/api/employees', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        res.status(403).json({ error: 'Unauthorized' });
        return;
    }

    try {
        const clockDataPath = path.join(dataDir, 'clock-data.json');
        const clockData = await readJsonFile(clockDataPath);
        const employees = [...new Set(clockData.map(entry => entry.username))];
        res.json(employees);
    } catch (error) {
        res.status(500).json({ error: 'Error loading employees' });
    }
});

// Enhanced time logs endpoint with filtering
app.get('/api/time-logs', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
        let clockData = await readJsonFile(path.join(dataDir, 'clock-data.json'));
        
        // Apply filters
        if (req.query.start) {
            clockData = clockData.filter(log => new Date(log.clockIn) >= new Date(req.query.start));
        }
        if (req.query.end) {
            clockData = clockData.filter(log => new Date(log.clockIn) <= new Date(req.query.end));
        }
        if (req.query.employee) {
            clockData = clockData.filter(log => log.username === req.query.employee);
        }

        // Sort by clock in time, most recent first
        clockData.sort((a, b) => new Date(b.clockIn) - new Date(a.clockIn));

        res.json(clockData);
    } catch (error) {
        res.status(500).json({ error: 'Error loading time logs' });
    }
});

// Add server refresh endpoint
app.post('/api/refresh-server', checkAuth, (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized' });
    }
    
    // Send success response before restarting
    res.json({ success: true });
    
    // Wait a moment before restarting to ensure response is sent
    setTimeout(() => {
        process.exit(0); // Glitch will automatically restart the server
    }, 1000);
});

// Add these new endpoints
app.get('/api/clock/employee-shifts', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
        const clockData = await readJsonFile(path.join(dataDir, 'clock-data.json'));
        let filtered = clockData;

        if (req.query.employee) {
            filtered = filtered.filter(entry => entry.username === req.query.employee);
        }
        if (req.query.start) {
            filtered = filtered.filter(entry => 
                new Date(entry.clockIn) >= new Date(req.query.start)
            );
        }
        if (req.query.end) {
            filtered = filtered.filter(entry => 
                new Date(entry.clockIn) <= new Date(req.query.end)
            );
        }

        res.json(filtered);
    } catch (error) {
        res.status(500).json({ error: 'Error loading shifts' });
    }
});

app.post('/api/clock/manual-entry', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
        const clockData = await readJsonFile(path.join(dataDir, 'clock-data.json'));
        const newEntry = {
            id: Date.now(),
            ...req.body,
            manualEntry: true,
            addedBy: req.session.username
        };
        
        clockData.push(newEntry);
        await writeJsonFile(path.join(dataDir, 'clock-data.json'), clockData);
        res.json(newEntry);
    } catch (error) {
        res.status(500).json({ error: 'Error adding manual entry' });
    }
});

app.get('/api/clock/export', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).send('Unauthorized');
    }

    try {
        const clockData = await readJsonFile(path.join(dataDir, 'clock-data.json'));
        const csv = generateTimeLogsCSV(clockData, req.query);
        
        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', 'attachment; filename=time-logs.csv');
        res.send(csv);
    } catch (error) {
        res.status(500).send('Error exporting time logs');
    }
});

function generateTimeLogsCSV(logs, filters = {}) {
    const headers = ['Employee', 'Clock In', 'Clock Out', 'Duration', 'Manual Entry', 'Added By'];
    let filteredLogs = [...logs];
    
    if (filters.employee) {
        filteredLogs = filteredLogs.filter(log => log.username === filters.employee);
    }
    if (filters.startDate) {
        filteredLogs = filteredLogs.filter(log => new Date(log.clockIn) >= new Date(filters.startDate));
    }
    if (filters.endDate) {
        filteredLogs = filteredLogs.filter(log => new Date(log.clockIn) <= new Date(filters.endDate));
    }

    const rows = filteredLogs.map(log => {
        const duration = calculateDuration(log.clockIn, log.clockOut);
        return [
            log.username,
            new Date(log.clockIn).toLocaleString(),
            log.clockOut ? new Date(log.clockOut).toLocaleString() : 'Still Working',
            duration,
            log.manualEntry ? 'Yes' : 'No',
            log.addedBy || 'System'
        ].join(',');
    });

    return [headers.join(','), ...rows].join('\n');
}

function calculateDuration(start, end) {
    const startTime = new Date(start);
    const endTime = end ? new Date(end) : new Date();
    const duration = Math.floor((endTime - startTime) / 1000 / 60);
    const hours = Math.floor(duration / 60);
    const minutes = duration % 60;
    return `${hours}h ${minutes}m`;
}

app.delete('/api/clock/entry/:id', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
        const clockData = await readJsonFile(path.join(dataDir, 'clock-data.json'));
        const updatedData = clockData.filter(entry => entry.id !== parseInt(req.params.id));
        await writeJsonFile(path.join(dataDir, 'clock-data.json'), updatedData);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Error deleting entry' });
    }
});

app.put('/api/clock/entry/:id', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
        const clockData = await readJsonFile(path.join(dataDir, 'clock-data.json'));
        const index = clockData.findIndex(entry => entry.id === parseInt(req.params.id));
        
        if (index === -1) {
            return res.status(404).json({ error: 'Entry not found' });
        }

        clockData[index] = {
            ...clockData[index],
            ...req.body,
            modifiedBy: req.session.username,
            modifiedAt: new Date().toISOString()
        };

        await writeJsonFile(path.join(dataDir, 'clock-data.json'), clockData);
        res.json(clockData[index]);
    } catch (error) {
        res.status(500).json({ error: 'Error updating entry' });
    }
});

// Employee profile route
app.get('/employee-profile/:username', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.redirect('/dashboard');
    }

    try {
        const employee = req.params.username;
        res.render('employee-profile', { employee });
    } catch (error) {
        res.status(500).send('Error loading employee profile');
    }
});

// Employee stats endpoint
app.get('/api/employee-stats/:username', checkAuth, async (req, res) => {
    if (req.session.username !== 'admin') {
        return res.status(403).json({ error: 'Unauthorized' });
    }

    try {
        const clockData = await readJsonFile(path.join(dataDir, 'clock-data.json'));
        const employeeShifts = clockData.filter(entry => entry.username === req.params.username);
        
        const stats = calculateEmployeeStats(employeeShifts);
        res.json(stats);
    } catch (error) {
        res.status(500).json({ error: 'Error loading employee stats' });
    }
});

function calculateEmployeeStats(shifts) {
    let totalHours = 0;
    let completedShifts = shifts.filter(shift => shift.clockOut);
    
    completedShifts.forEach(shift => {
        const duration = (new Date(shift.clockOut) - new Date(shift.clockIn)) / (1000 * 60 * 60);
        totalHours += duration;
    });

    return {
        totalHours: Math.round(totalHours * 10) / 10,
        avgShiftLength: completedShifts.length ? Math.round((totalHours / completedShifts.length) * 10) / 10 : 0,
        totalShifts: shifts.length,
        completedShifts: completedShifts.length
    };
}

// Add this near your other routes
app.post('/export-deductions-pdf', checkAuth, async (req, res) => {
  try {
    const doc = new PDFDocument();
    const buffers = [];
    
    doc.on('data', buffers.push.bind(buffers));
    doc.on('end', () => {
      const pdfData = Buffer.concat(buffers);
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', 'attachment; filename=deductions.pdf');
      res.send(pdfData);
    });

    // Add title
    doc.fontSize(20).text('Tax Deductions Report', { align: 'center' });
    doc.moveDown();

    // Add date range
    doc.fontSize(12).text(`Generated on: ${new Date().toLocaleDateString()}`, { align: 'right' });
    doc.moveDown();

    // Add table headers
    const headers = ['Date', 'Category', 'Description', 'Amount', 'Source', 'Status'];
    let yPos = doc.y;
    let xPos = 50;
    headers.forEach((header, i) => {
      doc.text(header, xPos, yPos);
      xPos += (i === 2 ? 150 : 85); // Wider column for description
    });

    // Add rows
    doc.moveDown();
    yPos = doc.y;
    req.body.deductions.forEach(d => {
      if (yPos > 700) { // Start new page if near bottom
        doc.addPage();
        yPos = 50;
      }
      
      xPos = 50;
      const date = new Date(d.date).toLocaleDateString();
      const category = d.category.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
      const values = [
        date,
        category,
        d.description,
        `$${d.amount.toFixed(2)}`,
        d.source === 'receipt' ? 'Receipt' : 'Manual',
        d.reviewed ? 'Reviewed' : 'Pending'
      ];

      values.forEach((value, i) => {
        doc.text(value, xPos, yPos, {
          width: i === 2 ? 150 : 85,
          align: i === 3 ? 'right' : 'left'
        });
        xPos += (i === 2 ? 150 : 85);
      });
      
      yPos += 20;
    });

    // Add totals
    doc.moveDown();
    const total = req.body.deductions.reduce((sum, d) => sum + d.amount, 0);
    doc.fontSize(12).text(`Total Deductions: $${total.toFixed(2)}`, { align: 'right' });

    doc.end();
  } catch (error) {
    console.error('Error generating PDF:', error);
    res.status(500).send('Error generating PDF');
  }
});

// Add these routes after your other receipt routes

app.get("/export-receipts", checkAuth, checkAdmin, async (req, res) => {
  try {
    const { format, timeframe, startDate, endDate } = req.query;
    const receipts = getReceipts();
    
    // Filter receipts based on timeframe
    const filteredReceipts = filterReceiptsByTimeframe(receipts, timeframe, startDate, endDate);

    switch (format) {
      case 'pdf':
        const doc = new PDFDocument();
        const buffers = [];
        
        doc.on('data', buffers.push.bind(buffers));
        doc.on('end', () => {
          const pdfData = Buffer.concat(buffers);
          res.setHeader('Content-Type', 'application/pdf');
          res.setHeader('Content-Disposition', 'attachment; filename=receipts.pdf');
          res.send(pdfData);
        });

        // Add title and date
        doc.fontSize(20).text('Receipts Report', { align: 'center' });
        doc.moveDown();
        doc.fontSize(12).text(`Generated on: ${new Date().toLocaleDateString()}`, { align: 'right' });
        doc.moveDown();

        // Add table headers
        const headers = ['Date', 'Vendor', 'Description', 'Amount', 'Category', 'Payment Method'];
        let yPos = doc.y;
        let xPos = 50;
        headers.forEach((header, i) => {
          doc.text(header, xPos, yPos);
          xPos += (i === 2 ? 150 : 85); // Wider column for description
        });

        // Add rows
        doc.moveDown();
        yPos = doc.y;
        filteredReceipts.forEach(receipt => {
          if (yPos > 700) { // Start new page if near bottom
            doc.addPage();
            yPos = 50;
          }
          
          xPos = 50;
          const date = new Date(receipt.date).toLocaleDateString();
          const values = [
            date,
            receipt.vendor || '',
            receipt.description || '',
            `$${receipt.amount.toFixed(2)}`,
            receipt.category.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase()),
            receipt.paymentMethod.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())
          ];

          values.forEach((value, i) => {
            doc.text(value, xPos, yPos, {
              width: i === 2 ? 150 : 85,
              align: i === 3 ? 'right' : 'left'
            });
            xPos += (i === 2 ? 150 : 85);
          });
          
          yPos += 20;
        });

        // Add total
        doc.moveDown();
        const total = filteredReceipts.reduce((sum, r) => sum + r.amount, 0);
        doc.fontSize(12).text(`Total Amount: $${total.toFixed(2)}`, { align: 'right' });

        doc.end();
        break;

      case 'csv':
        let csv = 'Date,Vendor,Description,Amount,Category,Payment Method,Image\n';
        filteredReceipts.forEach(receipt => {
          csv += `${new Date(receipt.date).toLocaleDateString()},`;
          csv += `${(receipt.vendor || '').replace(/,/g, ';')},`;
          csv += `${(receipt.description || '').replace(/,/g, ';')},`;
          csv += `$${receipt.amount.toFixed(2)},`;
          csv += `${receipt.category.replace(/_/g, ' ')},`;
          csv += `${receipt.paymentMethod.replace(/_/g, ' ')},`;
          csv += `${receipt.imageFilename ? 'Yes' : 'No'}\n`;
        });
        
        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', 'attachment; filename=receipts.csv');
        res.send(csv);
        break;

      case 'excel':
        let excel = 'Date\tVendor\tDescription\tAmount\tCategory\tPayment Method\tImage\n';
        filteredReceipts.forEach(receipt => {
          excel += `${new Date(receipt.date).toLocaleDateString()}\t`;
          excel += `${receipt.vendor || ''}\t`;
          excel += `${receipt.description || ''}\t`;
          excel += `$${receipt.amount.toFixed(2)}\t`;
          excel += `${receipt.category.replace(/_/g, ' ')}\t`;
          excel += `${receipt.paymentMethod.replace(/_/g, ' ')}\t`;
          excel += `${receipt.imageFilename ? 'Yes' : 'No'}\n`;
        });
        
        res.setHeader('Content-Type', 'text/tab-separated-values');
        res.setHeader('Content-Disposition', 'attachment; filename=receipts.xls');
        res.send(excel);
        break;

      default:
        res.status(400).send('Invalid export format');
    }
  } catch (error) {
    console.error('Error exporting receipts:', error);
    res.status(500).send('Error exporting receipts');
  }
});

function filterReceiptsByTimeframe(receipts, timeframe, startDate, endDate) {
  return receipts.filter(receipt => {
    const receiptDate = new Date(receipt.date);
    
    switch(timeframe) {
      case 'thisMonth':
        const now = new Date();
        return receiptDate.getMonth() === now.getMonth() && 
               receiptDate.getFullYear() === now.getFullYear();
      
      case 'lastMonth':
        const lastMonth = new Date();
        lastMonth.setMonth(lastMonth.getMonth() - 1);
        return receiptDate.getMonth() === lastMonth.getMonth() && 
               receiptDate.getFullYear() === lastMonth.getFullYear();
      
      case 'thisQuarter':
        const quarterStart = new Date();
        quarterStart.setMonth(Math.floor(quarterStart.getMonth() / 3) * 3);
        quarterStart.setDate(1);
        const quarterEnd = new Date(quarterStart);
        quarterEnd.setMonth(quarterStart.getMonth() + 3);
        return receiptDate >= quarterStart && receiptDate < quarterEnd;
      
      case 'thisYear':
        return receiptDate.getFullYear() === new Date().getFullYear();
      
      case 'lastYear':
        return receiptDate.getFullYear() === new Date().getFullYear() - 1;
      
      case 'custom':
        return (!startDate || receiptDate >= new Date(startDate)) && 
               (!endDate || receiptDate <= new Date(endDate));
      
      default: // 'all'
        return true;
    }
  });
}
