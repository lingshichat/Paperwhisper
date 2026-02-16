const fs = require('fs');
const crypto = require('crypto');

// Configuration
const BATCH_SIZE = 50;
const CODE_PREFIX = 'PW';
const ACTIVATION_LIMIT = 5;
const TYPE = 'lifetime'; // or 'subscription'

function generateCode() {
    // Generate 3 groups of 4 chars: XXXX-XXXX-XXXX
    // Total entropy: 36^12 (overkill but safe)
    const part = () => crypto.randomBytes(3).toString('hex').toUpperCase().substring(0, 4);
    return `${CODE_PREFIX}-${part()}-${part()}-${part()}`;
}

const codes = [];
const kvImportData = [];

for (let i = 0; i < BATCH_SIZE; i++) {
    const code = generateCode();

    // Save for CSV/Excel
    codes.push({
        code: code,
        limit: ACTIVATION_LIMIT,
        type: TYPE,
        generated_at: new Date().toISOString()
    });

    // Save for KV Bulk Import
    // KV Key: RC_<CODE>
    const kvValue = JSON.stringify({
        type: TYPE,
        limit: ACTIVATION_LIMIT,
        usage: 0,
        created_at: Date.now(),
        devices: []
    });

    kvImportData.push({
        key: `RC_${code}`,
        value: kvValue
    });
}

// Write to files
const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

// 1. Human readable list (CSV)
const csvContent = "Code,Limit,Type,Generated At\n" +
    codes.map(c => `${c.code},${c.limit},${c.type},${c.generated_at}`).join('\n');
fs.writeFileSync(`codes_${timestamp}.csv`, csvContent);

// 2. KV Import JSON
fs.writeFileSync(`kv_import_${timestamp}.json`, JSON.stringify(kvImportData, null, 2));

console.log(`Generated ${BATCH_SIZE} codes.`);
console.log(`1. CSV list: codes_${timestamp}.csv`);
console.log(`2. KV Import file: kv_import_${timestamp}.json`);
console.log(`\nTo import to Cloudflare KV:`);
console.log(`npx wrangler kv:key put --binding=PAPER_WHISPER_CODES --bulk kv_import_${timestamp}.json`);
