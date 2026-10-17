import { readFile, writeFile } from 'node:fs/promises';
import Ajv2020 from 'ajv/dist/2020.js';
import standaloneCode from 'ajv/dist/standalone/index.js';

// Compile at development time: Workers prohibit dynamic Function evaluation.
const schema = JSON.parse(await readFile(new URL('../../../contracts/revision-v1.schema.json', import.meta.url), 'utf8'));
const ajv = new Ajv2020({ code: { source: true, esm: true, lines: true }, strict: true, strictTuples: false });
const source = '// Generated from contracts/revision-v1.schema.json; npm run generate:validator.\n'
  + standaloneCode(ajv, ajv.compile(schema)).trimEnd() + '\n';
const output = new URL('../src/revision-validator.js', import.meta.url);
if (process.argv.includes('--check')) {
  if ((await readFile(output, 'utf8')).replace(/\r\n/g, '\n') !== source) {
    throw new Error('Revision validator is stale; run npm run generate:validator');
  }
  console.log('Draft 2020-12 validator matches the contract.');
} else {
  await writeFile(output, source);
  console.log('Generated Draft 2020-12 revision validator.');
}
