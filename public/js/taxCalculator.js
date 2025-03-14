const taxConfig = require('./taxConfig');

function calculateIncomeTax(taxableIncome, taxConfig) {
    if (!taxConfig || !taxConfig.taxBrackets || taxConfig.taxBrackets.length === 0) {
        console.warn('Tax configuration is invalid');
        return 0;
    }

    let tax = 0;
    for (const bracket of taxConfig.taxBrackets) {
        if (taxableIncome > bracket.min) {
            const taxableAmount = Math.min(taxableIncome - bracket.min, bracket.max - bracket.min);
            tax += taxableAmount * bracket.rate + bracket.base;
        }
        if (taxableIncome <= bracket.max) break;
    }
    return tax;
}

function calculateMedicareLevy(taxableIncome, taxConfig) {
    if (taxableIncome <= 0) return 0;
    const medicareRate = 0.02; // 2%
    return taxableIncome * medicareRate;
}

function calculateDepreciation(assetType, cost, years) {
    const rate = taxConfig.depreciationRates[assetType];
    if (!rate) {
        throw new Error(`Unknown asset type: ${assetType}`);
    }
    let remainingValue = cost;
    for (let i = 0; i < years; i++) {
        remainingValue *= (1 - rate);
    }
    return cost - remainingValue;
}

module.exports = {
    calculateIncomeTax,
    calculateMedicareLevy,
    calculateDepreciation,
    financialYear: '2023-2024',
    taxFreeThreshold: 18200,
    taxBrackets: [
        { min: 0, max: 18200, rate: 0, base: 0 },
        { min: 18201, max: 45000, rate: 0.19, base: 0 },
        { min: 45001, max: 120000, rate: 0.325, base: 5092 },
        { min: 120001, max: 180000, rate: 0.37, base: 29467 },
        { min: 180001, max: Infinity, rate: 0.45, base: 51667 }
    ]
};