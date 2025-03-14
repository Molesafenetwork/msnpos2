module.exports = {
  "financialYear": "2025-2026",
  "taxFreeThreshold": 18200,
  "medicareLevySettings": {
    "min": 26000,
    "max": 32500,
    "rate": 0.02
  },
  "taxBrackets": [
    {
      "min": 0,
      "max": 18200,
      "rate": 0
    },
    {
      "min": 18201,
      "max": 45000,
      "rate": 0.19
    },
    {
      "min": 45001,
      "max": 120000,
      "rate": 0.325
    },
    {
      "min": 120001,
      "max": 180000,
      "rate": 0.37
    },
    {
      "min": 180001,
      "max": 9999999999,
      "rate": 0.45
    }
  ]
};