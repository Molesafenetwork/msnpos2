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
            tax += taxableAmount * bracket.rate;
        }
        if (taxableIncome <= bracket.max) break;
    }
    return tax;
}

function calculateMedicareLevy(taxableIncome, taxConfig) {
    if (!taxConfig || !taxConfig.medicareLevySettings) {
        console.warn('Medicare Levy configuration is invalid');
        return 0;
    }

    const settings = taxConfig.medicareLevySettings;
    const MEDICARE_LEVY_RATE = settings.rate ?? 0;
    const MEDICARE_LEVY_MIN = settings.min ?? 0;
    const MEDICARE_LEVY_SHADE_IN_MAX = settings.max ?? 0;

    // If rate is 0, no levy applies
    if (MEDICARE_LEVY_RATE === 0) {
        return 0;
    }

    if (taxableIncome <= MEDICARE_LEVY_MIN) {
        return 0;
    }

    if (taxableIncome > MEDICARE_LEVY_SHADE_IN_MAX) {
        return taxableIncome * MEDICARE_LEVY_RATE;
    }

    // Shade-in range calculation
    const shadeInRange = MEDICARE_LEVY_SHADE_IN_MAX - MEDICARE_LEVY_MIN;
    const incomeOverMin = taxableIncome - MEDICARE_LEVY_MIN;
    const shadeInRate = (incomeOverMin / shadeInRange) * MEDICARE_LEVY_RATE;
    return taxableIncome * shadeInRate;
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
